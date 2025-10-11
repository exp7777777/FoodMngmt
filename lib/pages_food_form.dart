import 'package:flutter/material.dart';
import 'dart:io';
import 'dart:async';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'gemini_service.dart';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

import 'models.dart';
import 'providers.dart';
import 'localization.dart';

class FoodFormPage extends StatefulWidget {
  final FoodItem? initial;
  const FoodFormPage({super.key, this.initial});

  @override
  State<FoodFormPage> createState() => _FoodFormPageState();
}

class _FoodFormPageState extends State<FoodFormPage> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _name;
  late TextEditingController _quantity;
  late TextEditingController _unit;
  late TextEditingController _note;
  DateTime _expiry = DateTime.now().add(Duration(days: 7));
  FoodCategory _category = FoodCategory.other;
  String? _imagePath;
  Timer? _nameDebounce;

  @override
  void initState() {
    super.initState();
    final i = widget.initial;
    _name = TextEditingController(text: i?.name ?? '');
    _quantity = TextEditingController(text: (i?.quantity ?? 1).toString());
    _unit = TextEditingController(text: i?.unit ?? '件');
    _note = TextEditingController(text: i?.note ?? '');
    _expiry = i?.expiryDate ?? _expiry;
    _category = i?.category ?? _category;
    _imagePath = i?.imagePath;

    // 當輸入名稱時，自動以 pollinations 產圖並設定為圖片（若尚未有圖片）
    _name.addListener(_onNameChanged);
  }

  @override
  void dispose() {
    _name.dispose();
    _quantity.dispose();
    _unit.dispose();
    _note.dispose();
    _nameDebounce?.cancel();
    super.dispose();
  }

  void _onNameChanged() {
    final text = _name.text.trim();
    if (text.isEmpty) return;
    _nameDebounce?.cancel();
    _nameDebounce = Timer(const Duration(milliseconds: 800), () {
      if (!mounted) return;
      if (_imagePath != null && _imagePath!.isNotEmpty) return; // 不覆蓋已選圖片
      _generateImageFromName(text);
    });
  }

  Future<void> _generateImageFromName(String name) async {
    final url =
        'https://image.pollinations.ai/prompt/${Uri.encodeComponent(name)}';
    try {
      final dir = await getApplicationDocumentsDirectory();
      final file = File(
        p.join(
          dir.path,
          'pollinations_${DateTime.now().millisecondsSinceEpoch}.jpg',
        ),
      );
      final resp = await Dio().get<List<int>>(
        url,
        options: Options(responseType: ResponseType.bytes),
      );
      if (resp.data != null) {
        await file.writeAsBytes(resp.data!);
        if (!mounted) return;
        setState(() {
          _imagePath = file.path;
        });
      }
    } catch (e) {
      // 失敗不影響表單流程
      debugPrint('pollinations image error: $e');
    }
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _expiry,
      firstDate: DateTime.now().subtract(Duration(days: 365)),
      lastDate: DateTime.now().add(Duration(days: 365 * 5)),
    );
    if (picked != null) setState(() => _expiry = picked);
  }

  // 獲取分類的顯示名稱
  String _getCategoryDisplayName(FoodCategory category, BuildContext context) {
    switch (category) {
      case FoodCategory.dairy:
        return AppLocalizations.of(context).categoryDairy;
      case FoodCategory.dessert:
        return AppLocalizations.of(context).categoryDessert;
      case FoodCategory.fruit:
        return AppLocalizations.of(context).categoryFruit;
      case FoodCategory.staple:
        return AppLocalizations.of(context).categoryStaple;
      case FoodCategory.beverage:
        return AppLocalizations.of(context).categoryBeverage;
      case FoodCategory.other:
        return AppLocalizations.of(context).categoryOther;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.initial != null;
    final df = DateFormat('yyyy-MM-dd');
    return Scaffold(
      appBar: AppBar(
        title: Text(
          isEdit
              ? AppLocalizations.of(context).editFood
              : AppLocalizations.of(context).addFood,
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 34,
                    backgroundColor: Colors.grey[300],
                    backgroundImage:
                        (_imagePath != null && _imagePath!.isNotEmpty)
                            ? FileImage(File(_imagePath!))
                            : null,
                    child:
                        (_imagePath == null || _imagePath!.isEmpty)
                            ? Icon(Icons.fastfood, color: Colors.white)
                            : null,
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton.icon(
                    onPressed: () async {
                      final picker = ImagePicker();
                      final picked = await picker.pickImage(
                        source: ImageSource.gallery,
                        imageQuality: 85,
                      );
                      if (picked != null) {
                        setState(() => _imagePath = picked.path);
                        // 呼叫 Gemini Food Recognition 進行智慧辨識
                        try {
                          final identifiedResult = await GeminiService.instance
                              .identifyFood(File(picked.path));

                          if (mounted && identifiedResult['success'] == true) {
                            final identifiedFoods =
                                identifiedResult['items'] as List<dynamic>;

                            if (identifiedFoods.isNotEmpty) {
                              // 選擇第一個辨識結果
                              final firstFood =
                                  identifiedFoods.first as Map<String, dynamic>;
                              final bestFoodName = firstFood['name'] as String;

                              if (bestFoodName.isNotEmpty &&
                                  _name.text.trim().isEmpty) {
                                setState(() {
                                  _name.text = bestFoodName;
                                  // 設定數量和單位
                                  _quantity.text =
                                      firstFood['quantity'].toString();
                                  _unit.text = firstFood['unit'];
                                  // 自動判斷並設定分類
                                  _category = _getCategoryFromFoodName(
                                    bestFoodName,
                                  );
                                });

                                // 顯示辨識成功提示
                                if (mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        '已辨識為：$bestFoodName ${firstFood['quantity']}${firstFood['unit']} (${_getCategoryDisplayName(_category, context)})',
                                      ),
                                      duration: const Duration(seconds: 3),
                                    ),
                                  );
                                }
                              }
                            } else if (identifiedFoods.length > 1) {
                              // 如果有多個辨識結果，顯示選擇對話框
                              if (mounted) {
                                _showFoodSelectionDialog(identifiedFoods);
                              }
                            }
                          } else if (mounted) {
                            // 辨識失敗，顯示提示
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('無法辨識圖片中的食物，請手動輸入名稱'),
                                duration: const Duration(seconds: 3),
                              ),
                            );
                          }
                        } catch (e) {
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('辨識失敗：$e'),
                                duration: const Duration(seconds: 3),
                              ),
                            );
                          }
                        }
                      }
                    },
                    icon: const Icon(Icons.image),
                    label: Text(AppLocalizations.of(context).selectImage),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _name,
                decoration: InputDecoration(
                  labelText: AppLocalizations.of(context).name,
                ),
                validator:
                    (v) =>
                        (v == null || v.trim().isEmpty)
                            ? AppLocalizations.of(context).pleaseEnterName
                            : null,
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _quantity,
                      decoration: InputDecoration(
                        labelText: AppLocalizations.of(context).quantity,
                      ),
                      keyboardType: TextInputType.number,
                      validator:
                          (v) =>
                              (int.tryParse(v ?? '') == null)
                                  ? AppLocalizations.of(
                                    context,
                                  ).pleaseEnterNumber
                                  : null,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _unit,
                      decoration: InputDecoration(
                        labelText: AppLocalizations.of(context).unit,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<FoodCategory>(
                value: _category,
                items:
                    FoodCategory.values
                        .map(
                          (e) => DropdownMenuItem(
                            value: e,
                            child: Text(_getCategoryDisplayName(e, context)),
                          ),
                        )
                        .toList(),
                onChanged:
                    (v) => setState(() => _category = v ?? FoodCategory.other),
                decoration: InputDecoration(
                  labelText: AppLocalizations.of(context).category,
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                readOnly: true,
                decoration: InputDecoration(
                  labelText: AppLocalizations.of(context).expiryDateLabel,
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.date_range),
                    onPressed: _pickDate,
                  ),
                ),
                controller: TextEditingController(text: df.format(_expiry)),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _note,
                decoration: InputDecoration(
                  labelText: AppLocalizations.of(context).note,
                ),
                maxLines: 2,
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () async {
                  if (!_formKey.currentState!.validate()) return;
                  final item = FoodItem(
                    id: widget.initial?.id,
                    name: _name.text.trim(),
                    quantity: int.parse(_quantity.text.trim()),
                    unit: _unit.text.trim().isEmpty ? '件' : _unit.text.trim(),
                    expiryDate: _expiry,
                    category: _category,
                    note: _note.text.trim().isEmpty ? null : _note.text.trim(),
                    imagePath: _imagePath,
                  );

                  // 檢查當前登入帳號
                  final prefs = await SharedPreferences.getInstance();
                  final account = prefs.getString('session_account');
                  debugPrint('當前登入帳號: $account');
                  debugPrint('FoodItem 資料: ${item.toMap()}');

                  // 檢查用戶是否登入
                  if (account == null || account.isEmpty) {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('請先登入才能新增食材'),
                          duration: Duration(seconds: 3),
                        ),
                      );
                    }
                    return;
                  }

                  final provider = context.read<FoodProvider>();
                  try {
                    if (isEdit) {
                      await provider.update(item);
                      debugPrint('食材更新成功');
                    } else {
                      await provider.add(item);
                      debugPrint('食材新增成功');
                    }

                    if (!mounted) return;

                    // 顯示成功訊息
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(isEdit ? '食材更新成功' : '食材新增成功'),
                        duration: const Duration(seconds: 2),
                      ),
                    );

                    Navigator.pop(context);
                  } catch (e) {
                    debugPrint('儲存食材失敗: $e');
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('儲存失敗：$e'),
                          duration: const Duration(seconds: 3),
                        ),
                      );
                    }
                  }
                },
                child: Text(
                  isEdit
                      ? AppLocalizations.of(context).saveChanges
                      : AppLocalizations.of(context).addNew,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // 根據食物名稱自動判斷分類
  FoodCategory _getCategoryFromFoodName(String foodName) {
    final name = foodName.toLowerCase();

    // 乳製品
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

    // 甜點
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

    // 水果
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

    // 主食
    if (name.contains('米') ||
        name.contains('麵') ||
        name.contains('麵包') ||
        name.contains('吐司') ||
        name.contains('義大利麵') ||
        name.contains('烏龍麵') ||
        name.contains('白飯') ||
        name.contains('粥') ||
        name.contains('麥片') ||
        name.contains('穀物') ||
        name.contains('staple')) {
      return FoodCategory.staple;
    }

    // 飲料
    if (name.contains('水') ||
        name.contains('茶') ||
        name.contains('咖啡') ||
        name.contains('果汁') ||
        name.contains('汽水') ||
        name.contains('牛奶') ||
        name.contains('飲料') ||
        name.contains('beverage') ||
        name.contains('juice')) {
      return FoodCategory.beverage;
    }

    // 其他（預設）
    return FoodCategory.other;
  }

  // 顯示食物選擇對話框（當有多個辨識結果時）
  void _showFoodSelectionDialog(List<dynamic> identifiedFoods) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('選擇辨識結果'),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: identifiedFoods.length,
              itemBuilder: (context, index) {
                final foodItem = identifiedFoods[index] as Map<String, dynamic>;
                final foodName = foodItem['name'] as String;
                final quantity = foodItem['quantity'] as int;
                final unit = foodItem['unit'] as String;

                return ListTile(
                  title: Text('$foodName ${quantity}${unit}'),
                  subtitle: Text(
                    _getCategoryDisplayName(
                      _getCategoryFromFoodName(foodName),
                      context,
                    ),
                  ),
                  leading: Radio<int>(
                    value: index,
                    groupValue: null,
                    onChanged: (value) {
                      if (value != null) {
                        setState(() {
                          _name.text = foodName;
                          _quantity.text = quantity.toString();
                          _unit.text = unit;
                          // 自動判斷並設定分類
                          _category = _getCategoryFromFoodName(foodName);
                        });
                        Navigator.of(context).pop();
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              '已選擇：$foodName ${quantity}${unit} (${_getCategoryDisplayName(_category, context)})',
                            ),
                            duration: const Duration(seconds: 2),
                          ),
                        );
                      }
                    },
                  ),
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('取消'),
            ),
          ],
        );
      },
    );
  }
}
