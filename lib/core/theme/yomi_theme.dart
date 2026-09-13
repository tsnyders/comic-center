import 'package:flutter/widgets.dart';

/// ============================================================================
/// Yomi theming — one [YomiLook] × one mode (dark / light) × one accent.
///
/// Every colour in the UI resolves through the six semantic roles on
/// [YomiColors]. Widgets read them via `context.yc` (animated, crossfades on
/// theme change) and layout facts via `context.yomi`. Never hardcode a hex in
/// a widget.
///
/// Sumi ships; Cinema and Pastel palettes are registered so they can be
/// exposed later without touching the widgets.
/// ============================================================================

enum YomiLook { sumi, cinema, pastel }

enum YomiDensity { comfortable, compact }

enum CoverSize { small, medium, large }

class YomiColors {
  const YomiColors({
    required this.bg,
    required this.fg,
    required this.fg2,
    required this.line,
    required this.card,
    required this.ac,
    required this.onAccent,
  });

  /// Canvas.
  final Color bg;

  /// Primary text and primary button fill.
  final Color fg;

  /// Secondary text.
  final Color fg2;

  /// Hairlines, borders, dividers.
  final Color line;

  /// Raised surface.
  final Color card;

  /// Accent: unread, progress, active states, seal.
  final Color ac;

  /// Text drawn on [ac].
  final Color onAccent;

  YomiColors copyWith({Color? ac, Color? onAccent}) => YomiColors(
        bg: bg,
        fg: fg,
        fg2: fg2,
        line: line,
        card: card,
        ac: ac ?? this.ac,
        onAccent: onAccent ?? this.onAccent,
      );

  static YomiColors lerp(YomiColors a, YomiColors b, double t) => YomiColors(
        bg: Color.lerp(a.bg, b.bg, t)!,
        fg: Color.lerp(a.fg, b.fg, t)!,
        fg2: Color.lerp(a.fg2, b.fg2, t)!,
        line: Color.lerp(a.line, b.line, t)!,
        card: Color.lerp(a.card, b.card, t)!,
        ac: Color.lerp(a.ac, b.ac, t)!,
        onAccent: Color.lerp(a.onAccent, b.onAccent, t)!,
      );

  @override
  bool operator ==(Object other) =>
      other is YomiColors &&
      other.bg == bg &&
      other.fg == fg &&
      other.fg2 == fg2 &&
      other.line == line &&
      other.card == card &&
      other.ac == ac &&
      other.onAccent == onAccent;

  @override
  int get hashCode => Object.hash(bg, fg, fg2, line, card, ac, onAccent);
}

class YomiColorsTween extends Tween<YomiColors> {
  YomiColorsTween({super.begin, super.end});

  @override
  YomiColors lerp(double t) => YomiColors.lerp(begin!, end!, t);
}

/// Palette + curated accents for one look.
class YomiLookSpec {
  const YomiLookSpec({
    required this.dark,
    required this.light,
    required this.accents,
    required this.accentNames,
    required this.onAccent,
    required this.defaultMode,
    required this.darkName,
    required this.lightName,
  });

  final YomiColors dark;
  final YomiColors light;
  final List<Color> accents;
  final List<String> accentNames;
  final Color onAccent;
  final Brightness defaultMode;

  /// Labels shown on the Settings "Theme" row (e.g. Sumi / Paper).
  final String darkName;
  final String lightName;
}

const _white = Color(0xFFFFFFFF);

const sumiSpec = YomiLookSpec(
  dark: YomiColors(
    bg: Color(0xFF0B0B0A),
    fg: Color(0xFFF2EDE3),
    fg2: Color(0xFFA9A399),
    line: Color(0xFF2A2825),
    card: Color(0xFF1A1917),
    ac: Color(0xFFB7282E),
    onAccent: _white,
  ),
  light: YomiColors(
    bg: Color(0xFFF2EDE3),
    fg: Color(0xFF0B0B0A),
    fg2: Color(0xFF6B665C),
    line: Color(0xFFD8D2C6),
    card: Color(0xFFE7E1D5),
    ac: Color(0xFFB7282E),
    onAccent: _white,
  ),
  accents: [
    Color(0xFFB7282E), // Vermilion
    Color(0xFF2B4A7A), // Indigo
    Color(0xFFB8892E), // Gold
    Color(0xFF3F7A5E), // Jade
  ],
  accentNames: ['Vermilion', 'Indigo', 'Gold', 'Jade'],
  onAccent: _white,
  defaultMode: Brightness.dark,
  darkName: 'Sumi',
  lightName: 'Paper',
);

