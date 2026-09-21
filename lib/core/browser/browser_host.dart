import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';

import 'browser_challenge_sheet.dart';
import 'browser_cookie_store.dart';
import 'browser_fetch.dart';
import 'cloudflare_challenge.dart';

/// Keeps the process-wide fetcher installed; mounts a WebView only for a request.
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

    final browser = WebViewBrowserFetch(
      mountWebView: _mountWebView,
      unmountWebView: _unmountWebView,
      showChallenge: _showChallenge,
      hideChallenge: _hideChallenge,
    );
    _browser = browser;
    _previousBrowser = BrowserFetch.instance;
    BrowserFetch.instance = browser;
  }

  Future<WebViewController> _mountWebView() async {
    if (!mounted) throw const BrowserFetchUnavailable();
    final controller = WebViewController();
    // Hybrid composition keeps the WebView inside the Activity's view tree,
    // which the document-start bridge in MainActivity needs to find it. The
    // default virtual-display path hides it in a Presentation window.
    _webView = WebViewWidget.fromPlatformCreationParams(
      key: _webViewKey,
      params: AndroidWebViewWidgetCreationParams
          .fromPlatformWebViewWidgetCreationParams(
        PlatformWebViewWidgetCreationParams(controller: controller.platform),
        displayWithHybridComposition: true,
      ),
    );
    setState(() {});
    // Layout/attach before navigation. The document-start bridge also retries
    // WEBVIEW_NOT_READY while Android finishes attaching the native view.
    await WidgetsBinding.instance.endOfFrame;
    if (!mounted) throw const BrowserFetchUnavailable();
    return controller;
  }

  Future<void> _unmountWebView() async {
    if (!mounted) return;
    setState(() => _webView = null);
    // Detach this platform view before the serial queue can mount another.
    await WidgetsBinding.instance.endOfFrame;
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
    if (!_supported) return widget.child;
    return Stack(
      fit: StackFit.expand,
      children: [
        if (webView != null && !_challengeVisible)
          // Keep the challenge viewport stable for this request. Idle has no
          // platform view, so ordinary Flutter scrolling avoids composition.
          Positioned.fill(
            child: IgnorePointer(
              child: BrowserChallengeSheet(
                onCancel: _cancelChallenge,
                child: webView,
              ),
            ),
          ),
        KeyedSubtree(key: const ValueKey('browser-app'), child: widget.child),
        if (webView != null && _challengeVisible)
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
    required Future<WebViewController> Function() mountWebView,
    required Future<void> Function() unmountWebView,
    required Future<void> Function() showChallenge,
    required VoidCallback hideChallenge,
  })  : _mountWebView = mountWebView,
        _unmountWebView = unmountWebView,
        _showChallenge = showChallenge,
        _hideChallenge = hideChallenge;

  static const _platform = MethodChannel('yomi/platform');
  static const _automaticClearanceWait = Duration(seconds: 8);
  static const _pollInterval = Duration(milliseconds: 250);

  final Future<WebViewController> Function() _mountWebView;
  final Future<void> Function() _unmountWebView;
  WebViewController? _activeController;
  WebViewController get _controller => _activeController!;
  late final WebViewCookieManager _cookieManager = WebViewCookieManager();
  final Future<void> Function() _showChallenge;
  final VoidCallback _hideChallenge;
  final _SerialQueue _queue = _SerialQueue();
  Completer<void>? _pageLoaded;
  bool _disposed = false;

  @override
  String get userAgent => const UnavailableBrowserFetch().userAgent;

  Future<void> _configure() async {
    final controller = _controller;
    await BrowserCookieStore.refresh();
    await controller.setJavaScriptMode(JavaScriptMode.unrestricted);
    if (Platform.isAndroid && (kDebugMode || kProfileMode)) {
      await AndroidWebViewController.enableDebugging(true);
    }
    await controller.setUserAgent(userAgent);
    await controller.setNavigationDelegate(NavigationDelegate(
      onPageFinished: (_) {
        // Native callbacks can arrive after this request's view was detached.
        if (!identical(_activeController, controller)) return;
        final pageLoaded = _pageLoaded;
        if (pageLoaded != null && !pageLoaded.isCompleted) {
          pageLoaded.complete();
        }
      },
      onWebResourceError: (error) {
        if (!identical(_activeController, controller)) return;
        if (error.isForMainFrame != true) return;
        final pageLoaded = _pageLoaded;
        if (pageLoaded != null && !pageLoaded.isCompleted) {
          pageLoaded.completeError(StateError(error.description));
        }
      },
    ));
  }

  Future<T> _withWebView<T>(
    DateTime deadline,
    Future<T> Function() operation,
  ) =>
      _queue.add(() async {
        _ensureActive();
        // ponytail: one hybrid view, only during a serialized browser request.
        // CookieManager is process-global; detaching does not clear cookies.
        try {
          if (!DateTime.now().isBefore(deadline)) {
            throw TimeoutException('The in-app browser request timed out.');
          }
          _activeController = await _until(_mountWebView(), deadline);
          _ensureActive();
          final ready = _configure();
          await _until(ready, deadline);
          _ensureActive();
          return await operation();
        } finally {
          _hideChallenge();
          if (_activeController != null) await _abortNavigation();
          await _unmountWebView();
          _activeController = null;
        }
      });

  @override
  Future<String> fetchHtml(
    Uri url, {
    Duration timeout = const Duration(seconds: 30),
    bool interactive = true,
  }) {
    final deadline = DateTime.now().add(timeout);
    return _withWebView(deadline, () async {
      await _navigate(url, deadline);
      await _handleChallenge(
        url,
        interactive: interactive,
        deadline: deadline,
      );
      return await _until(_outerHtml(), deadline);
    });
  }

  @override
  Future<Map<String, dynamic>> capture(
    Uri url, {
    required String jsHook,
    required String channel,
    String? afterLoad,
    Duration timeout = const Duration(seconds: 30),
    bool interactive = true,
  }) {
    final deadline = DateTime.now().add(timeout);
    return _withWebView(deadline, () async {
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
        await _setDocumentStartScript(jsHook, url, deadline);
        await _navigate(url, deadline);
        await _handleChallenge(
          url,
          interactive: interactive,
          deadline: deadline,
        );
        if (afterLoad != null) {
          await _until(_controller.runJavaScript(afterLoad), deadline);
        }
        // SPA requests can raise a challenge after the initial page load.
        while (!captured.isCompleted) {
          await Future.any<void>([
            captured.future.then((_) {}),
            _delay(deadline, _pollInterval),
          ]);
          if (captured.isCompleted) break;
          final snapshot = await _until(_snapshot(), deadline);
          if (snapshot.challenged) {
            await _handleChallenge(
              url,
              interactive: interactive,
              deadline: deadline,
            );
          }
        }
        final result = await _until(captured.future, deadline);
        return result;
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
    _ensureActive();
    final controller = _controller;
    final readyState = _javascriptString(
      await controller.runJavaScriptReturningResult('document.readyState'),
    );
    final title = await controller.getTitle() ?? '';
    // Inspect mounted elements, not inline CSS/JS mentioning captcha classes.
    final html = _javascriptString(
      await controller.runJavaScriptReturningResult('''
(() => {
  const overlay = document.querySelector('.captcha-overlay--visible');
  if (overlay) return overlay.outerHTML;
  const body = document.body ? document.body.innerText : '';
  const challenge = document.querySelector(
    '#challenge-form, #cf-challenge-running, .cf-browser-verification'
  );
  return body + (challenge ? ' cf-chl' : '');
})()
'''),
    );
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
