import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'models.dart';

// 載具資料模型
class InvoiceCarrier {
  final String carrierId;
  final String carrierType;
  final DateTime boundDate;

  InvoiceCarrier({
    required this.carrierId,
    required this.carrierType,
    required this.boundDate,
  });

  Map<String, dynamic> toMap() => {
    'carrierId': carrierId,
    'carrierType': carrierType,
    'boundDate': boundDate.toIso8601String(),
  };

  factory InvoiceCarrier.fromMap(Map<String, dynamic> map) => InvoiceCarrier(
    carrierId: map['carrierId'] as String,
    carrierType: map['carrierType'] as String,
    boundDate: DateTime.parse(map['boundDate'] as String),
  );
}

class InvoiceService {
  static final InvoiceService _instance = InvoiceService._internal();
  factory InvoiceService() => _instance;
  InvoiceService._internal();

  static InvoiceService get instance => _instance;

  // 假資料商品清單
  static const List<Map<String, dynamic>> _fakeProducts = [
    {'name': '白米', 'category': '主食', 'expiryDays': 365, 'amount': '1kg'},
    {'name': '雞蛋', 'category': '蛋類', 'expiryDays': 21, 'amount': '10顆'},
    {'name': '牛奶', 'category': '乳製品', 'expiryDays': 7, 'amount': '1L'},
    {'name': '吐司', 'category': '麵包', 'expiryDays': 5, 'amount': '1條'},
    {'name': '蘋果', 'category': '水果', 'expiryDays': 21, 'amount': '6顆'},
    {'name': '香蕉', 'category': '水果', 'expiryDays': 7, 'amount': '1串'},
    {'name': '番茄', 'category': '蔬菜', 'expiryDays': 10, 'amount': '500g'},
    {'name': '胡蘿蔔', 'category': '蔬菜', 'expiryDays': 21, 'amount': '1kg'},
    {'name': '洋蔥', 'category': '蔬菜', 'expiryDays': 30, 'amount': '1kg'},
    {'name': '馬鈴薯', 'category': '蔬菜', 'expiryDays': 14, 'amount': '1kg'},
    {'name': '雞胸肉', 'category': '肉類', 'expiryDays': 3, 'amount': '500g'},
    {'name': '豬肉', 'category': '肉類', 'expiryDays': 3, 'amount': '300g'},
    {'name': '鮭魚', 'category': '海鮮', 'expiryDays': 2, 'amount': '400g'},
    {'name': '豆腐', 'category': '豆製品', 'expiryDays': 5, 'amount': '1盒'},
    {'name': '起司', 'category': '乳製品', 'expiryDays': 14, 'amount': '200g'},
    {'name': '優格', 'category': '乳製品', 'expiryDays': 10, 'amount': '4杯'},
    {'name': '義大利麵', 'category': '主食', 'expiryDays': 730, 'amount': '500g'},
    {'name': '橄欖油', 'category': '調味料', 'expiryDays': 730, 'amount': '500ml'},
    {'name': '鹽', 'category': '調味料', 'expiryDays': 1825, 'amount': '1包'},
    {'name': '糖', 'category': '調味料', 'expiryDays': 1095, 'amount': '1kg'},
  ];

  /// 獲取已綁定的載具
  Future<List<InvoiceCarrier>> getBoundCarriers() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final carriersData = prefs.getStringList('bound_carriers') ?? [];