const cinemaSpec = YomiLookSpec(
  dark: YomiColors(
    bg: Color(0xFF1C1917),
    fg: Color(0xFFF1EBE2),
    fg2: Color(0xFFB3A99C),
    line: Color(0xFF33302B),
    card: Color(0xFF2A2521),
    ac: Color(0xFFE8A33D),
    onAccent: Color(0xFF1C1917),
  ),
  light: YomiColors(
    bg: Color(0xFFEDE6DC),
    fg: Color(0xFF1C1917),
    fg2: Color(0xFF6E645A),
    line: Color(0xFFCFC6B8),
    card: Color(0xFFDED6CA),
    ac: Color(0xFFE8A33D),
    onAccent: Color(0xFF1C1917),
  ),
  accents: [
    Color(0xFFE8A33D),
    Color(0xFFC8412B),
    Color(0xFF8FB8C9),
    Color(0xFFF1EBE2),
  ],
  accentNames: ['Amber', 'Crimson', 'Ice', 'Ivory'],
  onAccent: Color(0xFF1C1917),
  defaultMode: Brightness.dark,
  darkName: 'Charcoal',
  lightName: 'Paper',
);

const pastelSpec = YomiLookSpec(
  dark: YomiColors(
    bg: Color(0xFF2A2530),
    fg: Color(0xFFF4ECEF),
    fg2: Color(0xFFB7A9B0),
    line: Color(0xFF4A4150),
    card: Color(0xFF372F3B),
    ac: Color(0xFFF6C1CC),
    onAccent: Color(0xFF3A2E33),
  ),
  light: YomiColors(
    bg: Color(0xFFFBF6F3),
    fg: Color(0xFF3A2E33),
    fg2: Color(0xFF8A7A80),
    line: Color(0xFFEADDD8),
    card: Color(0xFFFFFFFF),
    ac: Color(0xFFF6C1CC),
    onAccent: Color(0xFF3A2E33),
  ),
  accents: [
    Color(0xFFF6C1CC),
    Color(0xFFBFD8F0),
    Color(0xFFCFE8D2),
    Color(0xFFF3E1B8),
  ],
  accentNames: ['Blush', 'Sky', 'Mint', 'Butter'],
  onAccent: Color(0xFF3A2E33),
  defaultMode: Brightness.light,
  darkName: 'Plum',
  lightName: 'Cream',
);

const yomiLookSpecs = {
  YomiLook.sumi: sumiSpec,
  YomiLook.cinema: cinemaSpec,
  YomiLook.pastel: pastelSpec,
};

/// Reader surface is theme-independent: pure black, ivory text.
abstract final class YomiReader {
  static const bg = Color(0xFF000000);
  static const ink = Color(0xFFF2EDE3);
  static const ink2 = Color(0xFFA9A399);
  static const paper = Color(0xFFF4EFE4);
  static const panelBorder = Color(0xFF111111);
  static const track = Color(0xFF222222);
  static const scrubTrack = Color(0xFF333333);
  static const buttonBorder = Color(0xFF444444);
}

class YomiTheme {
  const YomiTheme({
    this.look = YomiLook.sumi,
    this.mode = Brightness.dark,
    this.accentIndex = 0,
    this.density = YomiDensity.comfortable,
    this.coverSize = CoverSize.medium,
  });

  final YomiLook look;
  final Brightness mode;
  final int accentIndex;
  final YomiDensity density;
  final CoverSize coverSize;

  YomiLookSpec get spec => yomiLookSpecs[look]!;
  bool get isDark => mode == Brightness.dark;
  bool get compact => density == YomiDensity.compact;

  Color get accent =>
      spec.accents[accentIndex.clamp(0, spec.accents.length - 1)];

  /// The six roles for this look × mode × accent.
  YomiColors get colors => (isDark ? spec.dark : spec.light)
      .copyWith(ac: accent, onAccent: spec.onAccent);

