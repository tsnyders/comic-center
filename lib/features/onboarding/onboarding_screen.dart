import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers/settings_provider.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/yomi_theme.dart';
import '../../shared/widgets/sumi.dart';

/// First launch: look mark + wordmark, genre picker, then the look / mode /
/// accent picker (previewed live), continue as guest.
class OnboardingScreen extends ConsumerWidget {
  const OnboardingScreen({super.key});

  static const genres = ['Action', 'Isekai', 'Comedy', 'Sci-fi'];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.yc;
    final theme = context.yomi;
    final look = theme.spec;
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
          index: i,
          name: genres[i],
          mark: look.genreMarks[i],
          selected: selected.contains(genres[i]),
          onTap: () => toggle(genres[i]),
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
                    gutter, insets.top + 36, gutter, insets.bottom + 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _Masthead(look: look),
                    const SizedBox(height: 32),
                    if (look.isSumi) ...[
                      Text('WHAT DO YOU READ?',
                          style:
                              YomiText.ui(13, color: c.fg2, letterSpacing: 1)),
                      const SizedBox(height: 14),
                    ],
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

                    // ── Look · mode · accent ──────────────────────────────
                    const SizedBox(height: 28),
                    const SumiOverline('LOOK', kanji: '姿'),
                    const SizedBox(height: 10),
                    Row(children: [
                      for (final l in YomiLook.values) ...[
                        if (l != YomiLook.values.first) SizedBox(width: gap),
                        Expanded(
                          child: _LookCard(
                            spec: yomiLookSpecs[l]!,
                            selected: theme.look == l,
                            onTap: () {
                              ref.read(lookProvider.notifier).state = l;
                              ref.read(brightnessProvider.notifier).state =
                                  yomiLookSpecs[l]!.defaultMode;
                            },
                          ),
                        ),
                      ],
                    ]),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        SumiChip(
                          label: look.darkName,
                          active: theme.isDark,
                          onTap: () => ref
                              .read(brightnessProvider.notifier)
                              .state = Brightness.dark,
                        ),
                        const SizedBox(width: 8),
                        SumiChip(
                          label: look.lightName,
                          active: !theme.isDark,
                          onTap: () => ref
                              .read(brightnessProvider.notifier)
                              .state = Brightness.light,
                        ),
                        const Spacer(),
                        AccentSwatches(
                          selected: theme.accentIndex,
                          onChanged: (i) =>
                              ref.read(accentIndexProvider.notifier).state = i,
                        ),
                      ],
                    ),

                    const Spacer(),
                    const SizedBox(height: 24),
                    SumiButton(label: look.copy.continueButton, onTap: finish),
                    const SizedBox(height: 14),
                    SumiPress(
                      onTap: () => finish(tab: 2),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: Text(look.copy.signIn,
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

/// Mark + wordmark per look: Sumi enso + "Yomi", Cinema kicker + "Set the
/// scene.", Pastel よ tile + "Hi, reader!".
class _Masthead extends StatelessWidget {
  const _Masthead({required this.look});
  final YomiLookSpec look;

  @override
  Widget build(BuildContext context) {
    final c = context.yc;
    final copy = look.copy;
    switch (look.look) {
      case YomiLook.sumi:
        return Column(children: [
          const Enso(),
          const SizedBox(height: 8),
          DisplayText(copy.onboardingTitle,
              size: 44, textAlign: TextAlign.center),
          const SizedBox(height: 6),
          Text(copy.onboardingKicker,
              textAlign: TextAlign.center,
              style: YomiText.ui(13, color: c.fg2, letterSpacing: 2)),
        ]);
      case YomiLook.cinema:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 24),
            SumiOverline(copy.onboardingKicker, color: c.ac),
            const SizedBox(height: 12),
            DisplayText(copy.onboardingTitle, size: 64, height: 0.9),
            const SizedBox(height: 16),
            Text(copy.onboardingBlurb,
                style: YomiText.ui(15, color: c.fg2, height: 1.45)),
          ],
        );
      case YomiLook.pastel:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 72,
              height: 72,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: c.card,
                borderRadius: BorderRadius.circular(24),
                boxShadow: const [
                  BoxShadow(
                      color: Color(0x1F503C3C),
                      blurRadius: 24,
                      offset: Offset(0, 8)),
                ],
              ),
              child: const DisplayText('よ', size: 40),
            ),
            const SizedBox(height: 22),
            DisplayText(copy.onboardingTitle, size: 44),
            const SizedBox(height: 10),
            Text(copy.onboardingKicker,
                style: YomiText.ui(14, weight: FontWeight.w600, color: c.fg2)),
          ],
        );
    }
  }
}

/// Genre tile. Sumi: ink stamp with kanji and a seal-red hairline when
/// selected. Cinema: numbered, square check. Pastel: tinted sticker that
/// tilts until picked. All transitions 180ms snap.
class _GenreTile extends StatelessWidget {
  const _GenreTile({
    required this.index,
    required this.name,
    required this.mark,
    required this.selected,
    required this.onTap,
  });

  final int index;
  final String name;
  final String mark;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.yc;
    final theme = context.yomi;
    final look = theme.spec;
    const clear = Color(0x00000000);

