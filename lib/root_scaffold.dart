import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'voice_service.dart';
import 'providers.dart';

import 'foodmngmt_FoodManager.dart';
import 'pages_shopping_list.dart';
import 'pages_food_form.dart';
import 'pages_calendar.dart';
import 'pages_settings.dart';
import 'localization.dart';
import 'image_recognition_helper.dart';

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
                    final rc = rootContext ?? context;
                    Navigator.pop(context);

                    // 開始語音輸入流程（用於新增食材）
                    await _handleVoiceInputForFood(rc);
                  },
                ),
                _ActionItem(
                  icon: Icons.camera_alt,
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

                      // 顯示 loading
                      showDialog(
                        context: rc,
                        barrierDismissible: false,
                        builder: (BuildContext context) {
                          return WillPopScope(
                            onWillPop: () async => false,
                            child: Container(
                              color: Colors.black54,
                              child: Center(
                                child: Card(
                                  elevation: 8,
                                  child: Padding(
                                    padding: const EdgeInsets.all(24.0),
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        CircularProgressIndicator(),
                                        const SizedBox(height: 16),
                                        Text(
                                          '正在辨識圖片...',
                                          style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      );

                      // 使用共用的影像辨識輔助函數
                      final recognizedFood =
                          await ImageRecognitionHelper.recognizeAndSelectFood(
                            context: rc,
                            imageFile: File(picked.path),
                            imagePath: picked.path,
                          );

                      // 關閉 loading
                      if (rc.mounted) {
                        try {
                          Navigator.of(rc).pop();
                          // 添加延遲，讓無障礙樹有時間更新，避免 AXTree 錯誤
                          await Future.delayed(
                            const Duration(milliseconds: 100),
                          );
                        } catch (_) {
                          // loading 對話框可能已被關閉
                        }
                      }

                      // 使用 addPostFrameCallback 確保在正確的時機導航，避免無障礙樹錯誤
                      if (rc.mounted) {
                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          if (rc.mounted) {
                            Navigator.push(
                              rc,
                              MaterialPageRoute(
                                builder:
                                    (_) =>
                                        FoodFormPage(initial: recognizedFood),
                              ),
                            );
                          }
                        });
                      }
                    } catch (e) {
                      debugPrint('影像辨識錯誤: $e');

                      // 關閉 loading
                      if (rc.mounted) {
                        try {
                          Navigator.of(rc).pop();
                          // 添加延遲，避免 AXTree 錯誤
                          await Future.delayed(
                            const Duration(milliseconds: 100),
                          );
                        } catch (_) {
                          // 如果 dialog 不存在則忽略
                        }
                      }

                      // 顯示錯誤提示
                      if (rc.mounted) {
                        ScaffoldMessenger.of(rc).showSnackBar(
                          const SnackBar(
                            content: Text('發生未預期的錯誤，請稍後再試'),
                            duration: Duration(seconds: 3),
                          ),
                        );

                        // 使用 addPostFrameCallback 導航，避免無障礙樹錯誤
                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          if (rc.mounted) {
                            Navigator.push(
                              rc,
                              MaterialPageRoute(
                                builder:
                                    (_) => const FoodFormPage(initial: null),
                              ),
                            );
                          }
                        });
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

// 處理語音輸入
Future<void> _handleVoiceInput(BuildContext context) async {
  try {
    // 顯示語音識別對話框
    bool isListening = false;
    bool isProcessing = false;
    String recognizedText = '';

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Row(
                children: [
                  Icon(
                    Icons.mic,
                    color: isListening ? Colors.red : Colors.grey,
                  ),
                  const SizedBox(width: 8),
                  const Text('語音登錄'),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (!isListening && !isProcessing) ...[
                    const Text('請點擊下方按鈕開始說話'),
                    const SizedBox(height: 16),
                    const Text(
                      '例如：「我要買雞蛋、三瓶牛奶和兩斤豬肉」',
                      style: TextStyle(
                        fontSize: 12,
                        fontStyle: FontStyle.italic,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ] else if (isListening) ...[
                    const SizedBox(
                      width: 60,
                      height: 60,
                      child: CircularProgressIndicator(strokeWidth: 3),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      '正在聆聽中...',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.red,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      '請說出您要購買的食材',
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ] else if (isProcessing) ...[
                    const SizedBox(
                      width: 60,
                      height: 60,
                      child: CircularProgressIndicator(strokeWidth: 3),
                    ),
                    const SizedBox(height: 16),
                    const Text('處理中...', style: TextStyle(fontSize: 16)),
                    if (recognizedText.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(
                        '「$recognizedText」',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[600],
                          fontStyle: FontStyle.italic,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ],
                ],
              ),
              actions: [
                if (!isListening && !isProcessing)
                  TextButton(
                    onPressed: () => Navigator.pop(dialogContext),
                    child: const Text('取消'),
                  ),
                if (!isListening && !isProcessing)
                  ElevatedButton.icon(
                    onPressed: () async {
                      setState(() => isListening = true);

                      // 開始持續語音識別
                      final voiceService = VoiceService.instance;
                      await voiceService.startContinuousListening();
                    },
                    icon: const Icon(Icons.mic),
                    label: const Text('開始錄音'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                    ),
                  ),
                if (isListening)
                  ElevatedButton.icon(
                    onPressed: () async {
                      setState(() {
                        isListening = false;
                        isProcessing = true;
                      });

                      // 停止錄音並獲取結果
                      final voiceService = VoiceService.instance;
                      final text = await voiceService.stopAndGetResult();

                      if (text != null && text.isNotEmpty) {
                        setState(() {
                          recognizedText = text;
                        });

                        // 使用 Gemini 解析語音內容
                        final items = await voiceService.parseVoiceInput(text);

                        if (items.isNotEmpty && dialogContext.mounted) {
                          Navigator.pop(dialogContext);

                          // 顯示確認對話框
                          _showConfirmItems(context, items);
                        } else {
                          if (dialogContext.mounted) {
                            Navigator.pop(dialogContext);
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('無法識別食材，請重試'),
                                backgroundColor: Colors.orange,
                              ),
                            );
                          }
                        }
                      } else {
                        setState(() => isProcessing = false);
                        if (dialogContext.mounted) {
                          Navigator.pop(dialogContext);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('語音識別失敗，請重試'),
                              backgroundColor: Colors.red,
                            ),
                          );
                        }
                      }
                    },
                    icon: const Icon(Icons.pause),
                    label: const Text('暫停'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange,
                      foregroundColor: Colors.white,
                    ),
                  ),
              ],
            );
          },
        );
      },
    );
  } catch (e) {
    debugPrint('語音輸入錯誤: $e');
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('語音輸入失敗: $e'), backgroundColor: Colors.red),
      );
    }
  }
}

