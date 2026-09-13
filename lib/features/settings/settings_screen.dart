import 'package:extended_image/extended_image.dart'
    show clearDiskCachedImages, getCachedSizeBytes;
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers/database_provider.dart';
import '../../core/providers/download_provider.dart';
import '../../core/providers/google_drive_provider.dart';
import '../../core/providers/library_provider.dart';
import '../../core/providers/reader_provider.dart';
import '../../core/providers/settings_provider.dart';
import '../../core/services/backup_service.dart';
import '../../core/services/google_drive_service.dart';
import '../../core/services/update_service.dart';
import '../../core/services/whats_new_service.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/yomi_theme.dart';
import '../../shared/widgets/sumi.dart';
import '../downloads/downloads_screen.dart';
import '../library/category_management_screen.dart';
import 'backup_restore_screen.dart';
import 'changelog_screen.dart';
import 'diagnostics_screen.dart';
import 'drive_restore_screen.dart';

/// Image disk cache size (extended_image reader pages).
final _cacheSizeProvider =
    FutureProvider.autoDispose<int>((_) => getCachedSizeBytes());

/// ============================================================================
/// Settings — "You". Account card, then grouped rows: READING · 読,
/// APPEARANCE · 姿 (Theme + Accent edit the live theme), LIBRARY · 庫,
/// STORAGE · 蔵, BACKUP · 写, ABOUT · 情.
/// ============================================================================
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.yc;
    final theme = context.yomi;
    final insets = MediaQuery.paddingOf(context);
    final gutter = context.yomiGutter;

    final direction = ref.watch(readingDirectionProvider);
    final readerMode = ref.watch(defaultReaderModeProvider);
    final scale = ref.watch(pageScaleModeProvider);
    final background = ref.watch(readerBackgroundProvider);
    final haptics = ref.watch(hapticsProvider);
    final autoUpdate = ref.watch(autoCheckUpdatesProvider);
    final dlLocation = ref.watch(downloadLocationProvider);
    final wifiOnly = ref.watch(wifiOnlyProvider);
    final queued = ref.watch(downloadQueueProvider).valueOrNull?.length ?? 0;
    final cacheBytes = ref.watch(_cacheSizeProvider).valueOrNull;
    final driveAccount = ref.watch(googleDriveProvider);

    void push(Widget screen) => Navigator.of(context, rootNavigator: true)
        .push(CupertinoPageRoute<void>(builder: (_) => screen));

    return CupertinoPageScaffold(
      backgroundColor: c.bg,
      child: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          SliverToBoxAdapter(child: SizedBox(height: insets.top + 12)),
          SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: gutter),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SumiOverline('SETTINGS · 設'),
                  Text('You', style: YomiText.kanji(36, color: c.fg)),
                ],
              ),
            ),
          ),

          // ── Account ───────────────────────────────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.fromLTRB(gutter, 18, gutter, 0),
              child: _AccountCard(
                email: driveAccount?.email,
                name: driveAccount?.displayName,
                photoUrl: driveAccount?.photoUrl,
                onSignIn: () => _linkGoogleDrive(context, ref),
                onSignOut: () => _signOutFromDrive(context, ref),
              ),
            ),
          ),

          // ── READING · 読 ──────────────────────────────────────────────────
          _Group(title: 'READING · 読', rows: [
            _Row(
              label: 'Reading direction',
              value: switch (direction) {
                ReadingDirection.ltr => 'Left to right',
                ReadingDirection.rtl => 'Right to left',
                ReadingDirection.vertical => 'Vertical',
              },
              onTap: () => _pick(
                  context,
                  'Reading direction',
                  [
                    (ReadingDirection.ltr, 'Left to right'),
                    (ReadingDirection.rtl, 'Right to left'),
                    (ReadingDirection.vertical, 'Vertical'),
                  ],
                  (v) => ref.read(readingDirectionProvider.notifier).state = v),
            ),
            _Row(
              label: 'Default mode',
              value: switch (readerMode) {
                ReaderMode.auto => 'Auto',
                ReaderMode.page => 'Page · 頁',
                ReaderMode.strip => 'Strip · 縦',
              },
              onTap: () => _pick(
                  context,
                  'Default mode',
                  [
                    (ReaderMode.auto, 'Auto (from source)'),
                    (ReaderMode.page, 'Page · 頁'),
                    (ReaderMode.strip, 'Strip · 縦'),
                  ],
                  (v) =>
                      ref.read(defaultReaderModeProvider.notifier).state = v),
            ),
            _Row(
              label: 'Page scale',
              value: switch (scale) {
                PageScaleMode.fitWidth => 'Fit width',
                PageScaleMode.fitHeight => 'Fit height',
                PageScaleMode.original => 'Original',
              },
              onTap: () => _pick(
                  context,
                  'Page scale',
                  [
                    (PageScaleMode.fitWidth, 'Fit width'),
                    (PageScaleMode.fitHeight, 'Fit height'),
                    (PageScaleMode.original, 'Original'),
                  ],
                  (v) => ref.read(pageScaleModeProvider.notifier).state = v),
            ),
            _Row(
              label: 'Page background',
              value: switch (background) {
                ReaderBackground.black => 'Black',
                ReaderBackground.white => 'White',
                ReaderBackground.sepia => 'Sepia',
              },
              onTap: () => _pick(
                  context,
                  'Page background',
                  [
                    (ReaderBackground.black, 'Black'),
                    (ReaderBackground.white, 'White'),
                    (ReaderBackground.sepia, 'Sepia'),
                  ],
                  (v) => ref.read(readerBackgroundProvider.notifier).state = v),
            ),
            _Row(
              label: 'Haptics on page turn',
              trailing: SumiToggle(
                label: 'Haptics on page turn',
                value: haptics,
                onChanged: (v) => ref.read(hapticsProvider.notifier).state = v,
              ),
              onTap: () => ref.read(hapticsProvider.notifier).state = !haptics,
            ),
          ]),

          // ── APPEARANCE · 姿 ───────────────────────────────────────────────
          _Group(title: 'APPEARANCE · 姿', rows: [
            _Row(
              label: 'Theme',
              value: theme.modeName,
              onTap: () => ref.read(brightnessProvider.notifier).state =
                  theme.isDark ? Brightness.light : Brightness.dark,
            ),
            _Row(
              label: 'Accent',
              trailing: _AccentSwatches(
                selected: theme.accentIndex,
                onChanged: (i) =>
                    ref.read(accentIndexProvider.notifier).state = i,
              ),
            ),
            _Row(
              label: 'Cover size',
              value: _cap(theme.coverSize.name),
              onTap: () => _pick(
                  context,
                  'Cover size',
                  [
                    (CoverSize.small, 'Small'),
                    (CoverSize.medium, 'Medium'),
                    (CoverSize.large, 'Large'),
                  ],
                  (v) => ref.read(coverSizeProvider.notifier).state = v),
            ),
            _Row(
              label: 'Density',
              value: _cap(theme.density.name),
              onTap: () => _pick(
                  context,
                  'Density',
                  [
                    (YomiDensity.comfortable, 'Comfortable'),
                    (YomiDensity.compact, 'Compact'),
                  ],
                  (v) => ref.read(densityProvider.notifier).state = v),
            ),
          ]),

          // ── LIBRARY · 庫 ──────────────────────────────────────────────────
          _Group(title: 'LIBRARY · 庫', rows: [
            _Row(
              label: 'Categories',
              onTap: () => push(const CategoryManagementScreen()),
            ),
            _Row(
              label: 'Check for chapter updates',
              trailing: SumiToggle(
                label: 'Check for chapter updates',
                value: autoUpdate,
                onChanged: (v) =>
                    ref.read(autoCheckUpdatesProvider.notifier).state = v,
              ),
              onTap: () => ref.read(autoCheckUpdatesProvider.notifier).state =
                  !autoUpdate,
            ),
          ]),

          // ── STORAGE · 蔵 ──────────────────────────────────────────────────
          _Group(title: 'STORAGE · 蔵', rows: [
            _Row(
              label: 'Downloads',
              value: queued == 0 ? 'Up to date' : '$queued queued',
              onTap: () => push(const DownloadsScreen()),
            ),
            _Row(
              label: 'Storage location',
              value: dlLocation == DownloadLocation.local
                  ? 'This device'
                  : 'Google Drive',
              onTap: () => _pick(
                  context,
                  'Storage location',
                  [
                    (DownloadLocation.local, 'This device'),
                    (DownloadLocation.googleDrive, 'Google Drive'),
                  ],
                  (v) => ref.read(downloadLocationProvider.notifier).state = v),
            ),
            _Row(
              label: 'Download over Wi-Fi only',
              trailing: SumiToggle(
                label: 'Download over Wi-Fi only',
                value: wifiOnly,
                onChanged: (v) => ref.read(wifiOnlyProvider.notifier).state = v,
              ),
              onTap: () =>
                  ref.read(wifiOnlyProvider.notifier).state = !wifiOnly,
            ),
            _Row(
              label: 'Clear cache',
              value: cacheBytes == null ? '…' : _mb(cacheBytes),
              onTap: () async {
                await clearDiskCachedImages();
                PaintingBinding.instance.imageCache.clear();
                ref.invalidate(_cacheSizeProvider);
              },
            ),
          ]),

          // ── BACKUP · 写 ───────────────────────────────────────────────────
          _Group(title: 'BACKUP · 写', rows: [
            _Row(
              label: 'Export backup',
              onTap: () => _exportBackup(context, ref),
            ),
            _Row(
              label: 'Restore backup',
              onTap: () => push(const BackupRestoreScreen()),
            ),
            if (driveAccount == null)
              _Row(
                label: 'Connect Google Drive',
                onTap: () => _linkGoogleDrive(context, ref),
              )
            else ...[
              _Row(
                label: 'Backup to Drive',
                value: driveAccount.email,
                onTap: () => _backupToDrive(context, ref),
              ),
              _Row(
                label: 'Restore from Drive',
                onTap: () => push(const DriveRestoreScreen()),
              ),
            ],
          ]),

          // ── ABOUT · 情 ────────────────────────────────────────────────────
          _Group(title: 'ABOUT · 情', rows: [
            _Row(label: 'Version', value: WhatsNewService.currentVersion),
            _Row(
              label: "What's new",
              onTap: () => push(const ChangelogScreen()),
            ),
            _Row(
              label: 'Check for updates',
              onTap: () => _checkForUpdates(context),
            ),
            _Row(
              label: 'Diagnostics',
              onTap: () => push(const DiagnosticsScreen()),
            ),
          ]),

          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.only(top: 30),
              child: Text(
                'YOMI ${WhatsNewService.currentVersion} · ${theme.look.name.toUpperCase()}',
                textAlign: TextAlign.center,
                style: YomiText.ui(11, color: c.fg2, letterSpacing: 1),
              ),
            ),
          ),
          SliverToBoxAdapter(child: SizedBox(height: insets.bottom + 120)),
        ],
      ),
    );
  }

  static String _cap(String s) =>
      s.isEmpty ? s : '${s[0].toUpperCase()}${s.substring(1)}';

  static String _mb(int bytes) => bytes < 1 << 20
      ? '${(bytes / 1024).round()} KB'
      : '${(bytes / (1 << 20)).toStringAsFixed(bytes < 100 << 20 ? 1 : 0)} MB';

  /// Action-sheet picker for enum rows (the whole row is the tap target).
  static Future<void> _pick<T>(
    BuildContext context,
    String title,
    List<(T, String)> options,
    ValueChanged<T> onChanged,
  ) async {
    final picked = await showCupertinoModalPopup<T>(
      context: context,
      builder: (ctx) => CupertinoActionSheet(
        title: Text(title),
        actions: [
          for (final o in options)
            CupertinoActionSheetAction(
              onPressed: () => Navigator.pop(ctx, o.$1),
              child: Text(o.$2),
            ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('Cancel'),
        ),
      ),
    );
    if (picked != null) {
      HapticFeedback.selectionClick();
      onChanged(picked);
    }
  }

  // ── Update check ─────────────────────────────────────────────────────────

  static Future<void> _checkForUpdates(BuildContext context) async {
    showCupertinoDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const CupertinoAlertDialog(
        title: Text('Checking for Updates'),
        content: Padding(
          padding: EdgeInsets.only(top: 12),
          child: CupertinoActivityIndicator(),
        ),
      ),
    );

    try {
      final release = await UpdateService.fetchLatestRelease();
      if (!context.mounted) return;
      Navigator.of(context, rootNavigator: true).pop();

      if (release == null) {
        _showAlert(context, 'No Updates Available',
            'You are already on the latest version.');
        return;
      }

      showCupertinoDialog<void>(
        context: context,
        builder: (_) => _UpdateDialog(release: release),
      );
    } catch (e) {
      if (!context.mounted) return;
      Navigator.of(context, rootNavigator: true).pop();
      _showAlert(context, 'Error', e.toString());
    }
  }

  // ── Google Drive actions ─────────────────────────────────────────────────

  static Future<void> _linkGoogleDrive(
      BuildContext context, WidgetRef ref) async {
    if (!GoogleDriveService.isConfigured) {
      _showAlert(
        context,
        'Google Drive Not Set Up',
        'This build has no Google OAuth client ID yet, so Drive backup is '
            'disabled.\n\nAdd an iOS client ID (see docs/DRIVE_SETUP_IOS.md) '
            'and rebuild to enable cloud backup. Local backup still works.',
      );
      return;
    }
    final confirmed = await showCupertinoDialog<bool>(
      context: context,
      builder: (_) => CupertinoAlertDialog(
        title: const Text('Connect Google Drive'),
        content: const Text(
            'Linking a Google account enables cloud backup and restore of your library.\n\nSign in to proceed.'),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Sign In'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;

    showCupertinoDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const CupertinoAlertDialog(
        title: Text('Signing in…'),
        content: Padding(
          padding: EdgeInsets.only(top: 12),
          child: CupertinoActivityIndicator(),
        ),
      ),
    );

    try {
      final ok = await ref.read(googleDriveProvider.notifier).signIn();
      if (!context.mounted) return;
      Navigator.of(context, rootNavigator: true).pop();
      if (!ok) return;
      final account = ref.read(googleDriveProvider);
      _showAlert(context, 'Google Drive Connected',
          'Signed in as ${account?.email ?? ''}');
    } catch (e) {
      if (!context.mounted) return;
      Navigator.of(context, rootNavigator: true).pop();
      final msg = e.toString();
      if (msg.contains('ApiException: 10') ||
          msg.contains('DEVELOPER_ERROR') ||
          msg.contains(': 10:')) {
        _showDeveloperErrorDialog(context);
      } else {
        _showAlert(context, 'Sign-In Failed', msg);
      }
    }
  }

  static void _showDeveloperErrorDialog(BuildContext context) {
    showCupertinoDialog<void>(
      context: context,
      builder: (_) => CupertinoAlertDialog(
        title: const Text('Google Drive Setup Required'),
        content: const Text(
          'Google Sign-In is not configured for this build.\n\n'
          'To fix:\n'
          '1. Register your app\'s SHA-1 fingerprint in Google Cloud Console\n'
          '2. Download the updated google-services.json and rebuild\n\n'
          'Get the debug fingerprint with:\n'
          'keytool -list -v -keystore ~/.android/debug.keystore '
          '-alias androiddebugkey -storepass android -keypass android',
        ),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  static Future<void> _signOutFromDrive(
      BuildContext context, WidgetRef ref) async {
    final confirmed = await showCupertinoDialog<bool>(
      context: context,
      builder: (_) => CupertinoAlertDialog(
        title: const Text('Google Drive'),
        content: Text(
            'Signed in as ${ref.read(googleDriveProvider)?.email ?? ''}.\n\nSign out?'),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Sign Out'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await ref.read(googleDriveProvider.notifier).signOut();
    }
  }

  static Future<void> _backupToDrive(
      BuildContext context, WidgetRef ref) async {
    showCupertinoDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const CupertinoAlertDialog(
        title: Text('Uploading to Drive…'),
        content: Padding(
          padding: EdgeInsets.only(top: 12),
          child: CupertinoActivityIndicator(),
        ),
      ),
    );
    try {
      final isar = ref.read(isarProvider);
      final categories = ref.read(libraryCategoriesProvider);
      final backup =
          await BackupService.export(isar: isar, categories: categories);
      await GoogleDriveService.uploadBackup(backup.file);
      if (!context.mounted) return;
      Navigator.of(context, rootNavigator: true).pop();
      _showAlert(context, 'Backup Uploaded',
          'Uploaded ${backup.mangaCount ?? 0} manga to Google Drive.');
    } catch (e) {
      if (!context.mounted) return;
      Navigator.of(context, rootNavigator: true).pop();
      _showAlert(context, 'Upload Failed', e.toString());
    }
  }

  static Future<void> _exportBackup(BuildContext context, WidgetRef ref) async {
    showCupertinoDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const CupertinoAlertDialog(
        title: Text('Exporting Backup'),
        content: Padding(
          padding: EdgeInsets.only(top: 12),
          child: CupertinoActivityIndicator(),
        ),
      ),
    );

    try {
      final isar = ref.read(isarProvider);
      final categories = ref.read(libraryCategoriesProvider);
      final backup = await BackupService.export(
        isar: isar,
        categories: categories,
      );
      if (!context.mounted) return;
      Navigator.of(context, rootNavigator: true).pop();
      _showAlert(context, 'Backup Exported',
          'Saved ${backup.mangaCount ?? 0} manga to:\n${backup.file.path}');
    } catch (e) {
      if (!context.mounted) return;
      Navigator.of(context, rootNavigator: true).pop();
      _showAlert(context, 'Export Failed', e.toString());
    }
  }

  static void _showAlert(BuildContext context, String title, String message) {
    showCupertinoDialog<void>(
      context: context,
      builder: (_) => CupertinoAlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }
}

// ── Account card ──────────────────────────────────────────────────────────────

class _AccountCard extends StatelessWidget {
  const _AccountCard({
    required this.email,
    required this.name,
    required this.photoUrl,
    required this.onSignIn,
    required this.onSignOut,
  });

  final String? email;
  final String? name;
  final String? photoUrl;
  final VoidCallback onSignIn;
  final VoidCallback onSignOut;

  @override
  Widget build(BuildContext context) {
    final c = context.yc;
    final signedIn = email != null;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border.all(color: c.line),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(color: c.fg, shape: BoxShape.circle),
            alignment: Alignment.center,
            child: signedIn && (photoUrl?.isNotEmpty ?? false)
                ? Image.network(photoUrl!,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) =>
                        Text('客', style: YomiText.kanji(26, color: c.bg)))
                : Text('客', style: YomiText.kanji(26, color: c.bg)),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  signedIn
                      ? ((name?.isNotEmpty ?? false) ? name! : email!)
                      : 'Guest reader',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: YomiText.ui(16, weight: FontWeight.w700, color: c.fg),
                ),
                Text(
                  signedIn ? email! : 'Sign in to sync progress',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: YomiText.ui(12, color: c.fg2),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          SumiPress(
            onTap: signedIn ? onSignOut : onSignIn,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: signedIn ? const Color(0x00000000) : c.ac,
                border: signedIn ? Border.all(color: c.line) : null,
                borderRadius: BorderRadius.circular(2),
              ),
              child: Text(
                signedIn ? 'Sign out' : 'Sign in',
                style: YomiText.ui(12,
                    weight: FontWeight.w700,
                    color: signedIn ? c.fg : c.onAccent),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Group + row ───────────────────────────────────────────────────────────────

class _Group extends StatelessWidget {
  const _Group({required this.title, required this.rows});
  final String title;
  final List<Widget> rows;

  @override
  Widget build(BuildContext context) {
    final c = context.yc;
    final gutter = context.yomiGutter;
    return SliverToBoxAdapter(
      child: Padding(
        padding: EdgeInsets.fromLTRB(gutter, 26, gutter, 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SumiOverline(title),
            const SizedBox(height: 8),
            Container(
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                border: Border.all(color: c.line),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Column(
                children: [
                  for (var i = 0; i < rows.length; i++) ...[
                    if (i > 0) Container(height: 1, color: c.line),
                    rows[i],
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 14×16 padding, 14px label, 13px `fg2` value, optional trailing control.
/// No chevrons: the whole row is the tap target.
class _Row extends StatelessWidget {
  const _Row({
    required this.label,
    this.value,
    this.trailing,
    this.onTap,
  });

  final String label;
  final String? value;
  final Widget? trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.yc;
    return Semantics(
      button: onTap != null,
      label: value == null ? label : '$label, $value',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap == null
            ? null
            : () {
                HapticFeedback.selectionClick();
                onTap!();
              },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Expanded(child: Text(label, style: YomiText.ui(14, color: c.fg))),
              if (value != null)
                Flexible(
                  child: Text(value!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.right,
                      style: YomiText.ui(13, color: c.fg2)),
                ),
              if (trailing != null) ...[
                const SizedBox(width: 8),
                trailing!,
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Four 22px swatches from the look's curated set; selected gets a `fg` ring.
class _AccentSwatches extends StatelessWidget {
  const _AccentSwatches({required this.selected, required this.onChanged});
  final int selected;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final spec = context.yomi.spec;
    final c = context.yc;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < spec.accents.length; i++)
          Semantics(
            button: true,
            selected: i == selected,
            label: spec.accentNames[i],
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () {
                HapticFeedback.selectionClick();
                onChanged(i);
              },
              child: AnimatedContainer(
                duration: AppMotion.fast,
                curve: AppMotion.snap,
                width: 28,
                height: 28,
                margin: const EdgeInsets.only(left: 6),
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: i == selected ? c.fg : const Color(0x00000000),
                    width: 1.5,
                  ),
                ),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: spec.accents[i],
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

// ── Update dialog ─────────────────────────────────────────────────────────

class _UpdateDialog extends StatefulWidget {
  const _UpdateDialog({required this.release});
  final ReleaseInfo release;

  @override
  State<_UpdateDialog> createState() => _UpdateDialogState();
}

class _UpdateDialogState extends State<_UpdateDialog> {
  double? _progress;
  bool _downloading = false;

  Future<void> _startDownload() async {
    final url = widget.release.apkUrl;
    // iOS can't sideload an APK, and a missing APK asset has nothing to
    // install — in both cases just open the release page in the browser.
    if (!UpdateService.supportsInAppUpdate || url == null) {
      Navigator.of(context).pop();
      await UpdateService.openUrl(UpdateService.releaseUrl(widget.release.tag));
      return;
    }
    setState(() {
      _downloading = true;
      _progress = 0;
    });
    try {
      await UpdateService.downloadAndInstall(
        url,
        onProgress: (p) {
          if (mounted) setState(() => _progress = p);
        },
      );
      // installApk hands off to the system installer — dialog can close.
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      setState(() => _downloading = false);
      Navigator.of(context).pop();
      showCupertinoDialog<void>(
        context: context,
        builder: (_) => CupertinoAlertDialog(
          title: const Text('Update Failed'),
          content: Text(e.toString()),
          actions: [
            CupertinoDialogAction(
              onPressed: () => Navigator.pop(context),
              child: const Text('OK'),
            ),
          ],
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoAlertDialog(
      title: Text('Version ${widget.release.tag}'),
      content: _downloading
          ? Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 12),
                const CupertinoActivityIndicator(),
                const SizedBox(height: 8),
                Text(
                  _progress != null
                      ? '${(_progress! * 100).toStringAsFixed(0)}%'
                      : 'Starting…',
                  style: const TextStyle(fontSize: 13),
                ),
              ],
            )
          : Text(
              widget.release.body.length > 300
                  ? '${widget.release.body.substring(0, 300)}…'
                  : widget.release.body.isNotEmpty
                      ? widget.release.body
                      : 'A new version is available.',
            ),
      actions: _downloading
          ? const []
          : [
              CupertinoDialogAction(
                onPressed: () => Navigator.pop(context),
                child: const Text('Later'),
              ),
              CupertinoDialogAction(
                isDefaultAction: true,
                onPressed: _startDownload,
                child: Text(
                  (UpdateService.supportsInAppUpdate &&
                          widget.release.apkUrl != null)
                      ? 'Download & Install'
                      : 'View Release',
                ),
              ),
            ],
    );
  }
}
