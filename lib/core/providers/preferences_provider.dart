import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Holds the app's [SharedPreferences] instance.
///
/// Overridden in `main()` with the instance loaded before the first frame, so
/// every setting provider can read its persisted value synchronously and write
/// changes back without async plumbing at the call site.
final sharedPreferencesProvider = Provider<SharedPreferences>(
  (_) => throw UnimplementedError(
    'sharedPreferencesProvider must be overridden in main()',
  ),
);

/// Reads a persisted enum index, clamped to the valid range, defaulting to
/// [fallback] when absent.
T readEnumPref<T extends Enum>(
  SharedPreferences prefs,
  String key,
  List<T> values,
  T fallback,
) {
  final i = prefs.getInt(key);
  if (i == null || i < 0 || i >= values.length) return fallback;
  return values[i];
}
