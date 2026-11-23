import 'package:material_ui/material_ui.dart';

class ProvitAssets {
  static const logoPrimary = 'assets/brand/logo/provit_emblema_dorado.png';
  static const isotipoPrimary = 'assets/brand/isotipo/provit_isotipo.png';
  static const appIcon = 'assets/brand/app/provit_app_icon.png';
  static const splashLogo = 'assets/brand/app/provit_splash_logo.png';
}

class ProvitSpacing {
  static const xxs = 4.0;
  static const xs = 8.0;
  static const sm = 12.0;
  static const md = 16.0;
  static const lg = 24.0;
  static const xl = 32.0;
}

class ProvitRadii {
  static const sm = Radius.circular(12);
  static const md = Radius.circular(16);
  static const lg = Radius.circular(24);
}

class ProvitPalette {
  static const brandGreen = Color(0xFF1F4D3E);
  static const brandGreenDeep = Color(0xFF15392E);
  static const ivory = Color(0xFFF7F2E6);
  static const ivoryStrong = Color(0xFFEEE5D4);
  static const darkBase = Color(0xFF0F1715);
  static const darkSurface = Color(0xFF182320);
  static const onDark = Color(0xFFEFE6D3);
  static const textPrimary = Color(0xFF1F2623);
  static const textOnDark = Color(0xFFEBE2CF);
  static const textSoft = Color(0xFF5A665F);

  static const highlightWarm = Color(0xFFFFE066);
  static const highlightMint = Color(0xFF8BE0B5);
  static const highlightSky = Color(0xFF8CC8FF);
  static const highlightRose = Color(0xFFFF9EB5);

  static const readingPaper = Color(0xFFFEFDF9);
  static const readingSepia = Color(0xFFF3EADA);
  static const readingDark = Color(0xFF1C2421);

  static const spokenRange = Color(0xFF99D8CD);
  static const annotationRange = Color(0xFFF2D783);
}

class ProvitTheme {
  static ThemeData light() {
    final scheme = ColorScheme.fromSeed(
      seedColor: ProvitPalette.brandGreen,
      brightness: Brightness.light,
      surface: ProvitPalette.ivory,
    );
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: ProvitPalette.ivory,
      textTheme: _textTheme(Brightness.light),
      appBarTheme: const AppBarTheme(centerTitle: false),
      cardTheme: CardThemeData(
        color: ProvitPalette.ivory,
        elevation: 0,
        shape: RoundedRectangleBorder(
          side: BorderSide(color: scheme.outlineVariant),
          borderRadius: const BorderRadius.all(ProvitRadii.md),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          padding: const EdgeInsets.symmetric(
            horizontal: ProvitSpacing.md,
            vertical: ProvitSpacing.sm,
          ),
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.all(ProvitRadii.md),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.all(ProvitRadii.md),
          ),
        ),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(ProvitRadii.lg),
        ),
      ),
      snackBarTheme: const SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  static ThemeData dark() {
    final scheme = ColorScheme.fromSeed(
      seedColor: ProvitPalette.brandGreen,
      brightness: Brightness.dark,
      surface: ProvitPalette.darkSurface,
    );
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: ProvitPalette.darkBase,
      textTheme: _textTheme(Brightness.dark),
      appBarTheme: const AppBarTheme(centerTitle: false),
      cardTheme: CardThemeData(
        color: ProvitPalette.darkSurface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          side: BorderSide(color: scheme.outlineVariant),
          borderRadius: const BorderRadius.all(ProvitRadii.md),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          padding: const EdgeInsets.symmetric(
            horizontal: ProvitSpacing.md,
            vertical: ProvitSpacing.sm,
          ),
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.all(ProvitRadii.md),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.all(ProvitRadii.md),
          ),
        ),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(ProvitRadii.lg),
        ),
      ),
      snackBarTheme: const SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  static TextTheme _textTheme(Brightness brightness) {
    final base = ThemeData(brightness: brightness).textTheme;
    final titleColor = brightness == Brightness.dark
        ? ProvitPalette.textOnDark
        : ProvitPalette.textPrimary;
    final bodyColor = brightness == Brightness.dark
        ? ProvitPalette.textOnDark
        : ProvitPalette.textPrimary;
    return base.copyWith(
      headlineLarge: base.headlineLarge?.copyWith(
        color: titleColor,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.3,
      ),
      headlineMedium: base.headlineMedium?.copyWith(
        color: titleColor,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.2,
      ),
      headlineSmall: base.headlineSmall?.copyWith(
        color: titleColor,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.1,
      ),
      titleLarge: base.titleLarge?.copyWith(
        color: titleColor,
        fontWeight: FontWeight.w600,
      ),
      bodyLarge: base.bodyLarge?.copyWith(color: bodyColor),
      bodyMedium: base.bodyMedium?.copyWith(color: bodyColor),
      bodySmall: base.bodySmall?.copyWith(
        color: brightness == Brightness.dark
            ? ProvitPalette.textOnDark.withValues(alpha: 0.8)
            : ProvitPalette.textSoft,
      ),
    );
  }
}
