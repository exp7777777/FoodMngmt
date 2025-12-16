import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

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

  // 使用與 GeminiService 相同的 API Key
  static const String _apiKey = 'AIzaSyDoOdI2d4OETtygEqwNqTLUilBGyj4IpIA';
  static const String _modelName = 'models/gemini-2.5-pro';
  static const Duration _requestTimeout = Duration(seconds: 45);
  static const Map<String, dynamic> _defaultGenerationConfig = {
    'temperature': 0.5,
    'topK': 30,
    'topP': 0.85,
    'maxOutputTokens': 2048,
    'responseMimeType': 'application/json',
  };
  static const Map<String, dynamic> _recipeResponseSchema = {
    'type': 'OBJECT',
    'required': ['recipes'],
    'properties': {
      'recipes': {
        'type': 'ARRAY',
        'items': {
          'type': 'OBJECT',
          'required': [
            'id',
            'title',
            'description',
            'preparationTime',
            'difficulty',
            'requiredIngredients',
            'missingIngredients',
            'steps',
          ],
          'properties': {
            'id': {'type': 'STRING'},
            'title': {'type': 'STRING'},
            'description': {'type': 'STRING'},
            'preparationTime': {'type': 'STRING'},
            'difficulty': {
              'type': 'STRING',
              'format': 'enum',
              'enum': ['簡單', '中等', '困難'],
            },
            'requiredIngredients': {
              'type': 'ARRAY',
              'items': {
                'type': 'OBJECT',
                'required': ['name', 'amount', 'unit'],
                'properties': {
                  'name': {'type': 'STRING'},
                  'amount': {'type': 'STRING'},
                  'unit': {'type': 'STRING'},
                },
              },
            },
            'missingIngredients': {
              'type': 'ARRAY',
              'items': {
                'type': 'OBJECT',
                'required': ['name', 'amount', 'unit'],
                'properties': {
                  'name': {'type': 'STRING'},
                  'amount': {'type': 'STRING'},
                  'unit': {'type': 'STRING'},
                },
              },
            },
            'steps': {
              'type': 'ARRAY',
              'items': {
                'type': 'OBJECT',
                'required': ['number', 'description'],
                'properties': {
                  'number': {'type': 'INTEGER'},
                  'description': {'type': 'STRING'},
                },
              },
            },
          },
        },
      },
    },
  };
  final http.Client _httpClient = http.Client();

  /// 生成食譜的主要方法（批次生成）
  Future<RecipeGenerationResult> generateRecipes({
    required List<String> availableIngredients,
    int numberOfRecipes = 10,
  }) async {
    if (availableIngredients.isEmpty) {
      return RecipeGenerationResult.error(
        error: '請先提供至少一項可用食材',
        requestCount: 0,
      );
    }

    final targetCount = numberOfRecipes.clamp(1, 10);
    List<Recipe> recipes = [];

    try {
      recipes = await _generateRecipesBatchWithRetry(
        availableIngredients: availableIngredients,
        numberOfRecipes: targetCount,
      );
    } catch (e) {
      debugPrint('❌ 生成食譜批次失敗: $e，改用備用食譜');
      final fallbackRecipes = _buildFallbackRecipes(
        availableIngredients,
        targetCount,
      );
      return RecipeGenerationResult.success(
        recipes: fallbackRecipes,
        requestCount: targetCount,
      );
    }

    if (recipes.isEmpty) {
      debugPrint('⚠️ 主要生成結果為空，改用備用食譜');
      final fallbackRecipes = _buildFallbackRecipes(
        availableIngredients,
        targetCount,
      );
      return RecipeGenerationResult.success(
        recipes: fallbackRecipes,
        requestCount: targetCount,
      );
    }

    debugPrint('✅ 成功生成 ${recipes.length} 個食譜（目標 $targetCount）');

    return RecipeGenerationResult.success(
      recipes: recipes,
      requestCount: targetCount,
    );
  }

  Future<List<Recipe>> _generateRecipesBatchWithRetry({
    required List<String> availableIngredients,
    required int numberOfRecipes,
  }) async {
    try {
      final prompt = _buildBatchRecipePrompt(
        availableIngredients: availableIngredients,
        numberOfRecipes: numberOfRecipes,
      );

      final responseJson = await _sendGenerateContentRequest(prompt);
      final rawText = _extractTextFromResponse(responseJson);
      if (rawText == null || rawText.isEmpty) {
        throw Exception('Gemini API 返回空回應');
      }

      final recipes = await _parseRecipeResponse(rawText);
      if (recipes.isEmpty) throw Exception('無法解析食譜資料');
      if (recipes.length < numberOfRecipes) {
        debugPrint('⚠️ 回傳食譜數量不足，預期 $numberOfRecipes，實際 ${recipes.length}');
      }

      return recipes.take(numberOfRecipes).toList();
    } catch (e) {
      debugPrint('❌ 食譜批次生成失敗: $e');
      rethrow;
    }
  }

  List<Recipe> _buildFallbackRecipes(
    List<String> availableIngredients,
    int numberOfRecipes,
  ) {
    final now = DateTime.now();
    final ingredients =
        availableIngredients.isEmpty ? ['常備食材'] : availableIngredients;

    final techniqueTemplates = [
      {
        'suffix': '香炒飯',
        'extras': ['雞蛋', '青蔥', '醬油'],
        'description': r'充分利用剩餘白飯的香氣炒飯，簡單快速又美味。',
        'steps': [
          r'將$INGREDIENT 撥散，雞蛋打散備用。',
          r'熱鍋加油，先炒蛋再放入$INGREDIENT 與醬油快炒。',
          r'撒上青蔥拌勻即可上桌。',
        ],
        'difficulty': RecipeDifficulty.easy,
        'time': 15,
      },
      {
        'suffix': '奶油燉煮',
        'extras': ['奶油', '牛奶', '黑胡椒'],
        'description': r'濃郁奶香的輕鬆燉煮料理，溫暖又有飽足感。',
        'steps': [
          r'在鍋中融化奶油，將$INGREDIENT 略為拌炒。',
          r'倒入牛奶與少量水，小火燉煮至食材軟嫩。',
          r'撒上黑胡椒與鹽調味後即可食用。',
        ],
        'difficulty': RecipeDifficulty.medium,
        'time': 25,
      },
      {
        'suffix': '爽口涼拌',
        'extras': ['蒜頭', '香油', '白芝麻'],
        'description': r'保留食材原味的清爽料理，適合炎熱天氣。',
        'steps': [
          r'將$INGREDIENT 切絲或薄片後汆燙，迅速冰鎮。',
          r'淋上蒜蓉、醬油、香油調成的醬汁拌勻。',
          r'撒上白芝麻提升香氣即可。',
        ],
        'difficulty': RecipeDifficulty.easy,
        'time': 10,
      },
      {
        'suffix': '風味燴麵',
        'extras': ['麵條', '高湯', '香菇'],
        'description': r'一鍋到底的燴麵，結合高湯與$INGREDIENT 的美味。',
        'steps': [
          r'香菇切片與$INGREDIENT 一起炒香。',
          r'倒入高湯煮滾後放入麵條，煮至軟硬適中。',
          r'調味後稍微收汁即可盛盤。',
        ],
        'difficulty': RecipeDifficulty.medium,
        'time': 20,
      },
    ];

    RecipeIngredient createIngredient(String name, String amount) =>
        RecipeIngredient(name: name, amount: amount);

    List<RecipeIngredient> buildRequiredIngredients(
      String main,
      List<String> extras,
    ) {
      final required = <RecipeIngredient>[createIngredient(main, '1份')];
      for (final extra in extras) {
        required.add(createIngredient(extra, '適量'));
      }
      return required;
    }

    List<RecipeIngredient> buildMissingIngredients(
      List<String> extras,
      List<String> available,
    ) {
      final missing = <RecipeIngredient>[];
      for (final extra in extras) {
        if (!available.contains(extra)) {
          missing.add(createIngredient(extra, '適量'));
        }
      }
      return missing;
    }

    return List.generate(numberOfRecipes, (index) {
      final main = ingredients[index % ingredients.length];
      final template = techniqueTemplates[index % techniqueTemplates.length];
      final steps =
          (template['steps'] as List<String>)
              .map((step) => step.replaceAll(r'$INGREDIENT', main))
              .toList();

      return Recipe(
        id: 'fallback_${now.millisecondsSinceEpoch}_$index',
        title: '$main${template['suffix']}',
        description: (template['description'] as String).replaceAll(
          r'$INGREDIENT',
          main,
        ),
        preparationTimeMinutes: template['time'] as int,
        difficulty: template['difficulty'] as RecipeDifficulty,
        requiredIngredients: buildRequiredIngredients(
          main,
          (template['extras'] as List<String>),
        ),
        missingIngredients: buildMissingIngredients(
          (template['extras'] as List<String>),
          ingredients,
        ),
        steps: List.generate(
          steps.length,
          (stepIndex) =>
              RecipeStep(number: stepIndex + 1, description: steps[stepIndex]),
        ),
        createdAt: now,
        source: 'Fallback',
      );
    });
  }

  Future<Map<String, dynamic>> _sendGenerateContentRequest(
    String prompt,
  ) async {
    final uri = Uri.parse(
      'https://generativelanguage.googleapis.com/v1beta/$_modelName:generateContent?key=$_apiKey',
    );

    final payload = {
      'contents': [
        {
          'role': 'user',
          'parts': [
            {'text': prompt},
          ],
        },
      ],
      'generationConfig': {
        ..._defaultGenerationConfig,
        'responseSchema': _recipeResponseSchema,
      },
    };

    final response = await _httpClient
        .post(
          uri,
          headers: {'Content-Type': 'application/json'},
          body: json.encode(payload),
        )
        .timeout(
          _requestTimeout,
          onTimeout: () => throw TimeoutException('API 請求超時'),
        );

    if (response.statusCode != 200) {
      throw Exception(
        'Gemini API 請求失敗 (${response.statusCode}): ${response.body}',
      );
    }

    return json.decode(response.body) as Map<String, dynamic>;
  }

  String? _extractTextFromResponse(Map<String, dynamic> jsonResponse) {
    final candidates = jsonResponse['candidates'];
    if (candidates is! List || candidates.isEmpty) {
      return null;
    }

    for (final candidate in candidates) {
      if (candidate is Map<String, dynamic>) {
        // 新格式：content -> parts -> text
        final content = candidate['content'];
        final text =
            _extractTextFromContent(content) ??
            _extractTextFromParts(candidate['parts']) ??
            candidate['output']?.toString() ??
            candidate['text']?.toString();
        if (text != null && text.isNotEmpty) {
          return text;
        }
      }
    }

    // 部分回應會直接把 JSON 放在 top-level
    if (jsonResponse['text'] is String) {
      return jsonResponse['text'] as String;
    }

    return null;
  }

  String? _extractTextFromContent(dynamic content) {
    if (content is Map<String, dynamic>) {
      final parts = content['parts'];
      return _extractTextFromParts(parts);
    }
    return null;
  }

  String? _extractTextFromParts(dynamic parts) {
    if (parts is! List) return null;

    for (final part in parts) {
      if (part is Map<String, dynamic>) {
        if (part['text'] is String && (part['text'] as String).isNotEmpty) {
          return part['text'] as String;
        }
        // 一些回應可能把 JSON 包在 inline_data/textBlock
        if (part['inlineData'] is Map) {
          final inline = part['inlineData'] as Map;
          if (inline['data'] is String) {
            try {
              final decoded = utf8.decode(base64.decode(inline['data']));
              if (decoded.isNotEmpty) return decoded;
            } catch (_) {}
          }
        }
      }
    }
    return null;
  }

  /// 建立批次食譜生成提示詞
  String _buildBatchRecipePrompt({
    required List<String> availableIngredients,
    required int numberOfRecipes,
  }) {
    final ingredientList = availableIngredients.join('、');

    return '''
你是一名專業料理顧問。請根據以下食材，設計 $numberOfRecipes 道不同風格的料理，並以 JSON 回覆，結構需與 schema 相符：

現有食材：$ingredientList

輸出要求：
1. recipes 陣列長度必須是 $numberOfRecipes，ID 依序為 recipe_1、recipe_2...。
2. 每道料理至少使用 1 種現有食材；requiredIngredients 必須是 {"食材": "數量單位"} 的物件，列出所有需要的食材。
3. missingIngredients 只列出庫存沒有的食材；若沒有缺少食材，請給空物件 {}。
4. steps 需 3~5 個繁體中文完整句。
5. difficulty 只能是「簡單」、「中等」或「困難」。
6. 請直接輸出合法 JSON，不要包含額外文字或 Markdown。
''';
  }

  /// 解析 Gemini 回應為食譜列表（增強版）
  Future<List<Recipe>> _parseRecipeResponse(String response) async {
    // 嘗試多種解析方法
    List<Recipe> recipes = [];

    // 方法1: 標準解析
    recipes = await _parseStandardJson(response);
    if (recipes.isNotEmpty) {
      debugPrint('✅ 標準解析成功，獲得 ${recipes.length} 個食譜');
      return recipes;
    }

    // 方法2: 清理後解析
    recipes = await _parseCleanedJson(response);
    if (recipes.isNotEmpty) {
      debugPrint('✅ 清理後解析成功，獲得 ${recipes.length} 個食譜');
      return recipes;
    }

    // 方法3: 提取 JSON 片段
    recipes = await _parsePartialResponse(response);
    if (recipes.isNotEmpty) {
      debugPrint('✅ 部分解析成功，獲得 ${recipes.length} 個食譜');
      return recipes;
    }

    debugPrint('❌ 所有解析方法都失敗');
    return [];
  }

  /// 標準 JSON 解析
  Future<List<Recipe>> _parseStandardJson(String response) async {
    try {
      debugPrint('嘗試標準解析...');

      final Map<String, dynamic> jsonData = json.decode(response);

      if (!jsonData.containsKey('recipes')) {
        return [];
      }

      final List<dynamic> recipesJson = jsonData['recipes'] as List<dynamic>;
      return _convertToRecipes(recipesJson);
    } catch (e) {
      debugPrint('標準解析失敗: $e');
      return [];
    }
  }

  /// 清理後的 JSON 解析
  Future<List<Recipe>> _parseCleanedJson(String response) async {
    try {
      debugPrint('嘗試清理後解析...');

      // 清理回應文字
      String cleanResponse = response.trim();

      // 移除多種可能的 markdown 標記
      final markdownPatterns = ['```json\n', '```json', '```\n', '```'];

      for (final pattern in markdownPatterns) {
        if (cleanResponse.startsWith(pattern)) {
          cleanResponse = cleanResponse.substring(pattern.length);
        }
        if (cleanResponse.endsWith(pattern)) {
          cleanResponse = cleanResponse.substring(
            0,
            cleanResponse.length - pattern.length,
          );
        }
      }

      cleanResponse = cleanResponse.trim();

      // 嘗試找到 JSON 的開始和結束
      final startIdx = cleanResponse.indexOf('{');
      final endIdx = cleanResponse.lastIndexOf('}');

      if (startIdx != -1 && endIdx != -1 && endIdx > startIdx) {
        cleanResponse = cleanResponse.substring(startIdx, endIdx + 1);
      }

      debugPrint('清理後長度: ${cleanResponse.length}');

      final Map<String, dynamic> jsonData = json.decode(cleanResponse);

      if (!jsonData.containsKey('recipes')) {
        return [];
      }

      final List<dynamic> recipesJson = jsonData['recipes'] as List<dynamic>;
      return _convertToRecipes(recipesJson);
    } catch (e) {
      debugPrint('清理後解析失敗: $e');
      return [];
    }
  }

  /// 將 JSON 陣列轉換為 Recipe 物件
  List<Recipe> _convertToRecipes(List<dynamic> recipesJson) {
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

        debugPrint('✅ 成功解析食譜 ${i + 1}: ${recipe.title}');
      } catch (e) {
        debugPrint('❌ 解析食譜 ${i + 1} 失敗: $e');
        // 繼續處理其他食譜
      }
    }

    return recipes;
  }

  /// 嘗試部分解析回應（增強版）
  Future<List<Recipe>> _parsePartialResponse(String response) async {
    try {
      debugPrint('嘗試部分解析...');
      debugPrint('回應總長度: ${response.length}');

      // 顯示回應的前 300 個字符用於調試
      final preview = response.substring(0, min(300, response.length));
      debugPrint('回應預覽: $preview');

      // 策略1: 嘗試找到 "recipes": [ 的位置
      final recipesKeyIndex = response.indexOf('"recipes"');
      if (recipesKeyIndex != -1) {
        debugPrint('找到 recipes 鍵在位置: $recipesKeyIndex');

        final arrayStart = response.indexOf('[', recipesKeyIndex);
        if (arrayStart != -1) {
          debugPrint('找到陣列開始在位置: $arrayStart');

          int bracketCount = 0;
          int endIndex = arrayStart;

          for (int i = arrayStart; i < response.length; i++) {
            if (response[i] == '[') bracketCount++;
            if (response[i] == ']') bracketCount--;
            if (bracketCount == 0) {
              endIndex = i;
              break;
            }
          }

          if (bracketCount == 0) {
            final jsonArrayString = response.substring(
              arrayStart,
              endIndex + 1,
            );
            debugPrint('提取陣列長度: ${jsonArrayString.length}');

            try {
              final List<dynamic> recipesJson = json.decode(jsonArrayString);
              debugPrint('成功解析 JSON 陣列，項目數: ${recipesJson.length}');
              return _convertToRecipes(recipesJson);
            } catch (e) {
              debugPrint('策略1 JSON解析失敗: $e');
            }
          }
        }
      }

      // 策略2: 嘗試找到完整的 JSON 對象 { "recipes": [...] }
      debugPrint('嘗試策略2: 完整 JSON 對象');
      final firstBrace = response.indexOf('{');
      final lastBrace = response.lastIndexOf('}');

      if (firstBrace != -1 && lastBrace != -1 && lastBrace > firstBrace) {
        final jsonString = response.substring(firstBrace, lastBrace + 1);
        debugPrint('提取對象長度: ${jsonString.length}');

        try {
          final jsonData = json.decode(jsonString);
          if (jsonData is Map && jsonData.containsKey('recipes')) {
            final recipesJson = jsonData['recipes'] as List<dynamic>;
            debugPrint('從對象中找到 ${recipesJson.length} 個食譜');
            return _convertToRecipes(recipesJson);
          }
        } catch (e) {
          debugPrint('策略2解析失敗: $e');
        }
      }

      // 策略3: 直接尋找陣列
      debugPrint('嘗試策略3: 直接尋找陣列');
      final startIndex = response.indexOf('[');
      if (startIndex != -1) {
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

        if (bracketCount == 0) {
          final jsonArrayString = response.substring(startIndex, endIndex + 1);
          try {
            final List<dynamic> recipesJson = json.decode(jsonArrayString);
            debugPrint('策略3成功，找到 ${recipesJson.length} 個項目');
            return _convertToRecipes(recipesJson);
          } catch (e) {
            debugPrint('策略3解析失敗: $e');
          }
        } else {
          debugPrint('找不到完整的 JSON 陣列（括號不匹配）');
        }
      } else {
        debugPrint('找不到 JSON 陣列開始標記');
      }

      debugPrint('❌ 所有部分解析策略都失敗');
      return [];
    } catch (e) {
      debugPrint('❌ 部分解析異常: $e');
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

  /// 重置服務狀態
  void reset() {
    debugPrint('Gemini 食譜服務已重置');
  }
}
