import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'models.dart';

/// 備用儲存服務
/// 當 Firebase 在某些平台上不可用時，提供本地儲存備用方案
class FallbackStorage {
  static FallbackStorage? _instance;
  static FallbackStorage get instance => _instance ??= FallbackStorage._();

  static const String _foodItemsKey = 'fallback_food_items';
  static const String _shoppingItemsKey = 'fallback_shopping_items';
  static const String _currentUserKey = 'fallback_current_user';

  FallbackStorage._();

  // ==================== 食物項目相關方法 ====================

  Future<List<FoodItem>> getFoodItems({
    String? keyword,
    bool? onlyExpiring,
    String? userId,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final foodItemsJson = prefs.getString(_foodItemsKey) ?? '[]';
      final List<dynamic> foodItemsData = json.decode(foodItemsJson);

      var items =
          foodItemsData
              .map((data) => FoodItem.fromMap(data as Map<String, dynamic>))
              .toList();

      // 篩選條件
      if (userId != null) {
        items = items.where((item) => item.account == userId).toList();
      }

      if (keyword != null && keyword.isNotEmpty) {
        items =
            items
                .where(
                  (item) =>
                      item.name.toLowerCase().contains(keyword.toLowerCase()),
                )
                .toList();
      }

      if (onlyExpiring == true) {
        final threeDaysFromNow = DateTime.now().add(const Duration(days: 3));
        items =
            items
                .where((item) => item.expiryDate.isBefore(threeDaysFromNow))
                .toList();
      }

      return items;
    } catch (e) {
      debugPrint('Error getting food items from fallback storage: $e');
      return [];
    }
  }

  Future<String> addFoodItem(FoodItem item, {String? userId}) async {
    try {
      final items = await getFoodItems();
      final newId = DateTime.now().millisecondsSinceEpoch.toString();
      final itemWithId = item.copyWith(id: newId, account: userId);

      items.add(itemWithId);
      await _saveFoodItems(items);

      return newId;
    } catch (e) {
      debugPrint('Error adding food item to fallback storage: $e');
      throw Exception('新增食物項目失敗：$e');
    }
  }

  Future<void> updateFoodItem(FoodItem item) async {
    try {
      final items = await getFoodItems();
      final index = items.indexWhere((i) => i.id == item.id);

      if (index != -1) {
        items[index] = item;
        await _saveFoodItems(items);
      }
    } catch (e) {
      debugPrint('Error updating food item in fallback storage: $e');
      throw Exception('更新食物項目失敗：$e');
    }
  }

  Future<void> deleteFoodItem(String id) async {
    try {
      final items = await getFoodItems();
      items.removeWhere((item) => item.id == id);
      await _saveFoodItems(items);
    } catch (e) {
      debugPrint('Error deleting food item from fallback storage: $e');
      throw Exception('刪除食物項目失敗：$e');
    }
  }

  Future<void> _saveFoodItems(List<FoodItem> items) async {
    final prefs = await SharedPreferences.getInstance();
    final itemsJson = json.encode(items.map((item) => item.toMap()).toList());
    await prefs.setString(_foodItemsKey, itemsJson);
  }

  // ==================== 購物清單相關方法 ====================

  Future<List<ShoppingItem>> getShoppingItems({String? userId}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final shoppingItemsJson = prefs.getString(_shoppingItemsKey) ?? '[]';
      final List<dynamic> shoppingItemsData = json.decode(shoppingItemsJson);

      var items =
          shoppingItemsData
              .map((data) => ShoppingItem.fromMap(data as Map<String, dynamic>))
              .toList();

      if (userId != null) {
        final filteredItems =
            items.where((item) {
              final matches = item.account == userId;
              return matches;
            }).toList();
        return filteredItems;
      }

      return items;
    } catch (e) {
      debugPrint('Error getting shopping items from fallback storage: $e');
      return [];
    }
  }

  Future<String> addShoppingItem(ShoppingItem item) async {
    try {
      final items = await getShoppingItems();
      final newId = DateTime.now().millisecondsSinceEpoch.toString();
      // 確保有正確的 account 欄位
      final itemWithId = item.copyWith(
        id: newId,
        account: item.account ?? 'unknown_user',
      );

      items.add(itemWithId);
      await _saveShoppingItems(items);

      return newId;
    } catch (e) {
      debugPrint('Error adding shopping item to fallback storage: $e');
      throw Exception('新增購物項目失敗：$e');
    }
  }

  Future<void> updateShoppingItem(ShoppingItem item) async {
    try {
      final items = await getShoppingItems();
      final index = items.indexWhere((i) => i.id == item.id);

      if (index != -1) {
        items[index] = item;
        await _saveShoppingItems(items);
      }
    } catch (e) {
      debugPrint('Error updating shopping item in fallback storage: $e');
      throw Exception('更新購物項目失敗：$e');
    }
  }

  Future<void> deleteShoppingItem(String id) async {
    try {
      final items = await getShoppingItems();
      items.removeWhere((item) => item.id == id);
      await _saveShoppingItems(items);
    } catch (e) {
      debugPrint('Error deleting shopping item from fallback storage: $e');
      throw Exception('刪除購物項目失敗：$e');
    }
  }

  Future<void> clearCompletedShoppingItems() async {
    try {
      final items = await getShoppingItems();
      items.removeWhere((item) => item.checked);
      await _saveShoppingItems(items);
    } catch (e) {
      debugPrint(
        'Error clearing completed shopping items from fallback storage: $e',
      );
      throw Exception('清除完成項目失敗：$e');
    }
  }

  Future<void> _saveShoppingItems(List<ShoppingItem> items) async {
    final prefs = await SharedPreferences.getInstance();
    final itemsJson = json.encode(items.map((item) => item.toMap()).toList());
    await prefs.setString(_shoppingItemsKey, itemsJson);
  }

  // ==================== 使用者相關方法 ====================

  Future<String?> getCurrentUserEmail() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(_currentUserKey);
    } catch (e) {
      debugPrint('Error getting current user from fallback storage: $e');
      return null;
    }
  }

  Future<void> setCurrentUserEmail(String email) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_currentUserKey, email);
    } catch (e) {
      debugPrint('Error setting current user in fallback storage: $e');
    }
  }

  Future<void> clearCurrentUser() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_currentUserKey);
    } catch (e) {
      debugPrint('Error clearing current user from fallback storage: $e');
    }
  }

  // ==================== 清理方法 ====================

  Future<void> clearAllData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_foodItemsKey);
      await prefs.remove(_shoppingItemsKey);
      await prefs.remove(_currentUserKey);
    } catch (e) {
      debugPrint('Error clearing all fallback data: $e');
    }
  }
}
