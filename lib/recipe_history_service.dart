import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'ai_recipe_engine.dart';

/// 歷史食譜項目
class HistoryRecipe {
  final String id;
  final RecipeSuggestion recipe;
  final DateTime createdAt;
  bool isFavorite;

  HistoryRecipe({
    required this.id,
    required this.recipe,
    required this.createdAt,
    this.isFavorite = false,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': recipe.title,
      'originalTitle': recipe.originalTitle,
      'steps': recipe.steps,
      'requiredItems': recipe.requiredItems,
      'missingItems': recipe.missingItems,
      'cookingTime': recipe.cookingTime,
      'difficulty': recipe.difficulty,
      'createdAt': createdAt.toIso8601String(),
      'isFavorite': isFavorite,
    };
  }

  factory HistoryRecipe.fromJson(Map<String, dynamic> json) {
    return HistoryRecipe(
      id: json['id'] as String,
      recipe: RecipeSuggestion(
        title: json['title'] as String,
        originalTitle: json['originalTitle'] as String?,
        steps: List<String>.from(json['steps'] as List),
        requiredItems: Map<String, String>.from(json['requiredItems'] as Map),
        missingItems: Map<String, String>.from(json['missingItems'] as Map),
        cookingTime: json['cookingTime'] as String?,
        difficulty: json['difficulty'] as String?,
      ),
      createdAt: DateTime.parse(json['createdAt'] as String),
      isFavorite: json['isFavorite'] as bool? ?? false,
    );
  }
}

/// 食譜歷史紀錄服務
class RecipeHistoryService {
  static RecipeHistoryService? _instance;
  static RecipeHistoryService get instance {
    _instance ??= RecipeHistoryService._();
    return _instance!;
  }

  RecipeHistoryService._();

  static const String _storageKey = 'recipe_history';
  static const int _maxHistoryCount = 100; // 最多保存 100 筆歷史

  List<HistoryRecipe> _history = [];
  bool _isLoaded = false;

  /// 載入歷史紀錄
  Future<void> _loadHistory() async {
    if (_isLoaded) return;

    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonString = prefs.getString(_storageKey);

      if (jsonString != null) {
        final List<dynamic> jsonList = json.decode(jsonString);
        _history =
            jsonList
                .map(
                  (json) =>
                      HistoryRecipe.fromJson(json as Map<String, dynamic>),
                )
                .toList();

        debugPrint('載入 ${_history.length} 筆食譜歷史紀錄');
      }

      _isLoaded = true;
    } catch (e) {
      debugPrint('載入歷史紀錄失敗: $e');
      _history = [];
      _isLoaded = true;
    }
  }

  /// 儲存歷史紀錄
  Future<void> _saveHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonList = _history.map((h) => h.toJson()).toList();
      await prefs.setString(_storageKey, json.encode(jsonList));
      debugPrint('儲存 ${_history.length} 筆食譜歷史紀錄');
    } catch (e) {
      debugPrint('儲存歷史紀錄失敗: $e');
    }
  }

  /// 新增食譜到歷史紀錄
  Future<void> addRecipe(RecipeSuggestion recipe) async {
    await _loadHistory();

    final id = '${DateTime.now().millisecondsSinceEpoch}_${recipe.title}';
    final historyRecipe = HistoryRecipe(
      id: id,
      recipe: recipe,
      createdAt: DateTime.now(),
    );

    _history.insert(0, historyRecipe);

    // 限制歷史數量
    if (_history.length > _maxHistoryCount) {
      _history = _history.take(_maxHistoryCount).toList();
    }

    await _saveHistory();
  }

  /// 批量新增食譜
  Future<void> addRecipes(List<RecipeSuggestion> recipes) async {
    await _loadHistory();

    final now = DateTime.now();
    for (int i = 0; i < recipes.length; i++) {
      final id = '${now.millisecondsSinceEpoch + i}_${recipes[i].title}';
      final historyRecipe = HistoryRecipe(
        id: id,
        recipe: recipes[i],
        createdAt: now,
      );
      _history.insert(0, historyRecipe);
    }

    // 限制歷史數量
    if (_history.length > _maxHistoryCount) {
      _history = _history.take(_maxHistoryCount).toList();
    }

    await _saveHistory();
  }

  /// 取得所有歷史紀錄（星號置頂）
  Future<List<HistoryRecipe>> getHistory() async {
    await _loadHistory();

    // 星號食譜在前，其他按時間排序
    final favorites = _history.where((h) => h.isFavorite).toList();
    final others = _history.where((h) => !h.isFavorite).toList();

    return [...favorites, ...others];
  }

  /// 切換星號狀態
  Future<void> toggleFavorite(String id) async {
    await _loadHistory();

    final index = _history.indexWhere((h) => h.id == id);
    if (index != -1) {
      _history[index].isFavorite = !_history[index].isFavorite;
      await _saveHistory();
    }
  }

  /// 移除食譜
  Future<void> removeRecipe(String id) async {
    await _loadHistory();

    _history.removeWhere((h) => h.id == id);
    await _saveHistory();
  }

  /// 清空所有歷史紀錄
  Future<void> clearAll() async {
    await _loadHistory();
    _history.clear();
    await _saveHistory();
  }

  /// 取得歷史紀錄數量
  Future<int> getCount() async {
    await _loadHistory();
    return _history.length;
  }
}
