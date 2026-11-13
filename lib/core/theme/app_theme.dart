import 'package:material_ui/material_ui.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app_colors.dart';
import 'app_text.dart';

/// Corner radii from the design: big cards 26, things inside a card 18,
/// inputs 16, buttons and pills fully round.
abstract final class AppRadius {
  static const card = 26.0;
  static const inner = 18.0;
  static const field = 16.0;
  static const pill = 999.0;
}

/// Frosted-glass cards (PDF rule 3): see-through fill, a thin light edge and,
/// in light mode only, a soft shadow that lifts white tiles off the ground.
/// Use `AppGlass.box` in a Container and `AppGlass.shape` + `AppGlass.lift`
/// in a Material (a Material is needed when the card reacts to a tap).
abstract final class AppGlass {
  static BoxDecoration box([double radius = AppRadius.inner, Color? color]) => BoxDecoration(
        color: color ?? AppColors.card,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: AppColors.glassEdge),
        boxShadow: [BoxShadow(color: AppColors.shadow, blurRadius: 22, offset: const Offset(0, 8))],
      );

  static ShapeBorder shape([double radius = AppRadius.inner]) =>
      RoundedRectangleBorder(borderRadius: BorderRadius.circular(radius), side: BorderSide(color: AppColors.glassEdge));

  /// Material's shadow height: a small lift in light mode, none in dark.
  static double get lift => AppColors.isLight ? 1.5 : 0;
}

/// The ground colour plus the green and violet glow, painted behind a page.
/// Every page gets it through the theme (see `_GlowPages`), so no screen adds it.
class GlowBackground extends StatelessWidget {
  const GlowBackground({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    // Radial gradients: a colour in the middle fading to nothing at the edge.
    // `center` is where the light sits (-1 = left/top, 1 = right/bottom).
    BoxDecoration light(Alignment center, Color colour, double radius) => BoxDecoration(
          gradient: RadialGradient(center: center, radius: radius, colors: [colour, colour.withValues(alpha: 0)]),
        );
    return DecoratedBox(
      decoration: BoxDecoration(color: AppColors.ground),
      child: Stack(
        children: [
          Positioned(
            left: 0,
            right: 0,
            top: 0,
            height: 420,
            child: IgnorePointer(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  DecoratedBox(decoration: light(const Alignment(-0.75, -1.05), AppColors.glowGreen, 0.95)),
                  DecoratedBox(decoration: light(const Alignment(0.95, -0.55), AppColors.glowViolet, 0.95)),
                ],
              ),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            height: 260,
            child: IgnorePointer(child: DecoratedBox(decoration: light(const Alignment(0, 1.2), AppColors.glowLow, 1.1))),
          ),
          Positioned.fill(child: child),
        ],
      ),
    );
  }
}

/// Flutter asks the theme how to animate a page in. We answer with Flutter's
/// normal animation, but with the page sitting on the glow. This is how the
/// glow reaches every screen while each screen keeps a plain `Scaffold`.
class _GlowPages extends PageTransitionsBuilder {
  const _GlowPages();

  @override
  Widget buildTransitions<T>(PageRoute<T> route, BuildContext context, Animation<double> animation, Animation<double> secondaryAnimation, Widget child) =>
      const PageTransitionsTheme().buildTransitions(route, context, animation, secondaryAnimation, GlowBackground(child: child));
}

