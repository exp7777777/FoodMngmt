// 強型別的食譜資料模型
// 用於處理 Gemini API 生成的食譜資料

/// 食譜難度等級
enum RecipeDifficulty {
  easy('簡單'),
  medium('中等'),
  hard('困難');

  const RecipeDifficulty(this.displayName);
  final String displayName;

  static RecipeDifficulty fromString(String value) {
    switch (value) {
      case '簡單':
        return RecipeDifficulty.easy;
      case '中等':
        return RecipeDifficulty.medium;
      case '困難':
        return RecipeDifficulty.hard;
      default:
        return RecipeDifficulty.medium;
    }
  }
}

/// 食譜食材
class RecipeIngredient {
  final String name;
  final String amount;
  final String? unit;

  const RecipeIngredient({required this.name, required this.amount, this.unit});

  factory RecipeIngredient.fromMap(Map<String, dynamic> map) {
    return RecipeIngredient(
      name: map['name'] as String? ?? '',
      amount: map['amount'] as String? ?? '',
      unit: map['unit'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {'name': name, 'amount': amount, if (unit != null) 'unit': unit};
  }

  /// 取得完整的食材描述
  String get fullDescription {
    if (unit != null) {
      return '$name $amount $unit';
    }
    return '$name $amount';
  }
}

/// 食譜步驟
class RecipeStep {
  final int number;
  final String description;

  const RecipeStep({required this.number, required this.description});

  factory RecipeStep.fromMap(Map<String, dynamic> map) {
    return RecipeStep(
      number: map['number'] as int? ?? 0,
      description: map['description'] as String? ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {'number': number, 'description': description};
  }
}

/// 完整食譜模型
class Recipe {
  final String id;
  final String title;
  final String? description;
  final int preparationTimeMinutes;
  final RecipeDifficulty difficulty;
  final List<RecipeIngredient> requiredIngredients;
  final List<RecipeIngredient> missingIngredients;
  final List<RecipeStep> steps;
  final String? imageUrl;
  final DateTime createdAt;
  final String source;

  const Recipe({
    required this.id,
    required this.title,
    this.description,
    required this.preparationTimeMinutes,
    required this.difficulty,
    required this.requiredIngredients,
    required this.missingIngredients,
    required this.steps,
    this.imageUrl,
    required this.createdAt,
    this.source = 'Gemini AI',
  });

  /// 從 JSON Map 建立 Recipe
  factory Recipe.fromMap(Map<String, dynamic> map) {
    return Recipe(
      id:
          map['id'] as String? ??
          DateTime.now().millisecondsSinceEpoch.toString(),
      title: map['title'] as String? ?? '未知食譜',
      description: map['description'] as String?,
      preparationTimeMinutes: _parseTimeToMinutes(
        map['preparationTime'] as String? ?? '30分鐘',
      ),
      difficulty: RecipeDifficulty.fromString(
        map['difficulty'] as String? ?? '中等',
      ),
      requiredIngredients:
          (map['requiredIngredients'] as List<dynamic>?)
              ?.map(
                (item) =>
                    RecipeIngredient.fromMap(item as Map<String, dynamic>),
              )
              .toList() ??
          [],
      missingIngredients:
          (map['missingIngredients'] as List<dynamic>?)
              ?.map(
                (item) =>
                    RecipeIngredient.fromMap(item as Map<String, dynamic>),
              )
              .toList() ??
          [],
      steps:
          (map['steps'] as List<dynamic>?)
              ?.map((item) => RecipeStep.fromMap(item as Map<String, dynamic>))
              .toList() ??
          [],
      imageUrl: map['imageUrl'] as String?,
      createdAt:
          DateTime.tryParse(map['createdAt'] as String? ?? '') ??
          DateTime.now(),
      source: map['source'] as String? ?? 'Gemini AI',
    );
  }

  /// 轉換為 JSON Map
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      if (description != null) 'description': description,
      'preparationTime': '${preparationTimeMinutes}分鐘',
      'difficulty': difficulty.displayName,
      'requiredIngredients':
          requiredIngredients.map((item) => item.toMap()).toList(),
      'missingIngredients':
          missingIngredients.map((item) => item.toMap()).toList(),
      'steps': steps.map((item) => item.toMap()).toList(),
      if (imageUrl != null) 'imageUrl': imageUrl,
      'createdAt': createdAt.toIso8601String(),
      'source': source,
    };
  }

  /// 取得烹飪時間的顯示文字
  String get preparationTimeText {
    if (preparationTimeMinutes < 60) {
      return '${preparationTimeMinutes}分鐘';
    } else {
      final hours = preparationTimeMinutes ~/ 60;
      final minutes = preparationTimeMinutes % 60;
      if (minutes == 0) {
        return '${hours}小時';
      } else {
        return '${hours}小時${minutes}分鐘';
      }
    }
  }

  /// 檢查是否有缺失食材
  bool get hasMissingIngredients => missingIngredients.isNotEmpty;

  /// 取得缺失食材數量
  int get missingIngredientCount => missingIngredients.length;

  /// 取得所需食材數量
  int get requiredIngredientCount => requiredIngredients.length;

  /// 檢查是否可以使用現有食材製作
  bool get canMakeWithAvailableIngredients => !hasMissingIngredients;

  /// 取得食材使用率（已擁有食材 / 總所需食材）
  double get ingredientUsageRate {
    if (requiredIngredientCount == 0) return 1.0;
    return (requiredIngredientCount - missingIngredientCount) /
        requiredIngredientCount;
  }

  /// 複製並修改 Recipe
  Recipe copyWith({
    String? id,
    String? title,
    String? description,
    int? preparationTimeMinutes,
    RecipeDifficulty? difficulty,
    List<RecipeIngredient>? requiredIngredients,
    List<RecipeIngredient>? missingIngredients,
    List<RecipeStep>? steps,
    String? imageUrl,
    DateTime? createdAt,
    String? source,
  }) {
    return Recipe(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      preparationTimeMinutes:
          preparationTimeMinutes ?? this.preparationTimeMinutes,
      difficulty: difficulty ?? this.difficulty,
      requiredIngredients: requiredIngredients ?? this.requiredIngredients,
      missingIngredients: missingIngredients ?? this.missingIngredients,
      steps: steps ?? this.steps,
      imageUrl: imageUrl ?? this.imageUrl,
      createdAt: createdAt ?? this.createdAt,
      source: source ?? this.source,
    );
  }

  @override
  String toString() {
    return 'Recipe(id: $id, title: $title, difficulty: ${difficulty.displayName}, time: $preparationTimeText)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Recipe && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}

/// 解析時間字串為分鐘數
int _parseTimeToMinutes(String timeString) {
  // 移除所有空白
  final cleanTime = timeString.replaceAll(RegExp(r'\s+'), '');

  // 匹配 "X小時Y分鐘" 格式
  final hourMinuteMatch = RegExp(r'(\d+)小時(\d+)分鐘').firstMatch(cleanTime);
  if (hourMinuteMatch != null) {
    final hours = int.tryParse(hourMinuteMatch.group(1) ?? '0') ?? 0;
    final minutes = int.tryParse(hourMinuteMatch.group(2) ?? '0') ?? 0;
    return hours * 60 + minutes;
  }

  // 匹配 "X小時" 格式
  final hourMatch = RegExp(r'(\d+)小時').firstMatch(cleanTime);
  if (hourMatch != null) {
    final hours = int.tryParse(hourMatch.group(1) ?? '0') ?? 0;
    return hours * 60;
  }

  // 匹配 "X分鐘" 格式
  final minuteMatch = RegExp(r'(\d+)分鐘').firstMatch(cleanTime);
  if (minuteMatch != null) {
    return int.tryParse(minuteMatch.group(1) ?? '30') ?? 30;
  }

  // 預設返回 30 分鐘
  return 30;
}

/// 食譜生成請求
class RecipeGenerationRequest {
  final List<String> availableIngredients;
  final int numberOfRecipes;
  final String? dietaryRestrictions;
  final String? cuisineType;

  const RecipeGenerationRequest({
    required this.availableIngredients,
    this.numberOfRecipes = 10,
    this.dietaryRestrictions,
    this.cuisineType,
  });

  Map<String, dynamic> toMap() {
    return {
      'availableIngredients': availableIngredients,
      'numberOfRecipes': numberOfRecipes,
      if (dietaryRestrictions != null)
        'dietaryRestrictions': dietaryRestrictions,
      if (cuisineType != null) 'cuisineType': cuisineType,
    };
  }
}

/// 食譜生成結果
class RecipeGenerationResult {
  final List<Recipe> recipes;
  final String? error;
  final DateTime generatedAt;
  final int requestCount;

  const RecipeGenerationResult({
    required this.recipes,
    this.error,
    required this.generatedAt,
    required this.requestCount,
  });

  bool get isSuccess => error == null && recipes.isNotEmpty;

  bool get hasError => error != null;

  int get recipeCount => recipes.length;

  factory RecipeGenerationResult.success({
    required List<Recipe> recipes,
    required int requestCount,
  }) {
    return RecipeGenerationResult(
      recipes: recipes,
      generatedAt: DateTime.now(),
      requestCount: requestCount,
    );
  }

  factory RecipeGenerationResult.error({
    required String error,
    required int requestCount,
  }) {
    return RecipeGenerationResult(
      recipes: [],
      error: error,
      generatedAt: DateTime.now(),
      requestCount: requestCount,
    );
  }
}
