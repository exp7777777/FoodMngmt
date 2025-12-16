import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:google_generative_ai/google_generative_ai.dart';

class GeminiService {
  static GeminiService? _instance;
  static GeminiService get instance {
    _instance ??= GeminiService._();
    return _instance!;
  }

  // 在實際應用中，應該從安全的環境變數或後端服務獲取 API 金鑰
  // 這裡使用一個範例金鑰，請務必替換為您自己的金鑰
  static const String _apiKey = 'YOUR API KEY';

  late GenerativeModel _textModel;
  late GenerativeModel _visionModel;

  // 緩存機制，避免重複調用API
  final Map<String, List<dynamic>> _recipeCache = {};
  final Map<String, DateTime> _cacheTimestamps = {};
  static const Duration _cacheExpiry = Duration(hours: 2);

  GeminiService._() {
    try {
      _initializeModelsSync();
    } catch (e) {
      debugPrint('Gemini 服務初始化失敗: $e');
      rethrow;
    }
  }

  // 生成緩存鍵
  String _getCacheKey(List<Map<String, dynamic>> ingredients) {
    final sortedIngredients =
        ingredients.map((item) {
            final name = item['name'] as String;
            final quantity = item['quantity']?.toString() ?? '1';
            final unit = item['unit'] as String? ?? 'piece';
            return '${name}_${quantity}_${unit}';
          }).toList()
          ..sort();

    final cacheKey = sortedIngredients.join('|');
    debugPrint('生成的緩存鍵: $cacheKey');
    return cacheKey;
  }

  // 檢查緩存是否有效
  bool _isCacheValid(String cacheKey) {
    if (!_cacheTimestamps.containsKey(cacheKey)) return false;
    return DateTime.now().difference(_cacheTimestamps[cacheKey]!) <
        _cacheExpiry;
  }

  // 清空緩存
  void clearCache() {
    _recipeCache.clear();
    _cacheTimestamps.clear();
    debugPrint('食譜緩存已清空');
  }

  void _initializeModelsSync() {
    // 同步初始化，使用預設模型
    try {
      _textModel = GenerativeModel(
        model: 'models/gemini-2.5-pro',
        apiKey: _apiKey,
        generationConfig: GenerationConfig(
          temperature: 0.1, // 降低溫度以提高一致性
          topK: 20, // 減少選擇範圍
          topP: 0.8, // 降低隨機性
          maxOutputTokens: 2048,
        ),
      );

      _visionModel = GenerativeModel(
        model: 'models/gemini-2.5-pro',
        apiKey: _apiKey,
        generationConfig: GenerationConfig(
          temperature: 0.1, // 降低溫度以提高一致性
          topK: 20, // 減少選擇範圍
          topP: 0.8, // 降低隨機性
          maxOutputTokens: 2048,
        ),
      );

      debugPrint('Gemini 服務同步初始化成功');

      // 異步檢查並更新模型
      _initializeModelsAsync();
    } catch (e) {
      debugPrint('Gemini 服務同步初始化失敗: $e');
      // 嘗試使用基本配置
      _setupBasicModels();
    }
  }

  Future<void> _initializeModelsAsync() async {
    try {
      debugPrint('Gemini 服務異步初始化完成');
      // 保持同步初始化時的模型配置
    } catch (e) {
      debugPrint('模型異步初始化失敗: $e');
      // 保持同步初始化時的模型
    }
  }

  void _setupBasicModels() {
    try {
      // 嘗試使用最基本的模型
      _textModel = GenerativeModel(
        model: 'models/gemini-2.5-pro',
        apiKey: _apiKey,
      );
      _visionModel = GenerativeModel(
        model: 'models/gemini-2.5-pro',
        apiKey: _apiKey,
      );
      debugPrint('使用基本模型設定');
    } catch (e) {
      debugPrint('基本模型設定也失敗: $e');
      throw Exception('無法初始化 Gemini 服務: $e');
    }
  }

  // 公開方法供發票服務使用
  Future<String?> generateTextContent(String prompt) async {
    try {
      final response = await _textModel.generateContent([Content.text(prompt)]);

      if (response.text != null) {
        return response.text;
      }

      // 檢查是否有候選回應
      if (response.candidates != null && response.candidates!.isNotEmpty) {
        final candidate = response.candidates!.first;
        if (candidate.content != null) {
          final content = candidate.content!;
          if (content.parts != null && content.parts!.isNotEmpty) {
            final part = content.parts!.first;
            if (part is TextPart) {
              return part.text;
            }
          }
        }
      }

      return null;
    } catch (e) {
      debugPrint('生成文字內容失敗: $e');
      debugPrint('錯誤詳情: ${e.toString()}');
      return null;
    }
  }

  // 生成智慧食譜推薦
  Future<List<dynamic>> generateRecipes(
    List<Map<String, dynamic>> availableIngredients,
  ) async {
    try {
      debugPrint('開始生成食譜推薦，食材數量: ${availableIngredients.length}');

      // 檢查是否已有緩存的食譜結果，避免重複調用API
      final cacheKey = _getCacheKey(availableIngredients);
      debugPrint('檢查緩存，鍵: $cacheKey');
      debugPrint(
        '緩存中已有 ${(_recipeCache.containsKey(cacheKey) ? "有" : "無")} 該鍵的結果',
      );
      if (_recipeCache.containsKey(cacheKey)) {
        debugPrint('緩存時間戳檢查: ${_isCacheValid(cacheKey) ? "有效" : "過期"}');
      }

      if (_recipeCache.containsKey(cacheKey) && _isCacheValid(cacheKey)) {
        debugPrint('使用緩存的食譜結果，共 ${_recipeCache[cacheKey]!.length} 個食譜');
        return _recipeCache[cacheKey]!;
      }

      // 直接使用 Gemini 生成食譜
      final result = await _generateRecipesWithGemini(availableIngredients);

      // 將結果存入緩存（如果有結果）
      if (result.isNotEmpty) {
        _recipeCache[cacheKey] = result;
        _cacheTimestamps[cacheKey] = DateTime.now();
        debugPrint('食譜結果已緩存，鍵: $cacheKey，共 ${result.length} 個食譜');
        debugPrint('當前緩存數量: ${_recipeCache.length}');
      } else {
        debugPrint('結果為空，不緩存');
      }

      return result;
    } catch (e) {
      debugPrint('生成食譜失敗: $e');
      debugPrint('錯誤詳情: ${e.toString()}');
      return [];
    }
  }

