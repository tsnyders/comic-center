import 'package:shared_preferences/shared_preferences.dart';

/// Persisted browser identity shared by the UI isolate, Dio, and WorkManager.
abstract final class BrowserCookieStore {
  static const cookiePrefix = 'browser.cookie.';
  static const userAgentKey = 'browser.ua';

  static final Map<String, String> _cookies = <String, String>{};
  static String? _userAgent;

  /// Hydrates the synchronous mirror used by image headers.
  static void hydrate(SharedPreferences preferences) {
    final cookies = <String, String>{};
    for (final key in preferences.getKeys()) {
      if (!key.startsWith(cookiePrefix)) continue;
      final value = preferences.getString(key)?.trim();
      if (value == null || value.isEmpty) continue;
      cookies[key.substring(cookiePrefix.length).toLowerCase()] = value;
    }
    _cookies
      ..clear()
      ..addAll(cookies);
    _userAgent = _nonEmpty(preferences.getString(userAgentKey));
  }

  /// Reloads the platform store. A WorkManager isolate calls this on request,
  /// so it observes clearance earned by the UI isolate.
  static Future<void> refresh() async {
    try {
      final preferences = await SharedPreferences.getInstance();
      await preferences.reload();
      hydrate(preferences);
    } catch (_) {
      // Browser state is an optional request enhancement. A preferences
      // failure must not turn an otherwise ordinary network request into one.
    }
  }

  static String? cookieForHost(String host) => _cookies[host.toLowerCase()];

  static String? get userAgent => _userAgent;

  static Future<void> persist({
    required String host,
    required String? cookieHeader,
    required String userAgent,
  }) async {
    final normalizedHost = host.toLowerCase();
    final cookie = _nonEmpty(cookieHeader);
    final ua = _nonEmpty(userAgent);
    final preferences = await SharedPreferences.getInstance();

    if (cookie == null) {
      _cookies.remove(normalizedHost);
      await preferences.remove('$cookiePrefix$normalizedHost');
    } else {
      _cookies[normalizedHost] = cookie;
      await preferences.setString('$cookiePrefix$normalizedHost', cookie);
    }

    _userAgent = ua;
    if (ua == null) {
      await preferences.remove(userAgentKey);
    } else {
      await preferences.setString(userAgentKey, ua);
    }
  }

  static Future<void> clear() async {
    _cookies.clear();
    _userAgent = null;
    final preferences = await SharedPreferences.getInstance();
    final keys = preferences
        .getKeys()
        .where((key) => key == userAgentKey || key.startsWith(cookiePrefix))
        .toList(growable: false);
    for (final key in keys) {
      await preferences.remove(key);
    }
  }

  static String? _nonEmpty(String? value) {
    final trimmed = value?.trim();
    return trimmed == null || trimmed.isEmpty ? null : trimmed;
  }
}
