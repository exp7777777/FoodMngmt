import 'package:flutter/foundation.dart';
import 'models.dart';
import 'recipe_models.dart';
import 'gemini_recipe_service.dart';
import 'ai_recipe_engine.dart';

/// 整合食譜服務
/// 將新的 Gemini 食譜服務與現有系統整合
class IntegratedRecipeService {
  static IntegratedRecipeService? _instance;
  static IntegratedRecipeService get instance {
    _instance ??= IntegratedRecipeService._();
    return _instance!;
  }

  IntegratedRecipeService._();

  /// 從 FoodItem 列表生成食譜
  ///
  /// [inventory] 用戶的食材庫存
  /// [numberOfRecipes] 要生成的食譜數量，預設為 10
  ///
  /// 返回食譜建議列表（相容現有系統）
  Future<List<RecipeSuggestion>> generateRecipeSuggestions({
    required List<FoodItem> inventory,
    int numberOfRecipes = 10,
  }) async {
    try {
      debugPrint('=== 開始整合食譜生成 ===');
      debugPrint('庫存食材數量: ${inventory.length}');

      // 提取食材名稱
      final ingredientNames = inventory.map((item) => item.name).toList();
      debugPrint('食材名稱: $ingredientNames');

      // 使用 Gemini 服務生成食譜
      final result = await GeminiRecipeService.instance.generateRecipes(
        availableIngredients: ingredientNames,
        numberOfRecipes: numberOfRecipes,
      );

      if (!result.isSuccess) {
        debugPrint('Gemini 食譜生成失敗: ${result.error}');
        return _getFallbackRecipes(inventory);
      }

      debugPrint('成功生成 ${result.recipeCount} 個食譜');

      // 轉換為現有系統相容的格式
      final suggestions =
          result.recipes.map((recipe) {
            return _convertToRecipeSuggestion(recipe, inventory);
          }).toList();

      // 排序：優先顯示缺料少的食譜
      suggestions.sort((a, b) {
        final missingComparison = a.missingItems.length.compareTo(
          b.missingItems.length,
        );
        if (missingComparison != 0) return missingComparison;

        // 如果缺料數量相同，優先使用即將到期的食材
        final aUsesExpiring = _recipeUsesExpiringIngredients(a, inventory);
        final bUsesExpiring = _recipeUsesExpiringIngredients(b, inventory);

        if (aUsesExpiring && !bUsesExpiring) return -1;
        if (!aUsesExpiring && bUsesExpiring) return 1;

        return 0;
      });

      debugPrint('轉換完成，返回 ${suggestions.length} 個食譜建議');
      return suggestions;
    } catch (e) {
      debugPrint('整合食譜生成失敗: $e');
      return _getFallbackRecipes(inventory);
    }
  }

  /// 將 Recipe 轉換為 RecipeSuggestion
  RecipeSuggestion _convertToRecipeSuggestion(
    Recipe recipe,
    List<FoodItem> inventory,
  ) {
    // 建立所需食材的 Map
    final requiredItems = <String, String>{};
    for (final ingredient in recipe.requiredIngredients) {
      requiredItems[ingredient.name] = ingredient.fullDescription;
    }

    // 建立缺失食材的 Map
    final missingItems = <String, String>{};
    for (final ingredient in recipe.missingIngredients) {
      missingItems[ingredient.name] = ingredient.fullDescription;
    }

    // 轉換步驟
    final steps =
        recipe.steps
            .map((step) => '${step.number}. ${step.description}')
            .toList();

    return RecipeSuggestion(
      title: recipe.title,
      originalTitle: recipe.title, // Gemini 已經生成中文標題
      steps: steps,
      requiredItems: requiredItems,
      missingItems: missingItems,
      cookingTime: recipe.preparationTimeText,
      difficulty: recipe.difficulty.displayName,
    );
  }

  /// 檢查食譜是否使用了即將到期的食材
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

