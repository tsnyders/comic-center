import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'core/database/isar_service.dart';
import 'core/extensions/source_registry.dart';
import 'core/extensions/sources/all_manga_source.dart';
import 'core/extensions/sources/asura_scans_source.dart';
import 'core/extensions/sources/mangadex_source.dart';
import 'core/providers/database_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final isar = await IsarService.init();

  SourceRegistry.instance.register(MangaDexSource());
  SourceRegistry.instance.register(AllMangaSource());
  SourceRegistry.instance.register(AsuraScansSource());

  runApp(
    ProviderScope(
      overrides: [
        isarProvider.overrideWithValue(isar),
      ],
      child: const YomiApp(),
    ),
  );
}
