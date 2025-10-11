import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'gemini_service.dart';
import 'models.dart';

import 'foodmngmt_FoodManager.dart';
import 'pages_shopping_list.dart';
import 'pages_food_form.dart';
import 'pages_calendar.dart';
import 'pages_settings.dart';
import 'localization.dart';

class RootScaffold extends StatefulWidget {
  final int initialIndex;
  const RootScaffold({super.key, this.initialIndex = 0});

  @override
  State<RootScaffold> createState() => _RootScaffoldState();
}

class _RootScaffoldState extends State<RootScaffold> {
  late int _index;

  @override
  void initState() {
    super.initState();
    _index = widget.initialIndex;
  }

  @override
  Widget build(BuildContext context) {
    final pages = <Widget>[
      FoodMngmtPage(),
      const CalendarPage(),
      const ShoppingListPage(),
      const SettingsPage(),
    ];
    return Scaffold(
      body: IndexedStack(index: _index, children: pages),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          showModalBottomSheet(
            context: context,
            backgroundColor: Colors.transparent,
            builder: (ctx) {
              return _AddActionSheet(rootContext: context);
            },
          );
        },
        child: const Icon(Icons.add),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        currentIndex: _index,
        onTap: (i) {
          setState(() => _index = i);
        },
        items: [
          BottomNavigationBarItem(
            icon: Icon(Icons.list),
            label: AppLocalizations.of(context).listTab,
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.calendar_today),
            label: AppLocalizations.of(context).calendarTab,
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.shopping_cart),
            label: AppLocalizations.of(context).shoppingTab,
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.settings),
            label: AppLocalizations.of(context).settingsTab,
          ),
        ],
      ),
    );
  }
}

class _AddActionSheet extends StatelessWidget {
  final BuildContext? rootContext;
  _AddActionSheet({this.rootContext});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.only(left: 16, right: 16, top: 12, bottom: 24),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor.withOpacity(0.98),
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _ActionItem(
                  icon: Icons.edit,
                  label: AppLocalizations.of(context).manualEntry,
                  onTap: () async {
                    final rc = rootContext ?? context;
                    Navigator.pop(context);
                    Navigator.push(
                      rc,
                      MaterialPageRoute(builder: (_) => const FoodFormPage()),
                    );
                  },
                ),
                _ActionItem(
                  icon: Icons.mic,
                  label: AppLocalizations.of(context).voiceEntry,
                  onTap: () async {
                    Navigator.pop(context);
                    // TODO: 語音輸入流程（後續可接）
                  },
                ),
                _ActionItem(
                  icon: Icons.auto_awesome,
                  label: AppLocalizations.of(context).scan,
                  onTap: () async {
                    final rc = rootContext ?? context;
                    Navigator.pop(context); // 先關閉底層表單

                    try {
                      final picker = ImagePicker();
                      final picked = await picker.pickImage(
                        source: ImageSource.gallery,
                        imageQuality: 85,
                      );

                      if (picked == null) return;

                      // 呼叫 Gemini 食物辨識
                      final identifiedResult = await GeminiService.instance
                          .identifyFood(File(picked.path));

                      FoodItem? initialFoodItem;

                      // 檢查辨識是否成功
                      if (rc.mounted && identifiedResult['success'] == true) {
                        final identifiedFoods =
                            identifiedResult['items'] as List<dynamic>;

                        if (identifiedFoods.isNotEmpty) {
                          // 選擇第一個辨識結果
                          final firstFood =
                              identifiedFoods.first as Map<String, dynamic>;
                          final foodName = firstFood['name'] as String;
                          final quantity = firstFood['quantity'] as int;
                          final unit = firstFood['unit'] as String;

                          initialFoodItem = FoodItem(
                            name: foodName,
                            quantity: quantity,
                            unit: unit,
                            expiryDate: DateTime.now().add(
                              const Duration(days: 7),
                            ),
                            category: FoodCategory.other, // 稍後會自動判斷
                            note: null,
                            imagePath: picked.path,
                          );
                        }
                      }

                      // 導航到食物表單頁面
                      if (rc.mounted) {
                        Navigator.push(
                          rc,
                          MaterialPageRoute(
                            builder:
                                (_) => FoodFormPage(initial: initialFoodItem),
                          ),
                        );
                      }
                    } catch (e) {
                      // 顯示錯誤提示並導航到空表單
                      if (rc.mounted) {
                        ScaffoldMessenger.of(rc).showSnackBar(
                          SnackBar(
                            content: Text(
                              '${AppLocalizations.of(rc).recognitionFailed}$e',
                            ),
                          ),
                        );

                        // 導航到空表單讓用戶手動輸入
                        Navigator.push(
                          rc,
                          MaterialPageRoute(
                            builder: (_) => FoodFormPage(initial: null),
                          ),
                        );
                      }
                    }
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ActionItem extends StatefulWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _ActionItem({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  State<_ActionItem> createState() => _ActionItemState();
}

class _ActionItemState extends State<_ActionItem> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: () {
          HapticFeedback.lightImpact();
          widget.onTap();
        },
        onTapDown: (_) => setState(() => _pressed = true),
        onTapCancel: () => setState(() => _pressed = false),
        onTapUp: (_) => setState(() => _pressed = false),
        child: Column(
          children: [
            AnimatedScale(
              duration: const Duration(milliseconds: 120),
              scale: _pressed ? 0.92 : 1.0,
              child: Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(22),
                ),
                child: Center(
                  child: Icon(
                    widget.icon,
                    size: 32,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(widget.label, style: const TextStyle(fontSize: 12)),
          ],
        ),
      ),
    );
  }
}