  String get modeName => isDark ? spec.darkName : spec.lightName;

  // ── Sumi-specific state tints ───────────────────────────────────────────────

  /// Selected genre-tile fill.
  Color get selectedTileBg =>
      isDark ? const Color(0xFF1C1213) : const Color(0xFFFBEFEF);

  /// Toggle track when off.
  Color get toggleOff =>
      isDark ? const Color(0xFF3A3733) : const Color(0xFFD8D2C6);

  // ── Layout ─────────────────────────────────────────────────────────────────

  static bool isTablet(double width) => width >= 600;

  double gutter(double width) {
    final tablet = isTablet(width);
    if (compact) return tablet ? 24 : 14;
    return tablet ? 36 : 20;
  }

  double gridGap(double width) {
    if (compact) return 8;
    return isTablet(width) ? 20 : 14;
  }

  int gridColumns(double width) {
    final base = switch (coverSize) {
      CoverSize.small => 4,
      CoverSize.medium => 3,
      CoverSize.large => 2,
    };
    return isTablet(width) ? base * 2 : base;
  }

  YomiTheme copyWith({
    YomiLook? look,
    Brightness? mode,
    int? accentIndex,
    YomiDensity? density,
    CoverSize? coverSize,
  }) =>
      YomiTheme(
        look: look ?? this.look,
        mode: mode ?? this.mode,
        accentIndex: accentIndex ?? this.accentIndex,
        density: density ?? this.density,
        coverSize: coverSize ?? this.coverSize,
      );

  @override
  bool operator ==(Object other) =>
      other is YomiTheme &&
      other.look == look &&
      other.mode == mode &&
      other.accentIndex == accentIndex &&
      other.density == density &&
      other.coverSize == coverSize;

  @override
  int get hashCode => Object.hash(look, mode, accentIndex, density, coverSize);
}

/// Provides the theme (layout facts) and the *animated* colours to the tree.
class YomiThemeScope extends InheritedWidget {
  const YomiThemeScope({
    super.key,
    required this.theme,
    required this.colors,
    required super.child,
  });

  final YomiTheme theme;
  final YomiColors colors;

  static YomiThemeScope? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<YomiThemeScope>();

  @override
  bool updateShouldNotify(YomiThemeScope old) =>
      old.theme != theme || old.colors != colors;
}

extension YomiThemeX on BuildContext {
  /// Layout + mode facts. Falls back to Sumi dark outside a scope (tests).
  YomiTheme get yomi =>
      YomiThemeScope.maybeOf(this)?.theme ?? const YomiTheme();

  /// The six colour roles, crossfading over 260ms on theme change.
  YomiColors get yc => YomiThemeScope.maybeOf(this)?.colors ?? yomi.colors;

  double get yomiGutter => yomi.gutter(MediaQuery.sizeOf(this).width);
  double get yomiGridGap => yomi.gridGap(MediaQuery.sizeOf(this).width);
  int get yomiGridColumns => yomi.gridColumns(MediaQuery.sizeOf(this).width);
}

/// Sumi type: Yuji Syuku for display / kanji, Zen Kaku Gothic New for UI.
abstract final class YomiText {
  static const display = 'YujiSyuku';
  static const body = 'ZenKakuGothicNew';

  /// Brush face — wordmark, screen titles, kanji marks. Line-height 1.1.
  static TextStyle kanji(double size, {Color? color, double? letterSpacing}) =>
      TextStyle(
        fontFamily: display,
        fontSize: size,
        height: 1.1,
        color: color,
        letterSpacing: letterSpacing,
      );

  /// UI face.
  static TextStyle ui(
    double size, {
    FontWeight weight = FontWeight.w400,
    Color? color,
    double? letterSpacing,
    double? height,
  }) =>
      TextStyle(
        fontFamily: body,
        fontSize: size,
        fontWeight: weight,
        color: color,
        letterSpacing: letterSpacing,
        height: height,
      );

  /// 11px, letter-spacing 2, uppercase Latin + kanji pair ("LIBRARY · 庫").
  static TextStyle overline(Color color) =>
      ui(11, color: color, letterSpacing: 2);
}
