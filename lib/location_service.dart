import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/foundation.dart';
import 'dart:math' as math;
import 'package:http/http.dart' as http;
import 'dart:convert';

class LocationService {
  static LocationService? _instance;
  static LocationService get instance {
    _instance ??= LocationService._();
    return _instance!;
  }

  LocationService._();

  // Google Places API Key
  // 注意：實際應用中應該從環境變數或安全的配置中讀取
  static const String _googlePlacesApiKey = 'YOUR API KEY';

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

  // 備用商店推薦邏輯（未呼叫 Places/Gemini 時使用）
  String _getStoreTypeForIngredientFallback(String itemName) {
    final lower = itemName.toLowerCase();

    if (_containsAny(lower, ['肉', '魚', '菜', '水果'])) {
      return '生鮮超市或傳統市場';
    }
    if (_containsAny(lower, ['米', '麵', '麵包', '吐司', '醬', '油', '鹽', '糖'])) {
      return '超市或雜貨店';
    }
    if (_containsAny(lower, ['藥', '感冒', '維他命', '保健'])) {
      return '藥局或藥妝店';
    }
    if (_containsAny(lower, ['洗髮', '沐浴', '清潔', '衛生紙'])) {
      return '藥妝店或生活用品店';
    }
    if (_containsAny(lower, ['電池', '充電', '耳機', '3c', 'usb'])) {
      return '3C 電器行或電信門市';
    }
    if (_containsAny(lower, ['螺絲', '工具', '水管', '修理'])) {
      return '五金行或家居賣場';
    }
    if (_containsAny(lower, ['筆', '文具', '紙', '筆記', '書'])) {
      return '文具店或書局';
    }
    if (_containsAny(lower, ['衣', '褲', '鞋', '襪'])) {
      return '服飾店或百貨公司';
    }
    if (_containsAny(lower, ['貓', '狗', '寵物', '飼料'])) {
      return '寵物用品店';
    }

    return '大型超市或購物中心';
  }

  // 使用 Gemini API 獲取商店推薦（已禁用）
  Future<String?> _getGeminiResponse(String prompt) async {
    // 暫時禁用 Gemini 服務
    return null;
  }

  // 商店資料庫 - 各種商店類型和名稱
  static const List<Map<String, dynamic>> _storeDatabase = [
    // 超市類
    {'name': '全聯福利中心', 'type': '超市', 'category': 'general'},
    {'name': '頂好超市', 'type': '超市', 'category': 'general'},
    {'name': '美廉社', 'type': '超市', 'category': 'general'},
    {'name': '愛買', 'type': '超市', 'category': 'general'},

    // 大賣場類
    {'name': '家樂福', 'type': '大賣場', 'category': 'hypermarket'},
    {'name': '大潤發', 'type': '大賣場', 'category': 'hypermarket'},
    {'name': '好市多', 'type': '會員制賣場', 'category': 'warehouse'},

    // 傳統市場類
    {'name': '南門市場', 'type': '傳統市場', 'category': 'traditional'},
    {'name': '東門市場', 'type': '傳統市場', 'category': 'traditional'},
    {'name': '士東市場', 'type': '傳統市場', 'category': 'traditional'},
    {'name': '永春市場', 'type': '傳統市場', 'category': 'traditional'},

    // 專門店類
    {'name': '肉品專賣店', 'type': '肉品專賣', 'category': 'meat'},
    {'name': '海鮮市場', 'type': '海鮮專賣', 'category': 'seafood'},
    {'name': '蔬菜專賣店', 'type': '蔬菜專賣', 'category': 'vegetables'},
    {'name': '水果專賣店', 'type': '水果專賣', 'category': 'fruits'},
    {'name': '麵包店', 'type': '麵包專賣', 'category': 'bakery'},
    {'name': '乳製品專賣店', 'type': '乳製品專賣', 'category': 'dairy'},

    // 便利商店類
    {'name': '7-Eleven', 'type': '便利商店', 'category': 'convenience'},
    {'name': '全家便利商店', 'type': '便利商店', 'category': 'convenience'},
    {'name': '萊爾富', 'type': '便利商店', 'category': 'convenience'},

    // 有機/健康食品店類
    {'name': '有機食品專賣店', 'type': '有機食品', 'category': 'organic'},
    {'name': '健康食品店', 'type': '健康食品', 'category': 'health'},

    // 進口食品店類
    {'name': '進口食品專賣店', 'type': '進口食品', 'category': 'imported'},
    {'name': '異國料理食材店', 'type': '異國食材', 'category': 'international'},

    // 藥妝與保健
    {'name': '屈臣氏', 'type': '藥妝店', 'category': 'drugstore'},
    {'name': '康是美', 'type': '藥妝店', 'category': 'drugstore'},
    {'name': '丁丁藥局', 'type': '連鎖藥局', 'category': 'pharmacy'},

    // 家居與清潔
    {'name': 'HOLA', 'type': '家居用品', 'category': 'household'},
    {'name': '特力屋', 'type': '五金與家修', 'category': 'hardware'},
    {'name': 'IKEA', 'type': '家具家飾', 'category': 'household'},

    // 3C / 電器
    {'name': '燦坤3C', 'type': '電子產品', 'category': 'electronics'},
    {'name': '順發3C', 'type': '電子產品', 'category': 'electronics'},

    // 文具 / 書局
    {'name': '金石堂書店', 'type': '書局', 'category': 'stationery'},
    {'name': '誠品生活', 'type': '書局/生活選物', 'category': 'stationery'},

    // 服飾 / 百貨
    {'name': 'UNIQLO', 'type': '服飾', 'category': 'clothing'},
    {'name': 'H&M', 'type': '服飾', 'category': 'clothing'},
    {'name': '新光三越', 'type': '百貨公司', 'category': 'department'},

    // 寵物
    {'name': 'Pet House', 'type': '寵物用品', 'category': 'pet'},
    {'name': '寵物公園', 'type': '寵物用品', 'category': 'pet'},
  ];