  // 使用 Gemini 生成食譜
  Future<List<dynamic>> _generateRecipesWithGemini(
    List<Map<String, dynamic>> availableIngredients,
  ) async {
    try {
      // 建立詳細的食材清單，包含數量和到期資訊
      final ingredientDetails = availableIngredients
          .map((item) {
            final name = item['name'] as String;
            final quantity = item['quantity'] as num;
            final unit = item['unit'] as String;
            return '$name ($quantity$unit)';
          })
          .join(', ');

      // 建立食材庫存摘要，幫助 Gemini 理解食材狀態
      final ingredientSummary = availableIngredients
          .map((item) {
            final name = item['name'] as String;
            final quantity = item['quantity'] as num;
            final unit = item['unit'] as String;
            final expiryDate = item['expiryDate'] as DateTime?;
            final daysUntilExpiry =
                expiryDate != null
                    ? DateTime.now().difference(expiryDate).inDays.abs()
                    : null;

            String status = '';
            if (daysUntilExpiry != null) {
              if (daysUntilExpiry <= 1) {
                status = ' (即將到期)';
              } else if (daysUntilExpiry <= 3) {
                status = ' (建議優先使用)';
              }
            }

            return '$name: $quantity$unit$status';
          })
          .join('\n');

      final prompt = '''
你是一個專業的廚師助手。根據以下食材庫存，請生成 10 個創意且實用的食譜：

【可用食材庫存】
$ingredientSummary

【食材清單摘要】
$ingredientDetails

重要規則：
1. 每個食譜至少使用庫存中的 1-2 種食材即可，不必全部使用
2. 請優先使用即將到期的食材作為主要食材
3. 食譜應該簡單實用，適合家庭料理
4. 可以建議適量的額外調味料（鹽、油等基本調味品）

請為每個食譜提供：
1. 食譜名稱（繁體中文）
2. 所需食材（必須從庫存中選擇，標明具體數量）
3. 簡單的烹飪步驟（3-5步）
4. 預估烹飪時間
5. 建議難度等級（簡單/中等/困難）

【重要】請嚴格按照以下 JSON 格式回應，不要添加任何其他文字、說明或標記：
{
  "recipes": [
    {
      "title": "食譜名稱",
      "requiredItems": {
        "食材名稱1": "數量單位1",
        "食材名稱2": "數量單位2"
      },
      "steps": [
        "步驟1",
        "步驟2",
        "步驟3"
      ],
      "cookingTime": "預估時間",
      "difficulty": "簡單"
    },
    {
      "title": "食譜名稱2",
      "requiredItems": {
        "食材名稱": "數量單位"
      },
      "steps": [
        "步驟1",
        "步驟2"
      ],
      "cookingTime": "預估時間",
      "difficulty": "中等"
    }
  ]
}

請確保：
- JSON 格式完全正確
- 不要使用 markdown 代碼塊標記（```json 或 ```）
- 不要添加任何解釋文字
- 每個食譜的 requiredItems 和 steps 都是陣列格式
- 難度只能是：簡單、中等、困難
- 烹飪時間格式如：15分鐘、30分鐘等
''';

      try {
        debugPrint('開始調用 Gemini API，提示長度: ${prompt.length}');
        final response = await _textModel.generateContent([
          Content.text(prompt),
        ]);

        debugPrint(
          '收到 Gemini API 回應，狀態: ${response.text != null ? '成功' : '失敗'}',
        );

        // 檢查回應是否有效
        if (response.text != null && response.text!.isNotEmpty) {
          debugPrint('回應內容長度: ${response.text!.length}');
          debugPrint(
            '回應內容預覽: ${response.text!.substring(0, min(200, response.text!.length))}',
          );
          return _parseRecipeResponse(response.text!);
        }

        // 檢查是否有候選回應
        if (response.candidates != null && response.candidates!.isNotEmpty) {
          final candidate = response.candidates!.first;
          if (candidate.content != null) {
            final content = candidate.content!;
            if (content.parts != null && content.parts!.isNotEmpty) {
              final part = content.parts!.first;
              if (part is TextPart && part.text.isNotEmpty) {
                return _parseRecipeResponse(part.text);
              }
            }
          }
        }

        // 如果沒有有效的回應，返回空清單並嘗試備用方法
        debugPrint('Gemini 回應無效，嘗試備用方法');
        return await _generateRecipesFallback(availableIngredients);
      } catch (e) {
        debugPrint('Gemini 生成食譜失敗: $e');
        debugPrint('錯誤詳情: ${e.toString()}');

        // 嘗試獲取回應內容進行除錯
        try {
          final response = await _textModel.generateContent([
            Content.text('測試'),
          ]);
          if (response.text != null) {
            debugPrint('Gemini API 測試回應: ${response.text}');
          }
        } catch (testError) {
          debugPrint('Gemini API 測試失敗: $testError');
        }

        // 檢查各種可能的錯誤模式
        final errorString = e.toString().toLowerCase();
        if (errorString.contains('quota exceeded') ||
            errorString.contains('rate limit') ||
            errorString.contains('billing') ||
            errorString.contains('limit')) {
          debugPrint('偵測到配額超限錯誤，直接使用預設食譜');
          return _getDefaultRecipes(availableIngredients);
        } else if (errorString.contains('role: model') ||
            errorString.contains('unhandled format') ||
            errorString.contains('content') ||
            errorString.contains('null')) {
          debugPrint('偵測到 Gemini API 錯誤，嘗試備用方法');
          return await _generateRecipesFallback(availableIngredients);
        }

        // 嘗試使用備用方法
        debugPrint('嘗試使用備用食譜生成方法');
        return await _generateRecipesFallback(availableIngredients);
      }
    } catch (e) {
      debugPrint('Gemini 生成食譜失敗: $e');
      debugPrint('錯誤詳情: ${e.toString()}');
      return [];
    }
  }

