import 'models.dart';

/// 將中文分類字串映射到 FoodCategory enum
FoodCategory mapCategoryStringToEnum(String categoryStr) {
  switch (categoryStr) {
    case '水果':
      return FoodCategory.fruit;
    case '蔬菜':
      return FoodCategory.vegetable;
    case '乳製品':
      return FoodCategory.dairy;
    case '飲料':
      return FoodCategory.beverage;
    case '穀物':
    case '主食':
      return FoodCategory.staple;
    case '甜點':
    case '點心':
      return FoodCategory.dessert;
    case '肉類':
    case '海鮮':
    case '豆類':
    case '調味料':
    case '其他':
    default:
      return FoodCategory.other;
  }
}

/// 將 FoodCategory 轉換為顯示文字
String categoryDisplayName(FoodCategory category) {
  switch (category) {
    case FoodCategory.dairy:
      return '乳製品';
    case FoodCategory.dessert:
      return '甜點';
    case FoodCategory.fruit:
      return '水果';
    case FoodCategory.vegetable:
      return '蔬菜';
    case FoodCategory.staple:
      return '穀物/主食';
    case FoodCategory.beverage:
      return '飲料';
    case FoodCategory.other:
    default:
      return '其他';
  }
}

/// 根據食材名稱推測分類
FoodCategory guessCategoryFromFoodName(String foodName) {
  final name = foodName.toLowerCase();

  if (name.contains('牛奶') ||
      name.contains('優格') ||
      name.contains('起司') ||
      name.contains('奶油') ||
      name.contains('鮮奶') ||
      name.contains('優酪') ||
      name.contains('乳') ||
      name.contains('dairy')) {
    return FoodCategory.dairy;
  }

  if (name.contains('蛋糕') ||
      name.contains('布丁') ||
      name.contains('冰淇淋') ||
      name.contains('巧克力') ||
      name.contains('糖果') ||
      name.contains('餅乾') ||
      name.contains('甜點') ||
      name.contains('dessert')) {
    return FoodCategory.dessert;
  }

  if (name.contains('蘋果') ||
      name.contains('香蕉') ||
      name.contains('橘子') ||
      name.contains('葡萄') ||
      name.contains('草莓') ||
      name.contains('藍莓') ||
      name.contains('芒果') ||
      name.contains('鳳梨') ||
      name.contains('西瓜') ||
      name.contains('水果') ||
      name.contains('fruit')) {
    return FoodCategory.fruit;
  }

  if (name.contains('蔬菜') ||
      name.contains('vegetable') ||
      name.contains('青椒') ||
      name.contains('高麗菜') ||
      name.contains('花椰菜') ||
      name.contains('番茄') ||
      name.contains('馬鈴薯') ||
      name.contains('紅蘿蔔') ||
      name.contains('洋蔥') ||
      name.contains('青江菜')) {
    return FoodCategory.vegetable;
  }

  if (name.contains('米') ||
      name.contains('飯') ||
      name.contains('麵') ||
      name.contains('麵包') ||
      name.contains('吐司') ||
      name.contains('饅頭') ||
      name.contains('餅') ||
      name.contains('穀') ||
      name.contains('staple')) {
    return FoodCategory.staple;
  }

  if (name.contains('茶') ||
      name.contains('咖啡') ||
      name.contains('奶茶') ||
      name.contains('果汁') ||
      name.contains('飲料') ||
      name.contains('water') ||
      name.contains('juice')) {
    return FoodCategory.beverage;
  }

  return FoodCategory.other;
}

/// 根據分類提供建議保存天數
int suggestShelfLifeDays(FoodCategory category) {
  switch (category) {
    case FoodCategory.dairy:
      return 7;
    case FoodCategory.dessert:
      return 4;
    case FoodCategory.fruit:
      return 5;
    case FoodCategory.vegetable:
      return 3;
    case FoodCategory.staple:
      return 14;
    case FoodCategory.beverage:
      return 10;
    case FoodCategory.other:
    default:
      return 7;
  }
}
