import 'package:comic_center/core/browser/browser_fetch.dart';

/// Scripted [BrowserFetch] for tests. Keys are full URL strings for [html]
/// and [captures], and hosts for [cookies]. Every call is recorded in [calls].
class FakeBrowserFetch implements BrowserFetch {
  FakeBrowserFetch({
    Map<String, String> html = const {},
    Map<String, Map<String, dynamic>> captures = const {},
    Map<String, String> cookies = const {},
    this.userAgent = 'FakeBrowser/1.0',
  })  : html = Map.of(html),
        captures = Map.of(captures),
        cookies = Map.of(cookies);

  final Map<String, String> html;
  final Map<String, Map<String, dynamic>> captures;
  final Map<String, String> cookies;
  final List<String> calls = [];

  @override
  final String userAgent;

  @override
  Future<String> fetchHtml(Uri url,
      {Duration timeout = const Duration(seconds: 30),
      bool interactive = true}) async {
    calls.add('fetchHtml $url interactive=$interactive');
    return html[url.toString()] ??
        (throw StateError('FakeBrowserFetch: no html scripted for $url'));
  }

  @override
  Future<Map<String, dynamic>> capture(Uri url,
      {required String jsHook,
      required String channel,
      Duration timeout = const Duration(seconds: 30),
      bool interactive = true}) async {
    calls.add('capture $url channel=$channel interactive=$interactive');
    return captures[url.toString()] ??
        (throw StateError('FakeBrowserFetch: no capture scripted for $url'));
  }

  @override
  Future<String?> cookieHeaderFor(Uri origin) async {
    calls.add('cookieHeaderFor ${origin.host}');
    return cookies[origin.host];
  }

  @override
  Future<void> clearCookies() async {
    calls.add('clearCookies');
    cookies.clear();
  }
}
