import 'dart:async';

import 'package:comic_center/core/browser/browser_challenge_sheet.dart';
import 'package:comic_center/core/browser/browser_fetch.dart';
import 'package:comic_center/core/browser/browser_host.dart';
import 'package:comic_center/core/theme/yomi_theme.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';
// Exercise the existing plugin's platform contract without native Android views.
// ignore: depend_on_referenced_packages
import 'package:webview_flutter_platform_interface/webview_flutter_platform_interface.dart';

void main() {
  const channel = MethodChannel('yomi/platform');
  final url = Uri.parse('https://example.test/chapter');
  late _FakePlatform platform;
  late BrowserFetch previous;
  late List<MethodCall> calls;

  setUp(() {
    previous = BrowserFetch.instance;
    platform = _FakePlatform();
    WebViewPlatform.instance = platform;
    SharedPreferences.setMockInitialValues({});
    calls = [];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      if (call.method == 'getCookies') return 'clearance=test';
      if (call.method == 'setDocumentStartScript') {
        if ((call.arguments as Map)['script'] != null) {
          expectSync(platform.controllers.last.attached, isTrue);
        }
        return true;
      }
      return null;
    });
  });

  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
    BrowserFetch.instance = previous;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  Future<void> mount(WidgetTester tester) async {
    const theme = YomiTheme();
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    try {
      await tester.pumpWidget(CupertinoApp(
        home: YomiThemeScope(
          theme: theme,
          colors: theme.colors,
          child: const BrowserHost(child: _AppStateProbe()),
        ),
      ));
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  }

  testWidgets('installs fetcher before any controller or WebView is created',
      (tester) async {
    await mount(tester);
    expect(BrowserFetch.instance, isA<WebViewBrowserFetch>());
    expect(platform.controllers, isEmpty);
    expect(find.byType(WebViewWidget), findsNothing);
    expect(await BrowserFetch.instance.cookieHeaderFor(url), 'clearance=test');
    await BrowserFetch.instance.clearCookies();
    expect(platform.cookiesCleared, isTrue);
    expect(platform.controllers, isEmpty);
    await tester.pumpWidget(const SizedBox());
    expect(BrowserFetch.instance, same(previous));
  });

  testWidgets(
      'fetch mounts lazily, stops and detaches, and preserves app state',
      (tester) async {
    await mount(tester);
    final appState = tester.state(find.byType(_AppStateProbe));
    final browser = BrowserFetch.instance;
    final result = browser.fetchHtml(url);
    await _pumpUntil(
        tester, () => platform.controllers.single.requests.isNotEmpty);
    expect(find.byType(WebViewWidget), findsOneWidget);
    expect(platform.controllers.single.attached, isTrue);
    expect(tester.state(find.byType(_AppStateProbe)), same(appState));
    platform.controllers.single.finish();
    await _pumpUntil(
        tester, () => find.byType(WebViewWidget).evaluate().isEmpty);
    expect(await result, '<html>chapter</html>');
    expect(platform.controllers.single.requests.last, Uri.parse('about:blank'));
    expect(platform.controllers.single.attached, isFalse);
    expect(BrowserFetch.instance, same(browser));
    expect(tester.state(find.byType(_AppStateProbe)), same(appState));
  });

  testWidgets('serial captures recreate the view and install hook before load',
      (tester) async {
    await mount(tester);
    final browser = BrowserFetch.instance;
    final first = browser.capture(url, jsHook: 'hook', channel: 'Yomi');
    final second = browser.capture(url, jsHook: 'hook2', channel: 'Yomi');
    await _pumpUntil(
        tester, () => platform.controllers.single.requests.isNotEmpty);
    expect(platform.controllers, hasLength(1));
    final firstController = platform.controllers.single;
    expect((calls.first.arguments as Map)['script'], 'hook');
    firstController.finish();
    firstController.post('{"pages":["one.jpg"]}');
    await _pumpUntil(
        tester,
        () =>
            platform.controllers.length == 2 &&
            platform.controllers.last.requests.isNotEmpty);
    expect(await first, {
      'pages': ['one.jpg']
    });
    expect(firstController.attached, isFalse);
    expect(firstController.channels, isEmpty);
    final secondController = platform.controllers.last;
    expect(secondController.attached, isTrue);
    secondController.finish();
    secondController.post('{"pages":["two.jpg"]}');
    await _pumpUntil(
        tester, () => find.byType(WebViewWidget).evaluate().isEmpty);
    expect(await second, {
      'pages': ['two.jpg']
    });
    expect(secondController.channels, isEmpty);
    expect(platform.maxAttached, 1);
  });

  testWidgets('navigation failure releases the view and next request works',
      (tester) async {
    await mount(tester);
    final result = BrowserFetch.instance.fetchHtml(url);
    final failure = expectLater(result, throwsStateError);
    await _pumpUntil(
        tester, () => platform.controllers.single.requests.isNotEmpty);
    platform.controllers.single.delegate.onError!(const WebResourceError(
      errorCode: -1,
      description: 'offline',
      isForMainFrame: true,
    ));
    await _pumpUntil(
        tester, () => find.byType(WebViewWidget).evaluate().isEmpty);
    await failure;
    final retry = BrowserFetch.instance.fetchHtml(url);
    await _pumpUntil(
        tester, () => platform.controllers.last.requests.isNotEmpty);
    platform.controllers.last.finish();
    await _pumpUntil(
        tester, () => find.byType(WebViewWidget).evaluate().isEmpty);
    expect(await retry, '<html>chapter</html>');
  });

  testWidgets('timeout detaches the platform view', (tester) async {
    await mount(tester);
    final result = BrowserFetch.instance
        .fetchHtml(url, timeout: const Duration(seconds: 1));
    final failure = expectLater(result, throwsA(isA<TimeoutException>()));
    await _pumpUntil(
        tester, () => platform.controllers.single.requests.isNotEmpty);
    await tester.pump(const Duration(seconds: 2));
    await _pumpUntil(
        tester, () => find.byType(WebViewWidget).evaluate().isEmpty);
    await failure;
    expect(platform.controllers.single.requests.last, Uri.parse('about:blank'));
  });

  testWidgets(
      'late events from a timed-out view cannot finish the next request',
      (tester) async {
    await mount(tester);
    final first = BrowserFetch.instance
        .fetchHtml(url, timeout: const Duration(seconds: 1));
    final failure = expectLater(first, throwsA(isA<TimeoutException>()));
    await _pumpUntil(
        tester, () => platform.controllers.single.requests.isNotEmpty);
    final oldController = platform.controllers.single;
    await tester.pump(const Duration(seconds: 2));
    await _pumpUntil(
        tester, () => find.byType(WebViewWidget).evaluate().isEmpty);
    await failure;

    var finished = false;
    final next = BrowserFetch.instance.fetchHtml(url).then((html) {
      finished = true;
      return html;
    });
    await _pumpUntil(
        tester,
        () =>
            platform.controllers.length == 2 &&
            platform.controllers.last.requests.isNotEmpty);
    oldController.finish();
    oldController.delegate.onError!(const WebResourceError(
      errorCode: -1,
      description: 'late old error',
      isForMainFrame: true,
    ));
    await tester.pump();
    expect(finished, isFalse);
    expect(find.byType(WebViewWidget), findsOneWidget);
    platform.controllers.last.finish();
    await _pumpUntil(
        tester, () => find.byType(WebViewWidget).evaluate().isEmpty);
    expect(await next, '<html>chapter</html>');
  });

  testWidgets(
      'disposing host fails active request and restores previous fetcher',
      (tester) async {
    await mount(tester);
    final browser = BrowserFetch.instance;
    final result = browser.fetchHtml(url);
    final failure =
        expectLater(result, throwsA(isA<BrowserFetchUnavailable>()));
    await _pumpUntil(
        tester, () => platform.controllers.single.requests.isNotEmpty);
    await tester.pumpWidget(const SizedBox());
    await failure;
    expect(BrowserFetch.instance, same(previous));
    await expectLater(
        browser.fetchHtml(url), throwsA(isA<BrowserFetchUnavailable>()));
  });

  for (final cancel in [false, true]) {
    testWidgets(
        'challenge keeps viewport and view until ${cancel ? 'cancel' : 'clearance'}',
        (tester) async {
      await mount(tester);
      final result = BrowserFetch.instance.fetchHtml(url);
      final completed = cancel
          ? expectLater(result, throwsA(isA<BrowserChallengeCancelled>()))
          : expectLater(result, completion('<html>chapter</html>'));
      await _pumpUntil(
          tester, () => platform.controllers.single.requests.isNotEmpty);
      final controller = platform.controllers.single;
      controller.challenged = true;
      controller.finish();
      await tester.pump();
      final viewport = tester.getSize(find.byType(WebViewWidget));
      // The production clearance deadline uses wall time, not the test clock.
      await tester
          .runAsync(() => Future<void>.delayed(const Duration(seconds: 8)));
      await tester.pump(const Duration(milliseconds: 250));
      await tester.pump();
      expect(find.byType(WebViewWidget), findsOneWidget);
      expect(tester.getSize(find.byType(WebViewWidget)), viewport);
      expect(platform.controllers, hasLength(1));
      expect(find.byType(BrowserChallengeSheet), findsOneWidget);
      expect(
          tester
              .widget<IgnorePointer>(find
                  .ancestor(
                    of: find.byType(WebViewWidget),
                    matching: find.byType(IgnorePointer),
                  )
                  .first)
              .ignoring,
          isFalse);
      if (cancel) {
        await tester.tap(find.text('Cancel'));
      } else {
        controller.challenged = false;
        await tester.pump(const Duration(milliseconds: 250));
      }
      await _pumpUntil(
          tester, () => find.byType(WebViewWidget).evaluate().isEmpty);
      await completed;
      expect(controller.attached, isFalse);
      // Drain the losing 250ms poll in the challenge/cancel race.
      await tester.pump(const Duration(milliseconds: 250));
    });
  }
}