    final Color bg;
    final Color border;
    final double borderWidth;
    final Color markColor;
    final double tiltDeg;
    switch (look.look) {
      case YomiLook.sumi:
        bg = selected ? theme.selectedTileBg : clear;
        border = selected ? c.ac : c.line;
        borderWidth = 1;
        markColor = selected ? c.ac : c.fg;
        tiltDeg = 0;
      case YomiLook.cinema:
        bg = clear;
        border = selected ? c.ac : c.line;
        borderWidth = 1;
        markColor = c.fg2;
        tiltDeg = 0;
      case YomiLook.pastel:
        bg = look.accents[index % look.accents.length];
        border = selected ? c.fg : clear;
        borderWidth = 2;
        markColor = look.onAccent;
        tiltDeg =
            selected || reduceMotion(context) ? 0 : (index.isOdd ? 1.5 : -1.5);
    }
    final nameColor = look.isPastel ? look.onAccent : c.fg;

    return Semantics(
      button: true,
      selected: selected,
      label: name,
      child: SumiPress(
        onTap: onTap,
        scale: AppMotion.activeScale,
        child: AnimatedRotation(
          turns: tiltDeg / 360,
          duration: AppMotion.fast,
          curve: AppMotion.snap,
          child: AnimatedContainer(
            duration: AppMotion.fast,
            curve: AppMotion.snap,
            height: look.isPastel ? 124 : 112,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: bg,
              border: Border.all(color: border, width: borderWidth),
              borderRadius: BorderRadius.circular(context.radii.card),
            ),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                if (look.isCinema)
                  Text(mark, style: YomiText.overline(markColor))
                else
                  AnimatedDefaultTextStyle(
                    duration: AppMotion.fast,
                    curve: AppMotion.snap,
                    style: YomiText.display(look.isPastel ? 34 : 40,
                            color: markColor)
                        .copyWith(height: 1),
                    child: Text(mark),
                  ),
                Positioned(
                  left: 0,
                  bottom: -2,
                  child: look.isCinema
                      ? DisplayText(name, size: 26, color: c.fg)
                      : Text(name,
                          style: YomiText.ui(look.isPastel ? 15 : 14,
                              weight: FontWeight.w700, color: nameColor)),
                ),
                Positioned(
                  right: -2,
                  top: -2,
                  child: _Check(selected: selected),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Selection mark: Sumi 22px ring that fills accent · Cinema 28px square
/// with a check · Pastel 24px dot with a check.
class _Check extends StatelessWidget {
  const _Check({required this.selected});
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final c = context.yc;
    final look = context.look;
    const clear = Color(0x00000000);
    final (double size, double radius, Color fill, Color border, Color? tick) =
        switch (look.look) {
      YomiLook.sumi => (
          22.0,
          11.0,
          selected ? c.ac : clear,
          selected ? c.ac : c.line,
          null,
        ),
      YomiLook.cinema => (
          28.0,
          0.0,
          selected ? c.ac : clear,
          selected ? c.ac : c.line,
          c.onAccent,
        ),
      YomiLook.pastel => (
          24.0,
          12.0,
          selected ? c.fg : const Color(0x99FFFFFF),
          clear,
          c.bg,
        ),
    };
    return AnimatedContainer(
      duration: AppMotion.fast,
      curve: AppMotion.snap,
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: fill,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: border, width: 1.5),
      ),
      child: selected && tick != null
          ? Icon(CupertinoIcons.checkmark, size: 14, color: tick)
          : null,
    );
  }
}

/// Look picker card: a swatch of the look's canvas, card and accent with its
/// name in its own display face.
class _LookCard extends StatelessWidget {
  const _LookCard({
    required this.spec,
    required this.selected,
    required this.onTap,
  });
  final YomiLookSpec spec;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.yc;
    final palette =
        spec.defaultMode == Brightness.dark ? spec.dark : spec.light;
    return Semantics(
      button: true,
      selected: selected,
      label: '${spec.name} look',
      child: SumiPress(
        onTap: onTap,
        scale: AppMotion.activeScale,
        child: AnimatedContainer(
          duration: AppMotion.fast,
          curve: AppMotion.snap,
          height: 84,
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: palette.bg,
            borderRadius: BorderRadius.circular(spec.radii.card),
            border: Border.all(
              color: selected ? c.fg : c.line,
              width: selected ? 2 : 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  for (final col in [palette.card, palette.ac, palette.fg])
                    Container(
                      width: 14,
                      height: 14,
                      margin: const EdgeInsets.only(right: 4),
                      decoration: BoxDecoration(
                        color: col,
                        borderRadius:
                            BorderRadius.circular(spec.radii.small.clamp(0, 7)),
                        border: Border.all(color: palette.line),
                      ),
                    ),
                ],
              ),
              Text(
                spec.displayUppercase ? spec.name.toUpperCase() : spec.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontFamily: spec.displayFont,
                  fontWeight: spec.displayWeight,
                  fontVariations: [
                    FontVariation('wght', spec.displayWeight.value.toDouble())
                  ],
                  fontSize: 18,
                  height: 1,
                  color: palette.fg,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
