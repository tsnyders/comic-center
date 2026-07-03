import 'dart:async';

import 'package:extended_image/extended_image.dart' show clearDiskCachedImages;
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app.dart';
import 'core/database/isar_service.dart';
import 'core/extensions/source_registry.dart';
import 'core/providers/database_provider.dart';
import 'core/providers/preferences_provider.dart';
import 'core/services/app_logger.dart';
import 'core/services/device_profile.dart';
import 'core/services/extension_manager.dart';
import 'core/services/whats_new_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Detect hardware/OS capabilities before the first frame so every widget
  // can consult DeviceProfile.current when deciding whether to animate.
  await DeviceProfile.init();
  if (DeviceProfile.current.lowSpec) {
    // Halve the decoded-image cache (default 100MB). On 4GB devices like the
    // Galaxy A23 the default lets the heap balloon until Android starts
    // killing/GC-thrashing the app; covers re-decode cheaply on demand.
    PaintingBinding.instance.imageCache.maximumSizeBytes = 48 << 20;
  }

  // Trim the reader page-image disk cache (extended_image never evicts on its
  // own, and manga pages are megabytes each — weeks of reading otherwise
  // accumulates gigabytes). Cover art is unaffected: cached_network_image
  // manages its own store with a built-in 7-day policy. Fire-and-forget so
  // startup isn't blocked on disk I/O.
  unawaited(clearDiskCachedImages(
    duration: DeviceProfile.current.lowSpec
        ? const Duration(days: 3)
        : const Duration(days: 7),
  ));

  FlutterError.onError = (details) {
    FlutterError.presentError(details);
    AppLogger.instance.error(
        'FlutterError: ${details.exceptionAsString()}', details.exception, details.stack);
  };
  PlatformDispatcher.instance.onError = (error, stack) {
    AppLogger.instance.error('Uncaught error', error, stack);
    return true;
  };

  final prefs = await SharedPreferences.getInstance();
  final isar = await IsarService.init();

  // On first run (empty DB) seed all bundled sources so users are not greeted
  // by an empty Browse screen. After that, installs/uninstalls are user-driven.
  await ExtensionManager.initializeIfEmpty(isar);

  // Fix any manga entries with percent-encoded slugs from a previous bug.
  await ExtensionManager.migratePercentEncodedSlugs(isar);

  // Hydrate the singleton registry from DB before the first frame renders.
  final sources = await ExtensionManager.loadInstalled(isar);
  for (final source in sources) {
    SourceRegistry.instance.register(source);
  }

  // Check if the app version changed since the last launch.
  final showWhatsNew = await WhatsNewService.checkAndMark();

  runApp(
    ProviderScope(
      overrides: [
        isarProvider.overrideWithValue(isar),
        showWhatsNewProvider.overrideWithValue(showWhatsNew),
        sharedPreferencesProvider.overrideWithValue(prefs),
      ],
      child: const YomiApp(),
    ),
  );
}