  // 備用食譜生成方法
  Future<List<dynamic>> _generateRecipesFallback(
    List<Map<String, dynamic>> availableIngredients,
  ) async {
    try {
      debugPrint('使用備用食譜生成方法');

      // 檢查是否已有緩存的備用結果
      final cacheKey = _getCacheKey(availableIngredients);
      if (_recipeCache.containsKey(cacheKey) && _isCacheValid(cacheKey)) {
        debugPrint('使用緩存的備用食譜結果');
        return _recipeCache[cacheKey]!;
      }

      // 建立簡單的食材清單
      final ingredientNames = availableIngredients
          .map((item) => item['name'] as String)
          .join(', ');

      final prompt = '''請根據食材：$ingredientNames

生成10個簡單食譜，每個食譜只需要使用1種食材。

請用JSON格式回應，格式如下：
{"recipes":[{"title":"食譜名稱","requiredItems":{"食材名稱":"數量"},"steps":["步驟1","步驟2"],"cookingTime":"15分鐘","difficulty":"簡單"}]}

規則：
- 只使用食材庫中的食材
- 每個食譜只用1種食材
- 步驟3-4步
- 時間15-30分鐘
- 難度都是"簡單"''';

      debugPrint('備用方法提示：$prompt');

      try {
        debugPrint('開始調用 Gemini API 備用方法，提示長度: ${prompt.length}');
        final response = await _textModel.generateContent([
          Content.text(prompt),
        ]);

        debugPrint('收到備用方法回應，狀態: ${response.text != null ? '成功' : '失敗'}');

        if (response.text != null && response.text!.isNotEmpty) {
          debugPrint('備用回應內容長度: ${response.text!.length}');
          debugPrint(
            '備用回應內容預覽: ${response.text!.substring(0, min(200, response.text!.length))}',
          );
          debugPrint('嘗試解析備用回應...');
          final result = _parseRecipeResponse(response.text!);
          debugPrint('備用方法解析結果: ${result.length} 個食譜');

          // 將備用結果也存入緩存
          if (result.isNotEmpty) {
            final cacheKey = _getCacheKey(availableIngredients);
            _recipeCache[cacheKey] = result;
            _cacheTimestamps[cacheKey] = DateTime.now();
            debugPrint('備用食譜結果已緩存');
          }

          return result;
        }

        // 檢查候選回應
        if (response.candidates != null && response.candidates!.isNotEmpty) {
          final candidate = response.candidates!.first;
          if (candidate.content != null) {
            final content = candidate.content!;
            if (content.parts != null && content.parts!.isNotEmpty) {
              final part = content.parts!.first;
              if (part is TextPart) {
                final result = _parseRecipeResponse(part.text);

                // 將備用結果也存入緩存
                if (result.isNotEmpty) {
                  final cacheKey = _getCacheKey(availableIngredients);
                  _recipeCache[cacheKey] = result;
                  _cacheTimestamps[cacheKey] = DateTime.now();
                  debugPrint('備用食譜結果已緩存（候選回應）');
                }

                return result;
              }
            }
          }
        }

        return [];
      } catch (e) {
        debugPrint('備用食譜生成失敗: $e');
        debugPrint('錯誤詳情: ${e.toString()}');

        // 嘗試獲取回應內容進行除錯
        try {
          final response = await _textModel.generateContent([
            Content.text('測試'),
          ]);
          if (response.text != null) {
            debugPrint('Gemini API 測試回應: ${response.text}');
          }
        } catch (testError) {
          debugPrint('Gemini API 測試失敗: $testError');
        }

        // 檢查各種可能的錯誤模式
        final errorString = e.toString().toLowerCase();
        if (errorString.contains('quota exceeded') ||
            errorString.contains('rate limit') ||
            errorString.contains('billing') ||
            errorString.contains('limit')) {
          debugPrint('備用方法也偵測到配額超限，返回預設食譜');
          return _getDefaultRecipes(availableIngredients);
        } else if (errorString.contains('role: model') ||
            errorString.contains('unhandled format') ||
            errorString.contains('content') ||
            errorString.contains('null')) {
          debugPrint('備用方法偵測到其他錯誤，返回預設食譜');
          return _getDefaultRecipes(availableIngredients);
        }

        return [];
      }
    } catch (e) {
      debugPrint('備用食譜生成失敗: $e');
      debugPrint('錯誤詳情: ${e.toString()}');
      return [];
    }
  }

