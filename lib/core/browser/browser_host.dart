import 'dart:async';
import 'dart:convert';

import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:webview_flutter/webview_flutter.dart';

import 'browser_challenge_sheet.dart';
import 'browser_cookie_store.dart';
import 'browser_fetch.dart';
import 'cloudflare_challenge.dart';

/// Owns the process-wide browser fetcher and its single persistent WebView.
class BrowserHost extends StatefulWidget {
  const BrowserHost({super.key, required this.child});

  final Widget child;

  @override
  State<BrowserHost> createState() => _BrowserHostState();
}

class _BrowserHostState extends State<BrowserHost> {
  final _webViewKey = GlobalKey();
  late final bool _supported;
  WebViewBrowserFetch? _browser;
  BrowserFetch? _previousBrowser;
  Widget? _webView;
  Completer<void>? _challengeDismissed;

  bool get _challengeVisible => _challengeDismissed != null;

  @override
  void initState() {
    super.initState();
    // ponytail: Android only; desktop, web, iOS, tests, and background
    // isolates deliberately retain UnavailableBrowserFetch.
    _supported = !kIsWeb && defaultTargetPlatform == TargetPlatform.android;
    if (!_supported) return;

    final controller = WebViewController();
    final browser = WebViewBrowserFetch(
      controller: controller,
      showChallenge: _showChallenge,
      hideChallenge: _hideChallenge,
    );
    _browser = browser;
    _webView = WebViewWidget(key: _webViewKey, controller: controller);
    _previousBrowser = BrowserFetch.instance;
    BrowserFetch.instance = browser;
    unawaited(browser.ready.catchError((Object _) {}));
  }

  Future<void> _showChallenge() {
    if (!mounted) return Future<void>.error(const BrowserChallengeCancelled());
    final existing = _challengeDismissed;
    if (existing != null) return existing.future;
    final completer = Completer<void>();
    setState(() => _challengeDismissed = completer);
    return completer.future;
  }

  void _hideChallenge() {
    final completer = _challengeDismissed;
    if (completer == null) return;
    _challengeDismissed = null;
    if (!completer.isCompleted) completer.complete();
    if (mounted) setState(() {});
  }

  void _cancelChallenge() {
    final completer = _challengeDismissed;
    if (completer == null) return;
    _challengeDismissed = null;
    if (!completer.isCompleted) {
      completer.completeError(const BrowserChallengeCancelled());
    }
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    final challenge = _challengeDismissed;
    _challengeDismissed = null;
    if (challenge != null && !challenge.isCompleted) {
      challenge.completeError(const BrowserChallengeCancelled());
    }
    final browser = _browser;
    if (browser != null) {
      browser.dispose();
      if (identical(BrowserFetch.instance, browser)) {
        BrowserFetch.instance =
            _previousBrowser ?? const UnavailableBrowserFetch();
      }
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final webView = _webView;
    if (!_supported || webView == null) return widget.child;
    return Stack(
      fit: StackFit.expand,
      children: [
        if (!_challengeVisible)
          // ponytail: one 1x1 WebView stays alive offstage behind the app and
          // all browser operations are serialized; never add a second view.
          Positioned(
            left: 0,
            top: 0,
            width: 1,
            height: 1,
            child: IgnorePointer(child: webView),
          ),
        widget.child,
        if (_challengeVisible)
          BrowserChallengeSheet(
            onCancel: _cancelChallenge,
            child: webView,
          ),
      ],
    );
  }
}

/// Android implementation backed by the WebView owned by [BrowserHost].
class WebViewBrowserFetch implements BrowserFetch {
  WebViewBrowserFetch({
    required WebViewController controller,
    required Future<void> Function() showChallenge,
    required VoidCallback hideChallenge,
  })  : _controller = controller,
        _showChallenge = showChallenge,
        _hideChallenge = hideChallenge {
    _ready = _configure();
  }

  static const _platform = MethodChannel('yomi/platform');
  static const _automaticClearanceWait = Duration(seconds: 8);
  static const _pollInterval = Duration(milliseconds: 250);

  final WebViewController _controller;
  final WebViewCookieManager _cookieManager = WebViewCookieManager();
  final Future<void> Function() _showChallenge;
  final VoidCallback _hideChallenge;
  final _SerialQueue _queue = _SerialQueue();
  late final Future<void> _ready;
  Completer<void>? _pageLoaded;
  bool _disposed = false;

  Future<void> get ready => _ready;

  @override
  String get userAgent => const UnavailableBrowserFetch().userAgent;

