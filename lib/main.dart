import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'core/database/isar_service.dart';
import 'core/extensions/source_registry.dart';
import 'core/providers/database_provider.dart';
import 'core/services/extension_manager.dart';
import 'core/services/whats_new_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final isar = await IsarService.init();

  // On first run (empty DB) seed all bundled sources so users are not greeted
  // by an empty Browse screen. After that, installs/uninstalls are user-driven.
  await ExtensionManager.initializeIfEmpty(isar);

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
      ],
      child: const YomiApp(),
    ),
  );
}
