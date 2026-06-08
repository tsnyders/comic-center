import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';

// ── Provider ────────────────────────────────────────────────────────────────

final _extensionIndexProvider = FutureProvider<List<_ExtensionEntry>>((ref) async {
  final dio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 15),
    receiveTimeout: const Duration(seconds: 30),
  ));

  final resp = await dio.get<String>(
    'https://raw.githubusercontent.com/keiyoushi/extensions/repo/index.min.json',
    options: Options(responseType: ResponseType.plain),
  );

  final list = jsonDecode(resp.data!) as List;
  return list
      .map((e) => _ExtensionEntry.fromJson(e as Map<String, dynamic>))
      .where((e) => e.lang == 'en' || e.lang == 'all')
      .toList()
    ..sort((a, b) => a.name.compareTo(b.name));
});

// ── Model ────────────────────────────────────────────────────────────────────

class _ExtensionEntry {
  const _ExtensionEntry({
    required this.name,
    required this.pkg,
    required this.lang,
    required this.version,
    required this.isNsfw,
  });

  factory _ExtensionEntry.fromJson(Map<String, dynamic> m) {
    return _ExtensionEntry(
      name: m['name'] as String? ?? 'Unknown',
      pkg: m['pkg'] as String? ?? '',
      lang: m['lang'] as String? ?? 'en',
      version: m['version'] as String? ?? '',
      isNsfw: m['isNsfw'] as bool? ?? false,
    );
  }

  final String name;
  final String pkg;
  final String lang;
  final String version;
  final bool isNsfw;

  // Native sources built into the app.
  static const _nativePkgs = {
    'eu.kanade.tachiyomi.extension.en.mangadex',
    'eu.kanade.tachiyomi.extension.en.allmanga',
    'eu.kanade.tachiyomi.extension.en.mangademon',
  };

  bool get isNativelySupported => _nativePkgs.contains(pkg);
}

// ── Screen ───────────────────────────────────────────────────────────────────

class RepositoryScreen extends ConsumerStatefulWidget {
  const RepositoryScreen({super.key});

  @override
  ConsumerState<RepositoryScreen> createState() => _RepositoryScreenState();
}

class _RepositoryScreenState extends ConsumerState<RepositoryScreen> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final extensions = ref.watch(_extensionIndexProvider);
    final topPadding = MediaQuery.of(context).padding.top;

    return CupertinoPageScaffold(
      backgroundColor: CupertinoTheme.of(context).scaffoldBackgroundColor,
      child: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          SliverToBoxAdapter(child: SizedBox(height: topPadding + 8)),

          // Header row
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.of(context).pop(),
                    child: const Icon(
                      CupertinoIcons.chevron_back,
                      color: AppColors.accent,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Extension Repository',
                    style: AppTextStyles.sectionTitle.copyWith(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Search bar
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
              child: _GlassSearchBar(
                onChanged: (q) => setState(() => _query = q.toLowerCase()),
              ),
            ),
          ),

          // Native sources header
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: Text('Built-in Sources', style: AppTextStyles.sectionTitle),
            ),
          ),

          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                _NativeExtensionTile(name: 'MangaDex', lang: 'EN', version: '1.0.0'),
                _NativeExtensionTile(name: 'AllManga', lang: 'EN', version: '1.0.0'),
                _NativeExtensionTile(name: 'DemonicScans', lang: 'EN', version: '1.0.0'),
              ]),
            ),
          ),

          // Index section
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: Text('Keiyoushi Index', style: AppTextStyles.sectionTitle),
            ),
          ),

          extensions.when(
            loading: () => const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 40),
                child: Center(child: CupertinoActivityIndicator()),
              ),
            ),
            error: (e, _) => SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Text(
                  'Failed to load repository:\n$e',
                  style: AppTextStyles.bodySmall,
                  textAlign: TextAlign.center,
                ),
              ),
            ),
            data: (entries) {
              final filtered = _query.isEmpty
                  ? entries
                  : entries
                      .where((e) => e.name.toLowerCase().contains(_query))
                      .toList();

              return SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 100),
                sliver: SliverList.builder(
                  itemCount: filtered.length,
                  itemBuilder: (_, i) => _ExtensionTile(entry: filtered[i]),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

// ── Widgets ──────────────────────────────────────────────────────────────────

class _GlassSearchBar extends StatefulWidget {
  const _GlassSearchBar({required this.onChanged});
  final ValueChanged<String> onChanged;

  @override
  State<_GlassSearchBar> createState() => _GlassSearchBarState();
}

class _GlassSearchBarState extends State<_GlassSearchBar> {
  final _ctrl = TextEditingController();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 44,
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated.withOpacity(0.7),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderStrong, width: 0.5),
      ),
      child: Row(
        children: [
          const SizedBox(width: 12),
          const Icon(CupertinoIcons.search, size: 15, color: AppColors.textTertiary),
          const SizedBox(width: 8),
          Expanded(
            child: CupertinoTextField(
              controller: _ctrl,
              placeholder: 'Search extensions...',
              placeholderStyle: AppTextStyles.bodySmall.copyWith(
                color: AppColors.textQuaternary,
              ),
              style: AppTextStyles.bodySmall.copyWith(color: AppColors.textPrimary),
              decoration: null,
              onChanged: widget.onChanged,
            ),
          ),
          if (_ctrl.text.isNotEmpty)
            GestureDetector(
              onTap: () {
                _ctrl.clear();
                widget.onChanged('');
              },
              child: const Padding(
                padding: EdgeInsets.only(right: 10),
                child: Icon(CupertinoIcons.xmark_circle_fill,
                    size: 15, color: AppColors.textTertiary),
              ),
            ),
        ],
      ),
    );
  }
}

class _NativeExtensionTile extends StatelessWidget {
  const _NativeExtensionTile({
    required this.name,
    required this.lang,
    required this.version,
  });

  final String name;
  final String lang;
  final String version;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated.withOpacity(0.6),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.accent.withOpacity(0.3), width: 0.5),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: AppColors.accent.withOpacity(0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(CupertinoIcons.book, color: AppColors.accent, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name,
                    style: AppTextStyles.bodyMedium
                        .copyWith(fontWeight: FontWeight.w600)),
                Text('$lang · v$version',
                    style: AppTextStyles.caption
                        .copyWith(color: AppColors.textTertiary)),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: AppColors.accent.withOpacity(0.15),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              'Built-in',
              style: AppTextStyles.caption.copyWith(
                color: AppColors.accent,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ExtensionTile extends StatelessWidget {
  const _ExtensionTile({required this.entry});
  final _ExtensionEntry entry;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.surface.withOpacity(0.4),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border, width: 0.5),
      ),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: AppColors.surfaceElevated,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Center(
              child: Text(
                entry.name.substring(0, 1).toUpperCase(),
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entry.name,
                  style: AppTextStyles.bodySmall
                      .copyWith(fontWeight: FontWeight.w500),
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  '${entry.lang.toUpperCase()} · v${entry.version}${entry.isNsfw ? ' · 18+' : ''}',
                  style: AppTextStyles.caption
                      .copyWith(color: AppColors.textQuaternary),
                ),
              ],
            ),
          ),
          Icon(
            CupertinoIcons.arrow_down_to_line,
            size: 16,
            color: AppColors.textTertiary.withOpacity(0.5),
          ),
        ],
      ),
    );
  }
}