  Future<void> _configure() async {
    await BrowserCookieStore.refresh();
    await _controller.setJavaScriptMode(JavaScriptMode.unrestricted);
    await _controller.setUserAgent(userAgent);
    await _controller.setNavigationDelegate(NavigationDelegate(
      onPageFinished: (_) {
        final pageLoaded = _pageLoaded;
        if (pageLoaded != null && !pageLoaded.isCompleted) {
          pageLoaded.complete();
        }
      },
      onWebResourceError: (error) {
        if (error.isForMainFrame != true) return;
        final pageLoaded = _pageLoaded;
        if (pageLoaded != null && !pageLoaded.isCompleted) {
          pageLoaded.completeError(StateError(error.description));
        }
      },
    ));
  }

  @override
  Future<String> fetchHtml(
    Uri url, {
    Duration timeout = const Duration(seconds: 30),
    bool interactive = true,
  }) {
    final deadline = DateTime.now().add(timeout);
    return _queue.add(() async {
      try {
        await _until(_ready, deadline);
        _ensureActive();
        await _navigate(url, deadline);
        await _handleChallenge(
          url,
          interactive: interactive,
          deadline: deadline,
        );
        return await _until(_outerHtml(), deadline);
      } on TimeoutException {
        await _abortNavigation();
        rethrow;
      }
    });
  }

  @override
  Future<Map<String, dynamic>> capture(
    Uri url, {
    required String jsHook,
    required String channel,
    Duration timeout = const Duration(seconds: 30),
    bool interactive = true,
  }) {
    final deadline = DateTime.now().add(timeout);
    return _queue.add(() async {
      await _until(_ready, deadline);
      _ensureActive();
      if (!RegExp(r'^[A-Za-z_$][A-Za-z0-9_$]*$').hasMatch(channel)) {
        throw ArgumentError.value(
            channel, 'channel', 'Invalid JavaScript name');
      }

      final captured = Completer<Map<String, dynamic>>();
      await _until(
        _controller.addJavaScriptChannel(
          channel,
          onMessageReceived: (message) {
            if (captured.isCompleted) return;
            try {
              final decoded = jsonDecode(message.message);
              if (decoded is! Map) {
                throw const FormatException(
                    'Browser capture must post a JSON object.');
              }
              final object = <String, dynamic>{};
              for (final entry in decoded.entries) {
                if (entry.key is! String) {
                  throw const FormatException(
                      'Browser capture object keys must be strings.');
                }
                object[entry.key as String] = entry.value;
              }
              captured.complete(object);
            } catch (error, stackTrace) {
              captured.completeError(error, stackTrace);
            }
          },
        ),
        deadline,
      );

      try {
        try {
          await _setDocumentStartScript(jsHook, url, deadline);
          await _navigate(url, deadline);
          await _handleChallenge(
            url,
            interactive: interactive,
            deadline: deadline,
          );
          return await _until(captured.future, deadline);
        } on TimeoutException {
          await _abortNavigation();
          rethrow;
        }
      } finally {
        await _clearDocumentStartScript();
        await _controller.removeJavaScriptChannel(channel);
      }
    });
  }

  Future<void> _navigate(Uri url, DateTime deadline) async {
    final loaded = Completer<void>();
    _pageLoaded = loaded;
    try {
      await _until(_controller.loadRequest(url), deadline);
      await _until(loaded.future, deadline);
    } finally {
      if (identical(_pageLoaded, loaded)) _pageLoaded = null;
    }
  }

  Future<void> _abortNavigation() async {
    try {
      await _controller.loadRequest(Uri.parse('about:blank'));
    } catch (_) {
      // The original TimeoutException is the useful error for the caller.
    }
  }

  Future<void> _handleChallenge(
    Uri url, {
    required bool interactive,
    required DateTime deadline,
  }) async {
    var snapshot = await _until(_snapshot(), deadline);
    if (!snapshot.challenged) {
      await _persistBrowserState(url);
      return;
    }

    final automaticDeadline = DateTime.now().add(_automaticClearanceWait);
    while (DateTime.now().isBefore(automaticDeadline) &&
        DateTime.now().isBefore(deadline)) {
      await _delay(deadline, _pollInterval);
      snapshot = await _until(_snapshot(), deadline);
      if (snapshot.loaded && !snapshot.challenged) {
        await _persistBrowserState(url);
        return;
      }
    }

    if (!interactive) {
      throw TimeoutException('The site check did not clear automatically.');
    }

    final dismissed = _showChallenge();
    try {
      while (true) {
        await Future.any<void>([
          _delay(deadline, _pollInterval),
          dismissed,
        ]);
        snapshot = await _until(_snapshot(), deadline);
        if (snapshot.loaded && !snapshot.challenged) {
          _hideChallenge();
          await dismissed;
          await _persistBrowserState(url);
          return;
        }
      }
    } finally {
      _hideChallenge();
    }
  }

