import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../theme/yomi_theme.dart';
import 'preferences_provider.dart';

enum DownloadLocation { local, googleDrive }

/// Where downloaded chapters are stored. Persisted.
final downloadLocationProvider = StateProvider<DownloadLocation>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  ref.listenSelf(
      (_, next) => prefs.setInt('settings.downloadLocation', next.index));
  return readEnumPref(prefs, 'settings.downloadLocation',
      DownloadLocation.values, DownloadLocation.local);
});

/// App-wide brightness (theme mode). Persisted. Defaults to dark (LUMEN ink).
final brightnessProvider = StateProvider<Brightness>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  ref.listenSelf((_, next) =>
      prefs.setBool('settings.brightnessDark', next == Brightness.dark));
  return (prefs.getBool('settings.brightnessDark') ?? true)
      ? Brightness.dark
      : Brightness.light;
});

/// Whether the app automatically checks for updates on launch. Persisted.
final autoCheckUpdatesProvider = StateProvider<bool>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  ref.listenSelf((_, next) => prefs.setBool('settings.autoCheckUpdates', next));
  return prefs.getBool('settings.autoCheckUpdates') ?? true;
});

// Glass / blur surface theming has been removed from Comic Center.
// Surfaces now use solid elevated layers — see AppColors and AppElevation.

// ── Sumi theme prefs (mode lives in brightnessProvider above) ─────────────────

/// Index into the current look's curated accent set. Persisted.
final accentIndexProvider = StateProvider<int>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  ref.listenSelf((_, next) => prefs.setInt('theme.accent', next));
  return prefs.getInt('theme.accent') ?? 0;
});

final coverSizeProvider = StateProvider<CoverSize>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  ref.listenSelf((_, next) => prefs.setInt('theme.coverSize', next.index));
  return readEnumPref(
      prefs, 'theme.coverSize', CoverSize.values, CoverSize.medium);
});

final densityProvider = StateProvider<YomiDensity>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  ref.listenSelf((_, next) => prefs.setInt('theme.density', next.index));
  return readEnumPref(
      prefs, 'theme.density', YomiDensity.values, YomiDensity.comfortable);
});

/// Which look (Sumi / Cinema / Pastel). Persisted. Also read in main() to
/// sync the launcher icon before the first frame.
const lookPrefKey = 'theme.look';

final lookProvider = StateProvider<YomiLook>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  ref.listenSelf((_, next) => prefs.setInt(lookPrefKey, next.index));
  return readEnumPref(prefs, lookPrefKey, YomiLook.values, YomiLook.sumi);
});

/// The composed theme every widget reads through `context.yomi` / `context.yc`.
final yomiThemeProvider = Provider<YomiTheme>((ref) => YomiTheme(
      look: ref.watch(lookProvider),
      mode: ref.watch(brightnessProvider),
      accentIndex: ref.watch(accentIndexProvider),
      density: ref.watch(densityProvider),
      coverSize: ref.watch(coverSizeProvider),
    ));

// ── Onboarding ────────────────────────────────────────────────────────────────

final onboardingDoneProvider = StateProvider<bool>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  ref.listenSelf((_, next) => prefs.setBool('onboarding.done', next));
  return prefs.getBool('onboarding.done') ?? false;
});

/// Genres picked on first launch. Persisted.
final selectedGenresProvider = StateProvider<Set<String>>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  ref.listenSelf(
      (_, next) => prefs.setStringList('onboarding.genres', next.toList()));
  return (prefs.getStringList('onboarding.genres') ?? const []).toSet();
});

// ── Reading / storage toggles ─────────────────────────────────────────────────

final hapticsProvider = StateProvider<bool>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  ref.listenSelf((_, next) => prefs.setBool('reader.haptics', next));
  return prefs.getBool('reader.haptics') ?? true;
});

/// Read by DownloadBackgroundService.scheduleQueue as a WorkManager constraint.
const wifiOnlyPrefKey = 'settings.wifiOnly';

final wifiOnlyProvider = StateProvider<bool>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  ref.listenSelf((_, next) => prefs.setBool(wifiOnlyPrefKey, next));
  return prefs.getBool(wifiOnlyPrefKey) ?? false;
});

// ── Root navigation ───────────────────────────────────────────────────────────

/// 0 Discover · 1 Library (yin-yang) · 2 Settings. In-memory.
final rootTabProvider = StateProvider<int>((_) => 1);

/// Keep the display awake while the reader is open (Android). Persisted.
final keepScreenOnProvider = StateProvider<bool>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  ref.listenSelf((_, next) => prefs.setBool('reader.keepScreenOn', next));
  return prefs.getBool('reader.keepScreenOn') ?? true;
});
