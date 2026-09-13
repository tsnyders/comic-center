import 'package:flutter/widgets.dart';

/// ============================================================================
/// Yomi theming — one [YomiLook] × one mode (dark / light) × one accent.
///
/// Every colour in the UI resolves through the six semantic roles on
/// [YomiColors]. Widgets read them via `context.yc` (animated, crossfades on
/// theme change) and layout / type / radius facts via `context.yomi` and
/// [YomiText]. Never hardcode a hex in a widget.
///
/// Three looks ship: Sumi (ink), Cinema (charcoal, condensed caps) and
/// Pastel (cream, rounded, handwritten). Each look owns its palette, fonts,
/// radii, shadows, copy and small marks; the screens share one skeleton and
/// branch on `look` only where the prototypes differ structurally.
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

/// Radii for one look (covers, cards, buttons, chips, small tiles).
class YomiRadii {
  const YomiRadii({
    required this.cover,
    required this.card,
    required this.button,
    required this.chip,
    required this.small,
  });
  final double cover;
  final double card;
  final double button;
  final double chip;
  final double small;
}

/// Screen copy that differs per look (prototype strings).
class YomiCopy {
  const YomiCopy({
    required this.onboardingKicker,
    required this.onboardingTitle,
    required this.onboardingBlurb,
    required this.continueButton,
    required this.signIn,
    required this.libraryTitle,
    required this.discoverTitle,
    required this.settingsTitle,
    required this.guestName,
    required this.guestHint,
    this.libraryKicker,
    this.discoverKicker,
    this.settingsKicker,
  });
  final String onboardingKicker;
  final String onboardingTitle;
  final String onboardingBlurb;
  final String continueButton;
  final String signIn;
  final String libraryTitle;
  final String discoverTitle;
  final String settingsTitle;
  final String guestName;
  final String guestHint;

  /// Screen kickers that replace the default section label; null keeps
  /// "LIBRARY" / "DISCOVER" / "SETTINGS" (with kanji pairs on Sumi).
  final String? libraryKicker;
  final String? discoverKicker;
  final String? settingsKicker;
}

/// Palette, type, radii, copy and marks for one look.
class YomiLookSpec {
  const YomiLookSpec({
    required this.look,
    required this.name,
    required this.dark,
    required this.light,
    required this.accents,
    required this.accentNames,
    required this.onAccent,
    required this.defaultMode,
    required this.darkName,
    required this.lightName,
    required this.displayFont,
    required this.displayWeight,
    required this.displayHeight,
    required this.displayUppercase,
    required this.bodyFont,
    required this.bodyWeightFloor,
    required this.overlineSize,
    required this.overlineWeight,
    required this.overlineTracking,
    required this.overlineUppercase,
    required this.radii,
    required this.cardShadow,
    required this.kanji,
    required this.grain,
    required this.genreMarks,
    required this.copy,
    required this.toggleOffDark,
    required this.toggleOffLight,
    this.toggleOn,
    this.selectedTileBgDark,
    this.selectedTileBgLight,
  });

  final YomiLook look;
  final String name;
  final YomiColors dark;
  final YomiColors light;
  final List<Color> accents;
  final List<String> accentNames;
  final Color onAccent;
  final Brightness defaultMode;

  /// Labels shown on the Settings "Theme" row (e.g. Sumi / Paper).
  final String darkName;
  final String lightName;

  final String displayFont;
  final FontWeight displayWeight;
  final double displayHeight;
  final bool displayUppercase;
  final String bodyFont;

  /// Pastel body never goes lighter than 600.
  final FontWeight bodyWeightFloor;

  final double overlineSize;
  final FontWeight overlineWeight;
  final double overlineTracking;
  final bool overlineUppercase;

  final YomiRadii radii;
  final List<BoxShadow> cardShadow;

  /// Pair Latin labels with kanji, use kanji numerals and marks.
  final bool kanji;

  /// Washi grain overlay.
  final bool grain;

  /// Glyph on each onboarding genre tile (Action, Isekai, Comedy, Sci-fi).
  final List<String> genreMarks;
  final YomiCopy copy;

  final Color toggleOffDark;
  final Color toggleOffLight;

  /// On-state track colour when it is not the accent (Pastel rose).
  final Color? toggleOn;
  final Color? selectedTileBgDark;
  final Color? selectedTileBgLight;

  bool get isSumi => look == YomiLook.sumi;
  bool get isCinema => look == YomiLook.cinema;
  bool get isPastel => look == YomiLook.pastel;
}

const _white = Color(0xFFFFFFFF);

