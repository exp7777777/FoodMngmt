import 'dart:async';
import 'package:flutter/foundation.dart';
import 'models.dart';
import 'integrated_recipe_service.dart';

class RecipeSuggestion {
  final String title;
  final String? originalTitle; // 原始英文標題
  final List<String> steps;
  final Map<String, String> requiredItems; // name -> amount
  final Map<String, String> missingItems; // name -> amount
  final String? cookingTime;
  final String? difficulty;

  RecipeSuggestion({
    required this.title,
    this.originalTitle,
    required this.steps,
    required this.requiredItems,
    required this.missingItems,
    this.cookingTime,
    this.difficulty,
  });
}

class RecipeEngine {
  // 簡易本地知識庫（作為備用）
  static final List<Map<String, dynamic>> _fallbackRecipes = [
    {
      'title': '奶油香蕉優格杯',
      'requires': {'鮮乳優格': '200g', '香蕉': '1根', '蜂蜜': '1湯匙', '堅果': '少許'},
      'steps': ['香蕉切片', '杯中放入優格與香蕉', '淋上蜂蜜灑堅果即可'],
      'cookingTime': '5分鐘',
      'difficulty': '簡單',
    },
    {
      'title': '提拉米蘇聖代',
      'requires': {'提拉米蘇': '1份', '鮮乳優格': '150g', '可可粉': '少許'},
      'steps': ['杯中先放優格', '加入切塊提拉米蘇', '灑上可可粉'],
      'cookingTime': '3分鐘',
      'difficulty': '簡單',
    },
    {
      'title': '布丁牛奶冰沙',
      'requires': {'統一布丁': '1個', '鮮乳優格': '100g', '冰塊': '數顆'},
      'steps': ['全部放入果汁機', '打至綿密即可'],
      'cookingTime': '2分鐘',
      'difficulty': '簡單',
    },
    {
      'title': '番茄炒蛋',
      'requires': {'雞蛋': '3顆', '番茄': '2顆', '蔥': '1根', '鹽': '少許', '油': '適量'},
      'steps': ['番茄切塊', '蛋打散', '熱油炒蛋至半熟取出', '炒番茄至軟爛', '加入炒蛋翻炒', '加鹽調味灑蔥花即可'],
      'cookingTime': '15分鐘',
      'difficulty': '簡單',
    },
    {
      'title': '洋蔥炒肉絲',
      'requires': {'豬肉': '200g', '洋蔥': '1顆', '醬油': '2湯匙', '蒜': '2瓣', '油': '適量'},
      'steps': ['豬肉切絲醃醬油', '洋蔥切絲、蒜切末', '熱油炒蒜末', '加入肉絲炒至變色', '加入洋蔥炒軟', '調味起鍋'],
      'cookingTime': '20分鐘',
      'difficulty': '中等',
    },
    {
      'title': '馬鈴薯燉肉',
      'requires': {
        '豬肉': '300g',
        '馬鈴薯': '2顆',
        '胡蘿蔔': '1根',
        '洋蔥': '1顆',
        '醬油': '3湯匙',
        '糖': '1湯匙',
      },
      'steps': [
        '食材切塊',
        '肉先煎至表面金黃',
        '加入洋蔥炒香',
        '加入馬鈴薯和胡蘿蔔',
        '加水、醬油、糖燉煮30分鐘',
        '收汁即可',
      ],
      'cookingTime': '50分鐘',
      'difficulty': '中等',
    },
    {
      'title': '蔬菜炒飯',
      'requires': {
        '白飯': '2碗',
        '雞蛋': '2顆',
        '胡蘿蔔': '半根',
        '蔥': '2根',
        '鹽': '適量',
        '醬油': '1湯匙',
      },
      'steps': ['胡蘿蔔切丁、蔥切花', '蛋炒散取出', '炒胡蘿蔔丁', '加入白飯炒散', '加入炒蛋和蔥花', '調味即可'],
      'cookingTime': '15分鐘',
      'difficulty': '簡單',
    },
    {
      'title': '蘋果優格沙拉',
      'requires': {'蘋果': '1顆', '鮮乳優格': '150g', '蜂蜜': '1湯匙', '肉桂粉': '少許'},
      'steps': ['蘋果切丁', '加入優格拌勻', '淋上蜂蜜', '灑肉桂粉即可'],
      'cookingTime': '5分鐘',
      'difficulty': '簡單',
    },
    {
      'title': '香蕉煎餅',
      'requires': {
        '香蕉': '2根',
        '雞蛋': '2顆',
        '麵粉': '100g',
        '牛奶': '50ml',
        '糖': '1湯匙',
      },
      'steps': ['香蕉壓成泥', '加入蛋、麵粉、牛奶、糖拌勻', '平底鍋小火煎至兩面金黃', '可淋蜂蜜或糖漿'],
      'cookingTime': '20分鐘',
      'difficulty': '中等',
    },
    {
      'title': '清炒高麗菜',
      'requires': {'高麗菜': '半顆', '蒜': '3瓣', '鹽': '適量', '油': '適量'},
      'steps': ['高麗菜切塊、蒜切片', '熱油爆香蒜片', '加入高麗菜大火快炒', '加鹽調味即可'],
      'cookingTime': '10分鐘',
      'difficulty': '簡單',
    },
    {
      'title': '番茄蛋花湯',
      'requires': {'番茄': '2顆', '雞蛋': '2顆', '蔥': '1根', '鹽': '適量', '水': '800ml'},
      'steps': ['番茄切塊、蔥切花', '番茄炒軟', '加水煮滾', '蛋打散慢慢倒入', '加鹽和蔥花即可'],
      'cookingTime': '15分鐘',
      'difficulty': '簡單',
    },
    {
      'title': '馬鈴薯沙拉',
      'requires': {
        '馬鈴薯': '3顆',
        '雞蛋': '2顆',
        '美乃滋': '3湯匙',
        '鹽': '適量',
        '黑胡椒': '少許',
      },
      'steps': ['馬鈴薯和蛋煮熟', '馬鈴薯壓成泥、蛋切碎', '加入美乃滋拌勻', '加鹽和黑胡椒調味', '冷藏後更美味'],
      'cookingTime': '30分鐘',
      'difficulty': '簡單',
    },
    {
      'title': '蒜香炒麵',
      'requires': {'麵條': '200g', '蒜': '5瓣', '醬油': '2湯匙', '青菜': '適量', '油': '適量'},
      'steps': ['麵條煮熟瀝乾', '蒜切末', '熱油爆香蒜末', '加入麵條和青菜翻炒', '加醬油調味即可'],
      'cookingTime': '15分鐘',
      'difficulty': '簡單',
    },
    {
      'title': '雞蛋豆腐',
      'requires': {'雞蛋': '3顆', '豆腐': '1盒', '蔥': '1根', '醬油': '1湯匙', '油': '適量'},
      'steps': ['豆腐切塊', '蛋打散', '熱油煎豆腐至金黃', '倒入蛋液', '加醬油和蔥花即可'],
      'cookingTime': '12分鐘',
      'difficulty': '簡單',
    },
    {
      'title': '涼拌小黃瓜',
      'requires': {'小黃瓜': '2根', '蒜': '2瓣', '醬油': '1湯匙', '醋': '1湯匙', '糖': '少許'},
      'steps': ['小黃瓜切片拍碎', '蒜切末', '加入醬油、醋、糖拌勻', '冷藏30分鐘更入味'],
      'cookingTime': '10分鐘',
      'difficulty': '簡單',
    },
    {
      'title': '玉米濃湯',
      'requires': {
        '玉米罐頭': '1罐',
        '牛奶': '200ml',
        '麵粉': '1湯匙',
        '奶油': '適量',
        '鹽': '適量',
      },
      'steps': ['玉米加水煮滾', '麵粉加水調勻', '倒入玉米湯中', '加入牛奶和奶油', '調味即可'],
      'cookingTime': '20分鐘',
      'difficulty': '簡單',
    },
    {
      'title': '青椒炒肉絲',
      'requires': {'豬肉': '150g', '青椒': '2個', '蒜': '2瓣', '醬油': '1湯匙', '油': '適量'},
      'steps': ['肉絲醃醬油', '青椒切絲', '熱油炒肉絲', '加入青椒和蒜末', '快炒調味即可'],
      'cookingTime': '15分鐘',
      'difficulty': '簡單',
    },
    {
      'title': '蛋炒飯',
      'requires': {'白飯': '2碗', '雞蛋': '2顆', '蔥': '2根', '醬油': '1湯匙', '油': '適量'},
      'steps': ['蛋打散', '熱油炒蛋至半熟', '加入白飯炒散', '加醬油和蔥花', '翻炒均勻即可'],
      'cookingTime': '10分鐘',
      'difficulty': '簡單',
    },
    {
      'title': '三杯雞',
      'requires': {
        '雞腿': '2支',
        '薑': '適量',
        '蒜': '5瓣',
        '九層塔': '適量',
        '醬油': '1杯',
        '麻油': '1杯',
        '米酒': '1杯',
      },
      'steps': ['雞肉切塊', '爆香薑蒜', '加入雞肉煎至金黃', '倒入醬油、米酒、麻油', '燉煮15分鐘', '加九層塔即可'],
      'cookingTime': '30分鐘',
      'difficulty': '中等',
    },
    {
      'title': '糖醋排骨',
      'requires': {
        '排骨': '300g',
        '番茄醬': '3湯匙',
        '醋': '2湯匙',
        '糖': '2湯匙',
        '蒜': '3瓣',
      },
      'steps': ['排骨汆燙', '熱油炸至金黃', '爆香蒜末', '加番茄醬、醋、糖煮滾', '加入排骨翻炒均勻'],
      'cookingTime': '35分鐘',
      'difficulty': '中等',
    },
  ];

