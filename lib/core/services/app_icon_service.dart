import 'dart:io';

import 'package:flutter/services.dart';

import '../theme/yomi_theme.dart';
import 'app_logger.dart';

/// Keeps the Android home-screen icon in step with the chosen look by
/// enabling the matching launcher alias (see AndroidManifest.xml). No-op on
/// other platforms; failures are logged, never surfaced.
abstract final class AppIconService {
  static const _channel = MethodChannel('yomi/platform');

  static Future<void> setLook(YomiLook look) async {
    if (!Platform.isAndroid) return;
    try {
      await _channel.invokeMethod<void>('setAppIcon', {'look': look.name});
    } catch (e, st) {
      AppLogger.instance.warn('Failed to switch app icon to ${look.name}', e, st);
    }
  }
}
