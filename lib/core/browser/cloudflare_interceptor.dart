import 'package:dio/dio.dart';

import 'browser_cookie_store.dart';
import 'browser_fetch.dart';
import 'cloudflare_challenge.dart';

const siteCheckMessage =
    'Open this title once in the reader to pass the site check';

/// Adds browser-earned identity and performs one interactive clearance retry.
class CloudflareInterceptor extends Interceptor {
  CloudflareInterceptor(this._dio, {required this.interactive});

  static const _retryKey = 'yomi.cloudflare.retry';
  static const _cookieHeader = 'Cookie';
  static const _userAgentHeader = 'User-Agent';

  final Dio _dio;
  final bool interactive;

  @override
  void onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    await BrowserCookieStore.refresh();
    final cookie = BrowserCookieStore.cookieForHost(options.uri.host);
    if (cookie != null && !_hasHeader(options.headers, _cookieHeader)) {
      options.headers[_cookieHeader] = cookie;
    }
    final userAgent = BrowserCookieStore.userAgent;
    if (userAgent != null) {
      _setHeader(options.headers, _userAgentHeader, userAgent);
    }
    handler.next(options);
  }

  @override
  void onResponse(
    Response<dynamic> response,
    ResponseInterceptorHandler handler,
  ) async {
    if (!_isChallenge(response)) {
      handler.next(response);
      return;
    }
    try {
      handler.resolve(await _retryChallenge(response.requestOptions, response));
    } on DioException catch (error) {
      handler.reject(error);
    }
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) async {
    final response = err.response;
    if (response == null || !_isChallenge(response)) {
      handler.next(err);
      return;
    }
    try {
      handler.resolve(await _retryChallenge(
        err.requestOptions,
        response,
        originalError: err,
      ));
    } on DioException catch (retryError) {
      handler.reject(retryError);
    }
  }

  bool _isChallenge(Response<dynamic> response) =>
      isCloudflareChallengeResponse(
        statusCode: response.statusCode,
        headers: response.headers.map,
        body: response.data,
      );

  Future<Response<dynamic>> _retryChallenge(
    RequestOptions request,
    Response<dynamic> response, {
    DioException? originalError,
  }) async {
    if (request.extra[_retryKey] == true ||
        !interactive ||
        BrowserFetch.instance is UnavailableBrowserFetch) {
      throw _siteCheckError(request, response, originalError);
    }

    try {
      final browser = BrowserFetch.instance;
      await browser.fetchHtml(request.uri);
      final cookie = await browser.cookieHeaderFor(request.uri);
      await BrowserCookieStore.persist(
        host: request.uri.host,
        cookieHeader: cookie,
        userAgent: browser.userAgent,
      );

      final headers = Map<String, dynamic>.from(request.headers);
      if (cookie != null && cookie.trim().isNotEmpty) {
        _setHeader(headers, _cookieHeader, cookie);
      }
      _setHeader(headers, _userAgentHeader, browser.userAgent);
      final retried = request.copyWith(
        headers: headers,
        extra: <String, dynamic>{...request.extra, _retryKey: true},
      );
      return await _dio.fetch<dynamic>(retried);
    } catch (error) {
      throw _siteCheckError(request, response, error);
    }
  }

  static DioException _siteCheckError(
    RequestOptions request,
    Response<dynamic> response,
    Object? error,
  ) =>
      DioException(
        requestOptions: request,
        response: response,
        type: DioExceptionType.badResponse,
        error: error,
        message: siteCheckMessage,
      );

  static bool _hasHeader(Map<String, dynamic> headers, String name) =>
      headers.keys.any((key) => key.toLowerCase() == name.toLowerCase());

  static void _setHeader(
    Map<String, dynamic> headers,
    String name,
    String value,
  ) {
    String? existing;
    for (final key in headers.keys) {
      if (key.toLowerCase() == name.toLowerCase()) {
        existing = key;
        break;
      }
    }
    headers[existing ?? name] = value;
  }
}