  // 預設食譜（當所有方法都失敗時使用）
  List<Map<String, dynamic>> _getDefaultRecipes(
    List<Map<String, dynamic>> availableIngredients,
  ) {
    try {
      debugPrint('使用預設食譜');

      final ingredientNames =
          availableIngredients.map((item) => item['name'] as String).toList();

      final recipes = <Map<String, dynamic>>[];

      // 根據食材生成創意預設食譜
      if (ingredientNames.isNotEmpty) {
        // 檢查特定食材組合
        if (ingredientNames.contains('草莓') && ingredientNames.contains('西瓜')) {
          recipes.add({
            'title': '草莓西瓜冰沙',
            'steps': ['將西瓜切塊放入果汁機', '加入草莓和適量冰塊', '攪打至均勻', '倒入杯中即可享用'],
            'requiredItems': {'草莓': '100g', '西瓜': '200g', '冰塊': '適量'},
            'cookingTime': '10分鐘',
            'difficulty': '簡單',
          });
        }

        if (ingredientNames.contains('奶油')) {
          recipes.add({
            'title': '奶油吐司',
            'steps': ['將吐司放入烤箱烤至金黃', '塗抹奶油', '可選擇加入果醬或蜂蜜'],
            'requiredItems': {'奶油': '適量', '吐司': '2片'},
            'cookingTime': '5分鐘',
            'difficulty': '簡單',
          });
        }

        if (ingredientNames.contains('草莓') && ingredientNames.contains('奶油')) {
          recipes.add({
            'title': '草莓奶油杯',
            'steps': ['將草莓洗淨切片', '在杯中鋪一層奶油', '加入草莓片', '重複層次直到裝滿', '冷藏30分鐘後享用'],
            'requiredItems': {'草莓': '150g', '奶油': '100g'},
            'cookingTime': '15分鐘',
            'difficulty': '簡單',
          });
        }

        // 如果沒有特定組合或食譜數量不足，生成更多通用食譜
        if (recipes.isEmpty || recipes.length < 10) {
          final mainIngredient =
              ingredientNames.isNotEmpty ? ingredientNames.first : '食材';

          // 基本食譜
          if (recipes.length < 10) {
            recipes.add({
              'title': '${mainIngredient}沙拉',
              'steps': ['將${mainIngredient}洗淨切塊', '加入適量調味料', '拌勻後即可享用'],
              'requiredItems': {mainIngredient: '適量'},
              'cookingTime': '10分鐘',
              'difficulty': '簡單',
            });
          }

          if (ingredientNames.length > 1 && recipes.length < 10) {
            final secondIngredient = ingredientNames[1];
            recipes.add({
              'title': '${mainIngredient}炒${secondIngredient}',
              'steps': [
                '熱鍋下油',
                '先加入${mainIngredient}翻炒',
                '再加入${secondIngredient}一起炒',
                '調味後即可起鍋',
              ],
              'requiredItems': {mainIngredient: '適量', secondIngredient: '適量'},
              'cookingTime': '12分鐘',
              'difficulty': '簡單',
            });
          }

          // 添加更多樣化的食譜選項
          if (recipes.length < 10) {
            recipes.add({
              'title': '${mainIngredient}湯品',
              'steps': [
                '將${mainIngredient}洗淨切塊',
                '加入熱水煮沸',
                '煮至軟爛後調味',
                '熱騰騰的湯品完成',
              ],
              'requiredItems': {mainIngredient: '適量'},
              'cookingTime': '20分鐘',
              'difficulty': '簡單',
            });
          }

          if (ingredientNames.length >= 2 && recipes.length < 10) {
            recipes.add({
              'title': '${ingredientNames[0]}與${ingredientNames[1]}燉煮',
              'steps': ['將所有食材洗淨切塊', '放入鍋中加水燉煮', '煮至食材軟爛', '調味後即可食用'],
              'requiredItems': {
                ingredientNames[0]: '適量',
                ingredientNames[1]: '適量',
              },
              'cookingTime': '25分鐘',
              'difficulty': '簡單',
            });
          }

          // 添加更多創意食譜以達到10個
          if (recipes.length < 10 && ingredientNames.length >= 1) {
            recipes.add({
              'title': '${mainIngredient}涼拌',
              'steps': [
                '將${mainIngredient}洗淨切絲',
                '加入調味醬汁',
                '拌勻後冷藏片刻',
                '清爽涼拌菜完成',
              ],
              'requiredItems': {mainIngredient: '適量'},
              'cookingTime': '8分鐘',
              'difficulty': '簡單',
            });
          }

          if (recipes.length < 10 && ingredientNames.length >= 2) {
            recipes.add({
              'title': '${ingredientNames[0]}煎${ingredientNames[1]}',
              'steps': [
                '將${ingredientNames[1]}切片',
                '熱鍋下油',
                '放入${ingredientNames[0]}和${ingredientNames[1]}煎至金黃',
                '調味後即可食用',
              ],
              'requiredItems': {
                ingredientNames[0]: '適量',
                ingredientNames[1]: '適量',
              },
              'cookingTime': '15分鐘',
              'difficulty': '簡單',
            });
          }

          // 繼續添加食譜直到達到10個
          for (
            int i = recipes.length;
            i < 10 && i < ingredientNames.length * 2;
            i++
          ) {
            final ingredient = ingredientNames[i % ingredientNames.length];
            final recipeTypes = ['烤', '蒸', '燜', '滷', '拌'];
            final type = recipeTypes[i % recipeTypes.length];

            recipes.add({
              'title': '${ingredient}${type}製',
              'steps': [
                '將${ingredient}處理乾淨',
                '用${type}的方式烹調',
                '調味並烹飪至熟',
                '${type}製${ingredient}完成',
              ],
              'requiredItems': {ingredient: '適量'},
              'cookingTime': '${15 + (i % 3) * 5}分鐘',
              'difficulty': '簡單',
            });
          }
        }
      }

      debugPrint('生成 ${recipes.length} 個預設食譜');
      return recipes;
    } catch (e) {
      debugPrint('生成預設食譜失敗: $e');
      return [];
    }
  }

  // 辨識食物圖片
  // 重試配置
  static const int _maxRetries = 3;
  static const Duration _initialRetryDelay = Duration(seconds: 2);
  static const double _retryBackoffMultiplier = 2.0;

  /// 帶重試機制的食物辨識
  Future<Map<String, dynamic>> identifyFood(File imageFile) async {
    int retryCount = 0;
    Duration currentDelay = _initialRetryDelay;

    while (retryCount <= _maxRetries) {
      try {
        debugPrint(
          '開始辨識圖片 (嘗試 ${retryCount + 1}/${_maxRetries + 1}): ${imageFile.path}',
        );

        final result = await _identifyFoodWithTimeout(imageFile);
        return result;
      } catch (e) {
        final errorString = e.toString();
        debugPrint(
          '食物辨識失敗 (嘗試 ${retryCount + 1}/${_maxRetries + 1}): $errorString',
        );

        // 檢查是否為可重試的錯誤
        final isRetryableError = _isRetryableError(errorString);

        if (isRetryableError && retryCount < _maxRetries) {
          retryCount++;
          debugPrint('等待 ${currentDelay.inSeconds} 秒後重試...');
          await Future.delayed(currentDelay);
          // 指數退避
          currentDelay = Duration(
            milliseconds:
                (currentDelay.inMilliseconds * _retryBackoffMultiplier).toInt(),
          );
        } else {
          // 不可重試的錯誤或已達最大重試次數
          debugPrint('無法重試或已達最大重試次數，返回錯誤');
          return {
            'success': false,
            'items': [],
            'error': _formatErrorMessage(errorString),
          };
        }
      }
    }

    // 理論上不會到這裡，但為了安全起見
    return {'success': false, 'items': [], 'error': '達到最大重試次數，辨識失敗'};
  }

  /// 檢查錯誤是否可以重試
  bool _isRetryableError(String errorString) {
    // 檢查是否為配額限制錯誤（不應該立即重試）
    if (errorString.contains('quota') ||
        errorString.contains('Quota exceeded') ||
        errorString.contains('exceeded your current quota')) {
      return false; // 配額錯誤不重試，需要等待或升級
    }

    return errorString.contains('503') || // 服務過載
        errorString.contains('UNAVAILABLE') || // 服務不可用
        errorString.contains('429') || // 請求過多
        errorString.contains('RESOURCE_EXHAUSTED') || // 資源耗盡
        errorString.contains('500') || // 伺服器錯誤
        errorString.contains('INTERNAL') || // 內部錯誤
        errorString.contains('DEADLINE_EXCEEDED') || // 超時
        errorString.contains('timeout'); // 超時
  }

