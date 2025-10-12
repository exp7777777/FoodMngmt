import 'package:flutter/foundation.dart';
import 'gemini_service.dart';

/// 食譜摘要資料模型
class RecipeSummary {
  final int id;
  final String title; // 中文標題
  final String? originalTitle; // 原始英文標題
  final String? image;
  final int usedIngredientCount;
  final int missedIngredientCount;
  final int likes;
  final String cookingTime;
  final String difficulty;
  final Map<String, String> requiredItems;
  final Map<String, String> missingItems;
  final List<String> steps;
  final String source;

  RecipeSummary({
    required this.id,
    required this.title,
    this.originalTitle,
    this.image,
    required this.usedIngredientCount,
    required this.missedIngredientCount,
    required this.likes,
    required this.cookingTime,
    required this.difficulty,
    required this.requiredItems,
    required this.missingItems,
    required this.steps,
    required this.source,
  });

  factory RecipeSummary.fromMap(Map<String, dynamic> map) {
    return RecipeSummary(
      id: map['id'] as int? ?? 0,
      title: map['title'] as String? ?? '未知食譜',
      originalTitle: map['originalTitle'] as String?,
      image: map['image'] as String?,
      usedIngredientCount: map['usedIngredientCount'] as int? ?? 0,
      missedIngredientCount: map['missedIngredientCount'] as int? ?? 0,
      likes: map['likes'] as int? ?? 0,
      cookingTime: map['cookingTime'] as String? ?? '30分鐘',
      difficulty: map['difficulty'] as String? ?? '中等',
      requiredItems: Map<String, String>.from(map['requiredItems'] ?? {}),
      missingItems: Map<String, String>.from(map['missingItems'] ?? {}),
      steps: List<String>.from(map['steps'] ?? []),
      source: map['source'] as String? ?? 'Spoonacular',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'originalTitle': originalTitle,
      'image': image,
      'usedIngredientCount': usedIngredientCount,
      'missedIngredientCount': missedIngredientCount,
      'likes': likes,
      'cookingTime': cookingTime,
      'difficulty': difficulty,
      'requiredItems': requiredItems,
      'missingItems': missingItems,
      'steps': steps,
      'source': source,
    };
  }
}

/// 智慧食譜推薦服務
class RecipeService {
  static RecipeService? _instance;
  static RecipeService get instance {
    _instance ??= RecipeService._();
    return _instance!;
  }

  RecipeService._();

  /// 智慧食譜推薦（純 Gemini 版本）
  ///
  /// [chineseIngredients] 中文食材清單，可能包含非標準或口語化名稱
  /// [number] 返回的食譜數量，預設為 10
  ///
  /// 返回食譜摘要清單
  Future<List<RecipeSummary>> getIntelligentRecipeRecommendations(
    List<String> chineseIngredients, {
    int number = 10,
  }) async {
    try {
      debugPrint('=== 開始智慧食譜推薦（純 Gemini） ===');
      debugPrint('輸入食材: $chineseIngredients');

      // 將中文食材轉換為 Gemini 需要的格式
      final ingredientMaps =
          chineseIngredients
              .map(
                (ingredient) => {
                  'name': ingredient,
                  'quantity': 1,
                  'unit': 'piece',
                },
              )
              .toList();

      // 使用 Gemini 直接生成食譜
      final geminiRecipes = await GeminiService.instance.generateRecipes(
        ingredientMaps,
      );

      debugPrint('Gemini 生成 ${geminiRecipes.length} 個食譜');

      if (geminiRecipes.isEmpty) {
        debugPrint('Gemini 未生成食譜');
        return [];
      }

      // 轉換為 RecipeSummary 格式
      final recipes =
          geminiRecipes.map((recipe) {
            return RecipeSummary(
              id: DateTime.now().millisecondsSinceEpoch, // 使用時間戳作為 ID
              title: recipe['title'] ?? '未知食譜',
              originalTitle: recipe['title'], // Gemini 已經生成中文標題
              image: null,
              usedIngredientCount: recipe['requiredItems']?.length ?? 0,
              missedIngredientCount: 0, // Gemini 生成的食譜通常沒有缺失食材
              likes: 0,
              cookingTime: recipe['cookingTime'] ?? '30分鐘',
              difficulty: recipe['difficulty'] ?? '中等',
              requiredItems: Map<String, String>.from(
                recipe['requiredItems'] ?? {},
              ),
              missingItems: {},
              steps: List<String>.from(recipe['steps'] ?? []),
              source: 'Gemini AI',
            );
          }).toList();

      debugPrint('完成食譜推薦，返回 ${recipes.length} 個食譜');
      return recipes;
    } catch (e) {
      debugPrint('智慧食譜推薦失敗: $e');
      return [];
    }
  }

  /// 測試智慧食譜推薦功能
  Future<void> testIntelligentRecommendations() async {
    debugPrint('=== 測試智慧食譜推薦功能 ===');

    // 測試案例 1: 基本食材
    final testIngredients1 = ['雞蛋', '牛番茄', '一把蔥', '幾瓣蒜'];
    debugPrint('\n測試案例 1: $testIngredients1');

    final recipes1 = await getIntelligentRecipeRecommendations(
      testIngredients1,
      number: 3,
    );
    debugPrint('找到 ${recipes1.length} 個食譜');

    for (final recipe in recipes1) {
      debugPrint('食譜: ${recipe.title}');
      if (recipe.originalTitle != null) {
        debugPrint('  原始標題: ${recipe.originalTitle}');
      }
      debugPrint('  烹飪時間: ${recipe.cookingTime}');
      debugPrint('  難度: ${recipe.difficulty}');
      debugPrint('  使用食材: ${recipe.usedIngredientCount}');
      debugPrint('  缺失食材: ${recipe.missedIngredientCount}');
      debugPrint('  步驟數量: ${recipe.steps.length}');
    }

    // 測試案例 2: 複雜食材
    final testIngredients2 = ['雞胸肉', '白米飯', '洋蔥', '大蒜', '橄欖油', '鹽巴'];
    debugPrint('\n測試案例 2: $testIngredients2');

    final recipes2 = await getIntelligentRecipeRecommendations(
      testIngredients2,
      number: 2,
    );
    debugPrint('找到 ${recipes2.length} 個食譜');

    for (final recipe in recipes2) {
      debugPrint('食譜: ${recipe.title}');
      if (recipe.originalTitle != null) {
        debugPrint('  原始標題: ${recipe.originalTitle}');
      }
      debugPrint('  烹飪時間: ${recipe.cookingTime}');
      debugPrint('  難度: ${recipe.difficulty}');
    }

    debugPrint('=== 智慧食譜推薦測試完成 ===');
  }
}
