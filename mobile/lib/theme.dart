import 'package:flutter/material.dart';

/// Macro colour palette — matches the web app's MACRO_THEME.
class AppColors {
  AppColors._();

  static const kcal    = Color(0xFFD0C3F1); // lavender
  static const protein = Color(0xFFC3DCD8); // teal mist
  static const carbs   = Color(0xFFF5A7A6); // rose
  static const fat     = Color(0xFFF5CF9F); // peach

  // Surface / background (dark mode constants — use AppColorScheme for theme-aware colours)
  static const bg      = Color(0xFF0F1117);
  static const card    = Color(0xFF1A1D27);
  static const border  = Color(0xFF2A2D3E);

  // Text (dark mode constants)
  static const textPrimary = Color(0xFFE2E8F0);
  static const textMuted   = Color(0xFF94A3B8);

  // Semantic
  static const success = Color(0xFF4ADE80);
  static const danger  = Color(0xFFEF4444);
}

// ── Theme extension for structural colours ────────────────────────────────────

class AppColorScheme extends ThemeExtension<AppColorScheme> {
  const AppColorScheme({
    required this.bg,
    required this.card,
    required this.border,
    required this.textPrimary,
    required this.textMuted,
    required this.kcalColor,
    required this.smartInsightColor,
  });

  final Color bg;
  final Color card;
  final Color border;
  final Color textPrimary;
  final Color textMuted;
  /// Theme-conditional kcal / calorie colour.
  /// Dark mode: deep teal-blue. Light mode: soft sky blue.
  final Color kcalColor;
  /// Smart Insight icon colour — dark: lavender (kcal), light: teal mist (protein).
  final Color smartInsightColor;

  static AppColorScheme of(BuildContext context) =>
      Theme.of(context).extension<AppColorScheme>()!;

  static const dark = AppColorScheme(
    bg: Color(0xFF0F1117),
    card: Color(0xFF1A1D27),
    border: Color(0xFF2A2D3E),
    textPrimary: Color(0xFFE2E8F0),
    textMuted: Color(0xFF94A3B8),
    kcalColor: Color(0xFFD0C3F1),
    smartInsightColor: AppColors.kcal,      // lavender
  );

  static const light = AppColorScheme(
    bg: Color(0xFFF0F4F8),
    card: Color(0xFFFFFFFF),
    border: Color(0xFFE2E8F0),
    textPrimary: Color(0xFF0F172A),
    textMuted: Color(0xFF64748B),
    kcalColor: Color(0xFF9BC0DA),
    smartInsightColor: AppColors.protein,   // teal mist
  );

  @override
  AppColorScheme copyWith({
    Color? bg,
    Color? card,
    Color? border,
    Color? textPrimary,
    Color? textMuted,
    Color? kcalColor,
    Color? smartInsightColor,
  }) =>
      AppColorScheme(
        bg: bg ?? this.bg,
        card: card ?? this.card,
        border: border ?? this.border,
        textPrimary: textPrimary ?? this.textPrimary,
        textMuted: textMuted ?? this.textMuted,
        kcalColor: kcalColor ?? this.kcalColor,
        smartInsightColor: smartInsightColor ?? this.smartInsightColor,
      );

