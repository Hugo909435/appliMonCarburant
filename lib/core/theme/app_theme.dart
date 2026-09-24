import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Palette sobre tirée du logo : le bleu nuit de sa tuile (#0F2D3F) remplace
/// le noir comme encre de marque, et les gris sont très légèrement bleutés
/// pour s'y accorder. L'orange du logo reste *réservé au logo* : repris dans
/// l'interface, il ferait concurrence aux couleurs de carburant et aux
/// signaux bon/mauvais. Fuel-type color-coding (see fuel_colors.dart) is kept
/// as a functional exception — it's how drivers tell fuels apart at a glance
/// on the map, not site branding.
///
/// Ces constantes ne servent qu'à ce qui est dessiné **par-dessus la carte**
/// (marqueurs, totems de prix, boutons flottants, tracé d'itinéraire) : les
/// tuiles restent claires quel que soit le thème de l'app, donc ces éléments
/// gardent une palette fixe.
///
/// Tout ce qui est posé sur une surface du thème — ListTile, Chip, carte,
/// feuille — doit prendre sa couleur dans `Theme.of(context).colorScheme`.
/// [primary] et [accent] sont un bleu très sombre : sur le fond sombre le
/// contraste tombe sous 1,5:1, et l'élément disparaît.
/// `test/theme_contrast_test.dart` verrouille cette règle.
class AppColors {
  /// Bleu nuit de la tuile du logo.
  static const primary = Color(0xFF0F2D3F);
  static const primaryLight = Color(0xFF1E4760);
  static const accent = Color(0xFF0F2D3F);

  // Même logique que sur la carte : des cartes blanches qui se détachent
  // d'un fond à peine grisé, plutôt que des cadres tracés sur du blanc.
  static const backgroundLight = Color(0xFFF3F5F7);
  static const surfaceLight = Color(0xFFFFFFFF);
  static const surfaceContainerLight = Color(0xFFE9EEF1);
  static const outlineLight = Color(0xFFDCE2E6);

  // Presque noir, à peine teinté de bleu : un noir pur ferait paraître les
  // boutons bleu nuit ternes par contraste.
  static const backgroundDark = Color(0xFF070D12);
  static const surfaceDark = Color(0xFF111B22);
  static const surfaceContainerDark = Color(0xFF1B2832);
  static const outlineDark = Color(0xFF243440);

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

  /// Feuilles et boîtes de dialogue.
  static const xl = 28.0;
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
    final container = isDark
        ? AppColors.surfaceContainerDark
        : AppColors.surfaceContainerLight;
    final outline = isDark ? AppColors.outlineDark : AppColors.outlineLight;
    final onSurface = isDark ? Colors.white : AppColors.primary;
    // Bleu nuit en clair ; en sombre, il disparaîtrait sur le fond, d'où un
    // bleu plus lumineux pour les boutons pleins.
    final brand = isDark ? AppColors.primaryLight : AppColors.primary;

    final colorScheme = ColorScheme(
      brightness: brightness,
      primary: brand,
      onPrimary: Colors.white,
      secondary: AppColors.accent,
      onSecondary: Colors.white,
      error: const Color(0xFFBA1A1A),
      onError: Colors.white,
      surface: surface,
      onSurface: onSurface,
      outline: outline,
      outlineVariant: outline,
      surfaceContainer: container,
      surfaceContainerHigh: container,
      surfaceContainerHighest: isDark
          ? const Color(0xFF17323F)
          : const Color(0xFFEEF2F4),
    );

    final textTheme = _textTheme(brightness);

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
        toolbarHeight: 64,
        titleSpacing: 20,
        titleTextStyle: textTheme.headlineSmall?.copyWith(
          color: onSurface,
          fontSize: 24,
          letterSpacing: -0.3,
        ),
        iconTheme: IconThemeData(color: onSurface),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: surface,
        margin: EdgeInsets.zero,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
        ),
      ),
      dividerTheme: DividerThemeData(
        color: onSurface.withValues(alpha: 0.08),
        thickness: 1,
        space: 1,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: container,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 18,
          vertical: 15,
        ),
        hintStyle: textTheme.bodyMedium?.copyWith(
          color: onSurface.withValues(alpha: 0.45),
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: BorderSide(color: onSurface, width: 1.5),
        ),
      ),
      // Boutons en gélule, comme les commandes posées sur la carte.
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: brand,
          foregroundColor: Colors.white,
          minimumSize: const Size.fromHeight(52),
          padding: const EdgeInsets.symmetric(horizontal: 22),
          shape: const StadiumBorder(),
          textStyle: textTheme.labelLarge?.copyWith(
            fontSize: 15.5,
            letterSpacing: 0.2,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: onSurface,
          backgroundColor: surface,
          minimumSize: const Size.fromHeight(52),
          padding: const EdgeInsets.symmetric(horizontal: 22),
          side: BorderSide(color: outline, width: 1.2),
          shape: const StadiumBorder(),
          textStyle: textTheme.labelLarge?.copyWith(fontSize: 15.5),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: onSurface,
          shape: const StadiumBorder(),
          textStyle: textTheme.labelLarge,
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: container,
        side: BorderSide.none,
        labelStyle: textTheme.labelMedium?.copyWith(color: onSurface),
        // Sans ceci, l'avatar d'un Chip garde la couleur d'icône par défaut
        // de Material, pensée pour un fond clair : en thème sombre elle
        // disparaît dans la puce.
        iconTheme: IconThemeData(color: onSurface, size: 18),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        shape: const StadiumBorder(),
      ),
      listTileTheme: ListTileThemeData(
        iconColor: onSurface,
        textColor: onSurface,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: brand,
        foregroundColor: Colors.white,
        elevation: 3,
        shape: const StadiumBorder(),
        extendedTextStyle: textTheme.labelLarge?.copyWith(color: Colors.white),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: surface,
        surfaceTintColor: Colors.transparent,
        showDragHandle: true,
        dragHandleColor: onSurface.withValues(alpha: 0.2),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(AppRadius.xl),
          ),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.xl),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: AppColors.primary,
        contentTextStyle: textTheme.bodyMedium?.copyWith(color: Colors.white),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(color: onSurface),
      sliderTheme: SliderThemeData(
        activeTrackColor: onSurface,
        inactiveTrackColor: onSurface.withValues(alpha: 0.12),
        thumbColor: onSurface,
        overlayColor: onSurface.withValues(alpha: 0.08),
        activeTickMarkColor: Colors.transparent,
        inactiveTickMarkColor: Colors.transparent,
        trackHeight: 5,
      ),
    );
  }

  static ThemeData light = _build(brightness: Brightness.light);
  static ThemeData dark = _build(brightness: Brightness.dark);
}
