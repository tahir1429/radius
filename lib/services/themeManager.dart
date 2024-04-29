import 'package:flutter/material.dart';
import 'package:radius_app/services/storageManager.dart';

MaterialColor buildMaterialColor(Color color) {
  List strengths = <double>[.05];
  Map<int, Color> swatch = {};
  final int r = color.red, g = color.green, b = color.blue;

  for (int i = 1; i < 10; i++) {
    strengths.add(0.1 * i);
  }
  for (var strength in strengths) {
    final double ds = 0.5 - strength;
    swatch[(strength * 1000).round()] = Color.fromRGBO(
      r + ((ds < 0 ? r : (255 - r)) * ds).round(),
      g + ((ds < 0 ? g : (255 - g)) * ds).round(),
      b + ((ds < 0 ? b : (255 - b)) * ds).round(),
      1,
    );
  }
  return MaterialColor(color.value, swatch);
}

@immutable
class MyColors extends ThemeExtension<MyColors> {
  const MyColors({
    required this.brandColor,
    required this.borderColor,
    required this.danger,
    required this.appSecBgColor,
    required this.appSecTextColor,
  });

  final Color? brandColor;
  final Color? borderColor;
  final Color? danger;
  final Color? appSecBgColor;
  final Color? appSecTextColor;

  @override
  MyColors copyWith({Color? brandColor, Color? borderColor, Color? danger, Color? appSecBgColor, Color? appSecTextColor}) {
    return MyColors(
      brandColor: brandColor ?? this.brandColor,
      borderColor: borderColor ?? this.borderColor,
      danger: danger ?? this.danger,
      appSecBgColor: appSecBgColor ?? this.appSecBgColor,
      appSecTextColor: appSecTextColor ?? this.appSecTextColor,
    );
  }

  @override
  MyColors lerp(MyColors? other, double t) {
    if (other is! MyColors) {
      return this;
    }
    return MyColors(
      brandColor: Color.lerp(brandColor, other.brandColor, t),
      borderColor: Color.lerp(borderColor, other.borderColor, t),
      danger: Color.lerp(danger, other.danger, t),
      appSecBgColor: Color.lerp(appSecBgColor, other.appSecBgColor, t),
      appSecTextColor: Color.lerp(appSecTextColor, other.appSecTextColor, t),
    );
  }

  // Optional
  @override
  String toString() => 'MyColors(brandColor: $brandColor, danger: $danger)';
}

const Color themePrimaryColor = Color(0xFF7F0DB5);

class ThemeNotifier with ChangeNotifier {

