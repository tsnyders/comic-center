import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'core/database/isar_service.dart';
import 'core/extensions/source_registry.dart';
import 'core/providers/database_provider.dart';
import 'core/services/extension_manager.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final isar = await IsarService.init();

  // On first run (empty DB) seed all bundled sources so users are not greeted
  // by an empty Browse screen. After that, installs/uninstalls are user-driven.
  final count = await isar.sourceEntrys.count();
  if (count == 0) {
    await ExtensionManager.seedDefaults(isar);
  }

  // Hydrate the singleton registry from DB before the first frame renders.
  final sources = await ExtensionManager.loadInstalled(isar);
  for (final source in sources) {
    SourceRegistry.instance.register(source);
  }

  runApp(
    ProviderScope(
      overrides: [
        isarProvider.overrideWithValue(isar),
      ],
      child: const YomiApp(),
    ),
  );
}
