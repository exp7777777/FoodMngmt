// 移除未使用的匯入

enum FoodCategory { dairy, dessert, fruit, vegetable, staple, beverage, other }

enum StorageLocation { refrigerated, frozen, roomTemperature }

class FoodItem {
  final String? id;
  final String name;
  final int quantity; // 單位數量
  final String unit; // 例如 件、g、ml
  final DateTime purchaseDate; //購買日期
  final DateTime expiryDate; //到期日期
  final int shelfLifeDays; //保存天數
  final FoodCategory category; //食材類型
  final StorageLocation storageLocation; //儲存位置
  final bool isOpened; //是否開封
  final String? note; //備註
  final String? imagePath; //圖片路徑
  final String? account; // 所屬用戶

  FoodItem({
    this.id,
    required this.name,
    required this.quantity,
    required this.unit,
    DateTime? purchaseDate,
    required this.expiryDate,
    int? shelfLifeDays,
    this.category = FoodCategory.other,
    this.storageLocation = StorageLocation.refrigerated,
    this.isOpened = false,
    this.note,
    this.imagePath,
    this.account,
  }) : purchaseDate = purchaseDate ?? DateTime.now(),
       shelfLifeDays =
           shelfLifeDays ??
           _calculateShelfLife(expiryDate, purchaseDate ?? DateTime.now());

  bool get isExpired => DateTime.now().isAfter(expiryDate);
  int get daysLeft => expiryDate.difference(DateTime.now()).inDays;

  FoodItem copyWith({
    String? id,
    String? name,
    int? quantity,
    String? unit,
    DateTime? purchaseDate,
    DateTime? expiryDate,
    int? shelfLifeDays,
    FoodCategory? category,
    StorageLocation? storageLocation,
    bool? isOpened,
    String? note,
    String? imagePath,
    String? account,
  }) {
    return FoodItem(
      id: id ?? this.id,
      name: name ?? this.name,
      quantity: quantity ?? this.quantity,
      unit: unit ?? this.unit,
      purchaseDate: purchaseDate ?? this.purchaseDate,
      expiryDate: expiryDate ?? this.expiryDate,
      shelfLifeDays: shelfLifeDays ?? this.shelfLifeDays,
      category: category ?? this.category,
      storageLocation: storageLocation ?? this.storageLocation,
      isOpened: isOpened ?? this.isOpened,
      note: note ?? this.note,
      imagePath: imagePath ?? this.imagePath,
      account: account ?? this.account,
    );
  }

  static FoodCategory categoryFromString(String value) {
    return FoodCategory.values.firstWhere(
      (e) => e.name == value,
      orElse: () => FoodCategory.other,
    );
  }

  static StorageLocation storageLocationFromString(String value) {
    return StorageLocation.values.firstWhere(
      (e) => e.name == value,
      orElse: () => StorageLocation.refrigerated,
    );
  }

  Map<String, dynamic> toMap() => {
    'id': id,
    'name': name,
    'quantity': quantity,
    'unit': unit,
    'purchaseDate': purchaseDate.toIso8601String(),
    'expiryDate': expiryDate.toIso8601String(),
    'shelfLifeDays': shelfLifeDays,
    'category': category.name,
    'storageLocation': storageLocation.name,
    'isOpened': isOpened,
    'note': note,
    'imagePath': imagePath,
    'account': account,
  };

  factory FoodItem.fromMap(Map<String, dynamic> map) {
    final expiry =
        _parseDateTime(map['expiryDate']) ??
        DateTime.now().add(const Duration(days: 7));
    final purchase =
        _parseDateTime(map['purchaseDate']) ??
        expiry.subtract(const Duration(days: 7));

    return FoodItem(
      id: map['id'] as String?,
      name: map['name'] as String,
      quantity:
          (map['quantity'] is int)
              ? map['quantity'] as int
              : (map['quantity'] as num).toInt(),
      unit: map['unit'] as String,
      purchaseDate: purchase,
      expiryDate: expiry,
      shelfLifeDays: _parseShelfLife(map['shelfLifeDays'], expiry, purchase),
      category: categoryFromString(map['category'] as String? ?? 'other'),
      storageLocation: storageLocationFromString(
        map['storageLocation'] as String? ?? 'refrigerated',
      ),
      isOpened: map['isOpened'] as bool? ?? false,
      note: map['note'] as String?,
      imagePath: map['imagePath'] as String?,
      account: map['account'] as String?,
    );
  }

  static int _calculateShelfLife(DateTime expiry, DateTime purchase) {
    final diff = expiry.difference(purchase).inDays;
    return diff > 0 ? diff : 1;
  }

  static DateTime? _parseDateTime(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    if (value is String) {
      try {
        return DateTime.parse(value);
      } catch (_) {
        return null;
      }
    }
    return null;
  }

  static int _parseShelfLife(
    dynamic value,
    DateTime expiry,
    DateTime purchase,
  ) {
    if (value is int) return value;
    if (value is String) {
      final parsed = int.tryParse(value);
      if (parsed != null) return parsed;
    }
    final diff = expiry.difference(purchase).inDays;
    return diff > 0 ? diff : 7;
  }
}

class ShoppingItem {
  final String? id;
  final String name;
  final String? amount; // 例如 125g, 2件
  final bool checked;
  final String? account; // 所屬帳號

  ShoppingItem({
    this.id,
    required this.name,
    this.amount,
    this.checked = false,
    this.account,
  });

  ShoppingItem copyWith({
    String? id,
    String? name,
    String? amount,
    bool? checked,
    String? account,
  }) {
    return ShoppingItem(
      id: id ?? this.id,
      name: name ?? this.name,
      amount: amount ?? this.amount,
      checked: checked ?? this.checked,
      account: account ?? this.account,
    );
  }

  Map<String, dynamic> toMap() => {
    'id': id,
    'name': name,
    'amount': amount,
    'checked': checked ? 1 : 0,
    'account': account,
  };

  factory ShoppingItem.fromMap(Map<String, dynamic> map) => ShoppingItem(
    id: map['id'] as String?,
    name: map['name'] as String,
    amount: map['amount'] as String?,
    checked: _parseChecked(map['checked']),
    account: map['account'] as String? ?? map['userId'] as String?,
  );

  // 處理 checked 欄位的不同資料類型
  static bool _parseChecked(dynamic value) {
    if (value == null) return false;
    if (value is bool) return value;
    if (value is int) return value == 1;
    if (value is String) return value == '1' || value.toLowerCase() == 'true';
    return false;
  }
}
