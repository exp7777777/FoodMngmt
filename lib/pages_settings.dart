import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'providers.dart';
import 'foodmngmt_AccountSettings.dart';
import 'localization.dart';
import 'foodmngmt_AccountLogin.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(AppLocalizations.of(context).settingsTitle)),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 帳號設定
            Card(
              child: MouseRegion(
                cursor: SystemMouseCursors.click,
                child: ListTile(
                  leading: const Icon(Icons.person),
                  title: Text(AppLocalizations.of(context).accountSettings),
                  trailing: const Icon(Icons.arrow_forward_ios),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => AccountSettings(),
                      ),
                    );
                  },
                ),
              ),
            ),
            const SizedBox(height: 16),

            // 主題設定
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      AppLocalizations.of(context).themeSettings,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<ThemeMode>(
                      value: context.watch<AppSettingsProvider>().themeMode,
                      decoration: InputDecoration(
                        labelText: AppLocalizations.of(context).selectTheme,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      items: [
                        DropdownMenuItem(
                          value: ThemeMode.light,
                          child: Text(AppLocalizations.of(context).lightTheme),
                        ),
                        DropdownMenuItem(
                          value: ThemeMode.dark,
                          child: Text(AppLocalizations.of(context).darkTheme),
                        ),
                        DropdownMenuItem(
                          value: ThemeMode.system,
                          child: Text(AppLocalizations.of(context).systemTheme),
                        ),
                      ],
                      onChanged: (ThemeMode? value) {
                        if (value != null) {
                          context.read<AppSettingsProvider>().setThemeMode(
                            value,
                          );
                        }
                      },
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // 語言設定
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      AppLocalizations.of(context).languageSettings,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      value:
                          context
                              .watch<AppSettingsProvider>()
                              .locale
                              .languageCode,
                      decoration: InputDecoration(
                        labelText: AppLocalizations.of(context).selectLanguage,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      items: [
                        DropdownMenuItem(
                          value: 'zh',
                          child: Text(
                            AppLocalizations.of(context).traditionalChinese,
                          ),
                        ),
                        DropdownMenuItem(
                          value: 'en',
                          child: Text(AppLocalizations.of(context).english),
                        ),
                      ],
                      onChanged: (String? value) {
                        if (value != null) {
                          context.read<AppSettingsProvider>().setLocale(
                            value == 'en'
                                ? const Locale('en')
                                : const Locale('zh', 'TW'),
                          );
                        }
                      },
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            const Divider(),
            const SizedBox(height: 12),
            Center(
              child: OutlinedButton.icon(
                onPressed: () async {
                  await context.read<AuthProvider>().logout();
                  if (!context.mounted) return;
                  Navigator.pushAndRemoveUntil(
                    context,
                    MaterialPageRoute(builder: (_) => const AccoutLogin()),
                    (route) => false,
                  );
                },
                icon: const Icon(Icons.logout),
                label: const Text('登出'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
