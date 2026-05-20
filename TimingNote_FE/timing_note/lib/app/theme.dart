import 'package:flutter/material.dart';
import '../shared/theme/colors.dart';
import '../shared/theme/typography.dart';

class AppTheme {
  static ThemeData get dark => ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        colorScheme: const ColorScheme.dark(
          primary: SpaceColors.neonPurple,
          secondary: SpaceColors.neonPink,
          surface: SpaceColors.space900,
          background: SpaceColors.space950,
          error: SpaceColors.error,
          onPrimary: SpaceColors.white,
          onSecondary: SpaceColors.white,
          onSurface: SpaceColors.white,
          onBackground: SpaceColors.white,
          onError: SpaceColors.white,
        ),
        scaffoldBackgroundColor: SpaceColors.space950,
        textTheme: SpaceTypography.textTheme,
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.transparent,
          elevation: 0,
          centerTitle: true,
          titleTextStyle: TextStyle(
            fontFamily: SpaceTypography.pixelFontFamily,
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: SpaceColors.white,
          ),
        ),
        dividerTheme: const DividerThemeData(
          color: SpaceColors.white10,
          thickness: 1,
        ),
      );

  // Keep light theme for compatibility if needed, but update to match system
  static ThemeData get light => dark; 
}
