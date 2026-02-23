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

class _AiMenuPageState extends State<AiMenuPage>
    with SingleTickerProviderStateMixin {
  List<RecipeSuggestion> _suggestions = [];
  bool _isLoading = false;
  String? _error;
  String? _lastGeminiResponse;
  bool _isCancelled = false;

  // 歷史和收藏清單
  List<HistoryRecipe> _favorites = [];
  List<HistoryRecipe> _history = [];
  bool _isLoadingHistory = true;
  bool _isGenerating = false; // 正在生成新食譜

  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(_onTabChanged);
    _loadHistoryAndFavorites();
  }

  @override
  void dispose() {
    _tabController.removeListener(_onTabChanged);
    _tabController.dispose();
    super.dispose();
  }

  void _onTabChanged() {
    // 強制刷新 UI 以更新 AppBar 的 actions
    if (mounted) {
      setState(() {});
    }
  }

  /// 載入歷史紀錄和收藏
  Future<void> _loadHistoryAndFavorites() async {
    setState(() {
      _isLoadingHistory = true;
    });

    try {
      final allHistory = await RecipeHistoryService.instance.getHistory();
      if (mounted) {
        setState(() {
          _favorites = allHistory.where((h) => h.isFavorite).toList();
          _history = allHistory.where((h) => !h.isFavorite).toList();
          _isLoadingHistory = false;
        });
      }
    } catch (e) {
      debugPrint('載入歷史紀錄失敗: $e');
      if (mounted) {
        setState(() {
          _isLoadingHistory = false;
        });
      }
    }
  }

  Future<void> _loadRecipes() async {
    _isCancelled = false;

    if (mounted) {
      setState(() {
        _isLoading = true;
        _isGenerating = true;
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
          _isGenerating = false;
          _lastGeminiResponse =
              '成功處理 ${inv.length} 個食材並生成 ${geminiRecipes.length} 個食譜';
        });

        // 重新載入清單以顯示新生成的食譜
        await _loadHistoryAndFavorites();

        // 顯示成功提示
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('已生成 ${geminiRecipes.length} 個新食譜'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        // 如果智慧推薦失敗，使用備用食譜
        final fallbackRecipes = engine.suggest(inv);

        // 保存備用食譜到歷史紀錄
        await RecipeHistoryService.instance.addRecipes(fallbackRecipes);

        setState(() {
          _suggestions = fallbackRecipes;
          _isLoading = false;
          _isGenerating = false;
          _lastGeminiResponse = '智慧推薦失敗，使用備用食譜';
        });

        // 重新載入清單
        await _loadHistoryAndFavorites();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('已生成 ${fallbackRecipes.length} 個備用食譜'),
              backgroundColor: Colors.orange,
            ),
          );
        }
      }
    } catch (e) {
      // 檢查是否已取消
      if (_isCancelled || !mounted) return;

      // 出錯時使用備用食譜
      final engine = RecipeEngine();
      final fallbackRecipes = engine.suggest(
        context.read<FoodProvider>().items,
      );

      // 保存備用食譜到歷史紀錄
      await RecipeHistoryService.instance.addRecipes(fallbackRecipes);

      setState(() {
        _suggestions = fallbackRecipes;
        _isLoading = false;
        _isGenerating = false;
        // 不顯示錯誤，只記錄日誌並提示使用備用食譜
        _lastGeminiResponse = 'AI 服務暫時無法使用，已為您提供精選食譜';
        _error = null;
      });

      // 重新載入清單
      await _loadHistoryAndFavorites();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('已生成 ${fallbackRecipes.length} 個精選食譜'),
            backgroundColor: Colors.blue,
          ),
        );
      }

      // 記錄錯誤到控制台
      debugPrint('食譜生成錯誤: $e');
    }
  }

  Future<bool> _onWillPop() async {
    // 如果正在生成中，取消生成
    if (_isGenerating) {
      _isCancelled = true;
      setState(() {
        _isGenerating = false;
        _isLoading = false;
      });
      debugPrint('用戶取消食譜生成');
    }
    // 直接允許返回，不顯示確認對話框
    return true;
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: _onWillPop,
      child: Scaffold(
        appBar: AppBar(
          title: Text(AppLocalizations.of(context).aiMenuTitle),
          actions: [
            // 收藏分頁時顯示清空收藏按鈕
            if (_tabController.index == 0 && _favorites.isNotEmpty)
              IconButton(
                icon: const Icon(Icons.delete_sweep),
                tooltip: '清空所有收藏',
                onPressed: _confirmClearFavorites,
              ),
            // 歷史分頁時顯示清空歷史按鈕
            if (_tabController.index == 1 && _history.isNotEmpty)
              IconButton(
                icon: const Icon(Icons.delete_sweep),
                tooltip: '清空所有歷史',
                onPressed: _confirmClearHistory,
              ),
          ],
          bottom: TabBar(
            controller: _tabController,
            tabs: [
              Tab(
                icon: const Icon(Icons.star),
                text: '收藏菜單 (${_favorites.length})',
              ),
              Tab(
                icon: const Icon(Icons.history),
                text: '歷史菜單 (${_history.length})',
              ),
            ],
          ),
        ),
        body: Stack(
          children: [
            _buildListBody(),
            // 生成中的 Loading 覆蓋層
            if (_isGenerating)
              Container(
                color: Colors.black54,
                child: Center(
                  child: Card(
                    elevation: 8,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const CircularProgressIndicator(strokeWidth: 3),
                          const SizedBox(height: 20),
                          const Text(
                            '正在生成新食譜...',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'AI 正在根據您的食材推薦美味料理',
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey[600],
                            ),
                          ),
                          const SizedBox(height: 16),
                          TextButton(
                            onPressed: () {
                              _isCancelled = true;
                              setState(() {
                                _isGenerating = false;
                                _isLoading = false;
                              });
                            },
                            child: const Text('取消'),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
        floatingActionButton: !_isGenerating
            ? FloatingActionButton.extended(
                onPressed: _loadRecipes,
                icon: const Icon(Icons.auto_awesome),
                label: const Text('生成新食譜'),
                backgroundColor: Theme.of(context).colorScheme.primary,
              )
            : null,
        floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
        floatingActionButtonAnimator: const _FadeFabAnimator(),
      ),
    );
  }

  /// 建構清單視圖（收藏和歷史分頁）
  Widget _buildListBody() {
    if (_isLoadingHistory) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('載入中...'),
          ],
        ),
      );
    }

    return TabBarView(
      controller: _tabController,
      children: [
        // 收藏菜單分頁
        _buildFavoritesTab(),
        // 歷史菜單分頁
        _buildHistoryTab(),
      ],
    );
  }

  /// 建構收藏菜單分頁
  Widget _buildFavoritesTab() {
    if (_favorites.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.star_border, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              '尚無收藏菜單',
              style: TextStyle(fontSize: 16, color: Colors.grey[600]),
            ),
            const SizedBox(height: 8),
            Text(
              '點擊食譜上的星號可加入收藏',
              style: TextStyle(fontSize: 12, color: Colors.grey[500]),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadHistoryAndFavorites,
      child: ListView.builder(
        padding: const EdgeInsets.only(bottom: 80),
        itemCount: _favorites.length,
        itemBuilder: (context, index) {
          return _buildHistoryRecipeCard(_favorites[index]);
        },
      ),
    );
  }

  /// 建構歷史菜單分頁
  Widget _buildHistoryTab() {
    if (_history.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.history_outlined, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              '尚無歷史菜單',
              style: TextStyle(fontSize: 16, color: Colors.grey[600]),
            ),
            const SizedBox(height: 8),
            Text(
              '點擊下方按鈕生成新食譜',
              style: TextStyle(fontSize: 12, color: Colors.grey[500]),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadHistoryAndFavorites,
      child: ListView.builder(
        padding: const EdgeInsets.only(bottom: 80),
        itemCount: _history.length,
        itemBuilder: (context, index) {
          return _buildHistoryRecipeCard(_history[index]);
        },
      ),
    );
  }

  /// 建構歷史食譜卡片
  Widget _buildHistoryRecipeCard(HistoryRecipe item) {
    final hasAll = item.recipe.missingItems.isEmpty;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: InkWell(
        onTap: () => _showRecipeDetail(item),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  // 星號按鈕
                  IconButton(
                    icon: Icon(
                      item.isFavorite ? Icons.star : Icons.star_border,
                      color: item.isFavorite ? Colors.amber : Colors.grey,
                      size: 28,
                    ),
                    onPressed: () => _toggleFavorite(item),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                  const SizedBox(width: 12),

                  // 標題和資訊
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.recipe.title,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(
                              Icons.access_time,
                              size: 14,
                              color: Colors.grey[600],
                            ),
                            const SizedBox(width: 4),
                            Text(
                              _formatDate(item.createdAt),
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[600],
                              ),
                            ),
                            if (item.recipe.cookingTime != null) ...[
                              const SizedBox(width: 12),
                              Icon(
                                Icons.timer,
                                size: 14,
                                color: Colors.grey[600],
                              ),
                              const SizedBox(width: 4),
                              Text(
                                item.recipe.cookingTime!,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey[600],
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),

                  // 材料狀態
                  Column(
                    children: [
                      Chip(
                        label: Text(
                          hasAll ? '材料齊全' : '缺 ${item.recipe.missingItems.length} 項',
                          style: const TextStyle(fontSize: 11),
                        ),
                        backgroundColor:
                            hasAll ? Colors.green[100] : Colors.orange[100],
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      if (item.recipe.difficulty != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: _getDifficultyColor(item.recipe.difficulty!),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              item.recipe.difficulty!,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),

                  // 刪除按鈕
                  IconButton(
                    icon: Icon(Icons.delete_outline, color: Colors.grey[600]),
                    onPressed: () => _confirmDelete(item),
                    padding: const EdgeInsets.only(left: 8),
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 切換收藏狀態
  Future<void> _toggleFavorite(HistoryRecipe item) async {
    await RecipeHistoryService.instance.toggleFavorite(item.id);
    await _loadHistoryAndFavorites();
  }

  /// 確認刪除
  Future<void> _confirmDelete(HistoryRecipe item) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('確認刪除'),
        content: Text('確定要刪除「${item.recipe.title}」嗎？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('刪除'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      await RecipeHistoryService.instance.removeRecipe(item.id);
      await _loadHistoryAndFavorites();
    }
  }

  /// 確認清空所有收藏
  Future<void> _confirmClearFavorites() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 28),
            const SizedBox(width: 8),
            const Text('清空收藏'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('確定要清空所有 ${_favorites.length} 個收藏菜單嗎？'),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.orange.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.orange[700], size: 20),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      '此操作無法復原，收藏的菜單將被永久刪除',
                      style: TextStyle(fontSize: 13),
                    ),
                  ),
                ],
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
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('確認清空'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      // 只刪除收藏的項目
      for (final item in _favorites) {
        await RecipeHistoryService.instance.removeRecipe(item.id);
      }
      await _loadHistoryAndFavorites();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('已清空所有收藏菜單'),
            backgroundColor: Colors.green,
          ),
        );
      }
    }
  }

  /// 確認清空所有歷史
  Future<void> _confirmClearHistory() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 28),
            const SizedBox(width: 8),
            const Text('清空歷史'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('確定要清空所有 ${_history.length} 個歷史菜單嗎？'),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.orange.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.orange[700], size: 20),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      '此操作無法復原，歷史菜單將被永久刪除\n（收藏的菜單不會被刪除）',
                      style: TextStyle(fontSize: 13),
                    ),
                  ),
                ],
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
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('確認清空'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      // 只刪除非收藏的項目（歷史）
      for (final item in _history) {
        await RecipeHistoryService.instance.removeRecipe(item.id);
      }
      await _loadHistoryAndFavorites();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('已清空所有歷史菜單'),
            backgroundColor: Colors.green,
          ),
        );
      }
    }
  }

  /// 顯示食譜詳情
  Future<void> _showRecipeDetail(HistoryRecipe item) async {
    await showDialog(
      context: context,
      builder: (context) => _RecipeDetailDialog(item: item),
    );
  }

  /// 格式化日期
  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);

    if (diff.inDays == 0) {
      if (diff.inHours == 0) {
        if (diff.inMinutes == 0) {
          return '剛剛';
        }
        return '${diff.inMinutes} 分鐘前';
      }
      return '${diff.inHours} 小時前';
    } else if (diff.inDays == 1) {
      return '昨天';
    } else if (diff.inDays < 7) {
      return '${diff.inDays} 天前';
    } else {
      return '${date.year}/${date.month}/${date.day}';
    }
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