  /// 格式化錯誤訊息，讓使用者更容易理解
  String _formatErrorMessage(String errorString) {
    // 配額限制錯誤
    if (errorString.contains('quota') ||
        errorString.contains('Quota exceeded') ||
        errorString.contains('exceeded your current quota')) {
      // 嘗試提取等待時間
      final retryMatch = RegExp(
        r'retry in (\d+\.?\d*)',
      ).firstMatch(errorString);
      if (retryMatch != null) {
        final seconds = double.tryParse(retryMatch.group(1) ?? '0') ?? 0;
        final waitTime =
            seconds > 60
                ? '${(seconds / 60).ceil()} 分鐘'
                : '${seconds.ceil()} 秒';
        return 'API 使用額度已達上限，請等待 $waitTime 後再試，或升級至付費方案';
      }
      return 'API 使用額度已達上限，請稍後再試或升級至付費方案';
    }

    // 其他錯誤類型
    if (errorString.contains('503') || errorString.contains('UNAVAILABLE')) {
      return '服務暫時過載，請稍後再試';
    } else if (errorString.contains('429') ||
        errorString.contains('RESOURCE_EXHAUSTED')) {
      return '請求次數過多，請稍後再試';
    } else if (errorString.contains('DEADLINE_EXCEEDED') ||
        errorString.contains('timeout')) {
      return '請求超時，請檢查網路連線';
    } else if (errorString.contains('500') ||
        errorString.contains('INTERNAL')) {
      return '伺服器發生錯誤，請稍後再試';
    } else {
      return '辨識失敗：$errorString';
    }
  }

  /// 帶超時控制的食物辨識
  Future<Map<String, dynamic>> _identifyFoodWithTimeout(File imageFile) async {
    return await _identifyFoodCore(imageFile).timeout(
      const Duration(seconds: 30),
      onTimeout: () {
        debugPrint('辨識請求超時');
        throw TimeoutException('辨識請求超時，請檢查網路連線');
      },
    );
  }

  /// 核心辨識邏輯
  Future<Map<String, dynamic>> _identifyFoodCore(File imageFile) async {
    try {
      final imageBytes = await imageFile.readAsBytes();
      debugPrint('圖片大小: ${imageBytes.length} bytes');

      // 檢查圖片大小，如果過大則壓縮
      if (imageBytes.length > 4 * 1024 * 1024) {
        debugPrint('圖片過大，建議壓縮後再辨識');
        return {
          'success': false,
          'items': [],
          'error': '圖片檔案過大（超過4MB），請選擇較小的圖片',
        };
      }

      final prompt = '''
請仔細觀察這張圖片，辨識出所有可見的食物食材，並分析每個食物的分類。

要求：
1. 只辨識食物相關的物品，不要包含容器、餐具、包裝或其他非食物物品
2. 請用準確的繁體中文食物名稱描述
3. 如果有多個相同食物，請列出具體數量或規格（如：香蕉 2根、牛奶 500ml）
4. 優先辨識主要的食物項目，忽略背景或不相關的物品
5. 為每個食物標註所屬分類（蔬菜、水果、肉類、海鮮、乳製品、飲料、調味料、穀物、豆類、其他）

請務必用以下 JSON 格式回應，不要包含其他文字：
{
  "foods": [
    {
      "name": "食物名稱",
      "category": "分類"
    }
  ]
}

正確範例：
{
  "foods": [
    {"name": "蘋果", "category": "水果"},
    {"name": "香蕉 2根", "category": "水果"},
    {"name": "牛奶 500ml", "category": "乳製品"},
    {"name": "雞蛋 6個", "category": "其他"},
    {"name": "白米 1kg", "category": "穀物"},
    {"name": "番茄", "category": "蔬菜"},
    {"name": "豬肉", "category": "肉類"}
  ]
}

錯誤範例（請避免）：
- 任何包含 "我看到" 或 "圖片中有" 的敘述
- 任何不是 JSON 格式的回應
- 任何包含解釋或分析的回應
- 回應格式與範例不符
''';

      debugPrint('發送 Gemini Vision API 請求...');
      final response = await _visionModel.generateContent([
        Content.multi([TextPart(prompt), DataPart('image/jpeg', imageBytes)]),
      ]);

      debugPrint('收到回應，狀態: ${response.text != null ? '成功' : '失敗'}');

      if (response.text != null) {
        debugPrint('回應內容: ${response.text}');
        final result = _parseFoodIdentificationResponse(response.text!);
        debugPrint('解析結果: $result');
        return result;
      }

      // 檢查是否有候選回應
      if (response.candidates != null && response.candidates!.isNotEmpty) {
        final candidate = response.candidates!.first;
        if (candidate.content != null) {
          final content = candidate.content!;
          if (content.parts != null && content.parts!.isNotEmpty) {
            final part = content.parts!.first;
            if (part is TextPart) {
              debugPrint('候選回應內容: ${part.text}');
              final result = _parseFoodIdentificationResponse(part.text);
              debugPrint('解析結果: $result');
              return result;
            }
          }
        }
      }

      debugPrint('回應為空');
      return {'success': false, 'items': [], 'error': '回應為空'};
    } catch (e) {
      debugPrint('食物辨識核心邏輯失敗: $e');
      debugPrint('錯誤詳情: ${e.toString()}');
      final exists = await imageFile.exists();
      debugPrint('圖片路徑: ${imageFile.path}, 存在: $exists');
      rethrow; // 重新拋出異常，讓外層的重試邏輯處理
    }
  }

