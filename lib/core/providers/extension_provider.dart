import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../extensions/extension_factory.dart';
import 'source_registry_provider.dart';

// ── Extension entry model ─────────────────────────────────────────────────

class ExtensionEntry {
  const ExtensionEntry({
    required this.name,
    required this.pkg,
    required this.lang,
    required this.version,
    required this.isNsfw,
  });

  factory ExtensionEntry.fromJson(Map<String, dynamic> m) {
    return ExtensionEntry(
      name: m['name'] as String? ?? 'Unknown',
      pkg: m['pkg'] as String? ?? '',
      lang: m['lang'] as String? ?? 'en',
      version: m['version'] as String? ?? '1.0.0',
      isNsfw: m['isNsfw'] as bool? ?? false,
    );
  }

  final String name;
  final String pkg;
  final String lang;
  final String version;
  final bool isNsfw;

  /// Icon served by the keiyoushi CDN.
  String get iconUrl =>
      'https://raw.githubusercontent.com/keiyoushi/extensions/repo/icon/$pkg.png';

  /// Non-null when Yomi ships a native Dart implementation for this extension.
  String? get yomiSourceId => ExtensionFactory.pkgToSourceId[pkg];

  bool get isNativelySupported => yomiSourceId != null;
}

// ── Providers ─────────────────────────────────────────────────────────────

/// Fetches and caches the keiyoushi extension index.
final extensionIndexProvider = FutureProvider<List<ExtensionEntry>>((ref) async {
  final dio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 15),
    receiveTimeout: const Duration(seconds: 30),
  ));

  final resp = await dio.get<String>(
    'https://raw.githubusercontent.com/keiyoushi/extensions/repo/index.min.json',
    options: Options(responseType: ResponseType.plain),
  );

  final list = jsonDecode(resp.data!) as List;
  final entries = list
      .map((e) => ExtensionEntry.fromJson(e as Map<String, dynamic>))
      .where((e) => e.lang == 'en' || e.lang == 'all')
      .toList();

  // Ensure every built-in native source is installable, even if the upstream
  // keiyoushi index doesn't list it (e.g. western-comic aggregators).
  final presentSourceIds = {
    for (final e in entries)
      if (e.yomiSourceId != null) e.yomiSourceId,
  };
  for (final b in ExtensionFactory.builtInExtensions) {
    if (presentSourceIds.contains(b.sourceId)) continue;
    entries.add(ExtensionEntry(
      name: b.name,
      pkg: b.pkg,
      lang: b.lang,
      version: '1.0.0',
      isNsfw: b.isNsfw,
    ));
  }

  // Natively supported extensions float to the top.
  entries.sort((a, b) {
    if (a.isNativelySupported != b.isNativelySupported) {
      return a.isNativelySupported ? -1 : 1;
    }
    return a.name.compareTo(b.name);
  });

  return entries;
});

/// The set of source IDs the user currently has installed (from the registry).
final installedSourceIdsProvider = Provider<Set<String>>((ref) {
  final sources = ref.watch(sourceRegistryProvider);
  return {for (final s in sources) s.id};
});