  /// 備用食譜（當 Gemini 服務失敗時使用）
  List<RecipeSuggestion> _getFallbackRecipes(List<FoodItem> inventory) {
    debugPrint('使用備用食譜');

    final fallbackRecipes = [
      {
        'title': '簡單炒飯',
        'requires': {'白飯': '1碗', '雞蛋': '2顆', '蔥': '1根', '醬油': '1湯匙'},
        'steps': ['熱鍋下油', '炒蛋盛起', '炒飯至粒粒分明', '加入蛋和蔥花', '調味即可'],
        'cookingTime': '15分鐘',
        'difficulty': '簡單',
      },
      {
        'title': '番茄炒蛋',
        'requires': {'雞蛋': '3顆', '番茄': '2顆', '蔥': '1根', '鹽': '少許'},
        'steps': ['番茄切塊', '蛋打散', '熱鍋炒蛋', '加入番茄', '調味起鍋'],
        'cookingTime': '10分鐘',
        'difficulty': '簡單',
      },
      {
        'title': '蒜炒青菜',
        'requires': {'青菜': '1把', '大蒜': '3瓣', '鹽': '少許', '油': '1湯匙'},
        'steps': ['青菜洗淨', '蒜切片', '熱鍋爆香蒜', '下青菜炒', '調味即可'],
        'cookingTime': '8分鐘',
        'difficulty': '簡單',
      },
    ];

    final invNames = inventory.map((e) => e.name).toList();
    final suggestions = <RecipeSuggestion>[];

    for (final recipeData in fallbackRecipes) {
      final req = Map<String, String>.from(recipeData['requires'] as Map);
      final missing = <String, String>{};

      req.forEach((name, amount) {
        final match = invNames.firstWhere(
          (n) => n.contains(name) || name.contains(n),
          orElse: () => '',
        );
        if (match.isEmpty) missing[name] = amount;
      });

      suggestions.add(
        RecipeSuggestion(
          title: recipeData['title'] as String,
          steps: List<String>.from(recipeData['steps'] as List),
          requiredItems: req,
          missingItems: missing,
          cookingTime: recipeData['cookingTime'] as String?,
          difficulty: recipeData['difficulty'] as String?,
        ),
      );
    }

    return suggestions;
  }

  /// 測試整合服務
  Future<void> testIntegratedService() async {
    debugPrint('=== 測試整合食譜服務 ===');

    try {
      // 建立測試食材
      final testInventory = [
        FoodItem(
          name: '雞蛋',
          quantity: 6,
          unit: '顆',
          expiryDate: DateTime.now().add(const Duration(days: 5)),
          category: FoodCategory.other,
        ),
        FoodItem(
          name: '白飯',
          quantity: 2,
          unit: '碗',
          expiryDate: DateTime.now().add(const Duration(days: 1)),
          category: FoodCategory.staple,
        ),
        FoodItem(
          name: '醬油',
          quantity: 1,
          unit: '瓶',
          expiryDate: DateTime.now().add(const Duration(days: 30)),
          category: FoodCategory.other,
        ),
        FoodItem(
          name: '蔥',
          quantity: 1,
          unit: '把',
          expiryDate: DateTime.now().add(const Duration(days: 2)),
          category: FoodCategory.other,
        ),
      ];

      final suggestions = await generateRecipeSuggestions(
        inventory: testInventory,
        numberOfRecipes: 5,
      );

      debugPrint('✅ 測試成功！生成了 ${suggestions.length} 個食譜建議');

      for (final suggestion in suggestions) {
        debugPrint('\n📋 食譜: ${suggestion.title}');
        debugPrint('   時間: ${suggestion.cookingTime ?? '未知'}');
        debugPrint('   難度: ${suggestion.difficulty ?? '未知'}');
        debugPrint('   所需食材: ${suggestion.requiredItems.length} 種');
        debugPrint('   缺失食材: ${suggestion.missingItems.length} 種');
        debugPrint('   步驟數: ${suggestion.steps.length}');

        if (suggestion.missingItems.isNotEmpty) {
          debugPrint('   缺失食材: ${suggestion.missingItems.keys.join(', ')}');
        }
      }
    } catch (e) {
      debugPrint('❌ 測試失敗: $e');
    }

    debugPrint('=== 整合食譜服務測試完成 ===');
  }

  /// 獲取服務狀態
  bool get isGeminiServiceAvailable =>
      GeminiRecipeService.instance.isInitialized;
}
