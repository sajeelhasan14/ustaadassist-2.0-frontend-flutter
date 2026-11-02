import 'package:material_ui/material_ui.dart';

/// Every colour in the app, by name. Screens use these names and never write
/// a hex value themselves, so changing a colour (or adding a light mode later)
/// only means editing this file.
///
/// Source: the "Night foundations" board in design_inspo/, with the accent
/// lime #B8E62D swapped for green #00E676.
abstract final class AppColors {
  // Surfaces: from back to front.
  static const ground = Color(0xFF121110); // screen background
  static const card = Color(0xFF1E1C19); // cards, secondary buttons, inputs
  static const line = Color(0xFF33302B); // dividers, input borders, neutral pill fill
  static const outline = Color(0xFF4A463E); // border of outline buttons

  // Text on the dark surfaces.
  static const text = Color(0xFFFFFFFF);
  static const textMuted = Color(0xFF9A9489); // secondary lines, labels
  static const textOnLine = Color(0xFFABA59A); // muted text on a `line` fill (design's #9A9489 was 4.4:1, too low)
  static const textFaint = Color(0xFF6A6459); // "Planned" ring, never for text

  // The accent: means "act here" (hero panel, primary buttons). Never a status.
  static const green = Color(0xFF00E676);
  static const onGreen = Color(0xFF16150F); // main text on green (11:1)
  static const onGreenSoft = Color(0xFF064D2A); // second line on green (6:1). Never white on green (1.7:1).

  // Status colours: each has a strong tone (dots, bars) plus a dark tint and a
  // light text for pills, e.g. the "On track" pill = successTint + successText.
  static const success = Color(0xFF38D49A); // held class, on track
  static const successTint = Color(0xFF123A2B);
  static const successText = Color(0xFF5FE0AC);

  static const warning = Color(0xFFF5A623); // behind plan
  static const warningTint = Color(0xFF3D2F10);
  static const warningText = Color(0xFFF5C264);

  static const danger = Color(0xFFFF6B4A); // absent, cancelled, missing mark; also the + button
  static const dangerTint = Color(0xFF3D1A14);
  static const dangerText = Color(0xFFFF9B82);
  static const onDanger = Color(0xFF2B0E05); // icon/text on a coral fill

  static const setup = Color(0xFF8B6CFF); // a course that still needs setting up
  static const setupTint = Color(0xFF2A1F5E);
  static const setupText = Color(0xFFC3B2FF);
  static const onSetup = Color(0xFF14102B);
}
