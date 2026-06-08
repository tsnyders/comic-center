import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:isar/isar.dart';

import '../extensions/source_interface.dart';
import '../extensions/source_registry.dart';
import '../services/extension_manager.dart';

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

  /// Install an extension: persists to DB and activates in the registry.
  /// Returns true if successful, false if no native implementation exists.
  Future<bool> install(
    Isar isar, {
    required String sourceId,
    required String name,
    required String version,
    required String language,
    bool hasNsfw = false,
  }) async {
    final source = await ExtensionManager.install(
      isar,
      sourceId: sourceId,
      name: name,
      version: version,
      language: language,
      hasNsfw: hasNsfw,
    );
    if (source == null) return false;
    register(source);
    return true;
  }

  /// Uninstall an extension: removes from DB and deactivates from registry.
  Future<void> uninstall(Isar isar, String sourceId) async {
    await ExtensionManager.uninstall(isar, sourceId);
    unregister(sourceId);
  }

  /// Update the stored version for an installed extension.
  Future<void> updateVersion(Isar isar, String sourceId, String newVersion) async {
    await ExtensionManager.updateVersion(isar, sourceId, newVersion);
    // Registry doesn't change — the source implementation stays the same.
  }
}

final sourceRegistryProvider =
    NotifierProvider<SourceRegistryNotifier, List<MangaSource>>(
  SourceRegistryNotifier.new,
);

// ── Single source lookup ──────────────────────────────────────────────────

final sourceByIdProvider = Provider.family<MangaSource?, String>((ref, id) {
  final sources = ref.watch(sourceRegistryProvider);
  try {
    return sources.firstWhere((s) => s.id == id);
  } catch (_) {
    return null;
  }
});