  // 生成智慧購物建議
  Future<List<String>> generateShoppingSuggestions(
    List<Map<String, dynamic>> availableIngredients,
    List<String> shoppingList,
  ) async {
    try {
      final availableItems = availableIngredients
          .map((item) => item['name'] as String)
          .join(', ');
      final shoppingItems = shoppingList.join(', ');

      final prompt = '''
你是一個智慧購物助手。根據以下資訊，請提供購物建議：

可用食材：$availableItems
現有購物清單：$shoppingItems

請提供以下建議：
1. 根據可用食材建議還需要購買哪些食材來補充營養均衡
2. 考慮季節性和價格因素的建議
3. 建議的購買優先順序

請用 JSON 格式回應：
{
  "suggestions": [
    "建議1: 購買某些食材的原因",
    "建議2: 購買某些食材的原因",
    "建議3: 購買某些食材的原因"
  ],
  "priorityItems": ["優先購買的食材1", "優先購買的食材2"]
}
''';

      try {
        final response = await _textModel.generateContent([
          Content.text(prompt),
        ]);

        if (response.text != null) {
          return _parseShoppingSuggestionsResponse(response.text!);
        }

        // 檢查是否有候選回應
        if (response.candidates != null && response.candidates!.isNotEmpty) {
          final candidate = response.candidates!.first;
          if (candidate.content != null) {
            final content = candidate.content!;
            if (content.parts != null && content.parts!.isNotEmpty) {
              final part = content.parts!.first;
              if (part is TextPart) {
                return _parseShoppingSuggestionsResponse(part.text);
              }
            }
          }
        }

        return [];
      } catch (e) {
        debugPrint('生成購物建議失敗: $e');
        debugPrint('錯誤詳情: ${e.toString()}');

        // 如果遇到 {role: model} 錯誤，返回預設建議
        if (e.toString().contains('role: model')) {
          debugPrint('返回預設購物建議');
          return [];
        }

        return [];
      }
    } catch (e) {
      debugPrint('生成購物建議失敗: $e');
      debugPrint('錯誤詳情: ${e.toString()}');
      return [];
    }
  }

  // 分析食材營養價值
  Future<Map<String, dynamic>> analyzeNutrition(
    List<Map<String, dynamic>> foods,
  ) async {
    try {
      final foodList = foods
          .map((item) => '${item['name']} ${item['quantity']}${item['unit']}')
          .join(', ');

      final prompt = '''
請分析以下食材的營養價值：

食材：$foodList

請提供：
1. 主要營養成分分析
2. 熱量估計
3. 營養均衡建議
4. 健康飲食建議

請用 JSON 格式回應：
{
  "nutrition": "營養成分分析",
  "calories": "熱量估計",
  "balance": "營養均衡建議",
  "healthTips": "健康飲食建議"
}
''';

      try {
        final response = await _textModel.generateContent([
          Content.text(prompt),
        ]);

        if (response.text != null) {
          return _parseNutritionResponse(response.text!);
        }

        // 檢查候選回應
        if (response.candidates != null && response.candidates!.isNotEmpty) {
          final candidate = response.candidates!.first;
          if (candidate.content != null) {
            final content = candidate.content!;
            if (content.parts != null && content.parts!.isNotEmpty) {
              final part = content.parts!.first;
              if (part is TextPart) {
                return _parseNutritionResponse(part.text);
              }
            }
          }
        }

        return {};
      } catch (e) {
        debugPrint('營養分析失敗: $e');
        debugPrint('錯誤詳情: ${e.toString()}');

        // 如果遇到 {role: model} 錯誤，返回預設分析
        if (e.toString().contains('role: model')) {
          return {
            'analysis': '營養成分分析暫時無法提供',
            'calories': '熱量估算暫時無法提供',
            'suggestions': ['建議均衡飲食', '多攝取蔬果'],
          };
        }

        return {};
      }
    } catch (e) {
      debugPrint('營養分析失敗: $e');
      return {};
    }
  }

  // 解析食譜回應
  List<Map<String, dynamic>> _parseRecipeResponse(String response) {
    try {
      debugPrint('原始食譜回應: $response');

      // 嘗試多種解析方法
      List<Map<String, dynamic>> recipes = [];

      // 方法1: 嘗試解析完整的 JSON
      try {
        recipes = _parseCompleteJson(response);
        if (recipes.isNotEmpty) {
          debugPrint('成功解析完整 JSON，獲得 ${recipes.length} 個食譜');
          return recipes;
        }
      } catch (e) {
        debugPrint('完整 JSON 解析失敗: $e');
      }

      // 方法2: 嘗試解析部分 JSON
      try {
        recipes = _parsePartialJson(response);
        if (recipes.isNotEmpty) {
          debugPrint('成功解析部分 JSON，獲得 ${recipes.length} 個食譜');
          return recipes;
        }
      } catch (e) {
        debugPrint('部分 JSON 解析失敗: $e');
      }

      // 方法3: 嘗試文字解析
      try {
        recipes = _parseTextResponse(response);
        if (recipes.isNotEmpty) {
          debugPrint('成功解析文字回應，獲得 ${recipes.length} 個食譜');
          return recipes;
        }
      } catch (e) {
        debugPrint('文字解析失敗: $e');
      }

      debugPrint('所有解析方法都失敗');
      return [];
    } catch (e) {
      debugPrint('解析食譜回應失敗: $e');
      debugPrint('回應內容: $response');
      return [];
    }
  }

  // 解析完整 JSON
  List<Map<String, dynamic>> _parseCompleteJson(String response) {
    debugPrint('嘗試解析完整 JSON，回應長度: ${response.length}');
    String cleanResponse = response.trim();

    try {
      // 移除 markdown 格式
      cleanResponse = cleanResponse
          .replaceAll('```json', '')
          .replaceAll('```', '')
          .replaceAll('```dart', '');

      debugPrint('清理後的回應長度: ${cleanResponse.length}');

      // 尋找 JSON 部分
      final jsonStart = cleanResponse.indexOf('{');
      final jsonEnd = cleanResponse.lastIndexOf('}');

      if (jsonStart != -1 && jsonEnd != -1 && jsonEnd > jsonStart) {
        cleanResponse = cleanResponse.substring(jsonStart, jsonEnd + 1);
        debugPrint('提取的 JSON 長度: ${cleanResponse.length}');
      }

      debugPrint('最終 JSON 內容: $cleanResponse');

      final data = json.decode(cleanResponse);
      final recipes = data['recipes'] as List<dynamic>? ?? [];

      debugPrint('解析出 ${recipes.length} 個食譜');

      return recipes.map((recipe) {
        return {
          'title': recipe['title'] ?? '未知食譜',
          'steps': List<String>.from(recipe['steps'] ?? []),
          'requiredItems': Map<String, String>.from(
            recipe['requiredItems'] ?? {},
          ),
          'missingItems': <String, String>{},
          'cookingTime': recipe['cookingTime'] ?? '15分鐘',
          'difficulty': recipe['difficulty'] ?? '簡單',
        };
      }).toList();
    } catch (e) {
      debugPrint('完整 JSON 解析失敗: $e');
      debugPrint('失敗的內容: $cleanResponse');
      return [];
    }
  }

