import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../extensions/source_interface.dart';
import '../extensions/source_registry.dart';

// ── Registered sources list ────────────────────────────────────────────────

class SourceRegistryNotifier extends Notifier<List<MangaSource>> {
  @override
  List<MangaSource> build() => SourceRegistry.instance.all;

  void register(MangaSource source) {
    SourceRegistry.instance.register(source);
    state = SourceRegistry.instance.all;
  }

  void unregister(String sourceId) {
    SourceRegistry.instance.unregister(sourceId);
    state = SourceRegistry.instance.all;
  }
}

final sourceRegistryProvider =
    NotifierProvider<SourceRegistryNotifier, List<MangaSource>>(
  SourceRegistryNotifier.new,
);

// ── Single source lookup (family) ─────────────────────────────────────────

final sourceByIdProvider = Provider.family<MangaSource?, String>((ref, id) {
  final sources = ref.watch(sourceRegistryProvider);
  try {
    return sources.firstWhere((s) => s.id == id);
  } catch (_) {
    return null;
  }
});
