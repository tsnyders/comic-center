import 'dart:io';

import 'package:flutter/services.dart';

import 'app_logger.dart';

/// Hardware/OS capability profile, detected once at startup (before the first
/// frame) via the `yomi/platform` channel. Read through [DeviceProfile.current]
/// from anywhere — including const-constructed widgets that have no Riverpod
/// access — so decorative animations can be skipped on devices that can't
/// afford them.
class DeviceProfile {
  const DeviceProfile({
    required this.reducedMotion,
    required this.lowSpec,
    this.sdkInt = 0,
    this.model = '',
  });

  /// Skip decorative animations: shimmer placeholders, entrance staggers,
  /// card sheens, and fancy page transitions. Functional motion (scroll
  /// physics, press feedback) is unaffected.
  ///
  /// True on Android 14 (API 34) and lower, and on [lowSpec] hardware
  /// regardless of OS version.
  final bool reducedMotion;

  /// Budget hardware (low RAM or a known entry-level model): additionally
  /// shrink the image cache and skip CPU-heavy extras such as cover palette
  /// extraction.
  final bool lowSpec;

  final int sdkInt;
  final String model;

  static const _channel = MethodChannel('yomi/platform');

  /// Samsung Galaxy A0x / A1x / A2x — the budget tier (e.g. the A23 is
  /// SM-A235x/SM-A236x). RAM alone under-detects these: 6GB variants pass a
  /// memory check but their entry SoCs (Snapdragon 680 / Helio G80) still
  /// drop frames on decorative animation.
  static final _budgetModel = RegExp(r'^SM-A[0-2]\d');

  /// ≤ ~4.5 GiB of physical RAM (a "4GB" device reports ~3.7 GiB usable).
  static const _lowRamThresholdBytes = 4608 * 1024 * 1024;

  /// Defaults to full motion (iOS, desktop, or if detection fails).
  static DeviceProfile current =
      const DeviceProfile(reducedMotion: false, lowSpec: false);

  /// Detect and populate [current]. Call once in `main()` before `runApp`.
  /// Never throws — on any failure the full-motion default stays in place.
  static Future<void> init() async {
    if (!Platform.isAndroid) return;
    try {
      final map =
          await _channel.invokeMapMethod<String, Object?>('getDeviceProfile');
      if (map == null) return;

      final sdkInt = map['sdkInt'] as int? ?? 0;
      final totalMem = map['totalMemBytes'] as int? ?? 0;
      final isLowRam = map['isLowRamDevice'] as bool? ?? false;
      final model = (map['model'] as String? ?? '').toUpperCase();

      final lowSpec = isLowRam ||
          (totalMem > 0 && totalMem <= _lowRamThresholdBytes) ||
          _budgetModel.hasMatch(model);

      current = DeviceProfile(
        reducedMotion: sdkInt <= 34 || lowSpec,
        lowSpec: lowSpec,
        sdkInt: sdkInt,
        model: model,
      );

      AppLogger.instance.info(
          'DeviceProfile: model=$model sdk=$sdkInt totalMem=${totalMem ~/ (1024 * 1024)}MB '
          'lowRam=$isLowRam → lowSpec=$lowSpec reducedMotion=${current.reducedMotion}');
    } catch (e, st) {
      AppLogger.instance.warn('DeviceProfile detection failed', e, st);
    }
  }
}
