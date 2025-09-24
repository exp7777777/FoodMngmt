// 移除未使用的匯入

enum FoodCategory { dairy, dessert, fruit, staple, beverage, other }

class FoodItem {
  final int? id;
  final String name;
  final int quantity; // 單位數量
  final String unit; // 例如 件、g、ml
  final DateTime expiryDate;
  final FoodCategory category;
  final String? note;
  final String? imagePath;
  final String? account; // 所屬帳號

  FoodItem({
    this.id,
    required this.name,
    required this.quantity,
    required this.unit,
    required this.expiryDate,
    this.category = FoodCategory.other,
    this.note,
    this.imagePath,
    this.account,
  });

  bool get isExpired => DateTime.now().isAfter(expiryDate);
  int get daysLeft => expiryDate.difference(DateTime.now()).inDays;

  FoodItem copyWith({
    int? id,
    String? name,
    int? quantity,
    String? unit,
    DateTime? expiryDate,
    FoodCategory? category,
    String? note,
    String? imagePath,
    String? account,
  }) {
    return FoodItem(
      id: id ?? this.id,
      name: name ?? this.name,
      quantity: quantity ?? this.quantity,
      unit: unit ?? this.unit,
      expiryDate: expiryDate ?? this.expiryDate,
      category: category ?? this.category,
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

  Map<String, dynamic> toMap() => {
    'id': id,
    'name': name,
    'quantity': quantity,
    'unit': unit,
    'expiryDate': expiryDate.toIso8601String(),
    'category': category.name,
    'note': note,
    'imagePath': imagePath,
    'account': account,
  };

  factory FoodItem.fromMap(Map<String, dynamic> map) => FoodItem(
    id: map['id'] as int?,
    name: map['name'] as String,
    quantity: map['quantity'] as int,
    unit: map['unit'] as String,
    expiryDate: DateTime.parse(map['expiryDate'] as String),
    category: categoryFromString(map['category'] as String? ?? 'other'),
    note: map['note'] as String?,
    imagePath: map['imagePath'] as String?,
    account: map['account'] as String?,
  );
}

class ShoppingItem {
  final int? id;
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
    int? id,
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
    id: map['id'] as int?,
    name: map['name'] as String,
    amount: map['amount'] as String?,
    checked: (map['checked'] as int? ?? 0) == 1,
    account: map['account'] as String?,
  );
}
