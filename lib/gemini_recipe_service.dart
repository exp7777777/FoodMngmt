import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:google_generative_ai/google_generative_ai.dart';

import 'recipe_models.dart';

/// Gemini 食譜生成服務
/// 專門用於生成完整的食譜，包含缺失食材分析
class GeminiRecipeService {
  static GeminiRecipeService? _instance;
  static GeminiRecipeService get instance {
    _instance ??= GeminiRecipeService._();
    return _instance!;
  }

  GeminiRecipeService._();

  late GenerativeModel _model;
  bool _isInitialized = false;

  /// 初始化 Gemini 模型
  Future<void> _initializeModel() async {
    if (_isInitialized) return;

    try {
      _model = GenerativeModel(
        model: 'gemini-1.5-pro',
        apiKey: const String.fromEnvironment('GEMINI_API_KEY'),
        generationConfig: GenerationConfig(
          temperature: 0.7,
          topK: 40,
          topP: 0.95,
          maxOutputTokens: 8192,
        ),
      );
      _isInitialized = true;
      debugPrint('Gemini 食譜服務初始化成功');
    } catch (e) {
      debugPrint('Gemini 食譜服務初始化失敗: $e');
      rethrow;
    }
  }

  /// 生成食譜的主要方法
  ///
  /// [availableIngredients] 用戶現有的食材清單（繁體中文）
  /// [numberOfRecipes] 要生成的食譜數量，預設為 10
  ///
  /// 返回食譜生成結果
  Future<RecipeGenerationResult> generateRecipes({
    required List<String> availableIngredients,
    int numberOfRecipes = 10,
  }) async {
    try {
      await _initializeModel();

      debugPrint('=== 開始生成食譜 ===');
      debugPrint('可用食材: $availableIngredients');
      debugPrint('目標食譜數量: $numberOfRecipes');

      final prompt = _buildRecipeGenerationPrompt(
        availableIngredients: availableIngredients,
        numberOfRecipes: numberOfRecipes,
      );

      debugPrint('發送請求到 Gemini API...');
      final response = await _model.generateContent([Content.text(prompt)]);

      if (response.text == null) {
        debugPrint('Gemini API 返回空回應');
        return RecipeGenerationResult.error(
          error: 'Gemini API 返回空回應',
          requestCount: numberOfRecipes,
        );
      }

      debugPrint('收到 Gemini 回應，長度: ${response.text!.length}');
      debugPrint(
        '回應內容預覽: ${response.text!.substring(0, min(200, response.text!.length))}...',
      );

      // 解析 JSON 回應
      final recipes = await _parseRecipeResponse(response.text!);

      if (recipes.isEmpty) {
        debugPrint('解析食譜失敗或未找到食譜');
        return RecipeGenerationResult.error(
          error: '無法解析食譜資料',
          requestCount: numberOfRecipes,
        );
      }

      debugPrint('成功生成 ${recipes.length} 個食譜');
      return RecipeGenerationResult.success(
        recipes: recipes,
        requestCount: numberOfRecipes,
      );
    } catch (e) {
      debugPrint('生成食譜時發生錯誤: $e');
      return RecipeGenerationResult.error(
        error: '生成食譜失敗: $e',
        requestCount: numberOfRecipes,
      );
    }
  }

  /// 建立食譜生成提示詞
  String _buildRecipeGenerationPrompt({
    required List<String> availableIngredients,
    required int numberOfRecipes,
  }) {
    final ingredientList = availableIngredients.join('、');

    return '''
你是一個專業的廚師助手。根據以下用戶現有的食材，請生成 $numberOfRecipes 個創意且實用的食譜。

【用戶現有食材】
$ingredientList

【任務要求】
1. 每個食譜必須至少使用用戶現有食材中的 1-2 種
2. 為每個食譜提供完整的食材清單，包括所需的所有食材和數量
3. 對於每個食譜，明確標示哪些食材用戶已有，哪些需要額外購買
4. 食譜應該簡單實用，適合家庭料理
5. 提供詳細的烹飪步驟
6. 所有文字必須使用繁體中文

【輸出格式】
請嚴格按照以下 JSON 格式回應，不要添加任何其他文字、說明或標記：

{
  "recipes": [
    {
      "id": "recipe_1",
      "title": "食譜名稱",
      "description": "簡短描述",
      "preparationTime": "30分鐘",
      "difficulty": "簡單",
      "requiredIngredients": [
        {
          "name": "食材名稱",
          "amount": "數量",
          "unit": "單位"
        }
      ],
      "missingIngredients": [
        {
          "name": "缺少的食材名稱",
          "amount": "數量",
          "unit": "單位"
        }
      ],
      "steps": [
        {
          "number": 1,
          "description": "步驟描述"
        }
      ]
    }
  ]
}

【重要規則】
- JSON 格式必須完全正確
- 不要使用 markdown 代碼塊標記（```json 或 ```）
- 不要添加任何解釋文字
- 難度只能是：簡單、中等、困難
- 烹飪時間格式如：15分鐘、1小時30分鐘等
- 確保每個食譜都有完整的步驟
- 食材數量要合理且具體
''';
  }

