import 'package:flutter/material.dart';

class AppTheme {
  // 淺色色票
  static const Color lightPrimary = Color(0xFFFF914D);
  static const Color lightAppBar = Color(0xFFFFB366);
  static const Color lightBackground = Color(0xFFFCF7EF);
  // 深色色票
  static const Color darkPrimary = Colors.black;
  static const Color darkAppBar = Color.fromARGB(255, 27, 27, 27); //標題列顏色
  static const Color darkBackground = Color(0xFF2A2A2A);
  static const Color darkSurface = Color(0xFF3A3A3A);
  static const Color darkBorder = Color(0xFF4A4A4A);

  static ThemeData get theme {
    final base = ThemeData.light();
    return base.copyWith(
      colorScheme: base.colorScheme.copyWith(
        primary: lightPrimary,
        secondary: lightPrimary,
      ),
      scaffoldBackgroundColor: lightBackground,
      appBarTheme: const AppBarTheme(
        backgroundColor: lightAppBar, // 淺橘色
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
      ),

      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: lightPrimary,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: lightPrimary,
        foregroundColor: Colors.white,
      ),
    );
  }

  static ThemeData get darkTheme {
    final base = ThemeData.dark();
    return base.copyWith(
      colorScheme: base.colorScheme.copyWith(
        primary: darkPrimary, // 黑色
        secondary: darkPrimary, // 黑色
        surface: darkSurface, // 較亮的表面顏色
        onSurface: Colors.white,
      ),
      scaffoldBackgroundColor: darkBackground, // 較亮的背景色
      appBarTheme: const AppBarTheme(
        backgroundColor: darkAppBar, // 深橘色 AppBar 背景
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: darkPrimary, // 黑色
        foregroundColor: Colors.white,
      ),
      // 深色主題中「被選取」的元件以深橘色呈現
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        selectedItemColor: lightPrimary,
        unselectedItemColor: Colors.grey,
      ),
      checkboxTheme: CheckboxThemeData(
        fillColor: MaterialStateProperty.resolveWith(
          (states) =>
              states.contains(MaterialState.selected)
                  ? lightPrimary
                  : Colors.white70,
        ),
      ),
      radioTheme: RadioThemeData(
        fillColor: MaterialStateProperty.resolveWith(
          (states) =>
              states.contains(MaterialState.selected)
                  ? lightPrimary
                  : Colors.white70,
        ),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: MaterialStateProperty.resolveWith(
          (states) =>
              states.contains(MaterialState.selected)
                  ? lightPrimary
                  : Colors.white70,
        ),
        trackColor: MaterialStateProperty.resolveWith(
          (states) =>
              states.contains(MaterialState.selected)
                  ? lightPrimary.withOpacity(0.5)
                  : Colors.white24,
        ),
      ),
      chipTheme: base.chipTheme.copyWith(
        selectedColor: lightPrimary.withOpacity(0.25),
        checkmarkColor: Colors.white,
        secondarySelectedColor: lightPrimary.withOpacity(0.35),
      ),
      textSelectionTheme: const TextSelectionThemeData(
        cursorColor: lightPrimary,
        selectionColor: Color(0x33FF914D),
        selectionHandleColor: lightPrimary,
      ),
      listTileTheme: const ListTileThemeData(
        selectedColor: lightPrimary,
        iconColor: Colors.white70,
      ),
      cardTheme: const CardThemeData(
        color: darkSurface, // 卡片顏色
        elevation: 2,
      ),
      inputDecorationTheme: InputDecorationTheme(
        fillColor: darkSurface, // 輸入框背景
        filled: true,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: darkBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: darkBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: darkPrimary, width: 2), // 將橘色改為黑色
        ),
      ),
    );
  }
}
