import 'dart:async';

/// Browser-backed fetching for sites that need a real browser: Cloudflare
/// clearance cookies, and pages whose data is only produced by the site's own
/// JavaScript (AllManga's chapter pages).
///
/// The Android WebView implementation installs itself into
/// [BrowserFetch.instance] when the app root mounts it. Everywhere else
/// (Windows, tests, the background download isolate) the instance stays
/// [UnavailableBrowserFetch] and callers get [BrowserFetchUnavailable].
abstract class BrowserFetch {
  static BrowserFetch _instance = const UnavailableBrowserFetch();
  static final _changes = StreamController<BrowserFetch>.broadcast();

  static BrowserFetch get instance => _instance;
  static set instance(BrowserFetch browser) {
    if (identical(_instance, browser)) return;
    _instance = browser;
    _changes.add(browser);
  }

  /// Lets foreground work resume when the browser host mounts after startup.
  static Stream<BrowserFetch> get changes => _changes.stream;

  /// The user agent the WebView sends. Sources reuse it so plain HTTP
  /// requests match the cookies the browser earned.
  String get userAgent;

  /// Loads [url]; waits for automatic Cloudflare clearance; when still
  /// challenged and [interactive], shows the challenge sheet until the user
  /// clears it or cancels ([BrowserChallengeCancelled]). Resolves with the
  /// final document HTML.
  Future<String> fetchHtml(
    Uri url, {
    Duration timeout = const Duration(seconds: 30),
    bool interactive = true,
  });

  /// Loads [url] with [jsHook] injected at document start and resolves with
  /// the first JSON object the page posts to the JavaScript channel
  /// [channel]. [afterLoad], when given, runs once the page has loaded and
  /// is clear of challenges (e.g. to trigger an in-page navigation).
  /// Challenge handling as in [fetchHtml].
  Future<Map<String, dynamic>> capture(
    Uri url, {
    required String jsHook,
    required String channel,
    String? afterLoad,
    Duration timeout = const Duration(seconds: 30),
    bool interactive = true,
  });

  /// `Cookie` header value for [origin] from the browser's store, including
  /// httpOnly cookies such as `cf_clearance`; null when none.
  Future<String?> cookieHeaderFor(Uri origin);

  Future<void> clearCookies();
}

/// Default when no WebView is available on this platform or isolate.
class UnavailableBrowserFetch implements BrowserFetch {
  const UnavailableBrowserFetch();

  @override
  String get userAgent =>
      'Mozilla/5.0 (Linux; Android 14) AppleWebKit/537.36 (KHTML, like Gecko) '
      'Chrome/128.0.0.0 Mobile Safari/537.36';

  @override
  Future<String> fetchHtml(Uri url,
          {Duration timeout = const Duration(seconds: 30),
          bool interactive = true}) =>
      throw const BrowserFetchUnavailable();

  @override
  Future<Map<String, dynamic>> capture(Uri url,
          {required String jsHook,
          required String channel,
          String? afterLoad,
          Duration timeout = const Duration(seconds: 30),
          bool interactive = true}) =>
      throw const BrowserFetchUnavailable();

  @override
  Future<String?> cookieHeaderFor(Uri origin) async => null;

  @override
  Future<void> clearCookies() async {}
}

/// The user dismissed the challenge sheet before the site cleared.
class BrowserChallengeCancelled implements Exception {
  const BrowserChallengeCancelled();
  @override
  String toString() => 'The site check was cancelled.';
}

/// No in-app browser on this platform or isolate.
class BrowserFetchUnavailable implements Exception {
  const BrowserFetchUnavailable();
  @override
  String toString() =>
      'This source needs the in-app browser, which is only available while '
      'the app is open on Android.';
}
