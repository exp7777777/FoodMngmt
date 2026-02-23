import 'dart:math';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'providers.dart';
import 'foodmngmt_AccountSettings.dart';
import 'localization.dart';
import 'foodmngmt_AccountLogin.dart';
import 'invoice_service.dart';
import 'models.dart';
import 'pages_api_management.dart';

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
            Card(
              child: MouseRegion(
                cursor: SystemMouseCursors.click,
                child: ListTile(
                  leading: const Icon(Icons.vpn_key),
                  title: const Text('API 管理'),
                  subtitle: const Text('新增或修改個人 API Key'),
                  trailing: const Icon(Icons.arrow_forward_ios),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const ApiManagementPage(),
                      ),
                    );
                  },
                ),
              ),
            ),
            // 發票載具設定
            Card(
              child: MouseRegion(
                cursor: SystemMouseCursors.click,
                child: ListTile(
                  leading: const Icon(Icons.receipt_long),
                  title: Text(
                    AppLocalizations.of(context).invoiceCarrierSettings,
                  ),
                  trailing: const Icon(Icons.arrow_forward_ios),
                  onTap: () {
                    _showInvoiceCarrierDialog(context);
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
            const Divider(),
            const SizedBox(height: 12),
            Center(
              child: OutlinedButton.icon(
                onPressed: () async {
                  await context.read<AuthProvider>().logout();
                  if (!context.mounted) return;
                  Navigator.pushAndRemoveUntil(
                    context,
                    MaterialPageRoute(builder: (_) => const AccountLogin()),
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

  // 顯示發票載具設定對話框
  void _showInvoiceCarrierDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return const InvoiceCarrierDialog();
      },
    );
  }
}

// 發票載具設定對話框
class InvoiceCarrierDialog extends StatefulWidget {
  const InvoiceCarrierDialog({super.key});

  @override
  State<InvoiceCarrierDialog> createState() => _InvoiceCarrierDialogState();
}

class _InvoiceCarrierDialogState extends State<InvoiceCarrierDialog> {
  final TextEditingController _carrierIdController = TextEditingController();
  String _selectedCarrierType = 'mobile';
  List<InvoiceCarrier> _boundCarriers = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadBoundCarriers();
  }

  @override
  void dispose() {
    _carrierIdController.dispose();
    super.dispose();
  }

  Future<void> _loadBoundCarriers() async {
    setState(() {
      _isLoading = true;
    });

    final carriers = await InvoiceService.instance.getBoundCarriers();

    setState(() {
      _boundCarriers = carriers;
      _isLoading = false;
    });
  }

  Future<void> _bindCarrier() async {
    final carrierId = _carrierIdController.text.trim();
    if (carrierId.isEmpty) {
      _showMessage('請輸入載具號碼');
      return;
    }

    setState(() {
      _isLoading = true;
    });

    final success = await InvoiceService.instance.bindCarrier(
      carrierId,
      _selectedCarrierType,
    );

    setState(() {
      _isLoading = false;
    });

    if (success) {
      _showMessage('載具綁定成功');
      _carrierIdController.clear();
      await _loadBoundCarriers();
    } else {
      _showMessage('載具綁定失敗，請檢查載具號碼');
    }
  }

  Future<void> _unbindCarrier(String carrierId) async {
    setState(() {
      _isLoading = true;
    });

    final success = await InvoiceService.instance.unbindCarrier(carrierId);

    setState(() {
      _isLoading = false;
    });

    if (success) {
      _showMessage('載具解除綁定成功');
      await _loadBoundCarriers();
    } else {
      _showMessage('載具解除綁定失敗');
    }
  }

  Future<void> _syncInvoices(String carrierId) async {
    setState(() {
      _isLoading = true;
    });

    try {
      // 顯示載入動畫至少2秒
      final stopwatch = Stopwatch()..start();

      final invoiceItems = await InvoiceService.instance.syncInvoicesForCarrier(
        carrierId,
      );
      final foodItems = await InvoiceService.instance.identifyFoodItems(
        invoiceItems,
      );

      // 確保載入動畫顯示至少2秒
      final elapsed = stopwatch.elapsedMilliseconds;
      if (elapsed < 2000) {
        await Future.delayed(Duration(milliseconds: 2000 - elapsed));
      }

      // 如果有食物項目，顯示確認對話框
      if (foodItems.isNotEmpty && context.mounted) {
        _showFoodItemsConfirmationDialog(foodItems);
      } else if (context.mounted) {
        _showMessage('發票同步完成，但沒有找到食物項目，或發票資料為空');
      }
    } catch (e) {
      if (context.mounted) {
        _showMessage('發票同步失敗：$e');
      }
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _showFoodItemsConfirmationDialog(List<Map<String, dynamic>> foodItems) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('發票同步結果'),
          content: SizedBox(
            width: double.maxFinite,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('發現 ${foodItems.length} 項食物項目：'),
                const SizedBox(height: 16),
                SizedBox(
                  height: 200,
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: foodItems.length,
                    itemBuilder: (context, index) {
                      final item = foodItems[index];
                      return Card(
                        child: ListTile(
                          title: Text(item['productName'] ?? '未知產品'),
                          subtitle: Text(
                            '${item['category']} - ${item['amount']} (${item['estimatedShelfLife']} 天)',
                          ),
                          dense: true,
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('取消'),
            ),
            ElevatedButton(
              onPressed: () async {
                // 加入食材管理並顯示結果
                final addedCount = await _addFoodItemsToInventory(foodItems);

                Navigator.of(context).pop();

                if (context.mounted) {
                  String message = '成功新增 $addedCount 項食物到食材管理！';
                  final skippedCount = foodItems.length - addedCount;
                  if (skippedCount > 0) {
                    message += '\n跳過 $skippedCount 項已存在的項目';
                  }

                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(message),
                      duration: const Duration(seconds: 4),
                      backgroundColor: Colors.green[600],
                    ),
                  );
                }
              },
              child: const Text('加入食材管理'),
            ),
          ],
        );
      },
    );
  }

  Future<int> _addFoodItemsToInventory(
    List<Map<String, dynamic>> foodItems,
  ) async {
    int addedCount = 0;

    try {
      final foodProvider = context.read<FoodProvider>();
      final now = DateTime.now();
      final random = Random();
      final lastDayOfMonth = DateTime(now.year, now.month + 1, 0).day;

      // 獲取當前食材管理中的所有食物項目，用於檢查重複
      await foodProvider.refresh(); // 確保資料是最新的
      final existingFoodItems = foodProvider.items;
      final existingFoodNames =
          existingFoodItems.map((item) => item.name.toLowerCase()).toSet();

      for (final foodItem in foodItems) {
        final productName = foodItem['productName'] as String;
        final productNameLower = productName.toLowerCase();

        // 檢查是否已經存在相同名稱的食物項目
        if (existingFoodNames.contains(productNameLower)) {
          debugPrint('跳過已存在的食物項目: $productName');
          continue;
        }

        // 為每個食材生成不同的隨機購買日期（當月1號到當月最後一天之間）
        final randomDay =
            random.nextInt(lastDayOfMonth) + 1; // 1 到 lastDayOfMonth
        final randomPurchaseDate = DateTime(now.year, now.month, randomDay);

        final expiryDate = randomPurchaseDate.add(
          Duration(days: foodItem['estimatedShelfLife'] as int),
        );

        final newFoodItem = FoodItem(
          id:
              DateTime.now().millisecondsSinceEpoch.toString() +
              '_${addedCount}',
          name: productName,
          quantity: 1,
          unit: foodItem['amount'] as String,
          purchaseDate: randomPurchaseDate,
          expiryDate: expiryDate,
          shelfLifeDays: expiryDate
              .difference(randomPurchaseDate)
              .inDays
              .clamp(1, 3650),
          category: FoodCategory.other,
          storageLocation: StorageLocation.refrigerated, // 預設冷藏
          isOpened: false, // 發票同步的項目預設未開封
          account: 'invoice_sync',
        );

        await foodProvider.add(newFoodItem);
        addedCount++;
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('加入食材管理失敗: $e')));
      }
    }

    return addedCount;
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(AppLocalizations.of(context).invoiceCarrierSettings),
      content: SizedBox(
        width: double.maxFinite,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 已綁定的載具列表
              if (_boundCarriers.isNotEmpty) ...[
                Text('已綁定的載具：', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                ..._boundCarriers.map(
                  (carrier) => Card(
                    child: ListTile(
                      title: Text(
                        '${carrier.carrierType == 'mobile' ? '手機' : '卡片'}載具',
                      ),
                      subtitle: Text(carrier.carrierId),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.sync),
                            onPressed: () => _syncInvoices(carrier.carrierId),
                            tooltip: AppLocalizations.of(context).syncInvoices,
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete),
                            onPressed: () => _unbindCarrier(carrier.carrierId),
                            tooltip: AppLocalizations.of(context).unbindCarrier,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // 綁定新載具表單
              Text(
                _boundCarriers.isEmpty ? '綁定發票載具：' : '綁定新載具：',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _carrierIdController,
                decoration: InputDecoration(
                  labelText: AppLocalizations.of(context).carrierId,
                  hintText: AppLocalizations.of(context).enterCarrierId,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                value: _selectedCarrierType,
                decoration: InputDecoration(
                  labelText: AppLocalizations.of(context).carrierType,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                items: [
                  DropdownMenuItem(
                    value: 'mobile',
                    child: Text(AppLocalizations.of(context).mobileCarrier),
                  ),
                  DropdownMenuItem(
                    value: 'card',
                    child: Text(AppLocalizations.of(context).cardCarrier),
                  ),
                ],
                onChanged: (value) {
                  setState(() {
                    _selectedCarrierType = value!;
                  });
                },
              ),
              const SizedBox(height: 16),
              if (_isLoading)
                const CircularProgressIndicator()
              else
                ElevatedButton(
                  onPressed: _bindCarrier,
                  child: Text(AppLocalizations.of(context).bindCarrier),
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('關閉'),
        ),
      ],
    );
  }
}