/// 食譜詳情對話框
class _RecipeDetailDialog extends StatelessWidget {
  final HistoryRecipe item;

  const _RecipeDetailDialog({required this.item});

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Container(
        width: MediaQuery.of(context).size.width * 0.9,
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.8,
        ),
        padding: const EdgeInsets.all(16),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // 標題列
              Row(
                children: [
                  Expanded(
                    child: Text(
                      item.recipe.title,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const Divider(),

              // 資訊行
              if (item.recipe.cookingTime != null ||
                  item.recipe.difficulty != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Row(
                    children: [
                      if (item.recipe.cookingTime != null) ...[
                        const Icon(Icons.access_time, size: 18),
                        const SizedBox(width: 4),
                        Text(item.recipe.cookingTime!),
                        const SizedBox(width: 16),
                      ],
                      if (item.recipe.difficulty != null)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: _getDifficultyColor(item.recipe.difficulty!),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            item.recipe.difficulty!,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),

              // 烹飪步驟
              const Text(
                '烹飪步驟：',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              ...item.recipe.steps.map(
                (step) => Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Text(step, style: const TextStyle(fontSize: 14)),
                ),
              ),

              const SizedBox(height: 16),

              // 所需材料
              const Text(
                '所需材料：',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              ...item.recipe.requiredItems.entries.map(
                (e) {
                  final isMissing = item.recipe.missingItems.containsKey(e.key);
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Row(
                      children: [
                        Icon(
                          isMissing
                              ? Icons.cancel_outlined
                              : Icons.check_circle,
                          size: 18,
                          color: isMissing ? Colors.orange : Colors.green,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            e.value,
                            style: TextStyle(
                              fontSize: 14,
                              color: isMissing ? Colors.orange[800] : null,
                            ),
                          ),
                        ),
                        if (isMissing)
                          Text(
                            '缺少',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.orange[700],
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                      ],
                    ),
                  );
                },
              ),

              const SizedBox(height: 16),

              // 加入購物清單按鈕
              if (item.recipe.missingItems.isNotEmpty)
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () async {
                      final shoppingProvider = context.read<ShoppingProvider>();
                      try {
                        for (final e in item.recipe.missingItems.entries) {
                          await shoppingProvider.add(e.key, amount: e.value);
                        }
                        if (context.mounted) {
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                '已加入 ${item.recipe.missingItems.length} 項到購物清單',
                              ),
                            ),
                          );
                        }
                      } catch (e) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('加入購物清單失敗: $e'),
                              backgroundColor: Colors.red,
                            ),
                          );
                        }
                      }
                    },
                    icon: const Icon(Icons.add_shopping_cart),
                    label: Text('將 ${item.recipe.missingItems.length} 項缺料加入購物清單'),
                  ),
                ),
            ],
          ),
        ),
      ),
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
        return Colors.grey;
    }
  }
}

/// 淡入淡出動畫器（按鈕直接在目標位置淡入淡出）
class _FadeFabAnimator extends FloatingActionButtonAnimator {
  const _FadeFabAnimator();

  @override
  Offset getOffset({
    required Offset begin,
    required Offset end,
    required double progress,
  }) {
    // 直接跳到目標位置，不做位置動畫
    return end;
  }

  @override
  Animation<double> getScaleAnimation({required Animation<double> parent}) {
    // 使用淡入淡出效果（透過縮放從0到1）
    return CurvedAnimation(
      parent: parent,
      curve: Curves.easeInOut,
    );
  }

  @override
  Animation<double> getRotationAnimation({required Animation<double> parent}) {
    // 旋轉效果
    return CurvedAnimation(
      parent: parent,
      curve: Curves.easeInOut,
    );
  }
}
