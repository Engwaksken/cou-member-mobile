import 'package:flutter/material.dart';

/// Brand colours from the Church of Uganda crest.
class AppColors {
  static const purple = Color(0xFF4A1E8F);
  static const purpleDark = Color(0xFF2B0E58);
  static const purpleLight = Color(0xFF6B3BB5);
  static const gold = Color(0xFFD4A62A);
  static const goldSoft = Color(0xFFFFF3D6);
  static const goldText = Color(0xFF6B4D00);
  static const blue = Color(0xFF1F4E9E);
  static const background = Color(0xFFF6F4FA);
  static const field = Color(0xFFF0ECF6);
  static const outline = Color(0xFFE5DFEE);
  static const success = Color(0xFF237A4B);
  static const successSoft = Color(0xFFDDF3E6);

  static const brandGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [purpleDark, purple, purpleLight],
  );
}

/// Corner radii used across the app.
class AppRadius {
  static const field = 14.0;
  static const card = 18.0;
  static const button = 14.0;
}

ThemeData buildAppTheme() {
  final scheme = ColorScheme.fromSeed(
    seedColor: AppColors.purple,
    primary: AppColors.purple,
    secondary: AppColors.blue,
    tertiary: AppColors.gold,
    surface: Colors.white,
    surfaceTint: Colors.transparent,
  );
  final base = ThemeData(colorScheme: scheme, useMaterial3: true);
  final text = base.textTheme;
  final textTheme = text.copyWith(
    headlineSmall: text.headlineSmall?.copyWith(fontWeight: FontWeight.w700, letterSpacing: -.2),
    titleLarge: text.titleLarge?.copyWith(fontWeight: FontWeight.w700, letterSpacing: -.1),
    titleMedium: text.titleMedium?.copyWith(fontWeight: FontWeight.w600),
    bodyLarge: text.bodyLarge?.copyWith(height: 1.45),
    bodyMedium: text.bodyMedium?.copyWith(fontSize: 14.5, height: 1.4),
    bodySmall: text.bodySmall?.copyWith(fontSize: 13, height: 1.35),
    labelLarge: text.labelLarge?.copyWith(fontSize: 15, fontWeight: FontWeight.w600, letterSpacing: .2),
  );
  final fieldShape = OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.field), borderSide: BorderSide.none);
  final buttonShape = RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.button));
  const buttonSize = Size(64, 52);

  return base.copyWith(
    scaffoldBackgroundColor: AppColors.background,
    textTheme: textTheme,
    appBarTheme: AppBarTheme(
      backgroundColor: AppColors.background,
      foregroundColor: scheme.onSurface,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleTextStyle: textTheme.titleLarge?.copyWith(color: scheme.onSurface, fontSize: 21),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.field,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      border: fieldShape,
      enabledBorder: fieldShape,
      disabledBorder: fieldShape,
      focusedBorder: fieldShape.copyWith(borderSide: const BorderSide(color: AppColors.purple, width: 2)),
      errorBorder: fieldShape.copyWith(borderSide: BorderSide(color: scheme.error, width: 1.2)),
      focusedErrorBorder: fieldShape.copyWith(borderSide: BorderSide(color: scheme.error, width: 2)),
      prefixIconColor: WidgetStateColor.resolveWith(
        (s) => s.contains(WidgetState.error) ? scheme.error : (s.contains(WidgetState.focused) ? AppColors.purple : scheme.onSurfaceVariant),
      ),
      suffixIconColor: scheme.onSurfaceVariant,
      labelStyle: TextStyle(color: scheme.onSurfaceVariant, fontSize: 15),
      floatingLabelStyle: WidgetStateTextStyle.resolveWith(
        (s) => TextStyle(color: s.contains(WidgetState.error) ? scheme.error : AppColors.purple, fontWeight: FontWeight.w600),
      ),
      hintStyle: TextStyle(color: scheme.onSurfaceVariant.withValues(alpha: .7)),
      helperStyle: TextStyle(color: scheme.onSurfaceVariant, fontSize: 12.5),
      helperMaxLines: 3,
      errorStyle: TextStyle(color: scheme.error, fontSize: 13, fontWeight: FontWeight.w500),
      errorMaxLines: 3,
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(minimumSize: buttonSize, shape: buttonShape, textStyle: textTheme.labelLarge, elevation: 0),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: buttonSize,
        shape: buttonShape,
        textStyle: textTheme.labelLarge,
        side: const BorderSide(color: AppColors.outline, width: 1.4),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(minimumSize: const Size(48, 48), shape: buttonShape, textStyle: textTheme.labelLarge),
    ),
    iconButtonTheme: IconButtonThemeData(style: IconButton.styleFrom(minimumSize: const Size(48, 48))),
    cardTheme: CardThemeData(
      color: Colors.white,
      elevation: 0,
      margin: const EdgeInsets.symmetric(vertical: 6),
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.card),
        side: const BorderSide(color: AppColors.outline),
      ),
    ),
    listTileTheme: ListTileThemeData(
      iconColor: AppColors.purple,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      minVerticalPadding: 10,
      titleTextStyle: textTheme.titleMedium?.copyWith(fontSize: 15.5, color: scheme.onSurface),
      subtitleTextStyle: textTheme.bodyMedium?.copyWith(fontSize: 13.5, color: scheme.onSurfaceVariant),
      selectedColor: AppColors.purple,
      selectedTileColor: scheme.primaryContainer.withValues(alpha: .55),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
    navigationBarTheme: NavigationBarThemeData(
      height: 68,
      backgroundColor: Colors.white,
      elevation: 0,
      shadowColor: Colors.transparent,
      indicatorColor: scheme.primaryContainer,
      labelTextStyle: WidgetStateTextStyle.resolveWith(
        (s) => TextStyle(
          fontSize: 13,
          fontWeight: s.contains(WidgetState.selected) ? FontWeight.w700 : FontWeight.w500,
          color: s.contains(WidgetState.selected) ? AppColors.purple : scheme.onSurfaceVariant,
        ),
      ),
      iconTheme: WidgetStateProperty.resolveWith(
        (s) => IconThemeData(color: s.contains(WidgetState.selected) ? AppColors.purple : scheme.onSurfaceVariant),
      ),
    ),
    tabBarTheme: TabBarThemeData(
      labelColor: AppColors.purple,
      unselectedLabelColor: scheme.onSurfaceVariant,
      labelStyle: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700),
      unselectedLabelStyle: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w500),
      indicatorSize: TabBarIndicatorSize.label,
      indicator: const UnderlineTabIndicator(
        borderSide: BorderSide(color: AppColors.purple, width: 3),
        borderRadius: BorderRadius.vertical(top: Radius.circular(3)),
      ),
      dividerColor: AppColors.outline,
    ),
    chipTheme: ChipThemeData(
      backgroundColor: scheme.primaryContainer,
      side: BorderSide.none,
      shape: const StadiumBorder(),
      labelStyle: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: scheme.onPrimaryContainer),
    ),
    dividerTheme: const DividerThemeData(color: AppColors.outline, thickness: 1, space: 1),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: const Color(0xFF241338),
      contentTextStyle: const TextStyle(color: Colors.white, fontSize: 14.5),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      titleTextStyle: textTheme.titleLarge?.copyWith(color: scheme.onSurface),
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: Colors.white,
      showDragHandle: true,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
    ),
    drawerTheme: const DrawerThemeData(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.horizontal(right: Radius.circular(24))),
    ),
    progressIndicatorTheme: ProgressIndicatorThemeData(color: AppColors.purple, linearTrackColor: scheme.primaryContainer),
    expansionTileTheme: const ExpansionTileThemeData(shape: Border(), collapsedShape: Border(), iconColor: AppColors.purple),
    bannerTheme: const MaterialBannerThemeData(backgroundColor: AppColors.goldSoft),
  );
}