Future<void> _pumpUntil(WidgetTester tester, bool Function() done) async {
  for (var i = 0; i < 30; i++) {
    await tester.pump(const Duration(milliseconds: 10));
    if (done()) return;
  }
  fail('Browser operation did not reach expected state');
}

class _FakePlatform extends WebViewPlatform {
  final controllers = <_FakeController>[];
  var cookiesCleared = false;
  var maxAttached = 0;

  @override
  PlatformWebViewController createPlatformWebViewController(
      PlatformWebViewControllerCreationParams params) {
    final controller = _FakeController(params);
    controllers.add(controller);
    return controller;
  }

  @override
  PlatformWebViewWidget createPlatformWebViewWidget(
      PlatformWebViewWidgetCreationParams params) {
    expectSync(
        (params as AndroidWebViewWidgetCreationParams)
            .displayWithHybridComposition,
        isTrue);
    return _FakeWidget(params, this);
  }

  @override
  PlatformNavigationDelegate createPlatformNavigationDelegate(
          PlatformNavigationDelegateCreationParams params) =>
      _FakeDelegate(params);

  @override
  PlatformWebViewCookieManager createPlatformCookieManager(
          PlatformWebViewCookieManagerCreationParams params) =>
      _FakeCookieManager(params, this);
}

class _FakeController extends PlatformWebViewController {
  _FakeController(super.params) : super.implementation();
  final requests = <Uri>[];
  final channels = <String, JavaScriptChannelParams>{};
  late _FakeDelegate delegate;
  var challenged = false;
  var attached = false;

