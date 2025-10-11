import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:http/http.dart' as http;

class GeminiService {
  static GeminiService? _instance;
  static GeminiService get instance {
    _instance ??= GeminiService._();
    return _instance!;
  }

  // 在實際應用中，應該從安全的環境變數或後端服務獲取 API 金鑰
  // 這裡使用一個範例金鑰，請務必替換為您自己的金鑰
  static const String _apiKey = 'AIzaSyDe_nciYgp9waBaMxhwK9R_PPcVVZIM9LY';

  late GenerativeModel _textModel;
  late GenerativeModel _visionModel;

  GeminiService._() {
    try {
      _initializeModelsSync();
    } catch (e) {
      debugPrint('Gemini 服務初始化失敗: $e');
      rethrow;
    }
  }

  void _initializeModelsSync() {
    // 同步初始化，使用預設模型
    try {
      _textModel = GenerativeModel(
        model: 'models/gemini-2.5-pro',
        apiKey: _apiKey,
        generationConfig: GenerationConfig(
          temperature: 0.4,
          topK: 32,
          topP: 1,
          maxOutputTokens: 2048,
        ),
      );

      _visionModel = GenerativeModel(
        model: 'models/gemini-2.5-pro',
        apiKey: _apiKey,
        generationConfig: GenerationConfig(
          temperature: 0.4,
          topK: 32,
          topP: 1,
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

  String _selectBestTextModel(List<String> availableModels) {
    // 優先使用 Gemini 2.5 Pro
    if (availableModels.any(
      (model) => model.contains('models/gemini-2.5-pro'),
    )) {
      return 'models/gemini-2.5-pro';
    }
    // 降級到 1.5 Pro
    if (availableModels.any((model) => model.contains('gemini-1.5-pro'))) {
      return 'gemini-1.5-pro';
    }
    // 最後使用 1.5 Flash
    if (availableModels.any((model) => model.contains('gemini-1.5-flash'))) {
      return 'gemini-1.5-flash';
    }
    // 預設使用 Gemini 2.5 Pro
    return 'models/gemini-2.5-pro';
  }

  String _selectBestVisionModel(List<String> availableModels) {
    // 優先使用 Gemini 2.5 Pro (支援視覺)
    if (availableModels.any(
      (model) => model.contains('models/gemini-2.5-pro'),
    )) {
      return 'models/gemini-2.5-pro';
    }
    // 降級到 1.5 Pro
    if (availableModels.any((model) => model.contains('gemini-1.5-pro'))) {
      return 'gemini-1.5-pro';
    }
    // 最後使用 1.5 Flash
    if (availableModels.any((model) => model.contains('gemini-1.5-flash'))) {
      return 'gemini-1.5-flash';
    }
    // 預設使用 Gemini 2.5 Pro
    return 'models/gemini-2.5-pro';
  }

  void _setupFallbackModels() {
    try {
      // 嘗試使用 Gemini 2.5 Pro 作為備用
      _textModel = GenerativeModel(
        model: 'models/gemini-2.5-pro',
        apiKey: _apiKey,
      );
      _visionModel = GenerativeModel(
        model: 'models/gemini-2.5-pro',
        apiKey: _apiKey,
      );
      debugPrint('使用 Gemini 2.5 Pro 備用模型設定');
    } catch (e) {
      debugPrint('備用模型設定也失敗: $e');
      throw Exception('無法初始化 Gemini 服務: $e');
    }
  }

  // 公開方法讓其他服務可以訪問
  GenerativeModel _getTextModel() => _textModel;

  // 檢查可用模型列表
  Future<List<String>> listAvailableModels() async {
    try {
      final url =
          'https://generativelanguage.googleapis.com/v1beta/models?key=$_apiKey';

      final response = await http.get(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final models = data['models'] as List<dynamic>? ?? [];

        return models.map((model) => model['name'] as String).toList();
      } else {
        debugPrint(
          'ListModels API 錯誤: ${response.statusCode} - ${response.body}',
        );
        return [];
      }
    } catch (e) {
      debugPrint('檢查可用模型失敗: $e');
      return [];
    }
  }

  // 公開方法供發票服務使用
  Future<String?> generateTextContent(String prompt) async {
    try {
      final response = await _textModel.generateContent([Content.text(prompt)]);
      return response.text;
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
你是一個專業的廚師助手。根據以下食材庫存，請生成 3-5 個創意且實用的食譜：

【可用食材庫存】
$ingredientSummary

【食材清單摘要】
$ingredientDetails

重要規則：
1. 每個食譜只能使用庫存中已有的食材
2. 請優先使用即將到期的食材
3. 食譜應該簡單實用，適合家庭料理
4. 考慮食材數量是否足夠製作

請為每個食譜提供：
1. 食譜名稱（用中文）
2. 所需食材（必須從庫存中選擇，標明具體數量）
3. 簡單的烹飪步驟（3-5步）
4. 預估烹飪時間
5. 建議難度等級（簡單/中等/困難）

請用 JSON 格式回應：
{
  "recipes": [
    {
      "title": "食譜名稱",
      "requiredItems": {"食材名稱": "具體數量單位"},
      "steps": ["步驟1", "步驟2", "步驟3"],
      "cookingTime": "預估時間",
      "difficulty": "簡單/中等/困難"
    }
  ]
}
''';

      final response = await _textModel.generateContent([Content.text(prompt)]);

      if (response.text != null) {
        return _parseRecipeResponse(response.text!);
      }

      return [];
    } catch (e) {
      debugPrint('生成食譜失敗: $e');
      return [];
    }
  }

  // 辨識食物圖片
  Future<Map<String, dynamic>> identifyFood(File imageFile) async {
    try {
      debugPrint('開始辨識圖片: ${imageFile.path}');
      final imageBytes = await imageFile.readAsBytes();
      debugPrint('圖片大小: ${imageBytes.length} bytes');

      final prompt = '''
請仔細觀察這張圖片，辨識出所有可見的食物食材。請用繁體中文描述所有你能辨識出的食物名稱。

要求：
1. 只辨識食物相關的物品，不要包含容器、餐具、包裝或其他非食物物品
2. 請用準確的繁體中文食物名稱描述
3. 如果有多個相同食物，請列出具體數量或規格（如：香蕉 2根、牛奶 500ml）
4. 優先辨識主要的食物項目，忽略背景或不相關的物品
5. 如果無法確定數量，請只寫食物名稱

請務必用以下 JSON 格式回應，不要包含其他文字：
{
  "foods": ["食物名稱1", "食物名稱2", "食物名稱3"]
}

正確範例：
{
  "foods": ["蘋果", "香蕉 2根", "牛奶 500ml", "雞蛋 6個", "白米 1kg"]
}

錯誤範例（請避免）：
- 任何包含 "我看到" 或 "圖片中有" 的敘述
- 任何不是 JSON 格式的回應
- 任何包含解釋或分析的回應
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

      return {'success': false, 'items': []};

      debugPrint('回應為空');
      return {'success': false, 'items': []};
    } catch (e) {
      debugPrint('食物辨識失敗: $e');
      debugPrint('錯誤詳情: ${e.toString()}');
      debugPrint('Stack trace: ${StackTrace.current}');
      return {'success': false, 'items': []};
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

      final response = await _textModel.generateContent([Content.text(prompt)]);

      if (response.text != null) {
        return _parseShoppingSuggestionsResponse(response.text!);
      }

      return [];
    } catch (e) {
      debugPrint('生成購物建議失敗: $e');
      return [];
    }
  }

  // 提供食材保存建議
  Future<String> getStorageAdvice(String foodName) async {
    try {
      final prompt = '''
請提供 $foodName 的最佳保存建議，包括：
1. 最佳保存溫度
2. 保存方式（冷藏/冷凍/室溫）
3. 保存期限
4. 保存技巧

請用簡潔明瞭的方式回答。
''';

      final response = await _textModel.generateContent([Content.text(prompt)]);

      return response.text ?? '無法獲取保存建議';
    } catch (e) {
      debugPrint('獲取保存建議失敗: $e');
      return '無法獲取保存建議';
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

      final response = await _textModel.generateContent([Content.text(prompt)]);

      if (response.text != null) {
        return _parseNutritionResponse(response.text!);
      }

      return {};
    } catch (e) {
      debugPrint('營養分析失敗: $e');
      return {};
    }
  }

  // 解析食譜回應
  List<Map<String, dynamic>> _parseRecipeResponse(String response) {
    try {
      final data = json.decode(response);
      final recipes = data['recipes'] as List<dynamic>? ?? [];

      return recipes.map((recipe) {
        final requiredItems = Map<String, String>.from(
          recipe['requiredItems'] ?? {},
        );
        final missingItems = <String, String>{};

        // 計算缺失的食材（這裡假設所有食材都可用，因為 Gemini 應該只推薦現有食材）
        // 在實際應用中，可能需要根據庫存驗證
        requiredItems.forEach((name, amount) {
          // 這裡可以根據實際庫存來計算缺失項目
          // 目前假設 Gemini 只推薦現有食材，所以沒有缺失項目
        });

        return {
          'title': recipe['title'] ?? '未知食譜',
          'steps': List<String>.from(recipe['steps'] ?? []),
          'requiredItems': requiredItems,
          'missingItems': missingItems,
          'cookingTime': recipe['cookingTime'] ?? '15分鐘',
          'difficulty': recipe['difficulty'] ?? '簡單',
        };
      }).toList();
    } catch (e) {
      debugPrint('解析食譜回應失敗: $e');
      return [];
    }
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
      final item = _parseSingleFoodItem(food.toString());
      if (item != null) {
        result.add(item);
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
}