  final darkTheme = ThemeData(
    fontFamily: 'MyriadProRegular',
    pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: CupertinoPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
        }
    ),
    //fontFamily: 'AbuDhabiMedia',
    primarySwatch: buildMaterialColor( const Color(0xFF000000) ),
    primaryColor: Colors.black,
    brightness: Brightness.dark,
    // App Bar
    appBarTheme: const AppBarTheme(
      backgroundColor: themePrimaryColor,
      titleTextStyle: TextStyle( color: Colors.white, fontSize: 18.0 ),
      toolbarTextStyle: TextStyle( color: Colors.white, fontSize: 16.0 ),
      elevation: 0,
    ),
    // Tabs
    tabBarTheme: const TabBarTheme(
      indicatorColor: Colors.white,
    ),
    extensions: const <ThemeExtension<dynamic>>[
        MyColors(
          brandColor: themePrimaryColor,
          borderColor: Color(0xFF969595),
          danger: Color(0xFFFFFFFF),
          appSecBgColor: Color(0xFF000000),
          appSecTextColor: Color(0xFFFFFFFF),
        ),
    ],

    textSelectionTheme: const TextSelectionThemeData(
      cursorColor: themePrimaryColor,
      selectionColor: themePrimaryColor,
      selectionHandleColor: themePrimaryColor,
    ),
    // Input Text Field
    inputDecorationTheme: const InputDecorationTheme(
      labelStyle: TextStyle(color: themePrimaryColor, fontWeight: FontWeight.w900),
      hintStyle: TextStyle(color: Color(0xFF969595)),
      suffixIconColor: Color(0xFF969595),
      prefixIconColor: Color(0xFF969595),
      enabledBorder: OutlineInputBorder(
        borderSide: BorderSide(
            style: BorderStyle.solid,
            color: Color(0xFF969595)
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderSide: BorderSide(
            style: BorderStyle.solid,
            color: Color(0xFF969595)
        ),
      )
    ),
    dividerColor: Colors.black12,
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ButtonStyle(
          backgroundColor: MaterialStateProperty.resolveWith<Color?>((s) {
            if (s.contains(MaterialState.disabled)) return Colors.brown; // Disabled button color
            return themePrimaryColor; // Enabled button color
          }),
          foregroundColor: MaterialStateProperty.resolveWith<Color?>((s) {
            if (s.contains(MaterialState.disabled)) return Colors.white30; // Disabled text color
            return Colors.white; // Enabled text color
          }),
        ),//
      ),
      filledButtonTheme:  FilledButtonThemeData(
        style: ButtonStyle(
          shape: MaterialStateProperty.all<RoundedRectangleBorder>(
              RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10.0),
              )
          ),
          backgroundColor: MaterialStateProperty.resolveWith<Color?>((s) {
            if (s.contains(MaterialState.disabled)) return Colors.brown; // Disabled button color
            return themePrimaryColor;
          }),
          foregroundColor: MaterialStateProperty.resolveWith<Color?>((s) {
            if (s.contains(MaterialState.disabled)) return Colors.white30; // Disabled text color
            return Colors.white; // Enabled text color
          }),
        ),//  <-- this auto selects the right color
      ),
    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor: Colors.black,
      foregroundColor: Colors.white
    ),
  );

  final lightTheme = ThemeData(
    pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: CupertinoPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
        }
    ),
    fontFamily: 'MyriadProRegular',
    primaryColor: Colors.white,
    brightness: Brightness.light,
    colorScheme: ColorScheme.fromSwatch(primarySwatch: buildMaterialColor( themePrimaryColor )).copyWith(secondary: Colors.white),
    appBarTheme: const AppBarTheme(
      backgroundColor: themePrimaryColor,
      iconTheme: IconThemeData( color: Colors.white, size: 24.0 ),
      titleTextStyle: TextStyle( color: Colors.white, fontSize: 18.0 ),
      toolbarTextStyle: TextStyle( color: Colors.white, fontSize: 16.0 ),
      elevation: 0.0,
    ),
    switchTheme: const SwitchThemeData(
      splashRadius: 0.0
    ),

    extensions: const <ThemeExtension<dynamic>>[
      MyColors(
        brandColor: themePrimaryColor,
        borderColor: Color(0xFF969595),
        danger: Color(0xFFEF9A9A),
        appSecBgColor: Colors.white,
        appSecTextColor: Color(0xFF000000),
      ),
    ],
    textTheme: const TextTheme(
      bodySmall: TextStyle(color: Color(0xFF0D0D0D)),
      bodyLarge: TextStyle(color: Color(0xFF0D0D0D)),
      bodyMedium: TextStyle(color: Color(0xFF0D0D0D)),
    ),
    listTileTheme: const ListTileThemeData(
      textColor: Color(0xFF0D0D0D),
      iconColor: Color(0xFF0D0D0D),
    ),

    inputDecorationTheme: const InputDecorationTheme(
        labelStyle: TextStyle(color: themePrimaryColor, fontWeight: FontWeight.w900),
        hintStyle: TextStyle(color: Color(0xFF969595)),
        suffixIconColor: Color(0xFF969595),
        prefixIconColor: Color(0xFF969595),
        enabledBorder: OutlineInputBorder(
          borderSide: BorderSide(
              style: BorderStyle.solid,
              color: Color(0xFF969595)
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderSide: BorderSide(
              style: BorderStyle.solid,
              color: Color(0xFF969595)
          ),
        ),
    ),



    // backgroundColor: const Color(0xFFE5E5E5),
    // accentColor: Colors.black,
    // accentIconTheme: IconThemeData(color: Colors.white),
    dividerColor: Colors.white54,

    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ButtonStyle(
        backgroundColor: MaterialStateProperty.resolveWith<Color?>((s) {
          if (s.contains(MaterialState.disabled)) return Colors.brown; // Disabled button color
          return themePrimaryColor; // Enabled button color
        }),
        foregroundColor: MaterialStateProperty.resolveWith<Color?>((s) {
          if (s.contains(MaterialState.disabled)) return Colors.white30; // Disabled text color
          return Colors.white; // Enabled text color
        }),
      ),//
    ),

    filledButtonTheme:  FilledButtonThemeData(
        style: ButtonStyle(
          shape: MaterialStateProperty.all<RoundedRectangleBorder>(
              RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10.0),
              )
          ),
          backgroundColor: MaterialStateProperty.resolveWith<Color?>((s) {
            if (s.contains(MaterialState.disabled)) return Colors.brown; // Disabled button color
            return themePrimaryColor; // Enabled button color
          }),
          foregroundColor: MaterialStateProperty.resolveWith<Color?>((s) {
            if (s.contains(MaterialState.disabled)) return Colors.white30; // Disabled text color
            return Colors.white; // Enabled text color
          }),
        ),//  <-- this auto selects the right color
      ),
    tabBarTheme : const TabBarTheme(
        labelColor: Colors.white,
        labelStyle: TextStyle(color: Colors.white),
        indicator: UnderlineTabIndicator( // color for indicator (underline)
              borderSide: BorderSide(color: Colors.white)
          ),

    ),
    floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: Colors.white,
        foregroundColor: Colors.black
    ),
  );

  bool isLightMode = true;
  String lang = 'ar';

  ThemeData _themeData = ThemeData();
  ThemeData getTheme() => _themeData;

  /// CONSTRUCTOR
  ThemeNotifier() {
    StorageManager.readData('themeMode').then((value) {
      var themeMode = value ?? 'light';
      if (themeMode == 'light') {
        _themeData = lightTheme;
        isLightMode = true;
      } else {
        _themeData = darkTheme;
        isLightMode = false;
      }
      notifyListeners();
    });
    StorageManager.readData('localeKey').then((value) {
      lang = value;
      notifyListeners();
    });
  }

  /// SET DARK MODE
  void setDarkMode() async {
    _themeData = darkTheme;
    isLightMode = false;
    StorageManager.saveData('themeMode', 'dark');
    notifyListeners();
  }

  /// SET LIGHT MODE
  void setLightMode() async {
    _themeData = lightTheme;
    isLightMode = true;
    StorageManager.saveData('themeMode', 'light');
    notifyListeners();
  }
}