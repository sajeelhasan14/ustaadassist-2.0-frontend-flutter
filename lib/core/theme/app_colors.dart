import 'package:material_ui/material_ui.dart';

/// Every colour in the app, by name. Screens use these names and never write
/// a hex value themselves.
///
/// Source: "Aurora Glass · dark and light" (UstaadAssist-aurora-light.pdf in
/// the project root). Each colour is written once with BOTH values side by
/// side: `_pick(dark, light)`. `isLight` decides which one comes back; app.dart
/// sets it from the phone's light/dark setting and then redraws every screen.
abstract final class AppColors {
  /// True when the phone is in light mode. Only app.dart changes this.
  static bool isLight = false;

  static Color _pick(int dark, int light) => Color(isLight ? light : dark);

  // Surfaces: from back to front.
  static Color get ground => _pick(0xFF06080A, 0xFFEEF2F5); // screen background: cool blue-black / cool blue-grey white
  // Cards are frosted glass: see-through, so the glow at the top shows through
  // them. Dark = 6% white, light = 74% white (the first two hex digits are
  // how solid it is: 0F = 6%, BD = 74%).
  static Color get card => _pick(0x0FFFFFFF, 0xBDFFFFFF); // cards, secondary buttons, inputs
  static Color get glassEdge => _pick(0x1AFFFFFF, 0xF2FFFFFF); // thin edge around a glass card
  static Color get shadow => _pick(0x00000000, 0x14101828); // light mode lifts cards with a soft shadow; dark has none
  // Anything that floats OVER the screen (dialogs, sheets, messages) must be
  // solid, or the screen behind would show through the words.
  static Color get sheet => _pick(0xFF121716, 0xFFFFFFFF);
  static Color get dock => _pick(0xD9141A18, 0xD1FFFFFF); // the floating tab bar and glass menus: 85% / 82% solid
  static Color get line => _pick(0xFF262C2A, 0xFFE2E6EA); // dividers, input borders, neutral pill fill
  static Color get outline => _pick(0xFF3A4240, 0xFFC5CCD2); // border of outline buttons

  // Text.
  static Color get text => _pick(0xFFFFFFFF, 0xFF0E1412);
  static Color get textMuted => _pick(0xFF9AA4A0, 0xFF56605C); // secondary lines, labels
  static Color get textOnLine => _pick(0xFFA9B2AE, 0xFF4D5753); // muted text on a `line` fill
  static Color get textFaint => _pick(0xFF5E6865, 0xFFA4ACA8); // "Planned" ring, never for text

  // The accent: means "act here" (hero panel, primary buttons). Never a status.
  // The FILL is the same bright green in both modes, always with dark text on it.
  static Color get green => _pick(0xFF00E676, 0xFF00E676);
  // Green WORDS, icons and thin lines on a normal surface. Bright green on
  // white is unreadable (1.6:1), so light mode uses a deeper green (5:1).
  static Color get greenText => _pick(0xFF00E676, 0xFF00803F);
  static Color get onGreen => _pick(0xFF04150B, 0xFF04150B); // main text on green. Never white on green.
  static Color get onGreenSoft => _pick(0xFF064D2A, 0xFF064D2A); // second line on green

  // Status colours: each has a strong tone (dots, bars) plus a tint and a text
  // colour for pills, e.g. the "On track" pill = successTint + successText.
  static Color get success => _pick(0xFF38D49A, 0xFF1FA774); // held class, on track
  static Color get successTint => _pick(0xFF18352B, 0xFFDDF6EA);
  static Color get successText => _pick(0xFF6CE6B5, 0xFF0B6B47);

  // Warning = electric violet (amber was rejected). PDF rule 4 "fill vs
  // words": a big FILL (hero panel, dialog, bar) keeps the same colour in both
  // modes, always with dark text on it. WORDS and pills on a normal surface go
  // a step deeper in light mode (rule 5) so "4 below 75%" still stands out.
  static Color get warning => _pick(0xFF8B7BFF, 0xFF8B7BFF); // fill: behind plan
  static Color get warningTint => _pick(0xFF231F3D, 0xFFECE7FF);
  static Color get warningText => _pick(0xFFC2B8FF, 0xFF4B2FC9);

  static Color get danger => _pick(0xFFFF6B6B, 0xFFFF6B6B); // fill: absent, cancelled, missing mark; also the + button
  static Color get dangerTint => _pick(0xFF382424, 0xFFFFE4DD);
  static Color get dangerText => _pick(0xFFFF9C9C, 0xFFB0301A);
  static Color get onDanger => _pick(0xFF2B0808, 0xFF2B0808); // icon/text on a red fill

  // A course that still needs setting up: the same violet as warning.
  static Color get setup => _pick(0xFF8B7BFF, 0xFF8B7BFF); // fill
  static Color get setupTint => _pick(0xFF231F3D, 0xFFECE7FF);
  static Color get setupText => _pick(0xFFC2B8FF, 0xFF4B2FC9);
  static Color get onSetup => _pick(0xFF140D3D, 0xFF140D3D); // text on a violet fill

  // The northern-lights glow at the top of every screen: green top-left,
  // violet top-right, a faint green at the bottom. A bit softer in light mode
  // so text on top stays easy to read (PDF rule 2).
  static Color get glowGreen => _pick(0x6100E676, 0x4D00E676); // 38% / 30%
  static Color get glowViolet => _pick(0x6B8B7BFF, 0x528B7BFF); // 42% / 32%
  static Color get glowLow => _pick(0x1A00E676, 0x1400E676); // 10% / 8%

  /// One colour per course, so a teacher spots a course without reading.
  /// `fill` is for blocks (always with dark text on it); `text` is for words
  /// and is a step deeper in light mode, like greenText.
  static List<({Color fill, Color text})> get courseColours => [
        (fill: green, text: greenText),
        (fill: const Color(0xFF8B7BFF), text: _pick(0xFFC2B8FF, 0xFF4B2FC9)), // violet
        (fill: const Color(0xFF5AB4FF), text: _pick(0xFF8FCBFF, 0xFF1F6FB8)), // sky
        (fill: const Color(0xFFFFBE5A), text: _pick(0xFFFFD08A, 0xFF8A5A00)), // sand
      ];

  /// Which colour (0-3) each course got, by course id. Filled from the phone's
  /// storage by Appearance, which also hands new courses their colour.
  static final courseColourIndex = <String, int>{};

  /// The colour of one course: the one it was given when first seen on this
  /// phone. Before that (or in tests) it's worked out from the id's letters,
  /// so it's still the same every time.
  static ({Color fill, Color text}) courseColour(String courseId) {
    final index = courseColourIndex[courseId] ?? courseId.codeUnits.fold<int>(0, (total, unit) => total + unit);
    return courseColours[index % courseColours.length];
  }
}
