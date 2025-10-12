import 'package:flutter/material.dart';
import 'dart:io';
import 'package:provider/provider.dart';

import 'pages_food_form.dart';
import 'providers.dart';
import 'pages_ai_menu.dart';
import 'localization.dart';

class FoodMngmtPage extends StatelessWidget {
  final List<Map<String, String>> foodItems = const [
    {
      'name': '鮮乳優格(450g)',
      'expiry': '2025.01.16',
      'remaining': '23小時',
      'quantity': '1件',
    },
    {
      'name': '提拉米蘇',
      'expiry': '2025.01.18',
      'remaining': '3天',
      'quantity': '1件',
    },
    {
      'name': '統一布丁',
      'expiry': '2025.01.31',
      'remaining': '17天',
      'quantity': '2件',
    },
    {
      'name': '香蕉',
      'expiry': '2025.02.03',
      'remaining': '20天',
      'quantity': '1件',
    },
    {
      'name': '咖啡豆',
      'expiry': '2025.04.16',
      'remaining': '3個月',
      'quantity': '1件',
    },
  ];

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<FoodProvider>();
    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.of(context).foodManagerTitle),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: () => provider.refresh(),
          ),
          IconButton(
            icon: Icon(Icons.auto_awesome),
            tooltip: AppLocalizations.of(context).aiMenuRecommendation,
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const AiMenuPage()),
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    decoration: InputDecoration(
                      hintText: AppLocalizations.of(context).searchName,
                      prefixIcon: Icon(Icons.search),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    onChanged: (v) => provider.setFilter(keyword: v),
                  ),
                ),
                const SizedBox(width: 8),
                FilterChip(
                  label: Text(AppLocalizations.of(context).expiringIn3Days),
                  selected: provider.onlyExpiring,
                  onSelected: (v) => provider.setFilter(onlyExpiring: v),
                ),
              ],
            ),
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: provider.refresh,
              child:
                  provider.isLoading
                      ? const Center(child: CircularProgressIndicator())
                      : provider.errorMessage != null
                      ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.error_outline,
                              size: 64,
                              color: Colors.red,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              provider.errorMessage!,
                              style: TextStyle(color: Colors.red),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 16),
                            ElevatedButton(
                              onPressed: () => provider.refresh(),
                              child: Text('重試'),
                            ),
                          ],
                        ),
                      )
                      : provider.items.isEmpty
                      ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.fastfood_outlined,
                              size: 64,
                              color: Colors.grey,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              '尚無食材資料',
                              style: TextStyle(color: Colors.grey[600]),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              '點擊下方 + 按鈕新增食材',
                              style: TextStyle(
                                color: Colors.grey[500],
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      )
                      : ListView.builder(
                        itemCount: provider.items.length,
                        itemBuilder: (context, index) {
                          final item = provider.items[index];
                          final days = item.daysLeft;
                          final color =
                              days < 0
                                  ? Colors.red
                                  : days <= 3
                                  ? Colors.orange
                                  : Colors.green;
                          return MouseRegion(
                            cursor: SystemMouseCursors.click,
                            child: ListTile(
                              leading: _buildLeadingImage(
                                item.imagePath,
                                color,
                              ),
                              title: Text(item.name),
                              subtitle: Text(
                                '${item.expiryDate.toString().split(' ').first} (${days >= 0 ? '$days ${AppLocalizations.of(context).days}' : '${AppLocalizations.of(context).expired} ${-days} ${AppLocalizations.of(context).days}'})',
                              ),
                              trailing: Text('${item.quantity}${item.unit}'),
                              onTap:
                                  () => Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder:
                                          (_) => FoodFormPage(initial: item),
                                    ),
                                  ),
                              onLongPress: () async {
                                final ok = await showDialog<bool>(
                                  context: context,
                                  builder:
                                      (_) => AlertDialog(
                                        title: Text(
                                          AppLocalizations.of(
                                            context,
                                          ).deleteConfirm,
                                        ),
                                        content: Text(
                                          '${AppLocalizations.of(context).confirmDelete} ${item.name} ?',
                                        ),
                                        actions: [
                                          TextButton(
                                            onPressed:
                                                () => Navigator.pop(
                                                  context,
                                                  false,
                                                ),
                                            child: Text(
                                              AppLocalizations.of(
                                                context,
                                              ).cancel,
                                            ),
                                          ),
                                          TextButton(
                                            onPressed:
                                                () => Navigator.pop(
                                                  context,
                                                  true,
                                                ),
                                            child: Text(
                                              AppLocalizations.of(
                                                context,
                                              ).deleteItem,
                                            ),
                                          ),
                                        ],
                                      ),
                                );
                                if (!context.mounted) return;
                                if (ok == true) {
                                  await context.read<FoodProvider>().remove(
                                    item.id!,
                                  );
                                }
                              },
                            ),
                          );
                        },
                      ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLeadingImage(String? imagePath, Color fallbackColor) {
    if (imagePath != null && imagePath.isNotEmpty) {
      final file = File(imagePath);
      if (file.existsSync()) {
        return ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: Image.file(file, width: 42, height: 42, fit: BoxFit.cover),
        );
      }
    }
    return Icon(Icons.fastfood, color: fallbackColor);
  }
}
