import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';

import '../../core/browser/browser_fetch.dart';
import '../../core/services/app_logger.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';

/// Shows the on-device diagnostic log so users can copy it into a bug report.
class DiagnosticsScreen extends StatefulWidget {
  const DiagnosticsScreen({super.key});

  @override
  State<DiagnosticsScreen> createState() => _DiagnosticsScreenState();
}

class _DiagnosticsScreenState extends State<DiagnosticsScreen> {
  String _log = '';
  bool _loading = true;
  bool _clearingCookies = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final text = await AppLogger.instance.readAll();
    if (mounted)
      setState(() {
        _log = text;
        _loading = false;
      });
  }

  Future<void> _copy() async {
    await Clipboard.setData(ClipboardData(text: _log));
    if (!mounted) return;
    showCupertinoDialog<void>(
      context: context,
      builder: (_) => CupertinoAlertDialog(
        title: const Text('Copied'),
        content: const Text('Diagnostic log copied to clipboard.'),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _confirmClear() {
    showCupertinoDialog<void>(
      context: context,
      builder: (_) => CupertinoAlertDialog(
        title: const Text('Clear Log'),
        content: const Text(
            'This permanently deletes the on-device diagnostic log.'),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () async {
              Navigator.pop(context);
              await AppLogger.instance.clear();
              if (mounted) setState(() => _log = '');
            },
            child: const Text('Clear'),
          ),
        ],
      ),
    );
  }

  Future<void> _clearSiteCookies() async {
    setState(() => _clearingCookies = true);
    String title = 'Site cookies cleared';
    String message = 'Saved browser checks will be requested again as needed.';
    try {
      await BrowserFetch.instance.clearCookies();
    } catch (error) {
      title = 'Could not clear cookies';
      message = error.toString();
    }
    if (!mounted) return;
    setState(() => _clearingCookies = false);
    showCupertinoDialog<void>(
      context: context,
      builder: (dialogContext) => CupertinoAlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top;
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    return CupertinoPageScaffold(
      backgroundColor: context.backgroundColor,
      child: Column(
        children: [
          SizedBox(
            height: topPadding + 56,
            child: Stack(
              children: [
                Align(
                  alignment: Alignment.bottomLeft,
                  child: CupertinoButton(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text(
                      '‹ Back',
                      style: TextStyle(
                        color: context.accentColor,
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
                Align(
                  alignment: Alignment.bottomCenter,
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Text(
                      'Diagnostics',
                      style: AppTextStyles.sectionTitle.copyWith(
                        color: context.textPrimaryColor,
                      ),
                    ),
                  ),
                ),
                Align(
                  alignment: Alignment.bottomRight,
                  child: CupertinoButton(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                    onPressed: _log.isEmpty ? null : _confirmClear,
                    child: Icon(
                      CupertinoIcons.trash,
                      size: 20,
                      color: _log.isEmpty
                          ? context.textQuaternaryColor
                          : context.unreadColor,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CupertinoActivityIndicator())
                : _log.isEmpty
                    ? Center(
                        child: Text(
                          'No diagnostic log yet.',
                          style: AppTextStyles.bodySmall.copyWith(
                            color: context.textSecondaryColor,
                          ),
                        ),
                      )
                    : SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                        child: Text(
                          _log,
                          style: AppTextStyles.caption.copyWith(
                            color: context.textSecondaryColor,
                            fontFamily: 'SpaceMono',
                          ),
                        ),
                      ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: context.surfaceColor,
                border: Border.all(color: context.borderColor),
                borderRadius: BorderRadius.circular(10),
              ),
              child: CupertinoButton(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                onPressed: _clearingCookies ? null : _clearSiteCookies,
                child: Row(
                  children: [
                    Icon(CupertinoIcons.globe,
                        size: 20, color: context.textPrimaryColor),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Clear site cookies',
                        style: AppTextStyles.bodyMedium.copyWith(
                          color: context.textPrimaryColor,
                        ),
                      ),
                    ),
                    if (_clearingCookies)
                      const CupertinoActivityIndicator(radius: 8),
                  ],
                ),
              ),
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(20, 0, 20, bottomPadding + 20),
            child: SizedBox(
              width: double.infinity,
              child: CupertinoButton(
                color: context.accentColor,
                borderRadius: BorderRadius.circular(10),
                onPressed: _log.isEmpty ? null : _copy,
                child: Text(
                  'Copy to Clipboard',
                  style: AppTextStyles.buttonPrimary.copyWith(
                    color: AppColors.textOnAccent,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