      return carriersData.map((data) {
        final map = Map<String, dynamic>.from(
          data
              .split('|')
              .asMap()
              .map(
                (index, value) => MapEntry(
                  ['carrierId', 'carrierType', 'boundDate'][index],
                  value,
                ),
              ),
        );
        return InvoiceCarrier.fromMap(map);
      }).toList();
    } catch (e) {
      debugPrint('獲取綁定載具失敗: $e');
      return [];
    }
  }

  /// 綁定載具
  Future<bool> bindCarrier(String carrierId, String carrierType) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final carriers = await getBoundCarriers();

      // 檢查是否已存在
      if (carriers.any((carrier) => carrier.carrierId == carrierId)) {
        return false;
      }

      final newCarrier = InvoiceCarrier(
        carrierId: carrierId,
        carrierType: carrierType,
        boundDate: DateTime.now(),
      );

      carriers.add(newCarrier);

      final carriersData =
          carriers
              .map(
                (carrier) =>
                    '${carrier.carrierId}|${carrier.carrierType}|${carrier.boundDate.toIso8601String()}',
              )
              .toList();

      await prefs.setStringList('bound_carriers', carriersData);
      return true;
    } catch (e) {
      debugPrint('綁定載具失敗: $e');
      return false;
    }
  }

  /// 解除綁定載具
  Future<bool> unbindCarrier(String carrierId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final carriers = await getBoundCarriers();

      carriers.removeWhere((carrier) => carrier.carrierId == carrierId);

      final carriersData =
          carriers
              .map(
                (carrier) =>
                    '${carrier.carrierId}|${carrier.carrierType}|${carrier.boundDate.toIso8601String()}',
              )
              .toList();

      await prefs.setStringList('bound_carriers', carriersData);
      return true;
    } catch (e) {
      debugPrint('解除綁定載具失敗: $e');
      return false;
    }
  }

  /// 同步發票資料（舊方法，保持相容性）
  Future<List<FoodItem>> syncInvoices() async {
    try {
      final today = DateTime.now();
      final todayKey = '${today.year}-${today.month}-${today.day}';

      // 檢查今天是否已經同步過
      final prefs = await SharedPreferences.getInstance();
      final lastSyncDate = prefs.getString('last_invoice_sync_date');

      if (lastSyncDate == todayKey) {
        debugPrint('今天已經同步過發票，跳過');
        return [];
      }

      // 生成隨機商品
      final random = Random();
      final itemCount = random.nextInt(5) + 3; // 3-7個商品
      final selectedProducts = <Map<String, dynamic>>[];

      // 隨機選擇商品
      final shuffledProducts = List.from(_fakeProducts)..shuffle(random);
      for (int i = 0; i < itemCount && i < shuffledProducts.length; i++) {
        selectedProducts.add(shuffledProducts[i]);
      }

      // 轉換為 FoodItem
      final foodItems = <FoodItem>[];
      for (final product in selectedProducts) {
        final expiryDate = today.add(Duration(days: product['expiryDays']));
        final foodItem = FoodItem(
          id:
              DateTime.now().millisecondsSinceEpoch.toString() +
              random.nextInt(1000).toString(),
          name: product['name'],
          quantity: 1,
          unit: product['amount'],
          expiryDate: expiryDate,
          category: FoodCategory.other,
          account: 'invoice_sync', // 標記為發票同步的商品
        );
        foodItems.add(foodItem);
      }

      // 儲存同步日期
      await prefs.setString('last_invoice_sync_date', todayKey);

      debugPrint('發票同步完成，生成 ${foodItems.length} 個商品');
      return foodItems;
    } catch (e) {
      debugPrint('發票同步失敗: $e');
      return [];
    }
  }

  /// 檢查今天是否已經同步過
  Future<bool> hasSyncedToday() async {
    try {
      final today = DateTime.now();
      final todayKey = '${today.year}-${today.month}-${today.day}';

      final prefs = await SharedPreferences.getInstance();
      final lastSyncDate = prefs.getString('last_invoice_sync_date');

      return lastSyncDate == todayKey;
    } catch (e) {
      debugPrint('檢查同步狀態失敗: $e');
      return false;
    }
  }

  /// 重置同步狀態（用於測試）
  Future<void> resetSyncStatus() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('last_invoice_sync_date');
      debugPrint('同步狀態已重置');
    } catch (e) {
      debugPrint('重置同步狀態失敗: $e');
    }
  }

  /// 同步發票資料（新方法，用於載具同步）
  Future<List<Map<String, dynamic>>> syncInvoicesForCarrier(
    String carrierId,
  ) async {
    try {
      final today = DateTime.now();
      final todayKey = '${today.year}-${today.month}-${today.day}';

      // 記錄同步時間（但不阻止多次同步）
      final prefs = await SharedPreferences.getInstance();
      final lastSyncDate = prefs.getString('last_invoice_sync_date_$carrierId');
      final lastSyncTime = prefs.getString('last_invoice_sync_time_$carrierId');

      debugPrint('載具 $carrierId 上次同步時間: $lastSyncDate $lastSyncTime');

      // 基於日期生成固定的商品組合（每天都一樣）
      final dateSeed = today.year * 10000 + today.month * 100 + today.day;
      final random = Random(dateSeed);
      final itemCount = random.nextInt(5) + 3; // 3-7個商品
      final selectedProducts = <Map<String, dynamic>>[];

      // 使用固定種子確保每天生成的商品組合相同
      final seededRandom = Random(dateSeed);
      final shuffledProducts = List.from(_fakeProducts)..shuffle(seededRandom);
      for (int i = 0; i < itemCount && i < shuffledProducts.length; i++) {
        selectedProducts.add(shuffledProducts[i]);
      }

      // 轉換為發票項目格式
      final invoiceItems = <Map<String, dynamic>>[];
      for (final product in selectedProducts) {
        final invoiceItem = {
          'productName': product['name'],
          'category': product['category'],
          'amount': product['amount'],
          'estimatedShelfLife': product['expiryDays'],
          'carrierId': carrierId,
          'syncDate': today.toIso8601String(),
        };
        invoiceItems.add(invoiceItem);
      }

      // 儲存同步時間（詳細記錄）
      await prefs.setString('last_invoice_sync_date_$carrierId', todayKey);
      await prefs.setString(
        'last_invoice_sync_time_$carrierId',
        '${today.hour}:${today.minute}:${today.second}',
      );

      debugPrint('載具 $carrierId 發票同步完成，生成 ${invoiceItems.length} 個商品');
      return invoiceItems;
    } catch (e) {
      debugPrint('載具 $carrierId 發票同步失敗: $e');
      return [];
    }
  }

  /// 辨識食物項目（將發票項目轉換為食物項目）
  Future<List<Map<String, dynamic>>> identifyFoodItems(
    List<Map<String, dynamic>> invoiceItems,
  ) async {
    try {
      final foodItems = <Map<String, dynamic>>[];

      for (final invoiceItem in invoiceItems) {
        final foodItem = {
          'productName': invoiceItem['productName'],
          'category': invoiceItem['category'],
          'amount': invoiceItem['amount'],
          'estimatedShelfLife': invoiceItem['estimatedShelfLife'],
          'source': 'invoice_sync',
        };
        foodItems.add(foodItem);
      }

      return foodItems;
    } catch (e) {
      debugPrint('辨識食物項目失敗: $e');
      return [];
    }
  }
}
