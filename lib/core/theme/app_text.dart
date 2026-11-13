import 'package:material_ui/material_ui.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app_colors.dart';

/// Every text style in the app, named by its job.
///
/// Three typefaces, each with one job (from the "Night foundations" board):
/// - Bricolage Grotesque, weight 800: screen titles and big numbers.
/// - Plus Jakarta Sans: everything you read. Never below 12px.
/// - IBM Plex Mono: values that must line up in a column (seat numbers, dates, %).
///
/// Styles carry no colour unless the colour is part of the job (labels are
/// always muted); the theme supplies white, and a screen adds a colour with
/// `.copyWith(color: ...)` when it needs one.
abstract final class AppText {
  // Display (Bricolage). Tight letter spacing: -0.03em, written in pixels
  // because Flutter's letterSpacing is in pixels, not em.
  static final heroTitle = _display(40); // "Normalization" in the green panel
  static final bigNumber = _display(44); // "46 present", "17 / 20"
  static final screenTitle = _display(26); // "Good morning"
  static final cardTitle = _display(20); // a course name on its card

  // Reading text (Plus Jakarta Sans).
  static final rowTitle = GoogleFonts.plusJakartaSans(fontSize: 14, fontWeight: FontWeight.w700);
  static final body = GoogleFonts.plusJakartaSans(fontSize: 14, fontWeight: FontWeight.w400, height: 1.45);
  static final small = GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.w400);
  static final button = GoogleFonts.plusJakartaSans(fontSize: 14, fontWeight: FontWeight.w700);
  static final input = GoogleFonts.plusJakartaSans(fontSize: 15, fontWeight: FontWeight.w600);
  static final pill = GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.w700);

  /// Small section label above a block ("MY COURSES"). Write the text itself in
  /// capitals; the 0.14em spacing is 1.5px at 11px. A getter (not `final`)
  /// because its grey is different in light and dark mode.
  static TextStyle get label => GoogleFonts.plusJakartaSans(
    fontSize: 11,
    fontWeight: FontWeight.w700,
    letterSpacing: 1.5,
    color: AppColors.textMuted,
  );

  // Aligned values (IBM Plex Mono).
  static final mono = GoogleFonts.ibmPlexMono(fontSize: 13, fontWeight: FontWeight.w500);
  static final monoSmall = GoogleFonts.ibmPlexMono(fontSize: 11, fontWeight: FontWeight.w400);

  static TextStyle _display(double size) => GoogleFonts.bricolageGrotesque(
        fontSize: size,
        fontWeight: FontWeight.w800,
        letterSpacing: size * -0.03,
        height: 1.05,
      );
}
