import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Monochrome palette: black, white, grays only. Fuel-type color-coding
/// (see fuel_colors.dart) is kept as a functional exception — it's how
/// drivers tell fuels apart at a glance on the map, not site branding.
///
/// Ces constantes ne servent qu'à ce qui est dessiné **par-dessus la carte**
/// (marqueurs, totems de prix, boutons flottants, tracé d'itinéraire) : les
/// tuiles restent claires quel que soit le thème de l'app, donc ces éléments
/// gardent une palette fixe.
///
/// Tout ce qui est posé sur une surface du thème — ListTile, Chip, carte,
/// feuille — doit prendre sa couleur dans `Theme.of(context).colorScheme`.
/// [primary] et [accent] valent #111111 : sur le fond sombre (#000000 /
/// #161616) le contraste tombe à 1,04:1, et l'élément disparaît.
/// `test/theme_contrast_test.dart` verrouille cette règle.
class AppColors {
  static const primary = Color(0xFF111111);
  static const primaryLight = Color(0xFF2B2B2B);
  static const accent = Color(0xFF111111);

  static const backgroundLight = Color(0xFFFFFFFF);
  static const surfaceLight = Color(0xFFFFFFFF);
  static const outlineLight = Color(0xFFDDDDDD);

  static const backgroundDark = Color(0xFF000000);
  static const surfaceDark = Color(0xFF161616);
  static const outlineDark = Color(0xFF2E2E2E);

  /// Functional exceptions too: "cheaper / dearer than usual" signals must
  /// read as good or bad news at a glance.
  static const good = Color(0xFF1F8A4C);
  static const bad = Color(0xFFC0392B);
}

/// Border radii shared by "sign plate" surfaces across the app.
class AppRadius {
  static const sm = 12.0;
  static const md = 16.0;
  static const lg = 22.0;
}

class AppTheme {
  static TextTheme _textTheme(Brightness brightness) {
    final base = brightness == Brightness.dark
        ? Typography.whiteMountainView
        : Typography.blackMountainView;
    final display = GoogleFonts.archivoTextTheme(base);
    final body = GoogleFonts.ibmPlexSansTextTheme(base);
    return display
        .copyWith(
          bodyLarge: body.bodyLarge,
          bodyMedium: body.bodyMedium,
          bodySmall: body.bodySmall,
          labelLarge: body.labelLarge?.copyWith(fontWeight: FontWeight.w700),
          labelMedium: body.labelMedium?.copyWith(fontWeight: FontWeight.w600),
          labelSmall: body.labelSmall,
        )
        .copyWith(
          headlineMedium: display.headlineMedium?.copyWith(
            fontWeight: FontWeight.w800,
          ),
          headlineSmall: display.headlineSmall?.copyWith(
            fontWeight: FontWeight.w800,
          ),
          titleLarge: display.titleLarge?.copyWith(fontWeight: FontWeight.w700),
          titleMedium: display.titleMedium?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        );
  }

  static ThemeData _build({required Brightness brightness}) {
    final isDark = brightness == Brightness.dark;
    final background = isDark
        ? AppColors.backgroundDark
        : AppColors.backgroundLight;
    final surface = isDark ? AppColors.surfaceDark : AppColors.surfaceLight;
    final outline = isDark ? AppColors.outlineDark : AppColors.outlineLight;
    final onSurface = isDark ? Colors.white : AppColors.primary;

    final colorScheme = ColorScheme(
      brightness: brightness,
      primary: isDark ? AppColors.primaryLight : AppColors.primary,
      onPrimary: Colors.white,
      secondary: AppColors.accent,
      onSecondary: Colors.white,
      error: const Color(0xFFBA1A1A),
      onError: Colors.white,
      surface: surface,
      onSurface: onSurface,
      outline: outline,
      outlineVariant: outline,
      surfaceContainerHighest: isDark
          ? const Color(0xFF17323F)
          : const Color(0xFFEFE7D4),
    );

    final textTheme = _textTheme(brightness);
    final borderRadius = BorderRadius.circular(AppRadius.md);

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: background,
      textTheme: textTheme,
      splashFactory: InkSparkle.splashFactory,
      appBarTheme: AppBarTheme(
        backgroundColor: background,
        foregroundColor: onSurface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: textTheme.titleLarge?.copyWith(color: onSurface),
        iconTheme: IconThemeData(color: onSurface),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: surface,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: borderRadius,
          side: BorderSide(color: outline, width: 1.3),
        ),
      ),
      dividerTheme: DividerThemeData(color: outline, thickness: 1, space: 1),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surface,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
        hintStyle: textTheme.bodyMedium?.copyWith(
          color: onSurface.withValues(alpha: 0.45),
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.sm),
          borderSide: BorderSide(color: outline, width: 1.3),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.sm),
          borderSide: BorderSide(color: outline, width: 1.3),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.sm),
          borderSide: const BorderSide(color: AppColors.accent, width: 2),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.accent,
          foregroundColor: Colors.white,
          minimumSize: const Size.fromHeight(52),
          padding: const EdgeInsets.symmetric(horizontal: 20),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.sm),
          ),
          textStyle: textTheme.labelLarge?.copyWith(
            fontSize: 15.5,
            letterSpacing: 0.2,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: onSurface,
          minimumSize: const Size.fromHeight(52),
          padding: const EdgeInsets.symmetric(horizontal: 20),
          side: BorderSide(color: outline, width: 1.4),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.sm),
          ),
          textStyle: textTheme.labelLarge?.copyWith(fontSize: 15.5),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.accent,
          textStyle: textTheme.labelLarge,
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: surface,
        side: BorderSide(color: outline, width: 1.2),
        labelStyle: textTheme.labelMedium?.copyWith(color: onSurface),
        // Sans ceci, l'avatar d'un Chip garde la couleur d'icône par défaut
        // de Material, pensée pour un fond clair : en thème sombre elle
        // disparaît dans la puce.
        iconTheme: IconThemeData(color: onSurface, size: 18),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.sm),
        ),
      ),
      listTileTheme: ListTileThemeData(
        iconColor: onSurface,
        textColor: onSurface,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: AppColors.accent,
        foregroundColor: Colors.white,
        elevation: 3,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        extendedTextStyle: textTheme.labelLarge?.copyWith(color: Colors.white),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: isDark ? AppColors.backgroundDark : AppColors.primary,
        indicatorColor: Colors.white24,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        height: 64,
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return textTheme.labelSmall?.copyWith(
            color: selected ? Colors.white : Colors.white60,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return IconThemeData(color: selected ? Colors.white : Colors.white60);
        }),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: AppColors.primary,
        contentTextStyle: textTheme.bodyMedium?.copyWith(color: Colors.white),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.sm),
        ),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: AppColors.accent,
      ),
    );
  }

  static ThemeData light = _build(brightness: Brightness.light);
  static ThemeData dark = _build(brightness: Brightness.dark);
}
