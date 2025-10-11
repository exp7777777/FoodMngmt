import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'ai_recipe_engine.dart';
import 'providers.dart';
import 'localization.dart';

class AiMenuPage extends StatefulWidget {
  const AiMenuPage({super.key});

  @override
  State<AiMenuPage> createState() => _AiMenuPageState();
}

class _AiMenuPageState extends State<AiMenuPage> {
  List<RecipeSuggestion> _suggestions = [];
  bool _isLoading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadRecipes();
  }

  Future<void> _loadRecipes() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final inv = context.read<FoodProvider>().items;
      final engine = RecipeEngine();

      // 嘗試使用 Gemini API 生成智慧食譜
      final geminiRecipes = await engine.suggestWithGemini(inv);

      if (geminiRecipes.isNotEmpty) {
        setState(() {
          _suggestions = geminiRecipes;
          _isLoading = false;
        });
      } else {
        // 如果 Gemini API 沒有回應，使用備用食譜
        final fallbackRecipes = engine.suggest(inv);
        setState(() {
          _suggestions = fallbackRecipes;
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _error = '無法載入食譜建議: $e';
        _isLoading = false;
      });

      // 出錯時使用備用食譜
      final engine = RecipeEngine();
      final fallbackRecipes = engine.suggest(
        context.read<FoodProvider>().items,
      );
      setState(() {
        _suggestions = fallbackRecipes;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.of(context).aiMenuTitle),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadRecipes,
            tooltip: '重新生成食譜',
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('正在生成智慧食譜...'),
          ],
        ),
      );
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64, color: Colors.red),
            const SizedBox(height: 16),
            Text(_error!, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            ElevatedButton(onPressed: _loadRecipes, child: const Text('重試')),
          ],
        ),
      );
    }

    if (_suggestions.isEmpty) {
      return const Center(child: Text('沒有可用的食譜建議'));
    }

    return ListView.builder(
      itemCount: _suggestions.length,
      itemBuilder: (context, index) {
        final s = _suggestions[index];
        final hasAll = s.missingItems.isEmpty;
        return Card(
          margin: const EdgeInsets.all(12),
          child: Padding(
            padding: const EdgeInsets.all(12.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 食譜標題和狀態
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        s.title,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    if (s.difficulty != null)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: _getDifficultyColor(s.difficulty!),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          s.difficulty!,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                          ),
                        ),
                      ),
                  ],
                ),

                // 烹飪時間
                if (s.cookingTime != null) ...[
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Icons.access_time, size: 16, color: Colors.grey),
                      const SizedBox(width: 4),
                      Text(
                        s.cookingTime!,
                        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                      ),
                    ],
                  ),
                ],

                // 材料狀態
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        hasAll ? '材料齊全' : '缺少 ${s.missingItems.length} 項',
                        style: TextStyle(
                          color: hasAll ? Colors.green : Colors.orange,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    Chip(
                      label: Text(
                        hasAll ? '材料齊全' : '缺少 ${s.missingItems.length} 項',
                      ),
                      backgroundColor:
                          hasAll ? Colors.green[100] : Colors.orange[100],
                    ),
                  ],
                ),

                // 烹飪步驟
                const SizedBox(height: 12),
                Text(
                  '烹飪步驟：',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[700],
                  ),
                ),
                const SizedBox(height: 4),
                ...s.steps.asMap().entries.map(
                  (entry) => Padding(
                    padding: const EdgeInsets.only(bottom: 2),
                    child: Text(
                      '${entry.key + 1}. ${entry.value}',
                      style: const TextStyle(fontSize: 14),
                    ),
                  ),
                ),

                // 所需材料
                const SizedBox(height: 12),
                Text(
                  '所需材料：',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[700],
                  ),
                ),
                const SizedBox(height: 4),
                ...s.requiredItems.entries.map(
                  (e) => Padding(
                    padding: const EdgeInsets.only(bottom: 2),
                    child: Row(
                      children: [
                        Icon(Icons.check_circle, size: 14, color: Colors.green),
                        const SizedBox(width: 4),
                        Text(
                          '${e.key}：${e.value}',
                          style: const TextStyle(fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                ),

                // 缺少的材料
                if (!hasAll) ...[
                  const SizedBox(height: 12),
                  Text(
                    '缺少的材料：',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.orange[800],
                    ),
                  ),
                  const SizedBox(height: 4),
                  ...s.missingItems.entries.map(
                    (e) => Padding(
                      padding: const EdgeInsets.only(bottom: 2),
                      child: Row(
                        children: [
                          Icon(
                            Icons.error_outline,
                            size: 14,
                            color: Colors.orange,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '${e.key}：${e.value}',
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.orange[800],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],

                // 操作按鈕
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerRight,
                  child: ElevatedButton.icon(
                    onPressed:
                        hasAll
                            ? null
                            : () async {
                              for (final e in s.missingItems.entries) {
                                await context.read<ShoppingProvider>().add(
                                  e.key,
                                  amount: e.value,
                                );
                              }
                              if (!context.mounted) return;
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    '已加入 ${s.missingItems.length} 項到購物清單',
                                  ),
                                ),
                              );
                            },
                    icon: const Icon(Icons.add_shopping_cart),
                    label: Text(hasAll ? '材料已齊全' : '缺料加入購物清單'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: hasAll ? Colors.grey : null,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Color _getDifficultyColor(String difficulty) {
    switch (difficulty) {
      case '簡單':
        return Colors.green;
      case '中等':
        return Colors.orange;
      case '困難':
        return Colors.red;
      default:
        return Colors.blue;
    }
  }
}
