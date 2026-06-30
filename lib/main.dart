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
import 'core/services/extension_manager.dart';
import 'core/services/whats_new_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

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
