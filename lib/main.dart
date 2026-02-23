import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'providers.dart';
import 'repositories.dart';
import 'root_scaffold.dart';
import 'theme.dart';
import 'foodmngmt_AccountSettings.dart';
import 'localization.dart';
import 'firebase_service.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 初始化本機資料服務（SQLite）
  final localService = FirebaseService.instance;
  await localService.init();

  // 初始化中文和英文的日期格式
  await initializeDateFormatting('zh_TW');
  await initializeDateFormatting('en');
  Intl.defaultLocale = 'zh_TW';

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) => AuthProvider(AuthRepository())..loadSession(),
        ),
        ChangeNotifierProvider(create: (_) => FoodProvider(FoodRepository())),
        ChangeNotifierProvider(
          create: (_) => ShoppingProvider(ShoppingRepository()),
        ),
        ChangeNotifierProvider(create: (_) => UserProfileProvider()..load()),
        ChangeNotifierProvider(create: (_) => AppSettingsProvider()..load()),
      ],
      child: Builder(
        builder: (context) {
          return MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: AppTheme.theme,
            darkTheme: AppTheme.darkTheme,
            themeMode: context.watch<AppSettingsProvider>().themeMode,
            localizationsDelegates: const [
              AppLocalizationsDelegate(),
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            supportedLocales: const [Locale('zh', 'TW'), Locale('en')],
            locale: context.watch<AppSettingsProvider>().locale,
            home: const Main(),
            routes: {'/account-settings': (context) => AccountSettings()},
          );
        },
      ),
    );
  }
}

class Main extends StatelessWidget {
  const Main({super.key});

  @override
  Widget build(BuildContext context) {
    // 顯示主框架，初始頁面為食材管理頁面（保留工具列）
    return const RootScaffold(initialIndex: 0);
  }
}