const sumiSpec = YomiLookSpec(
  look: YomiLook.sumi,
  name: 'Sumi',
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
  displayFont: 'YujiSyuku',
  displayWeight: FontWeight.w400,
  displayHeight: 1.1,
  displayUppercase: false,
  bodyFont: 'ZenKakuGothicNew',
  bodyWeightFloor: FontWeight.w400,
  overlineSize: 11,
  overlineWeight: FontWeight.w400,
  overlineTracking: 2,
  overlineUppercase: true,
  radii: YomiRadii(cover: 4, card: 6, button: 6, chip: 2, small: 3),
  cardShadow: [],
  kanji: true,
  grain: true,
  genreMarks: ['闘', '異', '笑', '宇'],
  copy: YomiCopy(
    onboardingKicker: '読む · READ',
    onboardingTitle: 'Yomi',
    onboardingBlurb: 'WHAT DO YOU READ?',
    continueButton: 'Continue as guest',
    signIn: 'Sign in to sync across devices',
    libraryTitle: 'Your shelf',
    discoverTitle: 'Explore',
    settingsTitle: 'You',
    guestName: 'Guest reader',
    guestHint: 'Sign in to sync progress',
  ),
  toggleOffDark: Color(0xFF3A3733),
  toggleOffLight: Color(0xFFD8D2C6),
  selectedTileBgDark: Color(0xFF1C1213),
  selectedTileBgLight: Color(0xFFFBEFEF),
);

const cinemaSpec = YomiLookSpec(
  look: YomiLook.cinema,
  name: 'Cinema',
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
    Color(0xFFE8A33D), // Amber
    Color(0xFFC8412B), // Crimson
    Color(0xFF8FB8C9), // Ice
    Color(0xFFF1EBE2), // Ivory
  ],
  accentNames: ['Amber', 'Crimson', 'Ice', 'Ivory'],
  onAccent: Color(0xFF1C1917),
  defaultMode: Brightness.dark,
  darkName: 'Charcoal',
  lightName: 'Paper',
  displayFont: 'BarlowCondensed',
  displayWeight: FontWeight.w800,
  displayHeight: 0.95,
  displayUppercase: true,
  bodyFont: 'Barlow',
  bodyWeightFloor: FontWeight.w400,
  overlineSize: 12,
  overlineWeight: FontWeight.w700,
  overlineTracking: 4,
  overlineUppercase: true,
  radii: YomiRadii(cover: 0, card: 0, button: 0, chip: 0, small: 0),
  cardShadow: [],
  kanji: false,
  grain: false,
  genreMarks: ['01', '02', '03', '04'],
  copy: YomiCopy(
    onboardingKicker: 'YOMI · EST. 2026',
    onboardingTitle: 'Set the scene.',
    onboardingBlurb:
        'Choose the genres you want in your opening reel. You can recut it later.',
    continueButton: 'Roll · continue as guest',
    signIn: 'Sign in to sync',
    libraryTitle: 'Your reel',
    discoverTitle: 'Programme',
    settingsTitle: 'Settings',
    guestName: 'Guest',
    guestHint: 'Progress kept on this device',
    libraryKicker: 'NOW SHOWING',
    discoverKicker: 'PROGRAMME',
    settingsKicker: 'CONTROL ROOM',
  ),
  toggleOffDark: Color(0xFF3A3532),
  toggleOffLight: Color(0xFFCFC6B8),
);

const pastelSpec = YomiLookSpec(
  look: YomiLook.pastel,
  name: 'Pastel',
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
    Color(0xFFF6C1CC), // Blush
    Color(0xFFBFD8F0), // Sky
    Color(0xFFCFE8D2), // Mint
    Color(0xFFF3E1B8), // Butter
  ],
  accentNames: ['Blush', 'Sky', 'Mint', 'Butter'],
  onAccent: Color(0xFF3A2E33),
  defaultMode: Brightness.light,
  darkName: 'Plum',
  lightName: 'Cream',
  displayFont: 'Gaegu',
  displayWeight: FontWeight.w700,
  displayHeight: 1.0,
  displayUppercase: false,
  bodyFont: 'Quicksand',
  bodyWeightFloor: FontWeight.w600,
  overlineSize: 13,
  overlineWeight: FontWeight.w600,
  overlineTracking: 0,
  overlineUppercase: false,
  radii: YomiRadii(cover: 18, card: 24, button: 22, chip: 16, small: 12),
  cardShadow: [
    BoxShadow(
      color: Color(0x0F503C3C),
      blurRadius: 14,
      offset: Offset(0, 4),
    ),
  ],
  kanji: false,
  grain: false,
  genreMarks: ['Pow!', 'Poof', 'Haha', 'Beep'],
  copy: YomiCopy(
    onboardingKicker: 'Pick a few. We\'ll keep your shelf cosy.',
    onboardingTitle: 'Hi, reader!\nWhat\'s your thing?',
    onboardingBlurb: '',
    continueButton: 'Start reading',
    signIn: 'I have an account',
    libraryTitle: 'My shelf',
    discoverTitle: 'Discover',
    settingsTitle: 'Settings',
    guestName: 'Guest',
    guestHint: 'Sign in to keep your shelf everywhere',
    libraryKicker: 'Good evening',
    discoverKicker: 'Handpicked this week',
    settingsKicker: 'Make it yours',
  ),
  toggleOffDark: Color(0xFF4A4150),
  toggleOffLight: Color(0xFFEADDD8),
  toggleOn: Color(0xFFD9788F), // Rose
);

