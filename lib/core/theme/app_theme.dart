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

/// Turns our colours and text styles into Flutter's ThemeData, so built-in
/// widgets (FilledButton, TextField, Card...) look right without each screen
/// styling them again.
abstract final class AppTheme {
  static ThemeData get night {
    const scheme = ColorScheme.dark(
      primary: AppColors.green, // FilledButton background
      onPrimary: AppColors.onGreen,
      secondaryContainer: AppColors.card, // FilledButton.tonal = the "Secondary" button
      onSecondaryContainer: AppColors.text,
      error: AppColors.danger,
      onError: AppColors.onDanger,
      surface: AppColors.ground,
      onSurface: AppColors.text,
      onSurfaceVariant: AppColors.textMuted,
      outline: AppColors.outline,
      outlineVariant: AppColors.line,
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
      brightness: Brightness.dark,
      colorScheme: scheme,
      scaffoldBackgroundColor: AppColors.ground,
      // Default font for all plain Text widgets: Plus Jakarta Sans in white.
      textTheme: GoogleFonts.plusJakartaSansTextTheme(ThemeData.dark().textTheme)
          .apply(bodyColor: AppColors.text, displayColor: AppColors.text),
      filledButtonTheme: FilledButtonThemeData(style: pillShape),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: pillShape.copyWith(
          foregroundColor: const WidgetStatePropertyAll(AppColors.text),
          side: const WidgetStatePropertyAll(BorderSide(color: AppColors.outline, width: 1.5)),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: pillShape.copyWith(foregroundColor: const WidgetStatePropertyAll(AppColors.text)),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.card,
        contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        labelStyle: AppText.small.copyWith(color: AppColors.textMuted, fontWeight: FontWeight.w700),
        hintStyle: AppText.input.copyWith(color: AppColors.textMuted),
        border: fieldBorder(AppColors.line),
        enabledBorder: fieldBorder(AppColors.line),
        focusedBorder: fieldBorder(AppColors.green, 1.5),
        errorBorder: fieldBorder(AppColors.danger),
        focusedErrorBorder: fieldBorder(AppColors.danger, 1.5),
      ),
      cardTheme: CardThemeData(
        color: AppColors.card,
        elevation: 0, // the design separates surfaces by tone, never by shadow
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.card)),
      ),
      dividerTheme: const DividerThemeData(color: AppColors.line, thickness: 1, space: 1),
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.ground,
        foregroundColor: AppColors.text,
        elevation: 0,
        scrolledUnderElevation: 0,
        titleTextStyle: AppText.rowTitle,
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: AppColors.green,
        linearTrackColor: AppColors.line,
      ),
    );
  }
}
