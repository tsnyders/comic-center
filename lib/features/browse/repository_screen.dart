import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
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
                    child: Icon(
                      CupertinoIcons.chevron_back,
                      color: context.accentColor,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Extension Repository',
                    style: AppTextStyles.sectionTitle.copyWith(
                      color: context.textPrimaryColor,
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
              child: Text(
                'Built-in Sources',
                style: AppTextStyles.sectionTitle.copyWith(
                  color: context.textPrimaryColor,
                ),
              ),
            ),
          ),

          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                const _NativeExtensionTile(name: 'MangaDex', lang: 'EN', version: '1.0.0'),
                const _NativeExtensionTile(name: 'AllManga', lang: 'EN', version: '1.0.0'),
                const _NativeExtensionTile(name: 'DemonicScans', lang: 'EN', version: '1.0.0'),
              ]),
            ),
          ),

          // Index section
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: Text(
                'Keiyoushi Index',
                style: AppTextStyles.sectionTitle.copyWith(
                  color: context.textPrimaryColor,
                ),
              ),
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
                  style: AppTextStyles.bodySmall.copyWith(
                    color: context.textSecondaryColor,
                  ),
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
        color: context.surfaceElevatedColor.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(
          color: context.borderStrongColor,
          width: AppRadius.hairline,
        ),
      ),
      child: Row(
        children: [
          const SizedBox(width: 12),
          Icon(CupertinoIcons.search, size: 15, color: context.textTertiaryColor),
          const SizedBox(width: 8),
          Expanded(
            child: CupertinoTextField(
              controller: _ctrl,
              placeholder: 'Search extensions...',
              placeholderStyle: AppTextStyles.bodySmall.copyWith(
                color: context.textQuaternaryColor,
              ),
              style: AppTextStyles.bodySmall.copyWith(
                color: context.textPrimaryColor,
              ),
              decoration: null,
              onChanged: (v) {
                setState(() {});
                widget.onChanged(v);
              },
            ),
          ),
          if (_ctrl.text.isNotEmpty)
            GestureDetector(
              onTap: () {
                _ctrl.clear();
                setState(() {});
                widget.onChanged('');
              },
              child: Padding(
                padding: const EdgeInsets.only(right: 10),
                child: Icon(
                  CupertinoIcons.xmark_circle_fill,
                  size: 15,
                  color: context.textTertiaryColor,
                ),
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
        color: context.surfaceElevatedColor.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(
          color: context.accentLineColor,
          width: AppRadius.hairline,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: context.accentSubtleColor,
              borderRadius: BorderRadius.circular(AppRadius.sm),
            ),
            child: Icon(
              CupertinoIcons.book,
              color: context.accentColor,
              size: 18,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: AppTextStyles.bodyMedium.copyWith(
                    fontWeight: FontWeight.w600,
                    color: context.textPrimaryColor,
                  ),
                ),
                Text(
                  '$lang · v$version',
                  style: AppTextStyles.caption.copyWith(
                    color: context.textTertiaryColor,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: context.accentSubtleColor,
              borderRadius: BorderRadius.circular(AppRadius.xs),
            ),
            child: Text(
              'Built-in',
              style: AppTextStyles.caption.copyWith(
                color: context.accentColor,
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

  static const _gradients = [
    AppColors.gradEmber,
    AppColors.gradViolet,
    AppColors.gradTeal,
    AppColors.gradRose,
  ];

  @override
  Widget build(BuildContext context) {
    final gradIndex = entry.name[0].codeUnitAt(0) % 4;
    final gradient = _gradients[gradIndex];

    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: context.surfaceElevatedColor.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(
          color: context.borderColor,
          width: AppRadius.hairline,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: gradient,
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            child: Center(
              child: Text(
                entry.name.substring(0, 1).toUpperCase(),
                style: const TextStyle(
                  color: CupertinoColors.white,
                  fontSize: 18,
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
                  style: AppTextStyles.sourceName.copyWith(
                    color: context.textPrimaryColor,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  '${entry.lang.toUpperCase()} · v${entry.version}${entry.isNsfw ? ' · 18+' : ''}',
                  style: AppTextStyles.caption.copyWith(
                    color: context.textTertiaryColor,
                  ),
                ),
              ],
            ),
          ),
          Icon(
            CupertinoIcons.arrow_down_to_line,
            size: 16,
            color: context.textTertiaryColor,
          ),
        ],
      ),
    );
  }
}
