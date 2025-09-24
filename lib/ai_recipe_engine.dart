import 'models.dart';

class RecipeSuggestion {
  final String title;
  final List<String> steps;
  final Map<String, String> requiredItems; // name -> amount
  final Map<String, String> missingItems; // name -> amount

  RecipeSuggestion({
    required this.title,
    required this.steps,
    required this.requiredItems,
    required this.missingItems,
  });
}

class RecipeEngine {
  // 簡易本地知識庫（可後續換成 LLM 或 RAG）
  static final List<Map<String, dynamic>> _recipes = [
    {
      'title': '奶油香蕉優格杯',
      'requires': {
        '鮮乳優格': '200g',
        '香蕉': '1根',
        '蜂蜜': '1湯匙',
        '堅果': '少許',
      },
      'steps': [
        '香蕉切片',
        '杯中放入優格與香蕉',
        '淋上蜂蜜灑堅果即可',
      ]
    },
    {
      'title': '提拉米蘇聖代',
      'requires': {
        '提拉米蘇': '1份',
        '鮮乳優格': '150g',
        '可可粉': '少許',
      },
      'steps': [
        '杯中先放優格',
        '加入切塊提拉米蘇',
        '灑上可可粉',
      ]
    },
    {
      'title': '布丁牛奶冰沙',
      'requires': {
        '統一布丁': '1個',
        '鮮乳優格': '100g',
        '冰塊': '數顆',
      },
      'steps': [
        '全部放入果汁機',
        '打至綿密即可',
      ]
    },
  ];

  List<RecipeSuggestion> suggest(List<FoodItem> inventory) {
    final invNames = inventory.map((e) => e.name).toList();
    final suggestions = <RecipeSuggestion>[];
    for (final r in _recipes) {
      final req = Map<String, String>.from(r['requires'] as Map);
      final missing = <String, String>{};
      req.forEach((name, amount) {
        final match = invNames.firstWhere(
          (n) => n.contains(name),
          orElse: () => '',
        );
        if (match.isEmpty) missing[name] = amount;
      });
      suggestions.add(
        RecipeSuggestion(
          title: r['title'] as String,
          steps: List<String>.from(r['steps'] as List),
          requiredItems: req,
          missingItems: missing,
        ),
      );
    }
    // 簡單排序：缺料少者優先，且優先使用即將到期食材的食譜
    suggestions.sort((a, b) => a.missingItems.length.compareTo(b.missingItems.length));
    return suggestions;
  }
}


