import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'ai_recipe_engine.dart';
import 'providers.dart';
import 'repositories.dart';
import 'models.dart';

class AiMenuPage extends StatelessWidget {
  const AiMenuPage({super.key});

  @override
  Widget build(BuildContext context) {
    final inv = context.watch<FoodProvider>().items;
    final engine = RecipeEngine();
    final suggestions = engine.suggest(inv);
    return Scaffold(
      appBar: AppBar(
        title: Text('AI 菜單推薦'),
      ),
      body: ListView.builder(
        itemCount: suggestions.length,
        itemBuilder: (context, index) {
          final s = suggestions[index];
          final hasAll = s.missingItems.isEmpty;
          return Card(
            margin: const EdgeInsets.all(12),
            child: Padding(
              padding: const EdgeInsets.all(12.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(s.title, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      ),
                      Chip(
                        label: Text(hasAll ? '材料齊全' : '缺少 ${s.missingItems.length} 項'),
                        backgroundColor: hasAll ? Colors.green[100] : Colors.orange[100],
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text('步驟：'),
                  ...s.steps.map((e) => Text('• $e')),
                  const SizedBox(height: 8),
                  Text('所需材料：'),
                  ...s.requiredItems.entries.map((e) => Text('- ${e.key}：${e.value}')),
                  if (!hasAll) ...[
                    const SizedBox(height: 8),
                    Text('缺少材料：', style: TextStyle(color: Colors.orange[800])),
                    ...s.missingItems.entries.map((e) => Text('- ${e.key}：${e.value}')),
                  ],
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerRight,
                    child: ElevatedButton.icon(
                      onPressed: () async {
                        final repo = ShoppingRepository();
                        for (final e in s.missingItems.entries) {
                          await repo.insert(
                            // 直接寫入購物清單
                            // 若重複項目，後續可改為 merge 策略
                            ShoppingItem(name: e.key, amount: e.value),
                          );
                        }
                        if (!context.mounted) return;
                        await context.read<ShoppingProvider>().refresh();
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('已加入 ${s.missingItems.length} 項到購物清單')),
                        );
                      },
                      icon: Icon(Icons.add_shopping_cart),
                      label: Text('缺料加入購物清單'),
                    ),
                  )
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}


