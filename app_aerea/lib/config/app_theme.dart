import 'package:flutter/material.dart';

/// ──────────────────────────────────────────────────────────────────
/// Paleta de Colores — Tonos Tierra Sofisticados
/// ──────────────────────────────────────────────────────────────────
class AppColors {
  AppColors._();

  // Primarios
  static const Color primary = Color(0xFF3D2A1E);
  static const Color secondary = Color(0xFF8A5A44);

  // Fondos y superficies
  static const Color background = Color(0xFFF4F1EA);
  static const Color surface = Color(0xFFF9F6F1);
  static const Color surfaceWhite = Colors.white;

  // Semánticos
  static const Color success = Color(0xFF2E7D32);
  static const Color successLight = Color(0xFFE8F5E9);
  static const Color error = Color(0xFFC62828);
  static const Color errorLight = Color(0xFFFFEBEE);
  static const Color warning = Color(0xFFF9A825);
  static const Color warningLight = Color(0xFFFFF8E1);
  static const Color info = Color(0xFF1565C0);
  static const Color infoLight = Color(0xFFE3F2FD);

  // Textos
  static const Color textPrimary = Color(0xFF3D2A1E);
  static const Color textSecondary = Color(0xFF6D4C41);
  static const Color textHint = Color(0xFF9E8E82);

  // Bordes y divisores
  static const Color border = Color(0xFFD7CEC7);
  static const Color divider = Color(0xFFE0D8D0);

  // Asientos
  static const Color seatAvailable = Color(0xFF8A5A44);
  static const Color seatSelected = Color(0xFF2E7D32);
  static const Color seatReserved = Color(0xFFC62828);
}

/// ──────────────────────────────────────────────────────────────────
/// Gradientes reutilizables
/// ──────────────────────────────────────────────────────────────────
class AppGradients {
  AppGradients._();

  static const LinearGradient primaryButton = LinearGradient(
    colors: [AppColors.primary, AppColors.secondary],
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
  );

  static const LinearGradient appBar = LinearGradient(
    colors: [AppColors.primary, AppColors.secondary],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient pageBackground = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [
      Color(0xFFE8E0D6),
      AppColors.background,
    ],
  );
}

/// ──────────────────────────────────────────────────────────────────
/// Estilos de texto reutilizables
/// ──────────────────────────────────────────────────────────────────
class AppTextStyles {
  AppTextStyles._();

  static const TextStyle heading = TextStyle(
    fontSize: 24,
    fontWeight: FontWeight.bold,
    color: AppColors.primary,
    letterSpacing: 0.5,
  );

  static const TextStyle subheading = TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.w600,
    color: AppColors.primary,
  );

  static const TextStyle body = TextStyle(
    fontSize: 14,
    color: AppColors.textSecondary,
  );

  static const TextStyle caption = TextStyle(
    fontSize: 12,
    color: AppColors.textHint,
  );

  static const TextStyle buttonText = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.bold,
    color: Colors.white,
    letterSpacing: 0.8,
  );
}

/// ──────────────────────────────────────────────────────────────────
/// Decoraciones reutilizables
/// ──────────────────────────────────────────────────────────────────
class AppDecorations {
  AppDecorations._();

  static BoxDecoration card = BoxDecoration(
    color: AppColors.surfaceWhite,
    borderRadius: BorderRadius.circular(24),
    border: Border.all(color: AppColors.border.withOpacity(0.3)),
    boxShadow: [
      BoxShadow(
        color: AppColors.primary.withOpacity(0.06),
        blurRadius: 16,
        offset: const Offset(0, 4),
      ),
    ],
  );

  static BoxDecoration gradientButton = BoxDecoration(
    gradient: AppGradients.primaryButton,
    borderRadius: BorderRadius.circular(24),
    boxShadow: [
      BoxShadow(
        color: AppColors.primary.withOpacity(0.35),
        blurRadius: 10,
        offset: const Offset(0, 4),
      ),
    ],
  );
}

/// ──────────────────────────────────────────────────────────────────
/// ThemeData completo
/// ──────────────────────────────────────────────────────────────────
class AppTheme {
  AppTheme._();

  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: AppColors.background,
      colorScheme: const ColorScheme.light(
        primary: AppColors.primary,
        onPrimary: Colors.white,
        secondary: AppColors.secondary,
        onSecondary: Colors.white,
        surface: AppColors.surface,
        onSurface: AppColors.textPrimary,
        error: AppColors.error,
        onError: Colors.white,
      ),
      appBarTheme: const AppBarTheme(
        elevation: 0,
        centerTitle: true,
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        titleTextStyle: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: Colors.white,
          letterSpacing: 0.5,
        ),
        iconTheme: IconThemeData(color: Colors.white),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: AppColors.surfaceWhite,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: BorderSide(color: AppColors.border.withOpacity(0.3)),
        ),
        margin: const EdgeInsets.only(bottom: 12),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surfaceWhite,
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppColors.secondary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppColors.error),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppColors.error, width: 2),
        ),
        labelStyle: const TextStyle(color: AppColors.textHint),
        hintStyle: const TextStyle(color: AppColors.textHint),
        prefixIconColor: AppColors.secondary,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          textStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.8,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.primary,
          side: const BorderSide(color: AppColors.secondary, width: 1.5),
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          textStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.8,
          ),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: AppColors.divider,
        thickness: 1,
      ),
      iconTheme: const IconThemeData(
        color: AppColors.secondary,
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: AppColors.secondary,
      ),
    );
  }
}
