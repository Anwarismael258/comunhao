import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

ThemeData buildAppTheme({
  Color seedColor = const Color(0xFF0E8F5A),
  Color? secondaryColor,
}) {
  final colorScheme = ColorScheme.fromSeed(
    seedColor: seedColor,
    brightness: Brightness.light,
  ).copyWith(
    secondary: secondaryColor,
  );

  final textTheme = GoogleFonts.interTextTheme().copyWith(
    displayLarge: GoogleFonts.caveat(
      fontSize: 44,
      fontWeight: FontWeight.w700,
      color: colorScheme.onSurface,
    ),
    displayMedium: GoogleFonts.caveat(
      fontSize: 38,
      fontWeight: FontWeight.w700,
      color: colorScheme.onSurface,
    ),
    headlineSmall: GoogleFonts.inter(
      fontWeight: FontWeight.w700,
      color: colorScheme.onSurface,
    ),
    titleMedium: GoogleFonts.inter(fontWeight: FontWeight.w600),
    labelLarge: GoogleFonts.inter(fontWeight: FontWeight.w600),
  );

  return ThemeData(
    colorScheme: colorScheme,
    textTheme: textTheme,
    scaffoldBackgroundColor: const Color(0xFFF7F9F8),
    useMaterial3: true,
    appBarTheme: AppBarTheme(
      centerTitle: false,
      elevation: 0,
      scrolledUnderElevation: 0,
      backgroundColor: const Color(0xFFF7F9F8),
      foregroundColor: colorScheme.primary,
      titleTextStyle: GoogleFonts.inter(
        color: colorScheme.primary,
        fontSize: 18,
        fontWeight: FontWeight.w700,
      ),
    ),
    progressIndicatorTheme: ProgressIndicatorThemeData(
      color: colorScheme.primary,
    ),
    navigationBarTheme: NavigationBarThemeData(
      indicatorColor: colorScheme.primaryContainer,
      iconTheme: WidgetStateProperty.resolveWith(
        (states) => IconThemeData(
          color: states.contains(WidgetState.selected)
              ? colorScheme.primary
              : colorScheme.onSurfaceVariant,
        ),
      ),
      labelTextStyle: WidgetStateProperty.resolveWith(
        (states) => TextStyle(
          color: states.contains(WidgetState.selected)
              ? colorScheme.primary
              : colorScheme.onSurfaceVariant,
          fontWeight: states.contains(WidgetState.selected)
              ? FontWeight.w700
              : FontWeight.w500,
        ),
      ),
    ),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: colorScheme.primary,
      foregroundColor: colorScheme.onPrimary,
    ),
    chipTheme: ChipThemeData(
      selectedColor: colorScheme.secondaryContainer,
      secondarySelectedColor: colorScheme.secondaryContainer,
      checkmarkColor: colorScheme.onSecondaryContainer,
      labelStyle: TextStyle(color: colorScheme.onSurface),
    ),
    cardTheme: CardThemeData(
      color: Colors.white,
      elevation: 0,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: const BorderSide(color: Color(0xFFE5EDE8)),
      ),
    ),
  );
}

ThemeData buildAppDarkTheme({
  Color seedColor = const Color(0xFF0E8F5A),
  Color? secondaryColor,
}) {
  final colorScheme = ColorScheme.fromSeed(
    seedColor: seedColor,
    brightness: Brightness.dark,
  ).copyWith(
    secondary: secondaryColor,
  );

  final textTheme =
      GoogleFonts.interTextTheme(ThemeData.dark().textTheme).copyWith(
    displayLarge: GoogleFonts.caveat(
      fontSize: 44,
      fontWeight: FontWeight.w700,
      color: colorScheme.onSurface,
    ),
    displayMedium: GoogleFonts.caveat(
      fontSize: 38,
      fontWeight: FontWeight.w700,
      color: colorScheme.onSurface,
    ),
    headlineSmall: GoogleFonts.inter(
      fontWeight: FontWeight.w700,
      color: colorScheme.onSurface,
    ),
    titleMedium: GoogleFonts.inter(fontWeight: FontWeight.w600),
    labelLarge: GoogleFonts.inter(fontWeight: FontWeight.w600),
  );

  return ThemeData(
    colorScheme: colorScheme,
    textTheme: textTheme,
    scaffoldBackgroundColor: const Color(0xFF0F1412),
    useMaterial3: true,
    appBarTheme: AppBarTheme(
      centerTitle: false,
      elevation: 0,
      scrolledUnderElevation: 0,
      backgroundColor: const Color(0xFF0F1412),
      foregroundColor: colorScheme.onSurface,
      titleTextStyle: GoogleFonts.inter(
        color: colorScheme.onSurface,
        fontSize: 18,
        fontWeight: FontWeight.w700,
      ),
    ),
    progressIndicatorTheme: ProgressIndicatorThemeData(
      color: colorScheme.primary,
    ),
    navigationBarTheme: NavigationBarThemeData(
      indicatorColor: colorScheme.primaryContainer,
      iconTheme: WidgetStateProperty.resolveWith(
        (states) => IconThemeData(
          color: states.contains(WidgetState.selected)
              ? colorScheme.primary
              : colorScheme.onSurfaceVariant,
        ),
      ),
      labelTextStyle: WidgetStateProperty.resolveWith(
        (states) => TextStyle(
          color: states.contains(WidgetState.selected)
              ? colorScheme.primary
              : colorScheme.onSurfaceVariant,
          fontWeight: states.contains(WidgetState.selected)
              ? FontWeight.w700
              : FontWeight.w500,
        ),
      ),
    ),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: colorScheme.primary,
      foregroundColor: colorScheme.onPrimary,
    ),
    chipTheme: ChipThemeData(
      selectedColor: colorScheme.secondaryContainer,
      secondarySelectedColor: colorScheme.secondaryContainer,
      checkmarkColor: colorScheme.onSecondaryContainer,
      labelStyle: TextStyle(color: colorScheme.onSurface),
    ),
    cardTheme: CardThemeData(
      color: colorScheme.surfaceContainerLow,
      elevation: 0,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(
            color: colorScheme.outlineVariant.withValues(alpha: 0.5)),
      ),
    ),
  );
}
