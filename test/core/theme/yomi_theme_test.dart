import 'package:comic_center/core/theme/yomi_theme.dart';
import 'package:comic_center/shared/widgets/sumi.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('YomiTheme', () {
    test('resolves mode + accent through the six roles', () {
      const dark = YomiTheme();
      expect(dark.colors.bg, const Color(0xFF0B0B0A));
      expect(dark.colors.ac, sumiSpec.accents[0]);
      expect(dark.modeName, 'Sumi');

      final paperJade = dark.copyWith(mode: Brightness.light, accentIndex: 3);
      expect(paperJade.colors.bg, const Color(0xFFF2EDE3));
      expect(paperJade.colors.ac, const Color(0xFF3F7A5E));
      expect(paperJade.colors.onAccent, const Color(0xFFFFFFFF));
      expect(paperJade.modeName, 'Paper');

      // Out-of-range accent index clamps instead of throwing.
      expect(dark.copyWith(accentIndex: 99).colors.ac, sumiSpec.accents.last);
    });

    test('grid columns / gutters follow cover size, density and width', () {
      const t = YomiTheme();
      expect(t.gridColumns(390), 3);
      expect(t.copyWith(coverSize: CoverSize.small).gridColumns(390), 4);
      expect(t.copyWith(coverSize: CoverSize.large).gridColumns(834), 4);
      expect(t.gridColumns(834), 6);
      expect(t.gutter(390), 20);
      expect(t.gutter(834), 36);
      expect(t.copyWith(density: YomiDensity.compact).gutter(390), 14);
      expect(t.gridGap(390), 14);
      expect(t.copyWith(density: YomiDensity.compact).gridGap(834), 8);
    });

    test('lerp crossfades every role', () {
      final mid = YomiColors.lerp(sumiSpec.dark, sumiSpec.light, 0.5);
      expect(mid.bg, Color.lerp(sumiSpec.dark.bg, sumiSpec.light.bg, 0.5));
      expect(mid.fg2, Color.lerp(sumiSpec.dark.fg2, sumiSpec.light.fg2, 0.5));
      expect(YomiColorsTween(begin: sumiSpec.dark, end: sumiSpec.light).lerp(1),
          sumiSpec.light);
    });
  });

  group('looks', () {
    test('each look resolves its own palette, default mode and type', () {
      for (final look in YomiLook.values) {
        final spec = yomiLookSpecs[look]!;
        final t = YomiTheme(look: look, mode: spec.defaultMode);
        expect(t.colors.ac, spec.accents.first);
        expect(t.colors.onAccent, spec.onAccent);
        expect(spec.accentNames.length, spec.accents.length);
        expect(spec.genreMarks.length, 4);
        expect(spec.displayFont.isNotEmpty, isTrue);
      }
      expect(const YomiTheme(look: YomiLook.pastel).spec.defaultMode,
          Brightness.light);
      expect(const YomiTheme(look: YomiLook.cinema).modeName, 'Charcoal');
      expect(
          const YomiTheme(look: YomiLook.pastel, mode: Brightness.light)
              .toggleOn,
          const Color(0xFFD9788F));
    });

    test('labels and chapter marks follow the look', () {
      YomiText.spec = sumiSpec;
      expect(YomiText.label('LIBRARY', '庫'), 'LIBRARY · 庫');
      expect(chapterMark(15), '十五');
      YomiText.spec = cinemaSpec;
      expect(YomiText.label('LIBRARY', '庫'), 'LIBRARY');
      expect(YomiText.displayCase('Your reel'), 'YOUR REEL');
      expect(chapterMark(8), '08');
      expect(chapterMark(12.5), '12.5');
      YomiText.spec = pastelSpec;
      expect(YomiText.label('LIBRARY', '庫'), 'Library');
      expect(chapterMark(8), '8');
      YomiText.spec = sumiSpec;
    });
  });

  group('kanji helpers', () {
    test('kanjiNumeral', () {
      expect(kanjiNumeral(0), '〇');
      expect(kanjiNumeral(3), '三');
      expect(kanjiNumeral(10), '十');
      expect(kanjiNumeral(15), '十五');
      expect(kanjiNumeral(20), '二十');
      expect(kanjiNumeral(23), '二十三');
      expect(kanjiNumeral(99), '九十九');
      expect(kanjiNumeral(123), '一二三');
      expect(kanjiNumeral(1050), '一〇五〇');
      expect(kanjiNumeral(12.5), '十二·5');
      expect(kanjiNumeral(7.25), '七·25');
    });

    test('kanjiTag and languageKanji', () {
      expect(kanjiTag('hokusai manga'), 'H');
      expect(kanjiTag('北斎漫画'), '北');
      expect(kanjiTag('  '), '読');
      expect(languageKanji('en'), '英');
      expect(languageKanji('ja-JP'), '日');
      expect(languageKanji('xx'), 'X');
    });
  });
}
