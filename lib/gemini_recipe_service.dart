import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'api_key_service.dart';
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

  // 使用設定頁儲存的 Gemini API Key
  static const String _modelName = 'models/gemini-2.5-flash';
  static const Duration _requestTimeout = Duration(seconds: 60);
  static const Duration _recipeCacheTtl = Duration(minutes: 5);
  static const int _fixedRecipeCount = 10;
  static const int _recipesPerBatch = 2;
  static const Map<String, dynamic> _defaultGenerationConfig = {
    'temperature': 0.5,
    'topK': 30,
    'topP': 0.85,
    'maxOutputTokens': 8192,
    'responseMimeType': 'application/json',
  };
  static const Map<String, dynamic> _ingredientSchema = {
    'type': 'OBJECT',
    'required': ['name', 'amount', 'unit'],
    'properties': {
      'name': {'type': 'STRING'},
      'amount': {'type': 'STRING'},
      'unit': {'type': 'STRING'},
    },
  };
  static const Map<String, dynamic> _stepSchema = {
    'type': 'OBJECT',
    'required': ['number', 'description'],
    'properties': {
      'number': {'type': 'INTEGER'},
      'description': {'type': 'STRING'},
    },
  };
  final http.Client _httpClient = http.Client();
  final Map<String, _CachedRecipeResult> _resultCache = {};
  final Map<String, Future<RecipeGenerationResult>> _inflightRequests = {};

  Future<String?> _resolveApiKey() async {
    final customKey = await ApiKeyService.instance.getKey(ManagedApiKey.gemini);
    if (ApiKeyService.isUsableKey(customKey)) {
      return customKey;
    }
    return null;
  }

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

    final targetCount = _fixedRecipeCount;
    if (numberOfRecipes != _fixedRecipeCount) {
      debugPrint('ℹ️ 已固定食譜生成數量為 $_fixedRecipeCount 道');
    }
    final requestKey = _buildRequestKey(
      availableIngredients: availableIngredients,
      numberOfRecipes: targetCount,
    );

    final cached = _resultCache[requestKey];
    if (cached != null &&
        DateTime.now().difference(cached.generatedAt) < _recipeCacheTtl) {
      debugPrint('♻️ 使用快取食譜結果（$requestKey）');
      return RecipeGenerationResult.success(
        recipes: List<Recipe>.from(cached.recipes),
        requestCount: targetCount,
      );
    }

    final inflight = _inflightRequests[requestKey];
    if (inflight != null) {
      debugPrint('⏳ 共用進行中的食譜請求（$requestKey）');
      return inflight;
    }

    final future = _generateRecipesInternal(
      availableIngredients: availableIngredients,
      targetCount: targetCount,
      requestKey: requestKey,
    );
    _inflightRequests[requestKey] = future;

    try {
      return await future;
    } finally {
      _inflightRequests.remove(requestKey);
    }
  }

  Future<RecipeGenerationResult> _generateRecipesInternal({
    required List<String> availableIngredients,
    required int targetCount,
    required String requestKey,
  }) async {
    List<Recipe> recipes = [];

    try {
      recipes = await _generateRecipesBatchWithRetry(
        availableIngredients: availableIngredients,
        numberOfRecipes: targetCount,
      );
    } catch (e) {
      debugPrint('❌ 生成食譜批次失敗: $e');
    }

    if (recipes.length < targetCount) {
      final shortfall = targetCount - recipes.length;
      debugPrint('⚠️ AI 食譜不足（${recipes.length}/$targetCount），以備用食譜補齊 $shortfall 道');
      final fallback = _buildFallbackRecipes(availableIngredients, shortfall);
      recipes.addAll(fallback);
    }

    debugPrint('✅ 最終取得 ${recipes.length} 個食譜（目標 $targetCount）');
    _cacheResult(requestKey, recipes);
    return RecipeGenerationResult.success(
      recipes: recipes.take(targetCount).toList(),
      requestCount: targetCount,
    );
  }

  void _cacheResult(String key, List<Recipe> recipes) {
    _resultCache[key] = _CachedRecipeResult(
      recipes: List<Recipe>.from(recipes),
      generatedAt: DateTime.now(),
    );
  }

  String _buildRequestKey({
    required List<String> availableIngredients,
    required int numberOfRecipes,
  }) {
    final normalized =
        availableIngredients
            .map((item) => item.trim().toLowerCase())
            .where((item) => item.isNotEmpty)
            .toList()
          ..sort();
    return '${normalized.join('|')}#$numberOfRecipes';
  }

  Future<List<Recipe>> _generateRecipesBatchWithRetry({
    required List<String> availableIngredients,
    required int numberOfRecipes,
  }) async {
    final apiKey = await _resolveApiKey();
    if (apiKey == null) {
      throw Exception('Gemini API Key 未設定');
    }
    final generatedRecipes = <Recipe>[];
    int startIndex = 1;
    final totalBatches = (numberOfRecipes / _recipesPerBatch).ceil();

    for (int batchIdx = 0; batchIdx < totalBatches; batchIdx++) {
      final remaining = numberOfRecipes - generatedRecipes.length;
      if (remaining <= 0) break;
      final batchSize = min(_recipesPerBatch, remaining);
      final batchNum = batchIdx + 1;

      final chunk = await _requestSingleBatch(
        apiKey: apiKey,
        availableIngredients: availableIngredients,
        batchSize: batchSize,
        startIndex: startIndex,
        batchNum: batchNum,
      );

      if (chunk.isEmpty) {
        debugPrint('❌ 第$batchNum批失敗，中止後續批次');
        break;
      }

      generatedRecipes.addAll(chunk.take(batchSize));
      startIndex += chunk.length;
      debugPrint('✅ 第$batchNum/$totalBatches批完成，累計 ${generatedRecipes.length} 道');
    }

    if (generatedRecipes.isEmpty) {
      throw Exception('所有批次食譜生成均失敗');
    }
    return generatedRecipes.take(numberOfRecipes).toList();
  }

  Future<List<Recipe>> _requestSingleBatch({
    required String apiKey,
    required List<String> availableIngredients,
    required int batchSize,
    required int startIndex,
    required int batchNum,
  }) async {
    try {
      final prompt = _buildBatchRecipePrompt(
        availableIngredients: availableIngredients,
        numberOfRecipes: batchSize,
        startIndex: startIndex,
      );
      final responseJson = await _sendGenerateContentRequest(
        prompt,
        apiKey,
        recipeCount: batchSize,
      );
      final finishReason = _extractFinishReason(responseJson);
      if (finishReason == 'MAX_TOKENS') {
        debugPrint('⚠️ 第$batchNum批被 MAX_TOKENS 截斷');
      }
      final rawText = _extractTextFromResponse(responseJson);
      if (rawText == null || rawText.isEmpty) {
        debugPrint('⚠️ 第$batchNum批回應為空');
        return [];
      }

      final recipes = await _parseRecipeResponse(rawText);
      if (recipes.isEmpty) {
        debugPrint('⚠️ 第$batchNum批解析失敗');
      }
      return recipes;
    } catch (e) {
      debugPrint('⚠️ 第$batchNum批異常: $e');
      return [];
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
    String apiKey,
    {required int recipeCount}
  ) async {
    final uri = Uri.parse(
      'https://generativelanguage.googleapis.com/v1beta/$_modelName:generateContent?key=$apiKey',
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
        'responseSchema': _buildRecipeResponseSchema(recipeCount),
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

  String? _extractFinishReason(Map<String, dynamic> jsonResponse) {
    final candidates = jsonResponse['candidates'];
    if (candidates is! List || candidates.isEmpty) return null;
    final first = candidates.first;
    if (first is! Map<String, dynamic>) return null;
    return first['finishReason']?.toString();
  }

  String? _extractTextFromResponse(Map<String, dynamic> jsonResponse) {
    final candidates = jsonResponse['candidates'];
    if (candidates is! List || candidates.isEmpty) {
      return null;
    }

    String? bestText;

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
          if (bestText == null || text.length > bestText.length) {
            bestText = text;
          }
        }
      }
    }
    if (bestText != null) return bestText;

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

    final textBuffer = StringBuffer();

    for (final part in parts) {
      if (part is Map<String, dynamic>) {
        if (part['text'] is String && (part['text'] as String).isNotEmpty) {
          textBuffer.write(part['text'] as String);
          continue;
        }
        // 一些回應可能把 JSON 包在 inline_data/textBlock
        if (part['inlineData'] is Map) {
          final inline = part['inlineData'] as Map;
          if (inline['data'] is String) {
            try {
              final decoded = utf8.decode(base64.decode(inline['data']));
              if (decoded.isNotEmpty) {
                textBuffer.write(decoded);
              }
            } catch (_) {}
          }
        }
      }
    }
    final merged = textBuffer.toString().trim();
    if (merged.isEmpty) return null;
    return merged;
  }

  /// 建立批次食譜生成提示詞
  String _buildBatchRecipePrompt({
    required List<String> availableIngredients,
    required int numberOfRecipes,
    required int startIndex,
  }) {
    final ingredientList = availableIngredients.join('、');
    final endIndex = startIndex + numberOfRecipes - 1;

    return '''
你是一名專業料理顧問。請根據以下食材，設計 $numberOfRecipes 道不同風格的料理。直接輸出合法 JSON，不要包含任何額外文字。

現有食材：$ingredientList

規則：
- recipes 陣列恰好 $numberOfRecipes 筆，id 依序為 recipe_$startIndex 到 recipe_$endIndex。
- 每道至少使用 1 種現有食材。
- requiredIngredients / missingIngredients 為陣列，元素固定 {"name":"","amount":"","unit":""}。無缺料時 missingIngredients 為 []。
- steps 恰好 3 步，number 從 1 連號。
- difficulty 僅限「簡單」「中等」「困難」。
- preparationTime 格式：「X分鐘」或「X小時Y分鐘」。
- description 30 字內，每步驟 25 字內。
- 不可輸出 null、不可新增未定義欄位。
''';
  }

  Map<String, dynamic> _buildRecipeResponseSchema(int recipeCount) {
    return {
      'type': 'OBJECT',
      'required': ['recipes'],
      'properties': {
        'recipes': {
          'type': 'ARRAY',
          'minItems': recipeCount,
          'maxItems': recipeCount,
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
                'items': _ingredientSchema,
              },
              'missingIngredients': {
                'type': 'ARRAY',
                'items': _ingredientSchema,
              },
              'steps': {
                'type': 'ARRAY',
                'minItems': 3,
                'maxItems': 3,
                'items': _stepSchema,
              },
            },
          },
        },
      },
    };
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
    final now = DateTime.now();

    for (int i = 0; i < recipesJson.length; i++) {
      try {
        final rawMap = recipesJson[i];
        if (rawMap is! Map<String, dynamic>) {
          throw Exception('食譜格式不是物件');
        }
        final recipeMap = _normalizeRecipeMap(rawMap, index: i, now: now);

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

  Map<String, dynamic> _normalizeRecipeMap(
    Map<String, dynamic> rawMap, {
    required int index,
    required DateTime now,
  }) {
    String stringify(dynamic value, {String fallback = ''}) {
      final text = value?.toString().trim() ?? '';
      return text.isEmpty ? fallback : text;
    }

    String normalizeDifficulty(dynamic value) {
      final text = stringify(value, fallback: '中等');
      if (text == '簡單' || text == '中等' || text == '困難') return text;
      return '中等';
    }

    String normalizePreparationTime(dynamic value) {
      final text = stringify(value, fallback: '30分鐘');
      final isValid = RegExp(r'^\d+分鐘$|^\d+小時(\d+分鐘)?$').hasMatch(text);
      return isValid ? text : '30分鐘';
    }

    List<Map<String, dynamic>> normalizeIngredients(dynamic value) {
      final normalized = <Map<String, dynamic>>[];
      if (value is List) {
        for (final item in value) {
          if (item is Map) {
            final name = stringify(item['name']);
            if (name.isEmpty) continue;
            normalized.add({
              'name': name,
              'amount': stringify(item['amount'], fallback: '適量'),
              'unit': stringify(item['unit'], fallback: ''),
            });
          }
        }
      } else if (value is Map) {
        value.forEach((key, rawAmount) {
          final name = key.toString().trim();
          if (name.isEmpty) return;
          normalized.add({
            'name': name,
            'amount': stringify(rawAmount, fallback: '適量'),
            'unit': '',
          });
        });
      }
      return normalized;
    }

    List<Map<String, dynamic>> normalizeSteps(dynamic value) {
      final normalized = <Map<String, dynamic>>[];
      if (value is List) {
        for (int i = 0; i < value.length; i++) {
          final item = value[i];
          if (item is Map) {
            final description = stringify(item['description']);
            if (description.isEmpty) continue;
            final number =
                int.tryParse(item['number']?.toString() ?? '') ?? (i + 1);
            normalized.add({'number': number, 'description': description});
          } else {
            final description = stringify(item);
            if (description.isEmpty) continue;
            normalized.add({'number': i + 1, 'description': description});
          }
        }
      }

      while (normalized.length < 3) {
        final number = normalized.length + 1;
        normalized.add({'number': number, 'description': '步驟$number'});
      }
      return normalized.take(3).toList();
    }

    return {
      'id': stringify(
        rawMap['id'],
        fallback: 'gemini_recipe_${now.millisecondsSinceEpoch}_${index + 1}',
      ),
      'title': stringify(rawMap['title'], fallback: '食譜${index + 1}'),
      'description': stringify(rawMap['description'], fallback: '暫無描述'),
      'preparationTime': normalizePreparationTime(rawMap['preparationTime']),
      'difficulty': normalizeDifficulty(rawMap['difficulty']),
      'requiredIngredients': normalizeIngredients(rawMap['requiredIngredients']),
      'missingIngredients': normalizeIngredients(rawMap['missingIngredients']),
      'steps': normalizeSteps(rawMap['steps']),
      'createdAt': now.toIso8601String(),
      'source': 'Gemini AI',
    };
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
        numberOfRecipes: _fixedRecipeCount,
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
    _resultCache.clear();
    _inflightRequests.clear();
    debugPrint('Gemini 食譜服務已重置');
  }
}

class _CachedRecipeResult {
  final List<Recipe> recipes;
  final DateTime generatedAt;

  _CachedRecipeResult({required this.recipes, required this.generatedAt});
}
