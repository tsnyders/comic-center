import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/extensions/source_interface.dart';
import '../../core/extensions/source_prefs.dart';
import '../../core/providers/preferences_provider.dart';
import '../../core/theme/yomi_theme.dart';
import '../../shared/widgets/sumi.dart';

/// Per-source settings: one row per [SourcePreference], written straight to
/// SharedPreferences under `source.<id>.<key>` so the source picks the value
/// up on its next request.
class SourceSettingsScreen extends ConsumerStatefulWidget {
  const SourceSettingsScreen({super.key, required this.source});
  final MangaSource source;

  @override
  ConsumerState<SourceSettingsScreen> createState() =>
      _SourceSettingsScreenState();
}

class _SourceSettingsScreenState extends ConsumerState<SourceSettingsScreen> {
  final _text = <String, TextEditingController>{};

  @override
  void dispose() {
    for (final c in _text.values) {
      c.dispose();
    }
    super.dispose();
  }

  String _key(SourcePreference pref) =>
      SourcePrefs.keyFor(widget.source.id, pref.key);

  Future<void> _write(Future<bool> write) async {
    await write;
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final c = context.yc;
    final prefs = ref.watch(sharedPreferencesProvider);
    final insets = MediaQuery.paddingOf(context);
    final gutter = context.yomiGutter;
    final source = widget.source;

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
                  SumiBackButton(onTap: () => Navigator.of(context).pop()),
                  const SizedBox(height: 16),
                  const SumiOverline('SOURCE', kanji: '源'),
                  DisplayText(source.name,
                      size: 36, maxLines: 2, overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
          ),
          SliverPadding(
            padding:
                EdgeInsets.fromLTRB(gutter, 26, gutter, insets.bottom + 40),
            sliver: SliverList.list(
              children: [
                const SumiOverline('SETTINGS', kanji: '設'),
                if (source.preferences.isEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Text('This source has no settings.',
                        style: YomiText.ui(14, color: c.fg2)),
                  )
                else
                  for (final pref in source.preferences)
                    _row(context, prefs, pref),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _row(
      BuildContext context, SharedPreferences prefs, SourcePreference pref) {
    final c = context.yc;
    final key = _key(pref);
    final title = Text(pref.title,
        style: YomiText.ui(15, weight: FontWeight.w600, color: c.fg));

    final Widget body;
    switch (pref) {
      case TogglePreference():
        body = Row(children: [
          Expanded(child: title),
          SumiToggle(
            label: pref.title,
            value: prefs.getBool(key) ?? pref.defaultValue,
            onChanged: (v) => _write(prefs.setBool(key, v)),
          ),
        ]);
      case TextPreference():
        final controller = _text.putIfAbsent(
          pref.key,
          () => TextEditingController(
              text: prefs.getString(key) ?? pref.defaultValue),
        );
        body = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            title,
            const SizedBox(height: 8),
            CupertinoTextField(
              controller: controller,
              onSubmitted: (v) => _write(prefs.setString(key, v)),
            ),
          ],
        );
      case SelectPreference():
        final current = prefs.getString(key) ?? pref.defaultValue;
        body = _chips(title, [
          for (var i = 0; i < pref.options.length; i++)
            SumiChip(
              label: pref.options[i],
              active: current == pref.values[i],
              onTap: () => _write(prefs.setString(key, pref.values[i])),
            ),
        ]);
      case MultiSelectPreference():
        final current = prefs.getStringList(key) ?? pref.defaultValue;
        body = _chips(title, [
          for (var i = 0; i < pref.options.length; i++)
            SumiChip(
              label: pref.options[i],
              active: current.contains(pref.values[i]),
              onTap: () {
                final v = pref.values[i];
                final next = current.contains(v)
                    ? current.where((x) => x != v).toList()
                    : [...current, v];
                _write(prefs.setStringList(key, next));
              },
            ),
        ]);
    }

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: c.line)),
      ),
      child: body,
    );
  }

  Widget _chips(Widget title, List<Widget> chips) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          title,
          const SizedBox(height: 10),
          Wrap(spacing: 8, runSpacing: 8, children: chips),
        ],
      );
}
