import 'package:flutter/material.dart';

import 'app_colors.dart';

/// Light theme matching "FixMyCampus Screens v2". The design is light-only,
/// so the app does not switch to a dark theme.
abstract final class AppTheme {
  static const fontFamily = 'PlusJakartaSans';
  static const monoFamily = 'GeistMono';

  static ThemeData light() {
    const scheme = ColorScheme(
      brightness: Brightness.light,
      primary: AppColors.ink,
      onPrimary: AppColors.white,
      primaryContainer: AppColors.periwinkle,
      onPrimaryContainer: AppColors.ink,
      secondary: AppColors.periwinkle,
      onSecondary: AppColors.ink,
      secondaryContainer: AppColors.periwinkleLight,
      onSecondaryContainer: AppColors.ink,
      tertiary: AppColors.orange,
      onTertiary: AppColors.ink,
      tertiaryContainer: AppColors.statusReported,
      onTertiaryContainer: AppColors.ink,
      error: AppColors.error,
      onError: AppColors.white,
      errorContainer: AppColors.statusReopened,
      onErrorContainer: AppColors.ink,
      surface: AppColors.white,
      onSurface: AppColors.ink,
      onSurfaceVariant: AppColors.textSecondary,
      surfaceContainerLowest: AppColors.white,
      surfaceContainerLow: AppColors.surfaceRow,
      surfaceContainer: AppColors.surface,
      surfaceContainerHigh: AppColors.surface,
      surfaceContainerHighest: AppColors.surface,
      outline: AppColors.textTertiary,
      outlineVariant: AppColors.border,
      shadow: Color(0x40283250),
      scrim: Color(0x66111111),
      inverseSurface: AppColors.ink,
      onInverseSurface: AppColors.white,
      inversePrimary: AppColors.periwinkle,
    );

    final base = ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      fontFamily: fontFamily,
      scaffoldBackgroundColor: AppColors.white,
      splashFactory: InkSparkle.splashFactory,
    );

    final text = base.textTheme.apply(
      bodyColor: AppColors.ink,
      displayColor: AppColors.ink,
      fontFamily: fontFamily,
    );

    return base.copyWith(
      textTheme: text.copyWith(
        // Screen titles: 22/700, tight tracking.
        headlineSmall: text.headlineSmall?.copyWith(
          fontSize: 22,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.44,
        ),
        titleLarge: text.titleLarge?.copyWith(
          fontSize: 20,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.2,
        ),
        titleMedium: text.titleMedium?.copyWith(
          fontSize: 16,
          fontWeight: FontWeight.w700,
        ),
        titleSmall: text.titleSmall?.copyWith(
          fontSize: 14,
          fontWeight: FontWeight.w700,
        ),
        bodyLarge: text.bodyLarge?.copyWith(fontSize: 15),
        bodyMedium: text.bodyMedium?.copyWith(fontSize: 14),
        bodySmall: text.bodySmall?.copyWith(
          fontSize: 12,
          color: AppColors.textSecondary,
        ),
        labelLarge: text.labelLarge?.copyWith(
          fontSize: 15,
          fontWeight: FontWeight.w600,
        ),
        labelMedium: text.labelMedium?.copyWith(
          fontSize: 13,
          fontWeight: FontWeight.w600,
        ),
        labelSmall: text.labelSmall?.copyWith(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          letterSpacing: 0,
        ),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.white,
        foregroundColor: AppColors.ink,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        titleTextStyle: TextStyle(
          fontFamily: fontFamily,
          fontSize: 16,
          fontWeight: FontWeight.w700,
          color: AppColors.ink,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surface,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 20,
          vertical: 17,
        ),
        hintStyle: const TextStyle(color: AppColors.textSecondary),
        labelStyle: const TextStyle(color: AppColors.textSecondary),
        floatingLabelStyle: const TextStyle(color: AppColors.ink),
        border: _pill(Colors.transparent),
        enabledBorder: _pill(Colors.transparent),
        focusedBorder: _pill(AppColors.ink, width: 1.5),
        errorBorder: _pill(AppColors.error),
        focusedErrorBorder: _pill(AppColors.error, width: 1.5),
        errorStyle: const TextStyle(color: AppColors.error),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.ink,
          foregroundColor: AppColors.white,
          disabledBackgroundColor: AppColors.border,
          minimumSize: const Size(64, AppSizes.field),
          shape: const StadiumBorder(),
          textStyle: const TextStyle(
            fontFamily: fontFamily,
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.ink,
          minimumSize: const Size(64, AppSizes.field),
          side: const BorderSide(color: AppColors.border),
          shape: const StadiumBorder(),
          textStyle: const TextStyle(
            fontFamily: fontFamily,
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.textStrong,
          textStyle: const TextStyle(
            fontFamily: fontFamily,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      cardTheme: const CardThemeData(
        elevation: 0,
        color: AppColors.surfaceRow,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(AppRadii.card)),
        ),
      ),
      chipTheme: const ChipThemeData(
        shape: StadiumBorder(side: BorderSide(color: AppColors.border)),
        backgroundColor: AppColors.white,
        selectedColor: AppColors.ink,
        labelStyle: TextStyle(
          fontFamily: fontFamily,
          fontSize: 13,
          fontWeight: FontWeight.w500,
          color: AppColors.ink,
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: AppColors.divider,
        thickness: 1,
        space: 1,
      ),
      snackBarTheme: const SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.ink,
        contentTextStyle: TextStyle(
          fontFamily: fontFamily,
          color: AppColors.white,
          fontSize: 14,
        ),
        shape: StadiumBorder(),
      ),
      dialogTheme: const DialogThemeData(
        backgroundColor: AppColors.white,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(AppRadii.card)),
        ),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: AppColors.white,
        surfaceTintColor: Colors.transparent,
        showDragHandle: true,
        dragHandleColor: AppColors.border,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(AppRadii.sheet),
          ),
        ),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: AppColors.ink,
        linearTrackColor: AppColors.border,
      ),
    );
  }

  static OutlineInputBorder _pill(Color color, {double width = 1}) =>
      OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppSizes.field / 2),
        borderSide: color == Colors.transparent
            ? BorderSide.none
            : BorderSide(color: color, width: width),
      );
}