  @override
  AppColorScheme lerp(ThemeExtension<AppColorScheme>? other, double t) {
    if (other is! AppColorScheme) return this;
    return AppColorScheme(
      bg: Color.lerp(bg, other.bg, t)!,
      card: Color.lerp(card, other.card, t)!,
      border: Color.lerp(border, other.border, t)!,
      textPrimary: Color.lerp(textPrimary, other.textPrimary, t)!,
      textMuted: Color.lerp(textMuted, other.textMuted, t)!,
      kcalColor: Color.lerp(kcalColor, other.kcalColor, t)!,
      smartInsightColor: Color.lerp(smartInsightColor, other.smartInsightColor, t)!,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────

class AppTheme {
  AppTheme._();

  static ThemeData get dark => ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    scaffoldBackgroundColor: AppColors.bg,
    extensions: const [AppColorScheme.dark],
    colorScheme: const ColorScheme.dark(
      surface: AppColors.bg,
      onSurface: AppColors.textPrimary,
      primary: AppColors.protein,
      onPrimary: Colors.black,
      secondary: AppColors.carbs,
      onSecondary: Colors.black,
      error: AppColors.danger,
      outline: AppColors.border,
    ),
    cardTheme: const CardThemeData(
      color: AppColors.card,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(16)),
        side: BorderSide(color: AppColors.border, width: 1),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.card,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.protein, width: 1.5),
      ),
      hintStyle: const TextStyle(color: AppColors.textMuted),
      labelStyle: const TextStyle(color: AppColors.textMuted),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.protein,
        foregroundColor: Colors.black,
        minimumSize: const Size.fromHeight(48),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(foregroundColor: AppColors.protein),
    ),
    dividerTheme: const DividerThemeData(color: AppColors.border, space: 1),
    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      backgroundColor: AppColors.card,
      selectedItemColor: AppColors.protein,
      unselectedItemColor: AppColors.textMuted,
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: AppColors.card,
      indicatorColor: AppColors.protein.withValues(alpha: 0.2),
      labelTextStyle: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return const TextStyle(color: AppColors.protein, fontSize: 11, fontWeight: FontWeight.w600);
        }
        return const TextStyle(color: AppColors.textMuted, fontSize: 11);
      }),
      iconTheme: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return const IconThemeData(color: AppColors.protein);
        }
        return const IconThemeData(color: AppColors.textMuted);
      }),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: AppColors.card,
      selectedColor: AppColors.protein.withValues(alpha: 0.2),
      labelStyle: const TextStyle(color: AppColors.textPrimary, fontSize: 12),
      side: const BorderSide(color: AppColors.border),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.bg,
      foregroundColor: AppColors.textPrimary,
      elevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(
        color: AppColors.textPrimary,
        fontSize: 18,
        fontWeight: FontWeight.w600,
      ),
    ),
    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor: AppColors.protein,
      foregroundColor: Colors.black,
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: AppColors.card,
      contentTextStyle: const TextStyle(color: AppColors.textPrimary),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      behavior: SnackBarBehavior.floating,
    ),
  );

  static ThemeData get light => ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    scaffoldBackgroundColor: AppColorScheme.light.bg,
    extensions: const [AppColorScheme.light],
    colorScheme: const ColorScheme.light(
      surface: Color(0xFFFFFFFF),
      onSurface: Color(0xFF0F172A),
      primary: Color(0xFF5C7A4A),
      onPrimary: Colors.white,
      secondary: Color(0xFF3A7499),
      onSecondary: Colors.white,
      error: AppColors.danger,
      outline: Color(0xFFE2E8F0),
    ),
    cardTheme: CardThemeData(
      color: AppColorScheme.light.card,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: const BorderRadius.all(Radius.circular(16)),
        side: BorderSide(color: AppColorScheme.light.border),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColorScheme.light.card,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: AppColorScheme.light.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: AppColorScheme.light.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFF5C7A4A), width: 1.5),
      ),
      hintStyle: TextStyle(color: AppColorScheme.light.textMuted),
      labelStyle: TextStyle(color: AppColorScheme.light.textMuted),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.protein,
        foregroundColor: Colors.black,
        minimumSize: const Size.fromHeight(48),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(foregroundColor: AppColors.protein),
    ),
    dividerTheme: DividerThemeData(color: AppColorScheme.light.border, space: 1),
    bottomNavigationBarTheme: BottomNavigationBarThemeData(
      backgroundColor: AppColorScheme.light.card,
      selectedItemColor: const Color(0xFF5C7A4A),
      unselectedItemColor: AppColorScheme.light.textMuted,
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: AppColorScheme.light.card,
      indicatorColor: const Color(0xFF5C7A4A).withValues(alpha: 0.15),
      labelTextStyle: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return const TextStyle(color: Color(0xFF5C7A4A), fontSize: 11, fontWeight: FontWeight.w600);
        }
        return TextStyle(color: AppColorScheme.light.textMuted, fontSize: 11);
      }),
      iconTheme: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return const IconThemeData(color: Color(0xFF5C7A4A));
        }
        return IconThemeData(color: AppColorScheme.light.textMuted);
      }),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: AppColorScheme.light.card,
      selectedColor: const Color(0xFF5C7A4A).withValues(alpha: 0.15),
      labelStyle: TextStyle(color: AppColorScheme.light.textPrimary, fontSize: 12),
      side: BorderSide(color: AppColorScheme.light.border),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: AppColorScheme.light.card,
      foregroundColor: AppColorScheme.light.textPrimary,
      elevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(
        color: AppColorScheme.light.textPrimary,
        fontSize: 18,
        fontWeight: FontWeight.w600,
      ),
      shadowColor: Colors.black12,
      surfaceTintColor: Colors.transparent,
    ),
    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor: Color(0xFF5C7A4A),
      foregroundColor: Colors.white,
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: AppColorScheme.light.card,
      contentTextStyle: TextStyle(color: AppColorScheme.light.textPrimary),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      behavior: SnackBarBehavior.floating,
    ),
  );
}
