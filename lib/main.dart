import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'providers.dart';
import 'repositories.dart';
import 'root_scaffold.dart';
import 'theme.dart';
import 'foodmngmt_AccountSettings.dart';
import 'foodmngmt_AccountLogin.dart';
import 'localization.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
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
          create: (_) => FoodProvider(FoodRepository())..refresh(),
        ),
        ChangeNotifierProvider(
          create: (_) => ShoppingProvider(ShoppingRepository())..refresh(),
        ),
        ChangeNotifierProvider(create: (_) => UserProfileProvider()..load()),
        ChangeNotifierProvider(create: (_) => AppSettingsProvider()..load()),
        ChangeNotifierProvider(
          create: (_) => AuthProvider(AuthRepository())..loadSession(),
        ),
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
    final authed = context.watch<AuthProvider>().isLoggedIn;
    if (authed) return const RootScaffold();
    return const AccoutLogin();
  }
}