  /// 解析 Gemini 回應為食譜列表
  Future<List<Recipe>> _parseRecipeResponse(String response) async {
    try {
      debugPrint('開始解析食譜回應...');

      // 清理回應文字
      String cleanResponse = response.trim();

      // 移除可能的 markdown 標記
      if (cleanResponse.startsWith('```json')) {
        cleanResponse = cleanResponse.substring(7);
      }
      if (cleanResponse.startsWith('```')) {
        cleanResponse = cleanResponse.substring(3);
      }
      if (cleanResponse.endsWith('```')) {
        cleanResponse = cleanResponse.substring(0, cleanResponse.length - 3);
      }

      cleanResponse = cleanResponse.trim();

      debugPrint('清理後的回應長度: ${cleanResponse.length}');
      debugPrint(
        '回應開頭: ${cleanResponse.substring(0, min(100, cleanResponse.length))}',
      );

      // 嘗試解析 JSON
      final Map<String, dynamic> jsonData = json.decode(cleanResponse);

      if (!jsonData.containsKey('recipes')) {
        debugPrint('JSON 中缺少 recipes 欄位');
        return [];
      }

      final List<dynamic> recipesJson = jsonData['recipes'] as List<dynamic>;
      debugPrint('找到 ${recipesJson.length} 個食譜 JSON 物件');

      final List<Recipe> recipes = [];

      for (int i = 0; i < recipesJson.length; i++) {
        try {
          final recipeMap = recipesJson[i] as Map<String, dynamic>;

          // 為每個食譜生成唯一 ID
          recipeMap['id'] =
              'gemini_recipe_${DateTime.now().millisecondsSinceEpoch}_$i';
          recipeMap['createdAt'] = DateTime.now().toIso8601String();
          recipeMap['source'] = 'Gemini AI';

          final recipe = Recipe.fromMap(recipeMap);
          recipes.add(recipe);

          debugPrint('成功解析食譜 ${i + 1}: ${recipe.title}');
        } catch (e) {
          debugPrint('解析食譜 ${i + 1} 失敗: $e');
          // 繼續處理其他食譜
        }
      }

      debugPrint('成功解析 ${recipes.length} 個食譜');
      return recipes;
    } catch (e) {
      debugPrint('解析食譜回應失敗: $e');
      debugPrint(
        '回應內容: ${response.substring(0, min(500, response.length))}...',
      );

      // 嘗試部分解析
      return await _parsePartialResponse(response);
    }
  }

  /// 嘗試部分解析回應
  Future<List<Recipe>> _parsePartialResponse(String response) async {
    try {
      debugPrint('嘗試部分解析...');

      // 尋找 JSON 陣列開始
      final startIndex = response.indexOf('[');
      if (startIndex == -1) {
        debugPrint('找不到 JSON 陣列開始標記');
        return [];
      }

      // 尋找 JSON 陣列結束
      int bracketCount = 0;
      int endIndex = startIndex;

      for (int i = startIndex; i < response.length; i++) {
        if (response[i] == '[') bracketCount++;
        if (response[i] == ']') bracketCount--;
        if (bracketCount == 0) {
          endIndex = i;
          break;
        }
      }

      if (bracketCount != 0) {
        debugPrint('找不到完整的 JSON 陣列');
        return [];
      }

      final jsonArrayString = response.substring(startIndex, endIndex + 1);
      debugPrint(
        '提取的 JSON 陣列: ${jsonArrayString.substring(0, min(200, jsonArrayString.length))}...',
      );

      final List<dynamic> recipesJson = json.decode(jsonArrayString);
      final List<Recipe> recipes = [];

      for (int i = 0; i < recipesJson.length; i++) {
        try {
          final recipeMap = recipesJson[i] as Map<String, dynamic>;
          recipeMap['id'] =
              'gemini_recipe_${DateTime.now().millisecondsSinceEpoch}_$i';
          recipeMap['createdAt'] = DateTime.now().toIso8601String();
          recipeMap['source'] = 'Gemini AI';

          final recipe = Recipe.fromMap(recipeMap);
          recipes.add(recipe);
        } catch (e) {
          debugPrint('部分解析食譜 ${i + 1} 失敗: $e');
        }
      }

      debugPrint('部分解析成功，獲得 ${recipes.length} 個食譜');
      return recipes;
    } catch (e) {
      debugPrint('部分解析也失敗: $e');
      return [];
    }
  }

  /// 測試食譜生成功能
  Future<void> testRecipeGeneration() async {
    debugPrint('=== 測試 Gemini 食譜生成功能 ===');

    try {
      final testIngredients = ['雞蛋', '白飯', '醬油', '蔥', '大蒜'];

      final result = await generateRecipes(
        availableIngredients: testIngredients,
        numberOfRecipes: 3,
      );

      if (result.isSuccess) {
        debugPrint('✅ 測試成功！生成了 ${result.recipeCount} 個食譜');

        for (final recipe in result.recipes) {
          debugPrint('\n📋 食譜: ${recipe.title}');
          debugPrint('   時間: ${recipe.preparationTimeText}');
          debugPrint('   難度: ${recipe.difficulty.displayName}');
          debugPrint('   所需食材: ${recipe.requiredIngredientCount} 種');
          debugPrint('   缺失食材: ${recipe.missingIngredientCount} 種');
          debugPrint('   步驟數: ${recipe.steps.length}');

          if (recipe.description != null) {
            debugPrint('   描述: ${recipe.description}');
          }

          debugPrint('   所需食材清單:');
          for (final ingredient in recipe.requiredIngredients) {
            debugPrint('     - ${ingredient.fullDescription}');
          }

          if (recipe.hasMissingIngredients) {
            debugPrint('   缺失食材清單:');
            for (final ingredient in recipe.missingIngredients) {
              debugPrint('     - ${ingredient.fullDescription}');
            }
          }
        }
      } else {
        debugPrint('❌ 測試失敗: ${result.error}');
      }
    } catch (e) {
      debugPrint('❌ 測試過程中發生錯誤: $e');
    }

    debugPrint('=== Gemini 食譜生成測試完成 ===');
  }

  /// 檢查服務狀態
  bool get isInitialized => _isInitialized;

  /// 重置服務狀態
  void reset() {
    _isInitialized = false;
    debugPrint('Gemini 食譜服務已重置');
  }
}
