import 'dart:async';
import 'models.dart';
import 'gemini_service.dart';

class RecipeSuggestion {
  final String title;
  final List<String> steps;
  final Map<String, String> requiredItems; // name -> amount
  final Map<String, String> missingItems; // name -> amount
  final String? cookingTime;
  final String? difficulty;

  RecipeSuggestion({
    required this.title,
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

  // 使用 Gemini API 生成智慧食譜
  Future<List<RecipeSuggestion>> suggestWithGemini(
    List<FoodItem> inventory,
  ) async {
    try {
      // 將 FoodItem 轉換為詳細的 Map 格式，包含到期日資訊
      final inventoryMaps =
          inventory
              .map(
                (item) => {
                  'name': item.name,
                  'quantity': item.quantity,
                  'unit': item.unit,
                  'expiryDate': item.expiryDate,
                  'category': item.category.toString(),
                },
              )
              .toList();

      final geminiRecipes = await GeminiService.instance.generateRecipes(
        inventoryMaps,
      );

      if (geminiRecipes.isNotEmpty) {
        // 將 Map 轉換為 RecipeSuggestion 物件
        return geminiRecipes.map((recipe) {
          return RecipeSuggestion(
            title: recipe['title'] ?? '未知食譜',
            steps: List<String>.from(recipe['steps'] ?? []),
            requiredItems: Map<String, String>.from(
              recipe['requiredItems'] ?? {},
            ),
            missingItems: Map<String, String>.from(
              recipe['missingItems'] ?? {},
            ),
            cookingTime: recipe['cookingTime'],
            difficulty: recipe['difficulty'],
          );
        }).toList();
      }
    } catch (e) {
      print('Gemini API 失敗，改用備用食譜: $e');
    }

    // 如果 Gemini API 失敗，使用備用食譜
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
      if (item.expiryDate != null) {
        final daysUntilExpiry = item.expiryDate!.difference(now).inDays;

        // 如果食材即將到期（3天內）
        if (daysUntilExpiry <= 3 && daysUntilExpiry >= 0) {
          // 檢查食譜是否使用了這個食材
          if (recipe.requiredItems.containsKey(item.name)) {
            return true;
          }
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
      print('獲取食材食譜建議失敗: $e');
      return [];
    }
  }
}