  // 根據清單項目推薦商店的邏輯（擴大到日用品/藥妝等）
  static final Map<String, List<String>> _itemCategoryToStoreCategories = {
    'meat': ['meat', 'traditional', 'hypermarket', 'general'],
    'seafood': ['seafood', 'traditional', 'hypermarket', 'general'],
    'vegetables': ['vegetables', 'traditional', 'organic', 'hypermarket'],
    'fruits': ['fruits', 'traditional', 'organic', 'hypermarket'],
    'grocery': ['general', 'hypermarket', 'convenience', 'traditional'],
    'household': ['household', 'hypermarket', 'convenience', 'general'],
    'cleaning': ['household', 'hypermarket', 'convenience'],
    'paper_goods': ['household', 'hypermarket', 'convenience'],
    'pharmacy': ['pharmacy', 'drugstore', 'health', 'convenience'],
    'beauty': ['drugstore', 'department', 'general'],
    'electronics': ['electronics', 'department', 'general'],
    'hardware': ['hardware', 'household', 'general'],
    'stationery': ['stationery', 'department', 'general'],
    'clothing': ['clothing', 'department', 'general'],
    'pet': ['pet', 'general', 'department'],
    'default': ['general', 'hypermarket', 'convenience', 'department'],
  };

  // 使用 Google Places API 搜尋附近的商店
  Future<List<Map<String, dynamic>>> getNearbyStores(String itemName) async {
    try {
      // 獲取當前位置
      final position = await getCurrentLocation();
      if (position == null) {
        debugPrint('無法獲取位置，使用備用資料');
        return _getFallbackStores(itemName);
      }

      // 根據食材確定搜尋關鍵字
      final searchQuery = _getSearchQueryForItem(itemName);
      final placeType = _getPlaceTypeForItem(itemName);

      debugPrint('搜尋附近店家：$searchQuery (類型: $placeType)');

      // 呼叫 Google Places API Nearby Search
      final url = Uri.parse(
        'https://maps.googleapis.com/maps/api/place/nearbysearch/json?'
        'location=${position.latitude},${position.longitude}&'
        'radius=2000&'
        'keyword=$searchQuery&'
        'type=$placeType&'
        'language=zh-TW&'
        'key=$_googlePlacesApiKey',
      );

      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        if (data['status'] == 'OK' && data['results'] != null) {
          final results = data['results'] as List;
          final stores = <Map<String, dynamic>>[];

          // 處理搜尋結果
          for (int i = 0; i < math.min(5, results.length); i++) {
            final place = results[i];

            // 計算距離
            final placeLat = place['geometry']['location']['lat'];
            final placeLng = place['geometry']['location']['lng'];
            final distance = _calculateDistance(
              position.latitude,
              position.longitude,
              placeLat,
              placeLng,
            );

            // 判斷是否為推薦商店（距離最近的前1個）
            final isRecommended = i == 0;

            stores.add({
              'name': place['name'] ?? '未知店家',
              'type': _getStoreTypeName(place),
              'distance': '${distance.toStringAsFixed(1)}公里',
              'address': place['vicinity'] ?? '地址未提供',
              'recommended': isRecommended,
              'placeId': place['place_id'],
              'rating': place['rating']?.toString() ?? '',
              'isOpen': place['opening_hours']?['open_now'] ?? false,
            });
          }

          if (stores.isNotEmpty) {
            debugPrint('找到 ${stores.length} 個真實店家');
            return stores;
          }
        } else {
          debugPrint('Google Places API 返回狀態: ${data['status']}');
        }
      } else {
        debugPrint('Google Places API 請求失敗: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('搜尋附近店家失敗: $e');
    }

    // 如果 API 失敗，使用備用資料
    debugPrint('使用備用店家資料');
    return _getFallbackStores(itemName);
  }

  // 計算兩點之間的距離（公里）
  double _calculateDistance(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    const R = 6371; // 地球半徑（公里）
    final dLat = _toRadians(lat2 - lat1);
    final dLon = _toRadians(lon2 - lon1);

    final a =
        math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_toRadians(lat1)) *
            math.cos(_toRadians(lat2)) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);

    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return R * c;
  }

  double _toRadians(double degrees) {
    return degrees * math.pi / 180;
  }

  // 根據清單項目確定搜尋關鍵字
  String _getSearchQueryForItem(String name) {
    final lower = name.toLowerCase();

    if (_containsAny(lower, ['肉', '雞', '豬', '牛', '魚', '海鮮', '菜', '水果'])) {
      return '生鮮,超市,傳統市場,便利商店';
    }
    if (_containsAny(lower, ['米', '麵', '麵包', '吐司', '醬', '油', '鹽', '糖'])) {
      return '超市,雜貨店,生活百貨';
    }
    if (_containsAny(lower, ['藥', '保健', '維他命', '感冒'])) {
      return '藥局,藥妝店,保健品';
    }
    if (_containsAny(lower, ['洗髮', '沐浴', '洗衣', '清潔', '衛生紙'])) {
      return '生活用品,藥妝店,超市';
    }
    if (_containsAny(lower, ['電池', '耳機', '充電', '電器', '3c', 'usb'])) {
      return '電子產品,家電,3C';
    }
    if (_containsAny(lower, ['螺絲', '工具', '水管', '修理'])) {
      return '五金,家居,建材';
    }
    if (_containsAny(lower, ['筆', '文具', '紙', '筆記', '書'])) {
      return '文具,書局,生活百貨';
    }
    if (_containsAny(lower, ['衣', '褲', '鞋', '襪', '外套'])) {
      return '服飾,百貨,購物中心';
    }
    if (_containsAny(lower, ['貓', '狗', '寵物', '飼料'])) {
      return '寵物用品,生活百貨';
    }

    return '生活用品,百貨,超市,便利商店';
  }

  // 根據項目確定 Google Places 類型
  String _getPlaceTypeForItem(String name) {
    final lower = name.toLowerCase();

    if (_containsAny(lower, ['麵包', '吐司'])) return 'bakery';
    if (_containsAny(lower, ['咖啡', '茶'])) return 'cafe';
    if (_containsAny(lower, ['藥', '保健', '感冒'])) return 'pharmacy';
    if (_containsAny(lower, ['電', '3c', '充電', '耳機', 'usb'])) {
      return 'electronics_store';
    }
    if (_containsAny(lower, ['螺絲', '工具', '水管', '修理'])) {
      return 'hardware_store';
    }
    if (_containsAny(lower, ['貓', '狗', '寵物', '飼料'])) return 'pet_store';
    if (_containsAny(lower, ['衣', '褲', '鞋', '襪'])) return 'clothing_store';
    if (_containsAny(lower, ['家具', '沙發', '桌', '椅'])) {
      return 'furniture_store';
    }
    if (_containsAny(lower, ['筆', '文具', '書'])) return 'book_store';

    return 'store';
  }

  // 取得店家類型名稱
  String _getStoreTypeName(Map<String, dynamic> place) {
    final types = place['types'] as List?;
    if (types == null || types.isEmpty) return '商店';

    if (types.contains('supermarket')) return '超市';
    if (types.contains('grocery_or_supermarket')) return '超市';
    if (types.contains('convenience_store')) return '便利商店';
    if (types.contains('bakery')) return '麵包店';
    if (types.contains('cafe')) return '咖啡店';
    if (types.contains('restaurant')) return '餐廳';
    if (types.contains('store')) return '商店';

    return '商店';
  }

  // 備用店家資料（當 API 失敗時使用）
  List<Map<String, dynamic>> _getFallbackStores(String itemName) {
    final itemCategory = _getItemCategory(itemName);
    final recommendedCategories =
        _itemCategoryToStoreCategories[itemCategory] ??
        _itemCategoryToStoreCategories['default']!;

    // 從資料庫中篩選適合的商店
    final availableStores =
        _storeDatabase
            .where((store) => recommendedCategories.contains(store['category']))
            .toList();

    // 隨機選擇商店並生成距離
    final selectedStores = <Map<String, dynamic>>[];

    // 使用當前時間作為種子
    final timeSeed = DateTime.now().millisecondsSinceEpoch;
    final seededRandom = math.Random(timeSeed);

    // 選擇推薦商店
    final recommendedCategory = recommendedCategories.first;
    final recommendedStores =
        availableStores
            .where((store) => store['category'] == recommendedCategory)
            .toList();

    if (recommendedStores.isNotEmpty) {
      final recommendedStore =
          recommendedStores[seededRandom.nextInt(recommendedStores.length)];
      selectedStores.add({
        'name': recommendedStore['name'] as String,
        'type': recommendedStore['type'] as String,
        'distance':
            '${(seededRandom.nextDouble() * 2 + 0.3).toStringAsFixed(1)}公里',
        'address': '附近的${recommendedStore['type']}',
        'recommended': true,
      });
    }

    // 選擇其他商店
    final otherStores =
        availableStores
            .where((store) => store['category'] != recommendedCategory)
            .toList();

    final numOtherStores = math.min(3, otherStores.length);
    final shuffledOtherStores = otherStores..shuffle(seededRandom);

    for (int i = 0; i < numOtherStores; i++) {
      final store = shuffledOtherStores[i];
      selectedStores.add({
        'name': store['name'] as String,
        'type': store['type'] as String,
        'distance':
            '${(seededRandom.nextDouble() * 3 + 0.5).toStringAsFixed(1)}公里',
        'address': '附近的${store['type']}',
        'recommended': false,
      });
    }

    return selectedStores;
  }

  // 根據項目名稱確定類型
  String _getItemCategory(String name) {
    final lower = name.toLowerCase();

    if (_containsAny(lower, ['肉', '雞', '豬', '牛'])) return 'meat';
    if (_containsAny(lower, ['魚', '海鮮'])) return 'seafood';
    if (_containsAny(lower, ['蔬菜', '菜'])) return 'vegetables';
    if (_containsAny(lower, ['水果', '果'])) return 'fruits';
    if (_containsAny(lower, ['米', '麵', '麵包', '吐司', '醬', '油', '鹽', '糖'])) {
      return 'grocery';
    }
    if (_containsAny(lower, ['衛生紙', '垃圾袋', '清潔'])) return 'household';
    if (_containsAny(lower, ['洗衣', '洗髮', '洗澡'])) return 'cleaning';
    if (_containsAny(lower, ['藥', '感冒', '維他命', '保健'])) return 'pharmacy';
    if (_containsAny(lower, ['保養', '化妝', '面膜'])) return 'beauty';
    if (_containsAny(lower, ['電', '3c', '充電', '耳機', 'usb'])) {
      return 'electronics';
    }
    if (_containsAny(lower, ['螺絲', '工具', '水管', '修理'])) return 'hardware';
    if (_containsAny(lower, ['筆', '文具', '紙', '筆記', '書'])) return 'stationery';
    if (_containsAny(lower, ['衣', '褲', '鞋', '襪'])) return 'clothing';
    if (_containsAny(lower, ['貓', '狗', '寵物', '飼料'])) return 'pet';

    return 'default';
  }

  bool _containsAny(String source, List<String> keywords) {
    for (final keyword in keywords) {
      if (source.contains(keyword)) return true;
    }
    return false;
  }

  // 保留舊的方法以維持相容性
  String getStoreTypeForIngredient(String ingredient) {
    return _getStoreTypeForIngredientFallback(ingredient);
  }
}