  void finish() => delegate.onFinished!(requests.last.toString());
  void post(String message) => channels.values.single
      .onMessageReceived(JavaScriptMessage(message: message));

  @override
  Future<void> setJavaScriptMode(JavaScriptMode mode) async {}
  @override
  Future<void> setUserAgent(String? userAgent) async {}
  @override
  Future<void> setPlatformNavigationDelegate(
      PlatformNavigationDelegate value) async {
    delegate = value as _FakeDelegate;
  }

  @override
  Future<void> loadRequest(LoadRequestParams params) async {
    requests.add(params.uri);
  }

  @override
  Future<void> addJavaScriptChannel(JavaScriptChannelParams params) async {
    channels[params.name] = params;
  }

  @override
  Future<void> removeJavaScriptChannel(String name) async =>
      channels.remove(name);
  @override
  Future<void> runJavaScript(String script) async {}
  @override
  Future<String?> getTitle() async =>
      challenged ? 'Just a moment...' : 'Chapter';
  @override
  Future<Object> runJavaScriptReturningResult(String script) async {
    if (script == 'document.readyState') return 'complete';
    if (script.contains('document.documentElement')) {
      return '<html>chapter</html>';
    }
    return challenged ? 'cf-chl challenge-form' : 'Chapter';
  }
}

class _FakeDelegate extends PlatformNavigationDelegate {
  _FakeDelegate(super.params) : super.implementation();
  PageEventCallback? onFinished;
  WebResourceErrorCallback? onError;
  @override
  Future<void> setOnPageFinished(PageEventCallback value) async =>
      onFinished = value;
  @override
  Future<void> setOnWebResourceError(WebResourceErrorCallback value) async =>
      onError = value;
}

class _FakeCookieManager extends PlatformWebViewCookieManager {
  _FakeCookieManager(super.params, this.platform) : super.implementation();
  final _FakePlatform platform;
  @override
  Future<bool> clearCookies() async {
    platform.cookiesCleared = true;
    return true;
  }
}

class _FakeWidget extends PlatformWebViewWidget {
  _FakeWidget(super.params, this.platform) : super.implementation();
  final _FakePlatform platform;
  @override
  Widget build(BuildContext context) =>
      _Surface(params.controller as _FakeController, platform);
}

class _Surface extends StatefulWidget {
  const _Surface(this.controller, this.platform);
  final _FakeController controller;
  final _FakePlatform platform;
  @override
  State<_Surface> createState() => _SurfaceState();
}

class _SurfaceState extends State<_Surface> {
  @override
  void initState() {
    super.initState();
    widget.controller.attached = true;
    final count = widget.platform.controllers.where((c) => c.attached).length;
    if (count > widget.platform.maxAttached) {
      widget.platform.maxAttached = count;
    }
  }

  @override
  void dispose() {
    widget.controller.attached = false;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => const SizedBox.expand();
}

class _AppStateProbe extends StatefulWidget {
  const _AppStateProbe();
  @override
  State<_AppStateProbe> createState() => _AppStateProbeState();
}

class _AppStateProbeState extends State<_AppStateProbe> {
  @override
  Widget build(BuildContext context) => const Text('App');
}
