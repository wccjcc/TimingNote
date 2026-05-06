import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'colors.dart';

class SpaceTypography {
  static const String pixelFontFamily = 'Galmuri11';

  static TextTheme get textTheme => TextTheme(
        displayLarge: GoogleFonts.inter(
          fontSize: 32,
          fontWeight: FontWeight.bold,
          color: SpaceColors.white,
        ),
        displayMedium: GoogleFonts.inter(
          fontSize: 28,
          fontWeight: FontWeight.bold,
          color: SpaceColors.white,
        ),
        displaySmall: GoogleFonts.inter(
          fontSize: 24,
          fontWeight: FontWeight.bold,
          color: SpaceColors.white,
        ),
        headlineLarge: const TextStyle(
          fontFamily: pixelFontFamily,
          fontSize: 24,
          fontWeight: FontWeight.bold,
          color: SpaceColors.white,
        ),
        headlineMedium: const TextStyle(
          fontFamily: pixelFontFamily,
          fontSize: 20,
          fontWeight: FontWeight.bold,
          color: SpaceColors.white,
        ),
        titleLarge: GoogleFonts.inter(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: SpaceColors.white,
        ),
        titleMedium: GoogleFonts.inter(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: SpaceColors.white,
        ),
        bodyLarge: GoogleFonts.inter(
          fontSize: 16,
          fontWeight: FontWeight.normal,
          color: SpaceColors.white,
        ),
        bodyMedium: GoogleFonts.inter(
          fontSize: 14,
          fontWeight: FontWeight.normal,
          color: SpaceColors.white,
        ),
        bodySmall: GoogleFonts.inter(
          fontSize: 12,
          fontWeight: FontWeight.normal,
          color: SpaceColors.white50,
        ),
        labelLarge: const TextStyle(
          fontFamily: pixelFontFamily,
          fontSize: 12,
          fontWeight: FontWeight.normal,
          color: SpaceColors.neonPurple,
        ),
      );
}
