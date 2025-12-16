import 'dart:io';
import 'package:flutter/material.dart';
import 'gemini_service.dart';
import 'models.dart';
import 'food_category_utils.dart';
import 'yolo_service.dart';

/// 影像辨識結果處理器
class ImageRecognitionHelper {
  /// 執行影像辨識並處理結果
  ///
  /// 返回值：
  /// - null: 辨識失敗或用戶取消
  /// - FoodItem: 辨識成功且用戶選擇了食物
  static Future<FoodItem?> recognizeAndSelectFood({
    required BuildContext context,
    required File imageFile,
    String? imagePath,
  }) async {
    try {
      // 檢查圖片檔案是否存在
      if (!await imageFile.exists()) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('圖片檔案不存在，請重新選擇'),
              duration: Duration(seconds: 3),
            ),
          );
        }
        return null;
      }

      final yoloFoods = await _detectFoodsUsingYolo(imageFile);
      List<Map<String, dynamic>>? detectedFoods = yoloFoods;

      if (detectedFoods == null || detectedFoods.isEmpty) {
        // 呼叫 Gemini 食物辨識作為備援
        final identifiedResult = await GeminiService.instance.identifyFood(
          imageFile,
        );
        if (identifiedResult['success'] == true) {
          detectedFoods =
              (identifiedResult['items'] as List<dynamic>)
                  .map((food) => food as Map<String, dynamic>)
                  .toList();
        } else {
          detectedFoods = [];
        }
      }

      if (!context.mounted) return null;

      if (detectedFoods.isEmpty) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('無法辨識圖片中的食物，請手動輸入名稱'),
              duration: Duration(seconds: 3),
            ),
          );
        }
        return null;
      } else if (detectedFoods.length == 1) {
        return _createFoodItemFromRecognition(detectedFoods.first, imagePath);
      } else {
        return await _showFoodSelectionDialog(
          context,
          detectedFoods,
          imagePath,
        );
      }
    } catch (e) {
      debugPrint('辨識失敗詳細錯誤: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('辨識失敗：$e'),
            duration: const Duration(seconds: 3),
          ),
        );
      }
      return null;
    }
  }

  /// 從辨識結果創建 FoodItem
  static FoodItem _createFoodItemFromRecognition(
    Map<String, dynamic> foodData,
    String? imagePath,
  ) {
    final foodName = foodData['name'] as String;
    final quantity = foodData['quantity'] as int;
    final unit = foodData['unit'] as String;
    final categoryStr = foodData['category'] as String? ?? '其他';
    final category = mapCategoryStringToEnum(categoryStr);

    final purchaseDate = DateTime.now();
    final expiryDate = purchaseDate.add(const Duration(days: 7));

    return FoodItem(
      name: foodName,
      quantity: quantity,
      unit: unit,
      purchaseDate: purchaseDate,
      expiryDate: expiryDate,
      shelfLifeDays: expiryDate.difference(purchaseDate).inDays,
      category: category,
      storageLocation: StorageLocation.refrigerated,
      isOpened: false,
      note: null,
      imagePath: imagePath,
    );
  }

  /// 顯示食物選擇對話框（當有多個辨識結果時）
  static Future<FoodItem?> _showFoodSelectionDialog(
    BuildContext context,
    List<dynamic> identifiedFoods,
    String? imagePath,
  ) async {
    return await showDialog<FoodItem>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('選擇辨識結果'),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: identifiedFoods.length,
              itemBuilder: (context, index) {
                final foodItem = identifiedFoods[index] as Map<String, dynamic>;
                final foodName = foodItem['name'] as String;
                final quantity = foodItem['quantity'] as int;
                final unit = foodItem['unit'] as String;
                final categoryStr = foodItem['category'] as String? ?? '其他';
                final category = mapCategoryStringToEnum(categoryStr);

                return ListTile(
                  title: Text('$foodName $quantity$unit'),
                  subtitle: Text(categoryDisplayName(category)),
                  leading: Radio<int>(
                    value: index,
                    groupValue: null,
                    onChanged: (value) {
                      if (value != null) {
                        final selectedFood = _createFoodItemFromRecognition(
                          foodItem,
                          imagePath,
                        );
                        Navigator.of(dialogContext).pop(selectedFood);
                      }
                    },
                  ),
                  onTap: () {
                    final selectedFood = _createFoodItemFromRecognition(
                      foodItem,
                      imagePath,
                    );
                    Navigator.of(dialogContext).pop(selectedFood);
                  },
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(null),
              child: const Text('取消'),
            ),
          ],
        );
      },
    );
  }

  /// 執行影像辨識並返回原始辨識結果（用於表單頁面）
  ///
  /// 此方法不會顯示對話框，而是返回原始的辨識數據
  /// 讓調用方自行決定如何處理（更新表單欄位等）
  static Future<List<Map<String, dynamic>>?> recognizeForForm({
    required BuildContext context,
    required File imageFile,
  }) async {
    try {
      // 檢查圖片檔案是否存在
      if (!await imageFile.exists()) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('圖片檔案不存在，請重新選擇'),
              duration: Duration(seconds: 3),
            ),
          );
        }
        return null;
      }

      var detectedFoods = await _detectFoodsUsingYolo(imageFile);

      if (detectedFoods == null || detectedFoods.isEmpty) {
        // 呼叫 Gemini 食物辨識作為備援
        final identifiedResult = await GeminiService.instance.identifyFood(
          imageFile,
        );
        if (identifiedResult['success'] == true) {
          detectedFoods =
              (identifiedResult['items'] as List<dynamic>)
                  .map((food) => food as Map<String, dynamic>)
                  .toList();
        } else {
          detectedFoods = [];
        }
      }

      if (!context.mounted) return null;

      if (detectedFoods.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('無法辨識圖片中的食物，請手動輸入名稱'),
            duration: Duration(seconds: 3),
          ),
        );
        return null;
      }

      return detectedFoods;
    } catch (e) {
      debugPrint('辨識失敗詳細錯誤: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('辨識失敗：$e'),
            duration: const Duration(seconds: 3),
          ),
        );
      }
      return null;
    }
  }

  /// 顯示食物選擇對話框並返回選中的食物數據（用於表單頁面）
  static Future<Map<String, dynamic>?> showFoodSelectionDialogForForm(
    BuildContext context,
    List<Map<String, dynamic>> identifiedFoods,
  ) async {
    return await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('選擇辨識結果'),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: identifiedFoods.length,
              itemBuilder: (context, index) {
                final foodItem = identifiedFoods[index];
                final foodName = foodItem['name'] as String;
                final quantity = foodItem['quantity'] as int;
                final unit = foodItem['unit'] as String;
                final categoryStr = foodItem['category'] as String? ?? '其他';
                final category = mapCategoryStringToEnum(categoryStr);

                return ListTile(
                  title: Text('$foodName $quantity$unit'),
                  subtitle: Text(categoryDisplayName(category)),
                  leading: Radio<int>(
                    value: index,
                    groupValue: null,
                    onChanged: (value) {
                      if (value != null) {
                        Navigator.of(dialogContext).pop(foodItem);
                      }
                    },
                  ),
                  onTap: () {
                    Navigator.of(dialogContext).pop(foodItem);
                  },
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(null),
              child: const Text('取消'),
            ),
          ],
        );
      },
    );
  }

  /// 使用 YOLO 服務偵測食材
  static Future<List<Map<String, dynamic>>?> _detectFoodsUsingYolo(
    File imageFile,
  ) async {
    if (!YoloService.instance.isConfigured) {
      return [];
    }

    try {
      final detections = await YoloService.instance.detectFoods(imageFile);
      return detections.map(_mapYoloDetectionToFoodData).toList();
    } catch (e) {
      debugPrint('YOLO 辨識失敗: $e');
      return [];
    }
  }

  static Map<String, dynamic> _mapYoloDetectionToFoodData(
    YoloDetection detection,
  ) {
    final normalizedLabel =
        detection.label.trim().isEmpty ? '未知食材' : detection.label.trim();
    final category = guessCategoryFromFoodName(normalizedLabel);
    final suggestedShelfLife = suggestShelfLifeDays(category);

    return {
      'name': normalizedLabel,
      'quantity': detection.count ?? 1,
      'unit': '件',
      'category': categoryDisplayName(category),
      'confidence': detection.confidence,
      'estimatedShelfLife': suggestedShelfLife,
      'source': 'yolo',
      if (detection.box != null) 'boundingBox': detection.box,
    };
  }
}
