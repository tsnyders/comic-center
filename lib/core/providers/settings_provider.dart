import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

enum DownloadLocation { local, googleDrive }

final downloadLocationProvider =
    StateProvider<DownloadLocation>((_) => DownloadLocation.local);

// Controls app-wide brightness (theme mode). Defaults to dark.
final brightnessProvider = StateProvider<Brightness>((_) => Brightness.dark);

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

/// App-wide glass style. Defaults to [GlassTheme.frosty] so existing users
/// keep the current look until they opt into liquid glass.
final glassThemeProvider = StateProvider<GlassTheme>((_) => GlassTheme.frosty);
