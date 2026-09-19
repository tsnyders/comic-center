import 'package:shared_preferences/shared_preferences.dart';

/// Reads a source's persisted settings at request time. Keys live under
/// `source.<sourceId>.<key>`; the settings screen writes the same keys through
/// `sharedPreferencesProvider` (same singleton, so writes are visible here).
class SourcePrefs {
  const SourcePrefs(this.sourceId);
  final String sourceId;

  static String keyFor(String sourceId, String key) => 'source.$sourceId.$key';

  // A setting is never worth failing a request over: with no platform store
  // (unit tests, early startup) every read resolves to its default.
  Future<SharedPreferences?> get _store async {
    try {
      return await SharedPreferences.getInstance();
    } catch (_) {
      return null;
    }
  }

  Future<bool> getBool(String key, bool fallback) async =>
      (await _store)?.getBool(keyFor(sourceId, key)) ?? fallback;

  Future<String> getString(String key, String fallback) async =>
      (await _store)?.getString(keyFor(sourceId, key)) ?? fallback;

  Future<List<String>> getStringList(String key, List<String> fallback) async =>
      (await _store)?.getStringList(keyFor(sourceId, key)) ?? fallback;
}
