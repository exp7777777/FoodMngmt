import 'package:flutter/foundation.dart';
import 'recipe_service.dart';

/// 智慧食譜推薦使用範例
class RecipeExample {
  /// 示範如何使用智慧食譜推薦功能
  static Future<void> demonstrateUsage() async {
    debugPrint('=== 智慧食譜推薦使用範例 ===');

    // 範例 1: 基本食材
    await _example1_BasicIngredients();

    // 範例 2: 複雜食材
    await _example2_ComplexIngredients();

    // 範例 3: 口語化食材
    await _example3_ColloquialIngredients();

    debugPrint('=== 範例演示完成 ===');
  }

  /// 範例 1: 基本食材
  static Future<void> _example1_BasicIngredients() async {
    debugPrint('\n--- 範例 1: 基本食材 ---');

    final ingredients = ['雞蛋', '番茄', '蔥', '鹽'];
    debugPrint('輸入食材: $ingredients');

    final recipes = await RecipeService.instance
        .getIntelligentRecipeRecommendations(ingredients, number: 3);

    debugPrint('找到 ${recipes.length} 個食譜:');
    for (final recipe in recipes) {
      debugPrint(
        '• ${recipe.title} (${recipe.cookingTime}, ${recipe.difficulty})',
      );
    }
  }

  /// 範例 2: 複雜食材
  static Future<void> _example2_ComplexIngredients() async {
    debugPrint('\n--- 範例 2: 複雜食材 ---');

    final ingredients = ['雞胸肉', '白米', '洋蔥', '大蒜', '橄欖油', '黑胡椒', '鹽巴'];
    debugPrint('輸入食材: $ingredients');

    final recipes = await RecipeService.instance
        .getIntelligentRecipeRecommendations(ingredients, number: 2);

    debugPrint('找到 ${recipes.length} 個食譜:');
    for (final recipe in recipes) {
      debugPrint('• ${recipe.title}');
      debugPrint('  烹飪時間: ${recipe.cookingTime}');
      debugPrint('  難度: ${recipe.difficulty}');
      debugPrint('  使用食材: ${recipe.usedIngredientCount}');
      debugPrint('  缺失食材: ${recipe.missedIngredientCount}');
      if (recipe.steps.isNotEmpty) {
        debugPrint('  第一步: ${recipe.steps.first}');
      }
    }
  }

  /// 範例 3: 口語化食材
  static Future<void> _example3_ColloquialIngredients() async {
    debugPrint('\n--- 範例 3: 口語化食材 ---');

    final ingredients = ['一把青菜', '幾顆蛋', '一些肉絲', '少許鹽', '一點點油'];
    debugPrint('輸入食材: $ingredients');

    final recipes = await RecipeService.instance
        .getIntelligentRecipeRecommendations(ingredients, number: 2);

    debugPrint('找到 ${recipes.length} 個食譜:');
    for (final recipe in recipes) {
      debugPrint('• ${recipe.title}');
      debugPrint('  所需食材: ${recipe.requiredItems.keys.join(', ')}');
      if (recipe.missingItems.isNotEmpty) {
        debugPrint('  缺失食材: ${recipe.missingItems.keys.join(', ')}');
      }
    }
  }

  /// 示範錯誤處理
  static Future<void> demonstrateErrorHandling() async {
    debugPrint('\n--- 錯誤處理範例 ---');

    // 空清單
    final emptyRecipes = await RecipeService.instance
        .getIntelligentRecipeRecommendations([]);
    debugPrint('空清單結果: ${emptyRecipes.length} 個食譜');

    // 無效食材
    final invalidRecipes = await RecipeService.instance
        .getIntelligentRecipeRecommendations(['無效食材', '不存在']);
    debugPrint('無效食材結果: ${invalidRecipes.length} 個食譜');
  }
}
