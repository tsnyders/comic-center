import 'dart:convert';

/// Markers used by Cloudflare and the supported source-specific captcha skin.
bool hasCloudflareChallengeMarkers(String value) {
  final body = value.toLowerCase();
  return body.contains('just a moment') ||
      body.contains('cf-chl') ||
      body.contains('challenge-platform') ||
      body.contains('captcha-overlay--visible');
}

/// Whether an HTTP response is a challenge rather than an ordinary site 403.
bool isCloudflareChallengeResponse({
  required int? statusCode,
  required Map<String, List<String>> headers,
  required Object? body,
}) {
  if (statusCode != 403 && statusCode != 503) return false;
  final mitigated = headers.entries
      .where((entry) => entry.key.toLowerCase() == 'cf-mitigated')
      .expand((entry) => entry.value)
      .any((value) => value.toLowerCase().contains('challenge'));
  return mitigated || hasCloudflareChallengeMarkers(_bodyText(body));
}

String _bodyText(Object? body) {
  if (body is String) return body;
  if (body is List<int>) return utf8.decode(body, allowMalformed: true);
  return body?.toString() ?? '';
}