  // 使用整合食譜服務
  Future<List<RecipeSuggestion>> suggestWithGemini(
    List<FoodItem> inventory,
  ) async {
    try {
      debugPrint('使用整合食譜服務，食材數量: ${inventory.length}');

      // 使用新的整合食譜服務
      final suggestions = await IntegratedRecipeService.instance
          .generateRecipeSuggestions(inventory: inventory, numberOfRecipes: 10);

      if (suggestions.isNotEmpty) {
        debugPrint('成功獲得 ${suggestions.length} 個食譜推薦');
        return suggestions;
      } else {
        debugPrint('整合食譜服務返回空清單，改用備用食譜');
      }
    } catch (e) {
      debugPrint('整合食譜服務失敗，改用備用食譜: $e');
    }

    // 如果整合服務失敗，使用備用食譜
    debugPrint('使用備用食譜');
    return _getFallbackRecipes(inventory);
  }

  // 同步版本，使用備用食譜
  List<RecipeSuggestion> suggest(List<FoodItem> inventory) {
    return _getFallbackRecipes(inventory);
  }

  // 備用食譜邏輯（智慧比對版）
  List<RecipeSuggestion> _getFallbackRecipes(List<FoodItem> inventory) {
    final invNamesLower = inventory.map((e) => e.name.toLowerCase()).toSet();
    final suggestions = <RecipeSuggestion>[];

    // 常見調味料列表（僅限真正的調味料）
    final commonSeasonings = {
      '鹽',
      '糖',
      '醬油',
      '醋',
      '料酒',
      '米酒',
      '胡椒',
      '味精',
      '雞精',
      '香油',
      '麻油',
      '辣椒粉',
      '八角',
      '桂皮',
      '花椒',
      '五香粉',
    };

    for (final r in _fallbackRecipes) {
      final req = Map<String, String>.from(r['requires'] as Map);
      final missing = <String, String>{};

      req.forEach((name, amount) {
        final nameLower = name.toLowerCase();
        bool hasIngredient = false;

        // 1. 精確匹配
        if (invNamesLower.contains(nameLower)) {
          hasIngredient = true;
        }

        // 2. 包含匹配
        if (!hasIngredient) {
          for (final invName in invNamesLower) {
            if (invName.contains(nameLower) || nameLower.contains(invName)) {
              hasIngredient = true;
              break;
            }
          }
        }

        // 3. 常見調味料（精確匹配）
        if (!hasIngredient && commonSeasonings.contains(name)) {
          hasIngredient = true;
        }

        // 如果沒有該食材，加入缺少清單
        if (!hasIngredient) {
          missing[name] = amount;
        }
      });

      suggestions.add(
        RecipeSuggestion(
          title: r['title'] as String,
          steps: List<String>.from(r['steps'] as List),
          requiredItems: req,
          missingItems: missing,
          cookingTime: r['cookingTime'] as String?,
          difficulty: r['difficulty'] as String?,
        ),
      );
    }

    // 智慧排序：優先考慮即將到期食材，並且缺料少的食譜優先
    suggestions.sort((a, b) {
      // 首先比較缺料數量
      final missingComparison = a.missingItems.length.compareTo(
        b.missingItems.length,
      );
      if (missingComparison != 0) return missingComparison;

      // 如果缺料數量相同，優先選擇使用即將到期食材的食譜
      final aUsesExpiring = _recipeUsesExpiringIngredients(a, inventory);
      final bUsesExpiring = _recipeUsesExpiringIngredients(b, inventory);

      if (aUsesExpiring && !bUsesExpiring) return -1;
      if (!aUsesExpiring && bUsesExpiring) return 1;

      return 0;
    });
    return suggestions;
  }

