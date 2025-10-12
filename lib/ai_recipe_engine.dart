import 'dart:async';
import 'package:flutter/foundation.dart';
import 'models.dart';
import 'integrated_recipe_service.dart';

class RecipeSuggestion {
  final String title;
  final String? originalTitle; // 原始英文標題
  final List<String> steps;
  final Map<String, String> requiredItems; // name -> amount
  final Map<String, String> missingItems; // name -> amount
  final String? cookingTime;
  final String? difficulty;

  RecipeSuggestion({
    required this.title,
    this.originalTitle,
    required this.steps,
    required this.requiredItems,
    required this.missingItems,
    this.cookingTime,
    this.difficulty,
  });
}

class RecipeEngine {
  // 簡易本地知識庫（作為備用）
  static final List<Map<String, dynamic>> _fallbackRecipes = [
    {
      'title': '奶油香蕉優格杯',
      'requires': {'鮮乳優格': '200g', '香蕉': '1根', '蜂蜜': '1湯匙', '堅果': '少許'},
      'steps': ['香蕉切片', '杯中放入優格與香蕉', '淋上蜂蜜灑堅果即可'],
      'cookingTime': '5分鐘',
      'difficulty': '簡單',
    },
    {
      'title': '提拉米蘇聖代',
      'requires': {'提拉米蘇': '1份', '鮮乳優格': '150g', '可可粉': '少許'},
      'steps': ['杯中先放優格', '加入切塊提拉米蘇', '灑上可可粉'],
      'cookingTime': '3分鐘',
      'difficulty': '簡單',
    },
    {
      'title': '布丁牛奶冰沙',
      'requires': {'統一布丁': '1個', '鮮乳優格': '100g', '冰塊': '數顆'},
      'steps': ['全部放入果汁機', '打至綿密即可'],
      'cookingTime': '2分鐘',
      'difficulty': '簡單',
    },
  ];

  // 使用整合食譜服務
  Future<List<RecipeSuggestion>> suggestWithGemini(
    List<FoodItem> inventory,
  ) async {
    try {
      debugPrint('使用整合食譜服務，食材數量: ${inventory.length}');

      // 使用新的整合食譜服務
      final suggestions = await IntegratedRecipeService.instance
          .generateRecipeSuggestions(inventory: inventory, numberOfRecipes: 10);

      if (suggestions.isNotEmpty) {
        debugPrint('成功獲得 ${suggestions.length} 個食譜推薦');
        return suggestions;
      } else {
        debugPrint('整合食譜服務返回空清單，改用備用食譜');
      }
    } catch (e) {
      debugPrint('整合食譜服務失敗，改用備用食譜: $e');
    }

    // 如果整合服務失敗，使用備用食譜
    debugPrint('使用備用食譜');
    return _getFallbackRecipes(inventory);
  }

  // 同步版本，使用備用食譜
  List<RecipeSuggestion> suggest(List<FoodItem> inventory) {
    return _getFallbackRecipes(inventory);
  }

  // 備用食譜邏輯
  List<RecipeSuggestion> _getFallbackRecipes(List<FoodItem> inventory) {
    final invNames = inventory.map((e) => e.name).toList();
    final suggestions = <RecipeSuggestion>[];

    for (final r in _fallbackRecipes) {
      final req = Map<String, String>.from(r['requires'] as Map);
      final missing = <String, String>{};

      req.forEach((name, amount) {
        final match = invNames.firstWhere(
          (n) => n.contains(name),
          orElse: () => '',
        );
        if (match.isEmpty) missing[name] = amount;
      });

      suggestions.add(
        RecipeSuggestion(
          title: r['title'] as String,
          steps: List<String>.from(r['steps'] as List),
          requiredItems: req,
          missingItems: missing,
          cookingTime: r['cookingTime'] as String?,
          difficulty: r['difficulty'] as String?,
        ),
      );
    }

    // 智慧排序：優先考慮即將到期食材，並且缺料少的食譜優先
    suggestions.sort((a, b) {
      // 首先比較缺料數量
      final missingComparison = a.missingItems.length.compareTo(
        b.missingItems.length,
      );
      if (missingComparison != 0) return missingComparison;

      // 如果缺料數量相同，優先選擇使用即將到期食材的食譜
      final aUsesExpiring = _recipeUsesExpiringIngredients(a, inventory);
      final bUsesExpiring = _recipeUsesExpiringIngredients(b, inventory);

      if (aUsesExpiring && !bUsesExpiring) return -1;
      if (!aUsesExpiring && bUsesExpiring) return 1;

      return 0;
    });
    return suggestions;
  }

  // 檢查食譜是否使用了即將到期的食材
  bool _recipeUsesExpiringIngredients(
    RecipeSuggestion recipe,
    List<FoodItem> inventory,
  ) {
    final now = DateTime.now();

    for (final item in inventory) {
      final daysUntilExpiry = item.expiryDate.difference(now).inDays;

      // 如果食材即將到期（3天內）
      if (daysUntilExpiry <= 3 && daysUntilExpiry >= 0) {
        // 檢查食譜是否使用了這個食材
        if (recipe.requiredItems.containsKey(item.name)) {
          return true;
        }
      }
    }

    return false;
  }

  // 獲取特定食材的食譜建議
  Future<List<RecipeSuggestion>> suggestRecipesForIngredient(
    String ingredient,
  ) async {
    try {
      // 創建假的食物項目列表，只包含這個食材
      final mockInventory = [
        FoodItem(
          name: ingredient,
          quantity: 1,
          unit: '份',
          expiryDate: DateTime.now().add(const Duration(days: 7)),
          category: FoodCategory.other,
        ),
      ];

      return await suggestWithGemini(mockInventory);
    } catch (e) {
      debugPrint('獲取食材食譜建議失敗: $e');
      return [];
    }
  }
}
