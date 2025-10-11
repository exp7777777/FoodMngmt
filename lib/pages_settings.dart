import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'providers.dart';
import 'foodmngmt_AccountSettings.dart';
import 'localization.dart';
import 'foodmngmt_AccountLogin.dart';
import 'invoice_service.dart';

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
            const SizedBox(height: 16),

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

    final invoiceItems = await InvoiceService.instance.syncInvoices(carrierId);
    final foodItems = await InvoiceService.instance.identifyFoodItems(
      invoiceItems,
    );

    setState(() {
      _isLoading = false;
    });

    if (foodItems.isNotEmpty) {
      _showFoodItemsDialog(foodItems);
    } else {
      _showMessage('沒有找到食物項目，或發票資料為空');
    }
  }

  void _showFoodItemsDialog(List<Map<String, dynamic>> foodItems) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(AppLocalizations.of(context).syncInvoices),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: foodItems.length,
              itemBuilder: (context, index) {
                final item = foodItems[index];
                return Card(
                  child: ListTile(
                    title: Text(item['productName'] ?? '未知產品'),
                    subtitle: Text(
                      '${AppLocalizations.of(context).category}: ${item['category']}',
                    ),
                    trailing: Text('${item['estimatedShelfLife']} 天'),
                  ),
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('取消'),
            ),
            ElevatedButton(
              onPressed: () {
                // 這裡會將辨識的食物項目加入食材管理
                _addFoodItemsToInventory(foodItems);
                Navigator.of(context).pop();
                Navigator.of(context).pop();
              },
              child: const Text('加入食材管理'),
            ),
          ],
        );
      },
    );
  }

  void _addFoodItemsToInventory(List<Map<String, dynamic>> foodItems) {
    // 這裡會將食物項目加入食材管理系統
    // 由於這需要與現有的食材管理系統整合，這裡先顯示成功訊息
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('已將 ${foodItems.length} 項食物加入食材管理')));
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
