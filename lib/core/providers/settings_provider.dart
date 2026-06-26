import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'preferences_provider.dart';

enum DownloadLocation { local, googleDrive }

/// Where downloaded chapters are stored. Persisted.
final downloadLocationProvider = StateProvider<DownloadLocation>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  ref.listenSelf((_, next) => prefs.setInt('settings.downloadLocation', next.index));
  return readEnumPref(prefs, 'settings.downloadLocation',
      DownloadLocation.values, DownloadLocation.local);
});

/// App-wide brightness (theme mode). Persisted. Defaults to dark (LUMEN ink).
final brightnessProvider = StateProvider<Brightness>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  ref.listenSelf(
      (_, next) => prefs.setBool('settings.brightnessDark', next == Brightness.dark));
  return (prefs.getBool('settings.brightnessDark') ?? true)
      ? Brightness.dark
      : Brightness.light;
});

// Glass / blur surface theming has been removed from Comic Center.
// Surfaces now use solid elevated layers — see AppColors and AppElevation.