  // 解析部分 JSON（當 JSON 不完整時）
  List<Map<String, dynamic>> _parsePartialJson(String response) {
    final recipes = <Map<String, dynamic>>[];

    // 尋找食譜區塊
    final recipePattern = RegExp(r'\{[^}]*"title":\s*"([^"]+)"[^}]*\}');
    final recipeMatches = recipePattern.allMatches(response);

    for (final match in recipeMatches) {
      final recipeBlock = match.group(0);
      if (recipeBlock != null) {
        try {
          // 嘗試解析單個食譜區塊
          final recipeData = json.decode(recipeBlock);
          if (recipeData is Map<String, dynamic>) {
            recipes.add({
              'title': recipeData['title'] ?? '未知食譜',
              'steps': List<String>.from(
                recipeData['steps'] ?? ['請參考食譜標題進行製作'],
              ),
              'requiredItems': Map<String, String>.from(
                recipeData['requiredItems'] ?? {'食材': '適量'},
              ),
              'missingItems': <String, String>{},
              'cookingTime': recipeData['cookingTime'] ?? '15分鐘',
              'difficulty': recipeData['difficulty'] ?? '簡單',
            });
          }
        } catch (e) {
          // 如果解析失敗，嘗試提取標題
          final titleMatch = RegExp(
            r'"title":\s*"([^"]+)"',
          ).firstMatch(recipeBlock);
          if (titleMatch != null) {
            final title = titleMatch.group(1);
            if (title != null && title.isNotEmpty) {
              recipes.add({
                'title': title,
                'steps': ['請參考食譜標題進行製作'],
                'requiredItems': {'食材': '適量'},
                'missingItems': <String, String>{},
                'cookingTime': '15分鐘',
                'difficulty': '簡單',
              });
            }
          }
        }
      }
    }

    // 如果沒有找到完整的食譜區塊，嘗試提取標題
    if (recipes.isEmpty) {
      final titlePattern = RegExp(r'"title":\s*"([^"]+)"');
      final titleMatches = titlePattern.allMatches(response);

      for (final match in titleMatches) {
        final title = match.group(1);
        if (title != null && title.isNotEmpty) {
          recipes.add({
            'title': title,
            'steps': ['請參考食譜標題進行製作'],
            'requiredItems': {'食材': '適量'},
            'missingItems': <String, String>{},
            'cookingTime': '15分鐘',
            'difficulty': '簡單',
          });
        }
      }
    }

    return recipes;
  }

  // 解析文字回應
  List<Map<String, dynamic>> _parseTextResponse(String response) {
    final recipes = <Map<String, dynamic>>[];

    // 尋找可能的食譜標題（中文）
    final lines = response.split('\n');
    String? currentTitle;
    final steps = <String>[];

    for (final line in lines) {
      final trimmedLine = line.trim();

      // 檢查是否為食譜標題
      if (trimmedLine.contains('食譜') ||
          trimmedLine.contains('汁') ||
          trimmedLine.contains('冰棒') ||
          trimmedLine.contains('沙拉') ||
          (trimmedLine.length > 5 &&
              trimmedLine.length < 20 &&
              !trimmedLine.contains('：'))) {
        // 保存上一個食譜
        if (currentTitle != null) {
          recipes.add({
            'title': currentTitle,
            'steps': steps.isNotEmpty ? steps : ['請參考食譜標題進行製作'],
            'requiredItems': {'食材': '適量'},
            'missingItems': <String, String>{},
            'cookingTime': '15分鐘',
            'difficulty': '簡單',
          });
        }

        // 開始新食譜
        currentTitle = trimmedLine;
        steps.clear();
      } else if (trimmedLine.isNotEmpty &&
          !trimmedLine.startsWith('{') &&
          !trimmedLine.startsWith('}')) {
        // 可能是步驟
        if (trimmedLine.length > 10) {
          steps.add(trimmedLine);
        }
      }
    }

    // 保存最後一個食譜
    if (currentTitle != null) {
      recipes.add({
        'title': currentTitle,
        'steps': steps.isNotEmpty ? steps : ['請參考食譜標題進行製作'],
        'requiredItems': {'食材': '適量'},
        'missingItems': <String, String>{},
        'cookingTime': '15分鐘',
        'difficulty': '簡單',
      });
    }

    return recipes;
  }

  // 解析食物辨識回應
  Map<String, dynamic> _parseFoodIdentificationResponse(String response) {
    try {
      debugPrint('原始回應: $response');

      // 清理回應，移除可能的 markdown 格式
      String cleanResponse = response.trim();

      // 移除可能的 markdown 代碼區塊標記
      cleanResponse = cleanResponse
          .replaceAll('```json', '')
          .replaceAll('```', '');

      // 嘗試解析 JSON
      final data = json.decode(cleanResponse);

      // 檢查是否為正確的格式
      if (data is Map && data.containsKey('foods')) {
        final foods = data['foods'];
        if (foods is List) {
          final result = _parseFoodItems(foods);
          debugPrint('JSON 解析成功，找到 ${result.length} 個食物項目');
          return {'success': true, 'items': result};
        }
      }

      // 如果不是標準格式，嘗試其他解析方式
      debugPrint('嘗試備用解析方式...');

      final result = _parseFoodItemsFromText(cleanResponse);

      if (result.isNotEmpty) {
        debugPrint('備用解析成功，找到 ${result.length} 個食物項目');
        return {'success': true, 'items': result};
      }

      debugPrint('無法解析食物辨識回應');
      return {'success': false, 'items': []};
    } catch (e) {
      debugPrint('解析食物辨識回應失敗: $e');
      debugPrint('回應內容: $response');
      return {'success': false, 'items': []};
    }
  }

