import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers/settings_provider.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/yomi_theme.dart';
import '../../shared/widgets/sumi.dart';

/// First launch: enso mark, wordmark, genre picker, continue as guest.
class OnboardingScreen extends ConsumerWidget {
  const OnboardingScreen({super.key});

  static const genres = [
    ('Action', '闘'),
    ('Isekai', '異'),
    ('Comedy', '笑'),
    ('Sci-fi', '宇'),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.yc;
    final selected = ref.watch(selectedGenresProvider);
    final insets = MediaQuery.paddingOf(context);
    final gutter = context.yomiGutter;
    final gap = context.yomiGridGap;

    void toggle(String name) {
      final next = {...selected};
      next.contains(name) ? next.remove(name) : next.add(name);
      ref.read(selectedGenresProvider.notifier).state = next;
    }

    void finish({int tab = 1}) {
      ref.read(rootTabProvider.notifier).state = tab;
      ref.read(onboardingDoneProvider.notifier).state = true;
    }

    Widget tile(int i) => _GenreTile(
          name: genres[i].$1,
          kanji: genres[i].$2,
          selected: selected.contains(genres[i].$1),
          onTap: () => toggle(genres[i].$1),
        );

    return CupertinoPageScaffold(
      backgroundColor: c.bg,
      child: SumiRise(
        duration: const Duration(milliseconds: 500),
        child: CustomScrollView(
          physics: const ClampingScrollPhysics(),
          slivers: [
            SliverFillRemaining(
              hasScrollBody: false,
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                    gutter, insets.top + 44, gutter, insets.bottom + 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Center(child: Enso()),
                    const SizedBox(height: 8),
                    Text('Yomi',
                        textAlign: TextAlign.center,
                        style: YomiText.kanji(44, color: c.fg)),
                    const SizedBox(height: 6),
                    Text('読む · READ',
                        textAlign: TextAlign.center,
                        style: YomiText.ui(13, color: c.fg2, letterSpacing: 2)),
                    const SizedBox(height: 40),
                    Text('WHAT DO YOU READ?',
                        style: YomiText.ui(13, color: c.fg2, letterSpacing: 1)),
                    const SizedBox(height: 14),
                    Row(children: [
                      Expanded(child: tile(0)),
                      SizedBox(width: gap),
                      Expanded(child: tile(1)),
                    ]),
                    SizedBox(height: gap),
                    Row(children: [
                      Expanded(child: tile(2)),
                      SizedBox(width: gap),
                      Expanded(child: tile(3)),
                    ]),
                    const Spacer(),
                    const SizedBox(height: 24),
                    SumiButton(label: 'Continue as guest', onTap: finish),
                    const SizedBox(height: 14),
                    SumiPress(
                      onTap: () => finish(tab: 2),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: Text('Sign in to sync across devices',
                            textAlign: TextAlign.center,
                            style: YomiText.ui(13, color: c.fg2)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Ink-stamp genre tile: kanji top-left, name bottom-left, 22px dot top-right.
/// Border, background, kanji colour and dot fill all transition 180ms snap.
class _GenreTile extends StatelessWidget {
  const _GenreTile({
    required this.name,
    required this.kanji,
    required this.selected,
    required this.onTap,
  });

  final String name;
  final String kanji;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.yc;
    const clear = Color(0x00000000);
    return Semantics(
      button: true,
      selected: selected,
      label: name,
      child: SumiPress(
        onTap: onTap,
        scale: AppMotion.activeScale,
        child: AnimatedContainer(
          duration: AppMotion.fast,
          curve: AppMotion.snap,
          height: 112,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: selected ? context.yomi.selectedTileBg : clear,
            border: Border.all(color: selected ? c.ac : c.line),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              AnimatedDefaultTextStyle(
                duration: AppMotion.fast,
                curve: AppMotion.snap,
                style: YomiText.kanji(40, color: selected ? c.ac : c.fg)
                    .copyWith(height: 1),
                child: Text(kanji),
              ),
              Positioned(
                left: 0,
                bottom: -2,
                child: Text(name,
                    style:
                        YomiText.ui(14, weight: FontWeight.w700, color: c.fg)),
              ),
              Positioned(
                right: -2,
                top: -2,
                child: AnimatedContainer(
                  duration: AppMotion.fast,
                  curve: AppMotion.snap,
                  width: 22,
                  height: 22,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: selected ? c.ac : clear,
                    border:
                        Border.all(color: selected ? c.ac : c.line, width: 1.5),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