/// Turns our colours and text styles into Flutter's ThemeData, so built-in
/// widgets (FilledButton, TextField, Card...) look right without each screen
/// styling them again.
abstract final class AppTheme {
  /// Built fresh each time from AppColors, so it is the dark theme or the
  /// light theme depending on `AppColors.isLight`.
  static ThemeData get current {
    final light = AppColors.isLight;
    // ColorScheme.light and ColorScheme.dark take the same settings; we pick
    // one and fill it with our colours.
    final makeScheme = light ? ColorScheme.light : ColorScheme.dark;
    final scheme = makeScheme(
      primary: AppColors.green, // FilledButton background
      onPrimary: AppColors.onGreen,
      secondaryContainer: AppColors.card, // FilledButton.tonal = the "Secondary" button
      onSecondaryContainer: AppColors.text,
      error: AppColors.dangerText, // error message under a field: words, so the readable red
      onError: AppColors.onDanger,
      surface: AppColors.ground,
      onSurface: AppColors.text,
      onSurfaceVariant: AppColors.textMuted,
      outline: AppColors.outline,
      outlineVariant: AppColors.line,
      shadow: const Color(0x33101828), // soft blue-grey shadow for light-mode cards
      surfaceContainerHigh: AppColors.sheet, // default dialog background
      surfaceContainerLow: AppColors.sheet, // default bottom sheet background
    );

    // Every button shares the design's 48px pill shape; colours come from the
    // scheme above, so FilledButton is green and FilledButton.tonal is dark.
    final pillShape = ButtonStyle(
      minimumSize: const WidgetStatePropertyAll(Size(48, 48)),
      padding: const WidgetStatePropertyAll(EdgeInsets.symmetric(horizontal: 24)),
      shape: const WidgetStatePropertyAll(StadiumBorder()),
      textStyle: WidgetStatePropertyAll(AppText.button),
    );

    OutlineInputBorder fieldBorder(Color color, [double width = 1]) => OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.field),
          borderSide: BorderSide(color: color, width: width),
        );

    return ThemeData(
      useMaterial3: true,
      brightness: light ? Brightness.light : Brightness.dark,
      colorScheme: scheme,
      // See-through, so the glow painted behind each page (GlowBackground) shows.
      scaffoldBackgroundColor: Colors.transparent,
      pageTransitionsTheme: PageTransitionsTheme(builders: {for (final platform in TargetPlatform.values) platform: const _GlowPages()}),
      dialogTheme: DialogThemeData(backgroundColor: AppColors.sheet),
      bottomSheetTheme: BottomSheetThemeData(backgroundColor: AppColors.sheet, modalBackgroundColor: AppColors.sheet),
      // Messages float above the dock as a small solid card, like the design's toast.
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.sheet,
        contentTextStyle: AppText.body.copyWith(color: AppColors.text),
        actionTextColor: AppColors.greenText,
        elevation: 6,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.inner), side: BorderSide(color: AppColors.glassEdge)),
      ),
      // Default font for all plain Text widgets: Plus Jakarta Sans in the text colour.
      textTheme: GoogleFonts.plusJakartaSansTextTheme((light ? ThemeData.light() : ThemeData.dark()).textTheme)
          .apply(bodyColor: AppColors.text, displayColor: AppColors.text),
      filledButtonTheme: FilledButtonThemeData(style: pillShape),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: pillShape.copyWith(
          foregroundColor: WidgetStatePropertyAll(AppColors.text),
          side: WidgetStatePropertyAll(BorderSide(color: AppColors.outline, width: 1.5)),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: pillShape.copyWith(foregroundColor: WidgetStatePropertyAll(AppColors.text)),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.card,
        contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        labelStyle: AppText.small.copyWith(color: AppColors.textMuted, fontWeight: FontWeight.w700),
        hintStyle: AppText.input.copyWith(color: AppColors.textMuted),
        border: fieldBorder(AppColors.line),
        enabledBorder: fieldBorder(AppColors.line),
        focusedBorder: fieldBorder(AppColors.greenText, 1.5),
        errorBorder: fieldBorder(AppColors.danger),
        focusedErrorBorder: fieldBorder(AppColors.danger, 1.5),
      ),
      cardTheme: CardThemeData(
        color: AppColors.card,
        elevation: AppGlass.lift,
        margin: EdgeInsets.zero,
        shape: AppGlass.shape(AppRadius.card),
      ),
      dividerTheme: DividerThemeData(color: AppColors.line, thickness: 1, space: 1),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent, // the glow shows behind the title
        foregroundColor: AppColors.text,
        elevation: 0,
        scrolledUnderElevation: 0,
        titleTextStyle: AppText.rowTitle.copyWith(color: AppColors.text),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: AppColors.greenText,
        linearTrackColor: AppColors.line,
      ),
    );
  }
}
