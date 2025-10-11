import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/foundation.dart';

class LocationService {
  static LocationService? _instance;
  static LocationService get instance {
    _instance ??= LocationService._();
    return _instance!;
  }

  LocationService._();

  Future<Position?> getCurrentLocation() async {
    try {
      // 檢查位置服務是否啟用
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        return null;
      }

      // 檢查位置權限
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          return null;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        return null;
      }

      // 獲取當前位置
      return await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
    } catch (e) {
      print('獲取位置失敗: $e');
      return null;
    }
  }

  Future<String?> getLocationAddress(Position position) async {
    try {
      List<Placemark> placemarks = await placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );

      if (placemarks.isNotEmpty) {
        Placemark place = placemarks.first;
        return '${place.locality ?? ''} ${place.subLocality ?? ''} ${place.thoroughfare ?? ''}'
            .trim();
      }
    } catch (e) {
      print('獲取地址失敗: $e');
    }
    return null;
  }

  Future<void> openMap(
    double latitude,
    double longitude, {
    String? label,
  }) async {
    final url =
        'https://www.google.com/maps/search/?api=1&query=$latitude,$longitude${label != null ? '&query_place_id=$label' : ''}';

    if (await canLaunchUrl(Uri.parse(url))) {
      await launchUrl(Uri.parse(url));
    }
  }

  // 使用 Gemini API 智慧推薦商店類型
  Future<String> getStoreTypeForIngredientWithGemini(String ingredient) async {
    try {
      final prompt = '''
你是一個專業的購物顧問。請根據以下食材推薦最適合購買的商店類型：

食材名稱：$ingredient

請考慮以下因素：
1. 食材的新鮮度要求（生鮮食材需要新鮮度高的商店）
2. 價格考量（某些商店特定食材更便宜）
3. 便利性（距離和營業時間）
4. 品質考量（有機、當地生產等）

請推薦最適合的商店類型，並簡要說明原因。

請用 JSON 格式回應：
{
  "storeType": "推薦商店類型",
  "reason": "推薦原因說明"
}
''';

      // 嘗試使用 Gemini API
      final response = await _getGeminiResponse(prompt);

      if (response != null) {
        return response;
      }
    } catch (e) {
      debugPrint('Gemini API 商店推薦失敗: $e');
    }

    // 如果 Gemini API 失敗，使用備用邏輯
    return _getStoreTypeForIngredientFallback(ingredient);
  }

  // 備用商店推薦邏輯
  String _getStoreTypeForIngredientFallback(String ingredient) {
    final lowerIngredient = ingredient.toLowerCase();

    // 肉類相關
    if (lowerIngredient.contains('肉') ||
        lowerIngredient.contains('雞') ||
        lowerIngredient.contains('豬') ||
        lowerIngredient.contains('牛') ||
        lowerIngredient.contains('魚') ||
        lowerIngredient.contains('海鮮')) {
      return '肉舖或超市';
    }

    // 蔬菜水果相關
    if (lowerIngredient.contains('菜') ||
        lowerIngredient.contains('果') ||
        lowerIngredient.contains('蔬菜') ||
        lowerIngredient.contains('水果')) {
      return '菜市場或超市';
    }

    // 乳製品相關
    if (lowerIngredient.contains('奶') ||
        lowerIngredient.contains('優格') ||
        lowerIngredient.contains('起司') ||
        lowerIngredient.contains('牛奶')) {
      return '超市或便利商店';
    }

    // 調味料相關
    if (lowerIngredient.contains('醬') ||
        lowerIngredient.contains('油') ||
        lowerIngredient.contains('鹽') ||
        lowerIngredient.contains('糖') ||
        lowerIngredient.contains('調味')) {
      return '超市或傳統市場';
    }

    // 穀物相關
    if (lowerIngredient.contains('米') ||
        lowerIngredient.contains('麵') ||
        lowerIngredient.contains('麵包') ||
        lowerIngredient.contains('麵條')) {
      return '超市或麵包店';
    }

    // 飲料相關
    if (lowerIngredient.contains('水') ||
        lowerIngredient.contains('汁') ||
        lowerIngredient.contains('茶') ||
        lowerIngredient.contains('咖啡') ||
        lowerIngredient.contains('飲料')) {
      return '超市或便利商店';
    }

    // 預設推薦
    return '超市';
  }

  // 使用 Gemini API 獲取商店推薦
  Future<String?> _getGeminiResponse(String prompt) async {
    try {
      // 這裡需要匯入 Gemini 服務
      // 先嘗試使用簡單的 HTTP 請求方式，後續可以改為正式的 Gemini SDK

      // 暫時返回 null，讓備用邏輯處理
      return null;
    } catch (e) {
      debugPrint('Gemini API 呼叫失敗: $e');
      return null;
    }
  }

  // 模擬商店資料（實際應用中可以從API或資料庫獲取）
  Future<List<Map<String, dynamic>>> getNearbyStores(String ingredient) async {
    // 嘗試使用 Gemini API 獲取智慧商店推薦
    final storeType = await getStoreTypeForIngredientWithGemini(ingredient);

    return [
      {
        'name': '全聯福利中心',
        'type': '超市',
        'distance': '0.5公里',
        'address': '附近的全聯超市',
        'recommended': false,
      },
      {
        'name': '家樂福',
        'type': '大賣場',
        'distance': '1.2公里',
        'address': '附近的家樂福',
        'recommended': false,
      },
      {
        'name': '傳統市場',
        'type': storeType,
        'distance': '0.8公里',
        'address': '附近的傳統市場',
        'recommended': true,
      },
    ];
  }

  // 保留舊的方法以維持相容性
  String getStoreTypeForIngredient(String ingredient) {
    return _getStoreTypeForIngredientFallback(ingredient);
  }
}
