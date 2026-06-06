import 'source_interface.dart';

/// In-memory registry of all active [MangaSource] instances.
///
/// Populated at startup by [SourceLoader] and kept in sync via the
/// [SourceRegistryNotifier] Riverpod provider.
class SourceRegistry {
  SourceRegistry._();

  static final instance = SourceRegistry._();

  final Map<String, MangaSource> _sources = {};

  void register(MangaSource source) {
    _sources[source.id] = source;
  }

  void unregister(String sourceId) {
    _sources.remove(sourceId);
  }

  MangaSource? find(String sourceId) => _sources[sourceId];

  List<MangaSource> get all => List.unmodifiable(_sources.values);

  bool get isEmpty => _sources.isEmpty;
}
