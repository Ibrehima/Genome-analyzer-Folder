import 'package:flutter/material.dart';

/// Central color & theme definitions mixing a clean Material 3 structure
/// (Style 1) with vibrant gradient accents per module (Style 2).
class AppColors {
  static const Color primaryBlue = Color(0xFF1565C0);
  static const Color teal = Color(0xFF00897B);
  static const Color background = Color(0xFFF7F9FA);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color textDark = Color(0xFF1B2733);
  static const Color textMuted = Color(0xFF64748B);

  // Module accent gradients (vibrant, Style 2 inspired)
  static const List<Color> gradSequence = [
    Color(0xFF1565C0),
    Color(0xFF42A5F5),
  ];
  static const List<Color> gradPrimer = [Color(0xFFF4511E), Color(0xFFFFB74D)];
  static const List<Color> gradAlignment = [
    Color(0xFF00897B),
    Color(0xFF4DD0E1),
  ];
  static const List<Color> gradPhylo = [Color(0xFF7B1FA2), Color(0xFFBA68C8)];
  static const List<Color> gradSpecies = [Color(0xFF2E7D32), Color(0xFF81C784)];
  static const List<Color> gradQuality = [Color(0xFF0277BD), Color(0xFF4FC3F7)];
  static const List<Color> gradStats = [Color(0xFFAD1457), Color(0xFFF06292)];
  static const List<Color> gradOnline = [Color(0xFF303F9F), Color(0xFF7986CB)];
  static const List<Color> gradAssistant = [
    Color(0xFF6A1B9A),
    Color(0xFFE040FB),
  ];
  static const List<Color> gradReports = [Color(0xFFEF6C00), Color(0xFFFFD54F)];
  static const List<Color> gradSequencing = [
    Color(0xFF00695C),
    Color(0xFF4DB6AC),
  ];
  static const List<Color> gradRna = [Color(0xFFC2185B), Color(0xFFF48FB1)];
  static const List<Color> gradProteomics = [
    Color(0xFF4527A0),
    Color(0xFF9575CD),
  ];
  static const List<Color> gradAnnotation = [
    Color(0xFF37474F),
    Color(0xFF90A4AE),
  ];
  static const List<Color> gradStructure3D = [
    Color(0xFF00838F),
    Color(0xFF4DD0E1),
  ];
  static const List<Color> gradTargets = [Color(0xFFD32F2F), Color(0xFFFF8A65)];
  static const List<Color> gradMetabolomics = [
    Color(0xFF558B2F),
    Color(0xFFAED581),
  ];

  static const Color success = Color(0xFF2E7D32);
  static const Color warning = Color(0xFFF9A825);
  static const Color danger = Color(0xFFC62828);
}

class AppTheme {
  static ThemeData get light {
    final base = ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.primaryBlue,
        primary: AppColors.primaryBlue,
        secondary: AppColors.teal,
        surface: AppColors.surface,
      ),
      scaffoldBackgroundColor: AppColors.background,
      fontFamily: 'Roboto',
    );

    return base.copyWith(
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.background,
        foregroundColor: AppColors.textDark,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: AppColors.textDark,
          fontSize: 20,
          fontWeight: FontWeight.w700,
        ),
      ),
      cardTheme: CardThemeData(
        color: AppColors.surface,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        margin: EdgeInsets.zero,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
      tabBarTheme: const TabBarThemeData(
        labelColor: AppColors.primaryBlue,
        unselectedLabelColor: AppColors.textMuted,
        indicatorColor: AppColors.primaryBlue,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(
            color: AppColors.primaryBlue,
            width: 1.6,
          ),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primaryBlue,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.primaryBlue,
          side: const BorderSide(color: AppColors.primaryBlue),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: AppColors.surface,
        selectedItemColor: AppColors.primaryBlue,
        unselectedItemColor: AppColors.textMuted,
        showUnselectedLabels: true,
        type: BottomNavigationBarType.fixed,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}