const yomiLookSpecs = {
  YomiLook.sumi: sumiSpec,
  YomiLook.cinema: cinemaSpec,
  YomiLook.pastel: pastelSpec,
};

/// Reader surface for Sumi and Cinema: pure black, ivory text. Pastel keeps
/// its cream canvas (see [ReaderPalette.of]).
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

/// Colours the reader chrome draws with, resolved per look.
class ReaderPalette {
  const ReaderPalette({
    required this.bg,
    required this.ink,
    required this.ink2,
    required this.card,
    required this.track,
    required this.scrubTrack,
    required this.border,
  });

  final Color bg;
  final Color ink;
  final Color ink2;
  final Color card;
  final Color track;
  final Color scrubTrack;
  final Color border;

  static const black = ReaderPalette(
    bg: YomiReader.bg,
    ink: YomiReader.ink,
    ink2: YomiReader.ink2,
    card: Color(0xFF1A1917),
    track: YomiReader.track,
    scrubTrack: YomiReader.scrubTrack,
    border: YomiReader.buttonBorder,
  );

  static ReaderPalette of(BuildContext context) {
    if (!context.yomi.spec.isPastel) return black;
    final c = context.yc;
    return ReaderPalette(
      bg: c.bg,
      ink: c.fg,
      ink2: c.fg2,
      card: c.card,
      track: c.line,
      scrubTrack: c.line,
      border: c.line,
    );
  }
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

  // ── Look-specific state tints ──────────────────────────────────────────────

  /// Selected genre-tile fill (Sumi); other looks fill with the accent.
  Color get selectedTileBg =>
      (isDark ? spec.selectedTileBgDark : spec.selectedTileBgLight) ?? accent;

  Color get toggleOff => isDark ? spec.toggleOffDark : spec.toggleOffLight;
  Color get toggleOn => spec.toggleOn ?? accent;

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

  YomiLookSpec get look => yomi.spec;
  YomiRadii get radii => yomi.spec.radii;

  double get yomiGutter => yomi.gutter(MediaQuery.sizeOf(this).width);
  double get yomiGridGap => yomi.gridGap(MediaQuery.sizeOf(this).width);
  int get yomiGridColumns => yomi.gridColumns(MediaQuery.sizeOf(this).width);
}

/// Type for the current look. Display face for titles and marks, body face
/// for UI.
///
/// ponytail: [spec] is a process-wide static set by the app root; one theme
/// per app, so threading it through every TextStyle call site buys nothing.
abstract final class YomiText {
  static YomiLookSpec spec = sumiSpec;

  /// Display face — wordmark, screen titles, kanji marks, numerals.
  /// Cinema titles ≥ 40px tighten by 1px, its labels open by 1px.
  static TextStyle display(double size, {Color? color, double? letterSpacing}) {
    final s = spec;
    return TextStyle(
      fontFamily: s.displayFont,
      fontWeight: s.displayWeight,
      fontVariations: [FontVariation('wght', s.displayWeight.value.toDouble())],
      fontSize: size,
      height: s.displayHeight,
      color: color,
      letterSpacing:
          letterSpacing ?? (s.isCinema ? (size >= 40 ? -1.0 : 1.0) : 0.0),
    );
  }

  /// Applies the look's case rule to display copy (Cinema is uppercase).
  static String displayCase(String text) =>
      spec.displayUppercase ? text.toUpperCase() : text;

  /// UI face.
  static TextStyle ui(
    double size, {
    FontWeight weight = FontWeight.w400,
    Color? color,
    double? letterSpacing,
    double? height,
  }) {
    final s = spec;
    final w =
        weight.value < s.bodyWeightFloor.value ? s.bodyWeightFloor : weight;
    return TextStyle(
      fontFamily: s.bodyFont,
      fontWeight: w,
      fontVariations: [FontVariation('wght', w.value.toDouble())],
      fontSize: size,
      color: color,
      letterSpacing: letterSpacing,
      height: height,
    );
  }

  /// Section overline: Sumi 11 tracked 2 · Cinema condensed 12/700 tracked 4
  /// · Pastel 13/600 sentence case.
  static TextStyle overline(Color color) {
    final s = spec;
    return TextStyle(
      fontFamily: s.isCinema ? s.displayFont : s.bodyFont,
      fontWeight: s.overlineWeight,
      fontVariations: [
        FontVariation('wght', s.overlineWeight.value.toDouble())
      ],
      fontSize: s.overlineSize,
      letterSpacing: s.overlineTracking,
      color: color,
    );
  }

  /// `LIBRARY` + `庫` → "LIBRARY · 庫" (Sumi), "LIBRARY" (Cinema),
  /// "Library" (Pastel).
  static String label(String latin, [String? kanji]) {
    final s = spec;
    if (s.kanji && kanji != null) return '$latin · $kanji';
    if (s.overlineUppercase) return latin.toUpperCase();
    return latin.isEmpty
        ? latin
        : latin[0].toUpperCase() + latin.substring(1).toLowerCase();
  }
}
