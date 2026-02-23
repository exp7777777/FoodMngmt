import 'package:flutter/material.dart';
import 'recipe_history_service.dart';

/// 歷史紀錄對話框
class HistoryDialog extends StatefulWidget {
  final List<HistoryRecipe> history;

  const HistoryDialog({super.key, required this.history});

  @override
  State<HistoryDialog> createState() => _HistoryDialogState();
}

class _HistoryDialogState extends State<HistoryDialog> {
  late List<HistoryRecipe> _history;

  @override
  void initState() {
    super.initState();
    _history = List.from(widget.history);
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Container(
        width: MediaQuery.of(context).size.width * 0.9,
        height: MediaQuery.of(context).size.height * 0.8,
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // 標題列
            Row(
              children: [
                const Icon(Icons.history, size: 28),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    '歷史紀錄',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                ),
                if (_history.isNotEmpty)
                  TextButton.icon(
                    onPressed: _confirmClearAll,
                    icon: const Icon(Icons.delete_sweep, size: 20),
                    label: const Text('清空'),
                    style: TextButton.styleFrom(foregroundColor: Colors.red),
                  ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const Divider(),

            // 歷史列表
            Expanded(
              child:
                  _history.isEmpty
                      ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.history_outlined,
                              size: 64,
                              color: Colors.grey[400],
                            ),
                            const SizedBox(height: 16),
                            Text(
                              '尚無歷史紀錄',
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      )
                      : ListView.builder(
                        itemCount: _history.length,
                        itemBuilder: (context, index) {
                          final item = _history[index];
                          return _buildHistoryItem(item);
                        },
                      ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHistoryItem(HistoryRecipe item) {
    final hasAll = item.recipe.missingItems.isEmpty;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: () => _showRecipeDetail(item),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
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

              // 食譜資訊
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.recipe.title,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(
                          Icons.access_time,
                          size: 12,
                          color: Colors.grey[600],
                        ),
                        const SizedBox(width: 4),
                        Text(
                          _formatDate(item.createdAt),
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey[600],
                          ),
                        ),
                        if (item.recipe.cookingTime != null) ...[
                          const SizedBox(width: 12),
                          Icon(Icons.timer, size: 12, color: Colors.grey[600]),
                          const SizedBox(width: 4),
                          Text(
                            item.recipe.cookingTime!,
                            style: TextStyle(
                              fontSize: 11,
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
              Chip(
                label: Text(
                  hasAll ? '齊全' : '缺${item.recipe.missingItems.length}',
                  style: const TextStyle(fontSize: 11),
                ),
                backgroundColor:
                    hasAll ? Colors.green[100] : Colors.orange[100],
                padding: const EdgeInsets.symmetric(horizontal: 4),
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              const SizedBox(width: 8),

              // 刪除按鈕
              IconButton(
                icon: const Icon(Icons.delete_outline, size: 22),
                onPressed: () => _confirmDelete(item),
                color: Colors.grey[600],
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 切換星號
  Future<void> _toggleFavorite(HistoryRecipe item) async {
    await RecipeHistoryService.instance.toggleFavorite(item.id);

    final updatedHistory = await RecipeHistoryService.instance.getHistory();

    if (mounted) {
      setState(() {
        _history = updatedHistory;
      });
    }
  }

  /// 確認刪除
  Future<void> _confirmDelete(HistoryRecipe item) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
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

      final updatedHistory = await RecipeHistoryService.instance.getHistory();

      if (mounted) {
        setState(() {
          _history = updatedHistory;
        });
      }
    }
  }

  /// 確認清空所有
  Future<void> _confirmClearAll() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('確認清空'),
            content: Text('確定要清空所有 ${_history.length} 筆歷史紀錄嗎？'),
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
                child: const Text('清空'),
              ),
            ],
          ),
    );

    if (confirmed == true && mounted) {
      await RecipeHistoryService.instance.clearAll();

      if (mounted) {
        setState(() {
          _history = [];
        });
      }
    }
  }

  /// 顯示食譜詳情
  Future<void> _showRecipeDetail(HistoryRecipe item) async {
    await showDialog(
      context: context,
      builder:
          (context) => Dialog(
            child: Container(
              width: MediaQuery.of(context).size.width * 0.9,
              height: MediaQuery.of(context).size.height * 0.8,
              padding: const EdgeInsets.all(16),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 標題
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

                    // 資訊
                    if (item.recipe.cookingTime != null ||
                        item.recipe.difficulty != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: Row(
                          children: [
                            if (item.recipe.cookingTime != null) ...[
                              const Icon(Icons.access_time, size: 16),
                              const SizedBox(width: 4),
                              Text(item.recipe.cookingTime!),
                              const SizedBox(width: 16),
                            ],
                            if (item.recipe.difficulty != null)
                              Chip(
                                label: Text(item.recipe.difficulty!),
                                backgroundColor: _getDifficultyColor(
                                  item.recipe.difficulty!,
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
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Text(step),
                      ),
                    ),

                    const SizedBox(height: 16),

                    // 所需材料（區分已有/缺少）
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
                        final isMissing =
                            item.recipe.missingItems.containsKey(e.key);
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: Row(
                            children: [
                              Icon(
                                isMissing
                                    ? Icons.cancel_outlined
                                    : Icons.check_circle,
                                size: 16,
                                color: isMissing ? Colors.orange : Colors.green,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  e.value,
                                  style: TextStyle(
                                    color: isMissing ? Colors.orange : null,
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
                  ],
                ),
              ),
            ),
          ),
    );
  }

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
        return Colors.grey;
    }
  }
}
