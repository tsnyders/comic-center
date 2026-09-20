import 'dart:typed_data';

import 'package:comic_center/core/browser/browser_cookie_store.dart';
import 'package:comic_center/core/browser/browser_fetch.dart';
import 'package:comic_center/core/browser/cloudflare_challenge.dart';
import 'package:comic_center/core/browser/cloudflare_interceptor.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../support/fake_browser_fetch.dart';

class _StubResponse {
  const _StubResponse(this.status, this.body, {this.headers = const {}});

  final int status;
  final String body;
  final Map<String, List<String>> headers;
}

class _SequenceAdapter implements HttpClientAdapter {
  _SequenceAdapter(this.responses);

  final List<_StubResponse> responses;
  final List<RequestOptions> requests = <RequestOptions>[];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    if (responses.isEmpty) throw StateError('No stubbed response remains.');
    final response = responses.removeAt(0);
    return ResponseBody.fromString(
      response.body,
      response.status,
      headers: <String, List<String>>{
        Headers.contentTypeHeader: <String>['text/html; charset=utf-8'],
        ...response.headers,
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

Dio _client(_SequenceAdapter adapter, {required bool interactive}) {
  final dio = Dio(BaseOptions(baseUrl: 'https://example.com'));
  dio.httpClientAdapter = adapter;
  dio.interceptors.add(CloudflareInterceptor(dio, interactive: interactive));
  return dio;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late BrowserFetch previousBrowser;

  setUp(() async {
    previousBrowser = BrowserFetch.instance;
    BrowserFetch.instance = const UnavailableBrowserFetch();
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await BrowserCookieStore.refresh();
  });

  tearDown(() {
    BrowserFetch.instance = previousBrowser;
  });

  group('Cloudflare challenge detection', () {
    test('recognizes HTML and response-header markers', () {
      expect(
        hasCloudflareChallengeMarkers(
            '<title>Just a moment...</title><script src="/cf-chl/x.js">'),
        isTrue,
      );
      expect(
        hasCloudflareChallengeMarkers(
            '<div class="captcha-overlay--visible"></div>'),
        isTrue,
      );
      expect(
        isCloudflareChallengeResponse(
          statusCode: 403,
          headers: const <String, List<String>>{
            'cf-mitigated': <String>['challenge'],
          },
          body: 'Forbidden',
        ),
        isTrue,
      );
      expect(
        isCloudflareChallengeResponse(
          statusCode: 403,
          headers: const <String, List<String>>{},
          body: 'Ordinary forbidden response',
        ),
        isFalse,
      );
    });
  });

  test('attaches persisted cookie and user agent without replacing a cookie',
      () async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'browser.cookie.example.com': 'cf_clearance=saved',
      'browser.ua': 'SavedBrowser/2.0',
    });
    final adapter = _SequenceAdapter(<_StubResponse>[
      const _StubResponse(200, '<html>ok</html>'),
      const _StubResponse(200, '<html>ok</html>'),
    ]);
    final dio = _client(adapter, interactive: true);

    await dio.get<String>('/first');
    await dio.get<String>(
      '/explicit',
      options: Options(headers: <String, String>{'Cookie': 'session=explicit'}),
    );

    expect(adapter.requests.first.headers['Cookie'], 'cf_clearance=saved');
    expect(adapter.requests.first.headers['User-Agent'], 'SavedBrowser/2.0');
    expect(adapter.requests.last.headers['Cookie'], 'session=explicit');
  });

  test('uses the browser once then retries once with fresh identity', () async {
    final url = Uri.parse('https://example.com/reader');
    final browser = FakeBrowserFetch(
      html: <String, String>{url.toString(): '<html>cleared</html>'},
      cookies: <String, String>{url.host: 'cf_clearance=fresh'},
      userAgent: 'FreshBrowser/3.0',
    );
    BrowserFetch.instance = browser;
    final adapter = _SequenceAdapter(<_StubResponse>[
      const _StubResponse(
        403,
        '<title>Just a moment...</title>',
        headers: <String, List<String>>{
          'cf-mitigated': <String>['challenge'],
        },
      ),
      const _StubResponse(200, '<html>reader</html>'),
    ]);
    final dio = _client(adapter, interactive: true);

    final response = await dio.get<String>('/reader');

    expect(response.statusCode, 200);
    expect(adapter.requests, hasLength(2));
    expect(adapter.requests.last.headers['Cookie'], 'cf_clearance=fresh');
    expect(adapter.requests.last.headers['User-Agent'], 'FreshBrowser/3.0');
    expect(
      browser.calls.where((call) => call.startsWith('fetchHtml ')),
      hasLength(1),
    );
  });

  test('non-interactive challenges give the reader clearance instruction',
      () async {
    final browser = FakeBrowserFetch();
    BrowserFetch.instance = browser;
    final adapter = _SequenceAdapter(<_StubResponse>[
      const _StubResponse(
        503,
        '<script src="/challenge-platform/run.js"></script>',
      ),
    ]);
    final dio = _client(adapter, interactive: false);

    await expectLater(
      dio.get<String>('/reader'),
      throwsA(
        isA<DioException>().having(
          (error) => error.message,
          'message',
          contains(siteCheckMessage),
        ),
      ),
    );
    expect(browser.calls, isEmpty);
    expect(adapter.requests, hasLength(1));
  });
}