  Future<_PageSnapshot> _snapshot() async {
    final readyState = _javascriptString(
      await _controller.runJavaScriptReturningResult('document.readyState'),
    );
    final title = await _controller.getTitle() ?? '';
    final html = await _outerHtml();
    return _PageSnapshot(
      loaded: readyState == 'complete',
      challenged: hasCloudflareChallengeMarkers('$title\n$html'),
    );
  }

  Future<String> _outerHtml() async => _javascriptString(
        await _controller.runJavaScriptReturningResult(
          'document.documentElement ? document.documentElement.outerHTML : ""',
        ),
      );

  Future<void> _persistBrowserState(Uri url) async {
    await BrowserCookieStore.persist(
      host: url.host,
      cookieHeader: await cookieHeaderFor(url),
      userAgent: userAgent,
    );
  }

  Future<void> _setDocumentStartScript(
    String script,
    Uri url,
    DateTime deadline,
  ) async {
    while (true) {
      try {
        final installed = await _until(
          _platform.invokeMethod<bool>('setDocumentStartScript', {
            'script': script,
            'origin': url.origin,
          }),
          deadline,
        );
        if (installed != true) {
          throw UnsupportedError(
              'This Android WebView cannot inject JavaScript at document start.');
        }
        return;
      } on PlatformException catch (error) {
        if (error.code != 'WEBVIEW_NOT_READY') rethrow;
        await _delay(deadline, const Duration(milliseconds: 50));
      }
    }
  }

  Future<void> _clearDocumentStartScript() async {
    try {
      await _platform.invokeMethod<bool>('setDocumentStartScript', {
        'script': null,
        'origin': null,
      });
    } on PlatformException {
      // The Activity or platform view may already be tearing down.
    }
  }

  @override
  Future<String?> cookieHeaderFor(Uri origin) async {
    final value = await _platform.invokeMethod<String>(
      'getCookies',
      {'url': origin.toString()},
    );
    final trimmed = value?.trim();
    return trimmed == null || trimmed.isEmpty ? null : trimmed;
  }

  @override
  Future<void> clearCookies() async {
    await _cookieManager.clearCookies();
    await BrowserCookieStore.clear();
  }

  void dispose() {
    _disposed = true;
    final pageLoaded = _pageLoaded;
    if (pageLoaded != null && !pageLoaded.isCompleted) {
      pageLoaded.completeError(const BrowserFetchUnavailable());
    }
    _hideChallenge();
    unawaited(_clearDocumentStartScript());
  }

  void _ensureActive() {
    if (_disposed) throw const BrowserFetchUnavailable();
  }

  static String _javascriptString(Object result) {
    if (result is! String) return result.toString();
    try {
      final decoded = jsonDecode(result);
      return decoded is String ? decoded : result;
    } on FormatException {
      return result;
    }
  }

  static Future<T> _until<T>(Future<T> future, DateTime deadline) {
    final remaining = deadline.difference(DateTime.now());
    if (remaining <= Duration.zero) {
      throw TimeoutException('The in-app browser request timed out.');
    }
    return future.timeout(
      remaining,
      onTimeout: () =>
          throw TimeoutException('The in-app browser request timed out.'),
    );
  }

  static Future<void> _delay(DateTime deadline, Duration duration) {
    final remaining = deadline.difference(DateTime.now());
    if (remaining <= Duration.zero) {
      throw TimeoutException('The in-app browser request timed out.');
    }
    return Future<void>.delayed(
      remaining < duration ? remaining : duration,
    );
  }
}

class _PageSnapshot {
  const _PageSnapshot({required this.loaded, required this.challenged});

  final bool loaded;
  final bool challenged;
}

class _SerialQueue {
  Future<void> _tail = Future<void>.value();

  Future<T> add<T>(Future<T> Function() operation) {
    final result = Completer<T>();
    _tail = _tail.then((_) async {
      try {
        result.complete(await operation());
      } catch (error, stackTrace) {
        result.completeError(error, stackTrace);
      }
    });
    return result.future;
  }
}
