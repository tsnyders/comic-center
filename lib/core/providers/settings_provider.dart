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

/// App-wide brightness (theme mode). Persisted. Defaults to dark.
final brightnessProvider = StateProvider<Brightness>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  ref.listenSelf(
      (_, next) => prefs.setBool('settings.brightnessDark', next == Brightness.dark));
  return (prefs.getBool('settings.brightnessDark') ?? true)
      ? Brightness.dark
      : Brightness.light;
});

/// The glass material style used for every translucent surface in the app.
///
/// * [frosty] — the original BackdropFilter-based frosted glass (default).
/// * [liquid] — real-time refraction lenses from `liquid_glass_easy`.
enum GlassTheme { frosty, liquid }

extension GlassThemeX on GlassTheme {
  String get label => switch (this) {
        GlassTheme.frosty => 'Frosty Glass',
        GlassTheme.liquid => 'Liquid Glass',
      };
}

/// App-wide glass style. Persisted. Defaults to [GlassTheme.frosty] so existing
/// users keep the current look until they opt into liquid glass.
final glassThemeProvider = StateProvider<GlassTheme>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  ref.listenSelf((_, next) => prefs.setInt('settings.glassTheme', next.index));
  return readEnumPref(
      prefs, 'settings.glassTheme', GlassTheme.values, GlassTheme.frosty);
});
