import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'gemini_service.dart';

class InvoiceCarrier {
  final String carrierId;
  final String carrierType; // 'mobile' or 'card'
  final bool isBound;

  InvoiceCarrier({
    required this.carrierId,
    required this.carrierType,
    this.isBound = false,
  });

  Map<String, dynamic> toMap() => {
    'carrierId': carrierId,
    'carrierType': carrierType,
    'isBound': isBound,
  };

  factory InvoiceCarrier.fromMap(Map<String, dynamic> map) => InvoiceCarrier(
    carrierId: map['carrierId'] as String,
    carrierType: map['carrierType'] as String,
    isBound: map['isBound'] as bool? ?? false,
  );
}

class InvoiceItem {
  final String description;
  final double? amount;
  final int? quantity;
  final String? unit;

  InvoiceItem({
    required this.description,
    this.amount,
    this.quantity,
    this.unit,
  });

  Map<String, dynamic> toMap() => {
    'description': description,
    'amount': amount,
    'quantity': quantity,
    'unit': unit,
  };

  factory InvoiceItem.fromMap(Map<String, dynamic> map) => InvoiceItem(
    description: map['description'] as String,
    amount: map['amount'] as double?,
    quantity: map['quantity'] as int?,
    unit: map['unit'] as String?,
  );
}

class InvoiceService {
  static InvoiceService? _instance;
  static InvoiceService get instance {
    _instance ??= InvoiceService._();
    return _instance!;
  }

  InvoiceService._();

  // 綁定發票載具
  Future<bool> bindCarrier(String carrierId, String carrierType) async {
    try {
      // 這裡會呼叫財政部發票載具綁定 API
      // 由於這是政府 API，需要正確的授權和認證

      final prefs = await SharedPreferences.getInstance();
      final carriers = await getBoundCarriers();

      final newCarrier = InvoiceCarrier(
        carrierId: carrierId,
        carrierType: carrierType,
        isBound: true,
      );

      carriers.add(newCarrier);
      await _saveCarriers(carriers);

      return true;
    } catch (e) {
      debugPrint('綁定載具失敗: $e');
      return false;
    }
  }

