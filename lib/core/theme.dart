import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class AppTheme {
  AppTheme._();
  static ThemeData get lightTheme => _build(Brightness.light);
  static ThemeData get darkTheme => _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    final dark = brightness == Brightness.dark;
    final scheme =
        ColorScheme.fromSeed(
          seedColor: const Color(0xFF675091),
          brightness: brightness,
        ).copyWith(
          primary: dark ? const Color(0xFFD0BCFF) : const Color(0xFF675091),
          onPrimary: dark ? const Color(0xFF38245B) : Colors.white,
          primaryContainer: dark
              ? const Color(0xFF4E3876)
              : const Color(0xFFD8C7FF),
          onPrimaryContainer: dark
              ? const Color(0xFFEBDDFF)
              : const Color(0xFF302047),
          secondaryContainer: dark
              ? const Color(0xFF48405E)
              : const Color(0xFFCEB9FF),
          onSecondaryContainer: dark
              ? const Color(0xFFE6DFF5)
              : const Color(0xFF38265D),
          tertiary: dark ? const Color(0xFFF5AFE9) : const Color(0xFF824780),
          onTertiary: dark ? const Color(0xFF4E194E) : Colors.white,
          tertiaryContainer: dark
              ? const Color(0xFF683065)
              : const Color(0xFFF6B1FA),
          onTertiaryContainer: dark
              ? const Color(0xFFFFD6F6)
              : const Color(0xFF360B36),
          onSurface: dark ? const Color(0xFFE9E0F0) : const Color(0xFF252132),
          onSurfaceVariant: dark
              ? const Color(0xFFCEC3DB)
              : const Color(0xFF514B61),
          surface: dark ? const Color(0xFF15121B) : const Color(0xFFFCF8FF),
          surfaceContainerLow: dark
              ? const Color(0xFF201C28)
              : const Color(0xFFF1ECFA),
          surfaceContainer: dark
              ? const Color(0xFF25212E)
              : const Color(0xFFE6E1F5),
          surfaceContainerHigh: dark
              ? const Color(0xFF302B39)
              : const Color(0xFFDFD7F0),
        );
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: dark
          ? const Color(0xFF15121B)
          : const Color(0xFFE6E1F5),
      visualDensity: VisualDensity.standard,
      appBarTheme: AppBarTheme(
        centerTitle: false,
        elevation: 0,
        backgroundColor: scheme.surfaceContainerLow,
        surfaceTintColor: Colors.transparent,
        systemOverlayStyle: dark
            ? SystemUiOverlayStyle.light
            : SystemUiOverlayStyle.dark,
        titleTextStyle: TextStyle(
          color: scheme.onSurface,
          fontSize: 22,
          fontWeight: FontWeight.w700,
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        margin: EdgeInsets.zero,
        color: scheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      ),
      dividerTheme: DividerThemeData(
        color: scheme.outlineVariant.withValues(alpha: .6),
        thickness: 1,
      ),
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: scheme.outlineVariant),
        ),
        filled: true,
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: scheme.primary, width: 2),
        ),
        fillColor: scheme.surfaceContainerLow,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          minimumSize: const Size(48, 48),
          shape: const StadiumBorder(),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          minimumSize: const Size(48, 48),
          shape: const StadiumBorder(),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: scheme.surfaceContainer,
        indicatorColor: scheme.primaryContainer,
        elevation: 0,
        height: 80,
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => TextStyle(
            fontSize: 12,
            color: states.contains(WidgetState.selected)
                ? scheme.onSurface
                : scheme.onSurfaceVariant,
            fontWeight: states.contains(WidgetState.selected)
                ? FontWeight.w700
                : FontWeight.w500,
          ),
        ),
      ),
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: scheme.surfaceContainerLow,
        indicatorColor: scheme.primaryContainer,
      ),
      chipTheme: ChipThemeData(
        side: BorderSide.none,
        backgroundColor: scheme.surfaceContainer,
        selectedColor: scheme.primaryContainer,
        shape: const StadiumBorder(),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: scheme.surfaceContainerHigh,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: scheme.surface,
        showDragHandle: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: scheme.primary,
        linearTrackColor: scheme.primaryContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      dataTableTheme: const DataTableThemeData(
        horizontalMargin: 20,
        columnSpacing: 24,
        dataRowMinHeight: 64,
        dataRowMaxHeight: 72,
      ),
    );
  }
}