// 顯示確認食材清單對話框
Future<void> _showConfirmItems(
  BuildContext context,
  List<Map<String, String>> items,
) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder:
        (context) => AlertDialog(
          title: const Text('確認食材'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('已識別以下食材，確認要加入購物清單嗎？'),
              const SizedBox(height: 16),
              ...items.map(
                (item) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      Icon(Icons.check_circle, size: 20, color: Colors.green),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '${item['name']} - ${item['amount']}',
                          style: const TextStyle(fontSize: 14),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('取消'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('確認加入'),
            ),
          ],
        ),
  );

  if (confirmed == true && context.mounted) {
    // 加入到購物清單
    final shoppingProvider = context.read<ShoppingProvider>();
    int successCount = 0;

    for (final item in items) {
      try {
        await shoppingProvider.add(item['name']!, amount: item['amount']);
        successCount++;
      } catch (e) {
        debugPrint('添加食材失敗: ${item['name']}, $e');
      }
    }

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('成功加入 $successCount 個食材到購物清單'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }
}

/// 處理語音輸入（用於新增食材）
Future<void> _handleVoiceInputForFood(BuildContext context) async {
  try {
    bool isListening = false;
    bool isProcessing = false;
    String recognizedText = '';

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Row(
                children: [
                  Icon(Icons.mic, color: Colors.orange),
                  SizedBox(width: 8),
                  Text('語音輸入食材'),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (!isListening && !isProcessing) ...[
                    const Icon(Icons.mic_none, size: 64, color: Colors.grey),
                    const SizedBox(height: 16),
                    const Text(
                      '請點擊「開始錄音」按鈕\n說出要新增的食材名稱',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 14),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      '例如：「雞蛋」、「牛奶」、「蘋果」',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ] else if (isListening) ...[
                    const Icon(Icons.mic, size: 64, color: Colors.red),
                    const SizedBox(height: 16),
                    const Text(
                      '正在錄音中...',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.red,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const CircularProgressIndicator(),
                  ] else if (isProcessing) ...[
                    const CircularProgressIndicator(),
                    const SizedBox(height: 16),
                    const Text('正在處理語音...'),
                    if (recognizedText.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(
                        '識別結果：$recognizedText',
                        style: const TextStyle(fontSize: 14),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ],
                ],
              ),
              actions: [
                if (!isListening && !isProcessing)
                  TextButton(
                    onPressed: () => Navigator.pop(dialogContext),
                    child: const Text('取消'),
                  ),
                if (!isListening && !isProcessing)
                  ElevatedButton.icon(
                    onPressed: () async {
                      setState(() => isListening = true);

                      // 開始持續語音識別
                      final voiceService = VoiceService.instance;
                      await voiceService.startContinuousListening();
                    },
                    icon: const Icon(Icons.mic),
                    label: const Text('開始錄音'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                    ),
                  ),
                if (isListening)
                  ElevatedButton.icon(
                    onPressed: () async {
                      setState(() {
                        isListening = false;
                        isProcessing = true;
                      });

                      // 停止錄音並獲取結果
                      final voiceService = VoiceService.instance;
                      final text = await voiceService.stopAndGetResult();

                      if (text != null && text.isNotEmpty) {
                        setState(() {
                          recognizedText = text;
                        });

                        // 關閉對話框並導向到食材表單頁面
                        if (dialogContext.mounted) {
                          Navigator.pop(dialogContext);

                          // 導航到食材表單頁面，帶入識別的食材名稱
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder:
                                  (_) => FoodFormPage(
                                    initial: null,
                                    initialName: text.trim(),
                                  ),
                            ),
                          );
                        }
                      } else {
                        if (dialogContext.mounted) {
                          Navigator.pop(dialogContext);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('無法識別語音，請重試'),
                              duration: Duration(seconds: 2),
                            ),
                          );
                        }
                      }
                    },
                    icon: const Icon(Icons.stop),
                    label: const Text('停止錄音'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange,
                      foregroundColor: Colors.white,
                    ),
                  ),
              ],
            );
          },
        );
      },
    );
  } catch (e) {
    debugPrint('語音輸入失敗: $e');
    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('語音輸入失敗: $e')));
    }
  }
}