  // 解析食物項目列表
  List<Map<String, dynamic>> _parseFoodItems(List foods) {
    final result = <Map<String, dynamic>>[];

    for (final food in foods) {
      // 檢查是否為新格式（包含 name 和 category 的對象）
      if (food is Map) {
        final name = food['name']?.toString().trim() ?? '';
        final category = food['category']?.toString().trim() ?? '其他';

        if (name.isNotEmpty && !_isNonFoodWord(name)) {
          final item = _parseSingleFoodItem(name);
          if (item != null) {
            item['category'] = category;
            result.add(item);
          }
        }
      } else {
        // 舊格式（純字符串）
        final item = _parseSingleFoodItem(food.toString());
        if (item != null) {
          // 沒有分類資訊時使用預設值
          item['category'] = '其他';
          result.add(item);
        }
      }
    }

    return result;
  }

  // 從文字中解析食物項目
  List<Map<String, dynamic>> _parseFoodItemsFromText(String text) {
    final result = <Map<String, dynamic>>[];

    // 尋找包含數量和單位的模式
    final patterns = [
      // 模式1: "蘋果 2個"
      RegExp(r'([^\d]+?)\s*(\d+)\s*([^\d\s]+)'),
      // 模式2: "牛奶 500ml"
      RegExp(r'([^\d]+?)\s*(\d+(?:\.\d+)?)\s*([^\d\s]+)'),
      // 模式3: "香蕉 3根"
      RegExp(r'([^\d]+?)\s*(\d+)\s*([^\d\s]+)'),
      // 模式4: 只有名稱
      RegExp(r'([^\d\s,]+)'),
    ];

    for (final pattern in patterns) {
      final matches = pattern.allMatches(text);

      for (final match in matches) {
        if (match.groupCount >= 1) {
          final name = match.group(1)?.trim() ?? '';
          final quantity = match.groupCount >= 2 ? match.group(2) : null;
          final unit = match.groupCount >= 3 ? match.group(3)?.trim() : null;

          if (name.isNotEmpty && !_isNonFoodWord(name)) {
            result.add({
              'name': name,
              'quantity': quantity != null ? int.tryParse(quantity) ?? 1 : 1,
              'unit': unit ?? '個',
              'category': '其他', // 備用解析無法獲得分類，使用預設值
            });
          }
        }
      }

      if (result.isNotEmpty) break; // 找到結果就停止
    }

    return result;
  }

  // 解析單個食物項目
  Map<String, dynamic>? _parseSingleFoodItem(String foodText) {
    // 清理文字
    String text = foodText.trim();

    // 嘗試解析數量和單位
    final quantityPattern = RegExp(r'(\d+(?:\.\d+)?)\s*([^\d\s]+)?$');
    final match = quantityPattern.firstMatch(text);

    if (match != null) {
      final quantityStr = match.group(1);
      final unit = match.group(2);

      // 移除數量和單位部分，得到名稱
      final name = text.substring(0, match.start).trim();

      if (name.isNotEmpty && !_isNonFoodWord(name)) {
        return {
          'name': name,
          'quantity': quantityStr != null ? int.tryParse(quantityStr) ?? 1 : 1,
          'unit': unit ?? '個',
        };
      }
    } else {
      // 沒有數量和單位，只有名稱
      if (!_isNonFoodWord(text)) {
        return {'name': text, 'quantity': 1, 'unit': '個'};
      }
    }

    return null;
  }

  bool _isNonFoodWord(String word) {
    final nonFoodWords = ['圖片', '看到', '辨識', '食物', '食材', '項目', '清單', '列表'];
    return nonFoodWords.contains(word.toLowerCase());
  }

  // 解析購物建議回應
  List<String> _parseShoppingSuggestionsResponse(String response) {
    try {
      final data = json.decode(response);
      return List<String>.from(data['suggestions'] ?? []);
    } catch (e) {
      debugPrint('解析購物建議回應失敗: $e');
      return [];
    }
  }

  // 解析營養分析回應
  Map<String, dynamic> _parseNutritionResponse(String response) {
    try {
      return json.decode(response);
    } catch (e) {
      debugPrint('解析營養分析回應失敗: $e');
      return {};
    }
  }

  /// 獲取食材的建議保存天數
  Future<int?> getShelfLifeForIngredient(String ingredient) async {
    try {
      final prompt = '''
你是一個專業的食物保鮮顧問。請根據以下食材名稱，提供合理的保存天數建議。

食材名稱：$ingredient

請考慮以下因素：
1. 食材的新鮮度要求
2. 一般家庭儲存條件
3. 衛生安全考量

請用 JSON 格式回應：
{
  "shelfLife": 建議保存天數（數字）
}

例如：
{"shelfLife": 7}
''';

      final response = await generateTextContent(prompt);

      if (response != null) {
        try {
          final jsonResponse = json.decode(response);
          return jsonResponse['shelfLife'] as int?;
        } catch (e) {
          debugPrint('解析保存天數回應失敗: $e');
        }
      }
    } catch (e) {
      debugPrint('獲取保存天數失敗: $e');
    }

    return null;
  }

  /// 根據食材名稱建議詳細資訊（分類、保存天數等）
  Future<List<Map<String, dynamic>>> suggestFoodDetails(String foodName) async {
    try {
      final prompt = '''
你是一個專業的食物管理顧問。請根據以下食材名稱，提供詳細的建議資訊：

食材名稱：$foodName

請分析該食材並提供以下資訊：
1. 最適合的食物分類
2. 建議的儲存位置
3. 建議的保存天數
4. 該食材的特性描述

請用 JSON 格式回應，格式如下：
{
  "suggestions": [
    {
      "category": "食物分類名稱",
      "storageLocation": "儲存位置",
      "shelfLife": 保存天數（數字）,
      "description": "該食材的特性描述"
    }
  ]
}

例如：
{
  "suggestions": [
    {
      "category": "蔬菜",
      "storageLocation": "冷藏",
      "shelfLife": 5,
      "description": "新鮮蔬菜，建議冷藏保存5天"
    }
  ]
}
''';

      final response = await generateTextContent(prompt);

      if (response != null) {
        try {
          final jsonResponse = json.decode(response);
          final suggestions = jsonResponse['suggestions'] as List<dynamic>?;
          if (suggestions != null) {
            return suggestions
                .map((suggestion) => suggestion as Map<String, dynamic>)
                .toList();
          }
        } catch (e) {
          debugPrint('解析智慧建議回應失敗: $e');
        }
      }
    } catch (e) {
      debugPrint('獲取智慧建議失敗: $e');
    }

    return [];
  }
}
