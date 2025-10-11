import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'gemini_service.dart';

class GeminiFoodRecognition {
  static GeminiFoodRecognition? _instance;
  static GeminiFoodRecognition get instance {
    _instance ??= GeminiFoodRecognition._();
    return _instance!;
  }

  GeminiFoodRecognition._();

  // 使用 Gemini Vision API 辨識食物圖片
  Future<List<Map<String, dynamic>>> predict(
    File imageFile, {
    bool detect = false,
  }) async {
    try {
      if (kDebugMode) {
        debugPrint('[GeminiFoodRecognition] 開始辨識圖片: ${imageFile.path}');
      }

      // 使用 Gemini Vision API 辨識食物
      final identifiedResult = await GeminiService.instance.identifyFood(
        imageFile,
      );

      if (kDebugMode) {
        debugPrint('[GeminiFoodRecognition] 辨識結果: $identifiedResult');
      }

      // 檢查辨識是否成功
      if (identifiedResult['success'] == true) {
        final identifiedFoods = identifiedResult['items'] as List<dynamic>;

        // 將辨識結果轉換為標準格式
        return identifiedFoods.map((food) {
          final foodMap = food as Map<String, dynamic>;
          return {
            'tagName': foodMap['name'],
            'probability': 0.9, // Gemini 沒有信心分數，使用固定值
            'boundingBox': null, // Gemini Vision 暫不支援物件偵測
          };
        }).toList();
      } else {
        // 辨識失敗，返回空列表
        return [];
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[GeminiFoodRecognition] 辨識失敗: $e');
      }
      rethrow;
    }
  }

  // 增強版辨識：獲取詳細的食物資訊
  Future<List<Map<String, dynamic>>> predictWithDetails(
    File imageFile, {
    bool detect = false,
  }) async {
    try {
      // 先進行基本辨識
      final basicResults = await predict(imageFile, detect: detect);

      // 為每個辨識結果獲取詳細資訊
      final enhancedResults = <Map<String, dynamic>>[];

      for (final result in basicResults) {
        final foodName = result['tagName'] as String;

        // 使用 Gemini API 獲取食物分類和估算保存期限
        final prompt = '''
  請分析以下食物並提供詳細資訊：

  食物名稱：$foodName

  請提供以下資訊：
  1. 食品分類（乳製品、蔬菜、水果、肉類、飲料、調味料、穀物等）
  2. 建議保存期限（天數）
  3. 保存方式建議（冷藏/冷凍/室溫）
  4. 營養價值簡述

  請用 JSON 格式回應：
  {
    "category": "食品分類",
    "shelfLife": 7,
    "storageMethod": "冷藏",
    "nutrition": "營養價值簡述"
  }
''';

        final response = await GeminiService.instance.generateTextContent(
          prompt,
        );

        if (response != null) {
          try {
            final foodDetails = json.decode(response) as Map<String, dynamic>;

            enhancedResults.add({
              ...result,
              'category': foodDetails['category'] ?? '其他',
              'estimatedShelfLife': foodDetails['shelfLife'] ?? 7,
              'storageMethod': foodDetails['storageMethod'] ?? '室溫',
              'nutrition': foodDetails['nutrition'] ?? '營養豐富',
            });
          } catch (e) {
            // 如果解析失敗，使用預設值
            enhancedResults.add({
              ...result,
              'category': '其他',
              'estimatedShelfLife': 7,
              'storageMethod': '室溫',
              'nutrition': '營養豐富',
            });
          }
        } else {
          // 如果無法獲取詳細資訊，使用預設值
          enhancedResults.add({
            ...result,
            'category': '其他',
            'estimatedShelfLife': 7,
            'storageMethod': '室溫',
            'nutrition': '營養豐富',
          });
        }
      }

      return enhancedResults;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[GeminiFoodRecognition] 增強辨識失敗: $e');
      }
      rethrow;
    }
  }
}
