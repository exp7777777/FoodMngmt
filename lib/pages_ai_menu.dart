import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'ai_recipe_engine.dart';
import 'providers.dart';
import 'localization.dart';
import 'recipe_history_service.dart';
import 'recipe_history_dialog.dart';

class AiMenuPage extends StatefulWidget {
  const AiMenuPage({super.key});

  @override
  State<AiMenuPage> createState() => _AiMenuPageState();
}

class _AiMenuPageState extends State<AiMenuPage> {
  List<RecipeSuggestion> _suggestions = [];
  bool _isLoading = false;
  String? _error;
  String? _lastGeminiResponse;
  bool _isCancelled = false;

  @override
  void initState() {
    super.initState();
    _loadRecipes();
  }

  Future<void> _loadRecipes() async {
    _isCancelled = false;

    if (mounted) {
      setState(() {
        _isLoading = true;
        _error = null;
        _lastGeminiResponse = null;
      });
    }

    try {
      final inv = context.read<FoodProvider>().items;

      // 使用智慧食譜推薦服務
      final engine = RecipeEngine();
      final geminiRecipes = await engine.suggestWithGemini(inv);

      // 檢查是否已取消
      if (_isCancelled || !mounted) return;

      if (geminiRecipes.isNotEmpty) {
        // 保存到歷史紀錄
        await RecipeHistoryService.instance.addRecipes(geminiRecipes);

        setState(() {
          _suggestions = geminiRecipes;
          _isLoading = false;
          _lastGeminiResponse =
              '成功處理 ${inv.length} 個食材並生成 ${geminiRecipes.length} 個食譜';
        });
      } else {
        // 如果智慧推薦失敗，使用備用食譜
        final fallbackRecipes = engine.suggest(inv);
        setState(() {
          _suggestions = fallbackRecipes;
          _isLoading = false;
          _lastGeminiResponse = '智慧推薦失敗，使用備用食譜';
        });
      }
    } catch (e) {
      // 檢查是否已取消
      if (_isCancelled || !mounted) return;

      // 出錯時使用備用食譜
      final engine = RecipeEngine();
      final fallbackRecipes = engine.suggest(
        context.read<FoodProvider>().items,
      );
      setState(() {
        _suggestions = fallbackRecipes;
        _isLoading = false;
        // 不顯示錯誤，只記錄日誌並提示使用備用食譜
        _lastGeminiResponse = 'AI 服務暫時無法使用，已為您提供精選食譜';
        _error = null;
      });

      // 記錄錯誤到控制台
      debugPrint('食譜生成錯誤: $e');
    }
  }

  Future<bool> _onWillPop() async {
    // 顯示確認對話框
    final shouldPop = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('確認退出'),
            content: Text(_isLoading ? '食譜正在生成中，確定要離開嗎？' : '確定要離開剩食譜頁面嗎？'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('否'),
              ),
              TextButton(
                onPressed: () {
                  // 如果正在生成中，標記為已取消
                  if (_isLoading) {
                    _isCancelled = true;
                    debugPrint('用戶取消食譜生成');
                  }
                  Navigator.of(context).pop(true);
                },
                child: const Text('是'),
              ),
            ],
          ),
    );

    return shouldPop ?? false;
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: _onWillPop,
      child: Scaffold(
        appBar: AppBar(
          title: Text(AppLocalizations.of(context).aiMenuTitle),
          actions: [
            IconButton(
              icon: const Icon(Icons.history),
              onPressed: () => _showHistory(context),
              tooltip: '歷史紀錄',
            ),
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: _loadRecipes,
              tooltip: '重新生成食譜',
            ),
          ],
        ),
        body: _buildBody(),
      ),
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
            Text('正在生成剩食譜...'),
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
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.restaurant_menu, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            const Text('沒有可用的食譜建議'),
            const SizedBox(height: 8),
            if (_lastGeminiResponse != null)
              Text(
                'Gemini: $_lastGeminiResponse',
                style: TextStyle(color: Colors.grey[600], fontSize: 12),
              ),
          ],
        ),
      );
    }

    return Column(
      children: [
        // 食譜清單
        Expanded(
          child: ListView.builder(
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
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
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
                          // 顯示原始英文標題（如果有）
                          if (s.originalTitle != null &&
                              s.originalTitle != s.title)
                            Padding(
                              padding: const EdgeInsets.only(top: 2),
                              child: Text(
                                'Original: ${s.originalTitle}',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey[600],
                                  fontStyle: FontStyle.italic,
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
                            Icon(
                              Icons.access_time,
                              size: 16,
                              color: Colors.grey,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              s.cookingTime!,
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[600],
                              ),
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
                      ...s.steps.map(
                        (step) => Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: Text(
                            step,
                            style: const TextStyle(fontSize: 14),
                          ),
                        ),
                      ),

                      // 所需材料（區分已有/缺少）
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
                        (e) {
                          final isMissing = s.missingItems.containsKey(e.key);
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 2),
                            child: Row(
                              children: [
                                Icon(
                                  isMissing
                                      ? Icons.cancel_outlined
                                      : Icons.check_circle,
                                  size: 14,
                                  color:
                                      isMissing ? Colors.orange : Colors.green,
                                ),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Text(
                                    e.value,
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: isMissing
                                          ? Colors.orange[800]
                                          : null,
                                    ),
                                  ),
                                ),
                                if (isMissing)
                                  Text(
                                    '缺少',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: Colors.orange[700],
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                              ],
                            ),
                          );
                        },
                      ),

                      // 操作按鈕
                      const SizedBox(height: 12),
                      Align(
                        alignment: Alignment.centerRight,
                        child: ElevatedButton.icon(
                          onPressed:
                              hasAll
                                  ? null
                                  : () async {
                                    // 防止重複點擊
                                    final shoppingProvider =
                                        context.read<ShoppingProvider>();
                                    if (shoppingProvider.isLoading) return;

                                    try {
                                      for (final e in s.missingItems.entries) {
                                        await shoppingProvider.add(
                                          e.key,
                                          amount: e.value,
                                        );
                                      }
                                      if (!context.mounted) return;
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        SnackBar(
                                          content: Text(
                                            '已加入 ${s.missingItems.length} 項到購物清單',
                                          ),
                                        ),
                                      );
                                    } catch (e) {
                                      if (!context.mounted) return;
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        SnackBar(
                                          content: Text('加入購物清單失敗: $e'),
                                          backgroundColor: Colors.red,
                                        ),
                                      );
                                    }
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
          ),
        ),
      ],
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

  /// 顯示歷史紀錄對話框
  Future<void> _showHistory(BuildContext context) async {
    final history = await RecipeHistoryService.instance.getHistory();

    if (!mounted) return;

    if (context.mounted) {
      await showDialog(
        context: context,
        builder: (context) => HistoryDialog(history: history),
      );
    }
  }
}