  // 檢查食譜是否使用了即將到期的食材
  bool _recipeUsesExpiringIngredients(
    RecipeSuggestion recipe,
    List<FoodItem> inventory,
  ) {
    final now = DateTime.now();

    for (final item in inventory) {
      final daysUntilExpiry = item.expiryDate.difference(now).inDays;

      // 如果食材即將到期（3天內）
      if (daysUntilExpiry <= 3 && daysUntilExpiry >= 0) {
        // 檢查食譜是否使用了這個食材
        if (recipe.requiredItems.containsKey(item.name)) {
          return true;
        }
      }
    }

    return false;
  }

  // 獲取特定食材的食譜建議
  Future<List<RecipeSuggestion>> suggestRecipesForIngredient(
    String ingredient,
  ) async {
    try {
      // 創建假的食物項目列表，只包含這個食材
      final mockInventory = [
        FoodItem(
          name: ingredient,
          quantity: 1,
          unit: '份',
          purchaseDate: DateTime.now(),
          expiryDate: DateTime.now().add(const Duration(days: 7)),
          shelfLifeDays: 7,
          category: FoodCategory.other,
          storageLocation: StorageLocation.refrigerated,
          isOpened: false,
        ),
      ];

      return await suggestWithGemini(mockInventory);
    } catch (e) {
      debugPrint('獲取食材食譜建議失敗: $e');
      return [];
    }
  }
}