  // 解除綁定發票載具
  Future<bool> unbindCarrier(String carrierId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final carriers = await getBoundCarriers();

      carriers.removeWhere((carrier) => carrier.carrierId == carrierId);
      await _saveCarriers(carriers);

      return true;
    } catch (e) {
      debugPrint('解除綁定載具失敗: $e');
      return false;
    }
  }

  // 獲取已綁定的載具
  Future<List<InvoiceCarrier>> getBoundCarriers() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final carriersJson = prefs.getStringList('bound_carriers') ?? [];

      return carriersJson.map((json) {
        final map = jsonDecode(json) as Map<String, dynamic>;
        return InvoiceCarrier.fromMap(map);
      }).toList();
    } catch (e) {
      debugPrint('獲取綁定載具失敗: $e');
      return [];
    }
  }

  // 同步發票資料
  Future<List<InvoiceItem>> syncInvoices(String carrierId) async {
    try {
      // 這裡會呼叫財政部發票查詢 API
      // 實際實作需要正確的 API 呼叫和資料解析

      // 暫時返回模擬資料
      return await _getMockInvoiceData();
    } catch (e) {
      debugPrint('同步發票失敗: $e');
      return [];
    }
  }

  // 使用 Gemini API 辨識發票中的食物項目
  Future<List<Map<String, dynamic>>> identifyFoodItems(
    List<InvoiceItem> invoiceItems,
  ) async {
    try {
      final foodItems = <Map<String, dynamic>>[];

      for (final item in invoiceItems) {
        // 使用 Gemini API 判斷是否為食物並解析資訊
        final isFood = await _isFoodItem(item.description);
        if (isFood) {
          final foodInfo = await _parseFoodInfo(item.description);
          if (foodInfo != null) {
            foodItems.add(foodInfo);
          }
        }
      }

      return foodItems;
    } catch (e) {
      debugPrint('辨識食物項目失敗: $e');
      return [];
    }
  }

  // 使用 Gemini API 判斷是否為食物項目
  Future<bool> _isFoodItem(String description) async {
    try {
      final prompt = '''
請判斷以下發票項目是否為食物相關項目。只回答 "true" 或 "false"：

項目描述：$description

判斷規則：
- 如果是食物、飲料、食材等食品相關項目，返回 true
- 如果是非食品項目（如服飾、文具、電子產品等），返回 false
- 如果無法確定，返回 false

請只回答 true 或 false，不要包含其他文字。
''';

      final response = await GeminiService.instance.generateTextContent(prompt);

      final result = response?.toLowerCase().trim();
      return result == 'true';
    } catch (e) {
      debugPrint('判斷食物項目失敗: $e');
      return false;
    }
  }

  // 使用 Gemini API 解析食物資訊
  Future<Map<String, dynamic>?> _parseFoodInfo(String description) async {
    try {
      final prompt = '''
請從以下發票項目描述中抽取出食物相關資訊：

項目描述：$description

請抽取以下資訊：
1. 品牌名稱（如果有）
2. 產品名稱
3. 規格/數量（如果有）
4. 食品分類（乳製品、蔬菜、水果、肉類、飲料、調味料等）

請用 JSON 格式回應：
{
  "brand": "品牌名稱",
  "productName": "產品名稱",
  "specification": "規格",
  "category": "食品分類"
}
''';

      final response = await GeminiService.instance.generateTextContent(prompt);

      if (response != null) {
        try {
          final data = json.decode(response);
          return data as Map<String, dynamic>;
        } catch (e) {
          debugPrint('解析食物資訊失敗: $e');
        }
      }

      return null;
    } catch (e) {
      debugPrint('解析食物資訊失敗: $e');
      return null;
    }
  }

  // 查詢外部食物資料庫獲取詳細資訊（使用 Spoonacular API）
  Future<Map<String, dynamic>?> enrichFoodData(
    String productName,
    String category,
  ) async {
    try {
      // 這裡會呼叫 Spoonacular API 或其他食物資料庫 API
      // 暫時返回模擬資料

      return {
        'name': productName,
        'category': category,
        'estimatedShelfLife': _estimateShelfLife(category),
        'imageUrl': 'https://via.placeholder.com/150', // 預設圖片
        'nutritionInfo': {
          'calories': 100,
          'protein': 5.0,
          'carbs': 20.0,
          'fat': 2.0,
        },
      };
    } catch (e) {
      debugPrint('豐富食物資料失敗: $e');
      return null;
    }
  }

  // 智慧估算保存期限
  int _estimateShelfLife(String category) {
    switch (category.toLowerCase()) {
      case '乳製品':
      case 'dairy':
        return 7; // 7天
      case '蔬菜':
      case '蔬菜類':
        return 5; // 5天
      case '水果':
      case '水果類':
        return 7; // 7天
      case '肉類':
        return 3; // 3天
      case '魚類':
      case '海鮮':
        return 2; // 2天
      case '飲料':
        return 30; // 30天
      case '調味料':
        return 180; // 180天
      case '穀物':
        return 90; // 90天
      default:
        return 7; // 預設7天
    }
  }

  // 儲存綁定的載具
  Future<void> _saveCarriers(List<InvoiceCarrier> carriers) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final carriersJson =
          carriers.map((carrier) => jsonEncode(carrier.toMap())).toList();
      await prefs.setStringList('bound_carriers', carriersJson);
    } catch (e) {
      debugPrint('儲存載具失敗: $e');
    }
  }

  // 獲取模擬發票資料（用於測試）
  Future<List<InvoiceItem>> _getMockInvoiceData() async {
    // 模擬延遲
    await Future.delayed(const Duration(seconds: 1));

    return [
      InvoiceItem(
        description: '統一布丁 100g x 2',
        amount: 45.0,
        quantity: 2,
        unit: '個',
      ),
      InvoiceItem(
        description: '鮮乳優格 450g',
        amount: 65.0,
        quantity: 1,
        unit: '盒',
      ),
      InvoiceItem(description: '香蕉 1kg', amount: 35.0, quantity: 1, unit: 'kg'),
      InvoiceItem(
        description: '衛生紙 12捲',
        amount: 120.0,
        quantity: 12,
        unit: '捲',
      ),
    ];
  }
}
