import 'package:flutter/material.dart';
import 'dart:io';
import 'dart:async';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

import 'models.dart';
import 'providers.dart';
import 'localization.dart';
import 'image_recognition_helper.dart';
import 'food_category_utils.dart';

class FoodFormPage extends StatefulWidget {
  final FoodItem? initial;
  final String? initialName;
  const FoodFormPage({super.key, this.initial, this.initialName});

  @override
  State<FoodFormPage> createState() => _FoodFormPageState();
}

class _FoodFormPageState extends State<FoodFormPage> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _name;
  late TextEditingController _quantity;
  late TextEditingController _unit;
  late TextEditingController _note;
  late TextEditingController _shelfLife;
  DateTime _purchaseDate = DateTime.now();
  DateTime _expiry = DateTime.now().add(Duration(days: 7));
  FoodCategory _category = FoodCategory.other;
  StorageLocation _storageLocation = StorageLocation.refrigerated;
  bool _isOpened = false;
  String? _imagePath;
  Timer? _nameDebounce;
  bool _isRecognizing = false;

  @override
  void initState() {
    super.initState();
    final i = widget.initial;
    // 優先使用 initialName（語音輸入），否則使用 initial 的 name
    final initialNameText = widget.initialName ?? i?.name ?? '';
    _name = TextEditingController(text: initialNameText);
    _quantity = TextEditingController(text: (i?.quantity ?? 1).toString());
    _unit = TextEditingController(text: i?.unit ?? '件');
    _note = TextEditingController(text: i?.note ?? '');
    _shelfLife = TextEditingController();

    // 計算到期日
    if (i != null) {
      _purchaseDate = i.purchaseDate;
      _expiry = i.expiryDate;
      final shelfLifeDays = i.shelfLifeDays;
      _shelfLife.text = shelfLifeDays > 0 ? shelfLifeDays.toString() : '1';
    } else {
      _purchaseDate = DateTime.now();
      _expiry = _purchaseDate.add(const Duration(days: 7));
      // 初始化為空，等待智慧建議或用戶輸入
      _shelfLife.text = '';
    }

    _category = i?.category ?? _category;
    _storageLocation = i?.storageLocation ?? _storageLocation;
    _isOpened = i?.isOpened ?? false;
    _imagePath = i?.imagePath;

    // 當輸入名稱時，自動以 pollinations 產圖並設定為圖片（若尚未有圖片）
    _name.addListener(_onNameChanged);

    // 初始化智慧建議（如果名稱不為空且不是編輯模式）
    // 編輯模式下不觸發智慧建議，保留用戶原本設定的天數
    // 包含語音輸入的情況
    if (_name.text.trim().isNotEmpty && widget.initial?.id == null) {
      _suggestShelfLife(_name.text.trim());
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _quantity.dispose();
    _unit.dispose();
    _note.dispose();
    _shelfLife.dispose();
    _nameDebounce?.cancel();
    super.dispose();
  }

  void _onNameChanged() {
    final text = _name.text.trim();
    if (text.isEmpty) return;
    _nameDebounce?.cancel();
    _nameDebounce = Timer(const Duration(milliseconds: 800), () async {
      if (!mounted) return;
      if (_imagePath != null && _imagePath!.isNotEmpty) return; // 不覆蓋已選圖片
      _generateImageFromName(text);

      // 智慧建議保存天數
      await _suggestShelfLife(text);
    });
  }

  Future<void> _suggestShelfLife(String foodName) async {
    // 暫時禁用 Gemini 服務，使用簡單的規則建議保存天數
    if (_shelfLife.text.isNotEmpty && _shelfLife.text != '7')
      return; // 如果用戶已經填寫了保存天數（且不是預設的7天），不覆蓋

    _applySimpleShelfLifeSuggestion(foodName);
  }

  void _applySimpleShelfLifeSuggestion(String foodName) {
    final lowerFoodName = foodName.toLowerCase();
    int suggestedDays = 7; // 預設7天

    // 根據食材類型設定建議保存天數
    if (lowerFoodName.contains('肉') ||
        lowerFoodName.contains('魚') ||
        lowerFoodName.contains('海鮮')) {
      suggestedDays = 3; // 肉類和海鮮建議3天
    } else if (lowerFoodName.contains('菜') ||
        lowerFoodName.contains('葉') ||
        lowerFoodName.contains('水果')) {
      suggestedDays = 5; // 蔬菜水果建議5天
    } else if (lowerFoodName.contains('牛奶') || lowerFoodName.contains('優格')) {
      suggestedDays = 7; // 乳製品建議7天
    } else if (lowerFoodName.contains('麵包') || lowerFoodName.contains('吐司')) {
      suggestedDays = 3; // 麵包建議3天
    } else if (lowerFoodName.contains('雞蛋')) {
      suggestedDays = 14; // 雞蛋建議14天
    }

    if (mounted) {
      setState(() {
        _shelfLife.text = suggestedDays.toString();
        _updateExpiryDate();
      });
    }
  }

  void _updateExpiryDate() {
    try {
      final shelfLifeDays = int.parse(_shelfLife.text);
      _expiry = _purchaseDate.add(Duration(days: shelfLifeDays));
    } catch (e) {
      debugPrint('計算到期日失敗: $e');
    }
  }

  void _updateShelfLifeFromExpiry() {
    try {
      final daysDifference = _expiry.difference(_purchaseDate).inDays;
      if (daysDifference > 0) {
        _shelfLife.text = daysDifference.toString();
      }
    } catch (e) {
      debugPrint('計算保存天數失敗: $e');
    }
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

  // 獲取分類的顯示名稱
  String _getCategoryDisplayName(FoodCategory category, BuildContext context) {
    switch (category) {
      case FoodCategory.dairy:
        return AppLocalizations.of(context).categoryDairy;
      case FoodCategory.dessert:
        return AppLocalizations.of(context).categoryDessert;
      case FoodCategory.fruit:
        return AppLocalizations.of(context).categoryFruit;
      case FoodCategory.vegetable:
        return AppLocalizations.of(context).categoryVegetable;
      case FoodCategory.staple:
        return AppLocalizations.of(context).categoryStaple;
      case FoodCategory.beverage:
        return AppLocalizations.of(context).categoryBeverage;
      case FoodCategory.other:
        return AppLocalizations.of(context).categoryOther;
    }
  }

  // 獲取儲存位置的顯示名稱
  String _getStorageLocationDisplayName(
    StorageLocation location,
    BuildContext context,
  ) {
    switch (location) {
      case StorageLocation.refrigerated:
        return '冷藏';
      case StorageLocation.frozen:
        return '冷凍';
      case StorageLocation.roomTemperature:
        return '室溫/櫥櫃';
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.initial?.id != null;
    final df = DateFormat('yyyy-MM-dd');
    return Stack(
      children: [
        Scaffold(
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
                            debugPrint('選擇的圖片路徑: ${picked.path}');
                            setState(() => _imagePath = picked.path);

                            // 檢查圖片檔案是否存在
                            final imageFile = File(picked.path);
                            if (!await imageFile.exists()) {
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('圖片檔案不存在，請重新選擇'),
                                    duration: Duration(seconds: 3),
                                  ),
                                );
                              }
                              return;
                            }

                            // 使用共用的影像辨識輔助函數
                            try {
                              setState(() => _isRecognizing = true);
                              debugPrint('開始辨識圖片...');

                              final identifiedFoods =
                                  await ImageRecognitionHelper.recognizeForForm(
                                    context: context,
                                    imageFile: imageFile,
                                  );

                              setState(() => _isRecognizing = false);

                              await Future.delayed(
                                const Duration(milliseconds: 100),
                              );

                              if (mounted && identifiedFoods != null) {
                                if (identifiedFoods.length == 1) {
                                  final firstFood = identifiedFoods.first;
                                  _applyRecognitionResult(firstFood);
                                } else {
                                  final sheetResult =
                                      await _showBatchImportSheet(
                                        identifiedFoods,
                                      );

                                  if (!mounted || sheetResult == null) return;

                                  if (sheetResult.action ==
                                      _BatchSheetAction.batchImport) {
                                    final selectedFoods =
                                        sheetResult.selectedIndexes
                                            .map(
                                              (index) => identifiedFoods[index],
                                            )
                                            .toList();
                                    await _batchAddDetectedFoods(selectedFoods);
                                  } else if (sheetResult.action ==
                                      _BatchSheetAction.pickSingle) {
                                    final selectedFood =
                                        await ImageRecognitionHelper.showFoodSelectionDialogForForm(
                                          context,
                                          identifiedFoods,
                                        );

                                    if (selectedFood != null && mounted) {
                                      _applyRecognitionResult(selectedFood);
                                    }
                                  }
                                }
                              }
                            } catch (e) {
                              setState(() => _isRecognizing = false);
                              debugPrint('辨識失敗詳細錯誤: $e');
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
                                child: Text(
                                  _getCategoryDisplayName(e, context),
                                ),
                              ),
                            )
                            .toList(),
                    onChanged:
                        (v) =>
                            setState(() => _category = v ?? FoodCategory.other),
                    decoration: InputDecoration(
                      labelText: AppLocalizations.of(context).category,
                    ),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<StorageLocation>(
                    value: _storageLocation,
                    items:
                        StorageLocation.values
                            .map(
                              (e) => DropdownMenuItem(
                                value: e,
                                child: Text(
                                  _getStorageLocationDisplayName(e, context),
                                ),
                              ),
                            )
                            .toList(),
                    onChanged:
                        (v) => setState(
                          () =>
                              _storageLocation =
                                  v ?? StorageLocation.refrigerated,
                        ),
                    decoration: InputDecoration(labelText: '儲存位置'),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          readOnly: true,
                          key: ValueKey(_purchaseDate),
                          decoration: InputDecoration(
                            labelText: '購買日期',
                            suffixIcon: IconButton(
                              icon: const Icon(Icons.date_range),
                              onPressed: () async {
                                final picked = await showDatePicker(
                                  context: context,
                                  initialDate: _purchaseDate,
                                  firstDate: DateTime.now().subtract(
                                    Duration(days: 365),
                                  ),
                                  lastDate: DateTime.now().add(
                                    Duration(days: 7),
                                  ),
                                );
                                if (picked != null) {
                                  setState(() {
                                    _purchaseDate = picked;
                                    _updateExpiryDate();
                                  });
                                }
                              },
                            ),
                          ),
                          controller: TextEditingController(
                            text: df.format(_purchaseDate),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextFormField(
                          controller: _shelfLife,
                          decoration: InputDecoration(
                            labelText: '保存天數',
                            suffixText: '天',
                          ),
                          keyboardType: TextInputType.number,
                          onChanged: (value) {
                            if (value.isNotEmpty) {
                              setState(() {
                                _updateExpiryDate();
                              });
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    readOnly: true,
                    key: ValueKey(_expiry),
                    decoration: InputDecoration(
                      labelText: '預計到期日',
                      suffixIcon: IconButton(
                        icon: const Icon(Icons.date_range),
                        onPressed: () async {
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: _expiry,
                            firstDate: DateTime.now(),
                            lastDate: DateTime.now().add(
                              Duration(days: 365 * 2),
                            ),
                          );
                          if (picked != null) {
                            setState(() {
                              _expiry = picked;
                              _updateShelfLifeFromExpiry();
                            });
                          }
                        },
                      ),
                    ),
                    controller: TextEditingController(text: df.format(_expiry)),
                  ),
                  const SizedBox(height: 12),
                  CheckboxListTile(
                    title: const Text('已開封'),
                    value: _isOpened,
                    onChanged: (value) {
                      setState(() {
                        _isOpened = value ?? false;
                      });
                    },
                    controlAffinity: ListTileControlAffinity.leading,
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
                      final parsedShelfLife = int.tryParse(
                        _shelfLife.text.trim(),
                      );
                      final calculatedShelfLife =
                          parsedShelfLife != null && parsedShelfLife > 0
                              ? parsedShelfLife
                              : (_expiry.difference(_purchaseDate).inDays > 0
                                  ? _expiry.difference(_purchaseDate).inDays
                                  : 1);

                      final item = FoodItem(
                        id: widget.initial?.id,
                        name: _name.text.trim(),
                        quantity: int.parse(_quantity.text.trim()),
                        unit:
                            _unit.text.trim().isEmpty ? '件' : _unit.text.trim(),
                        purchaseDate: _purchaseDate,
                        expiryDate: _expiry,
                        shelfLifeDays: calculatedShelfLife,
                        category: _category,
                        storageLocation: _storageLocation,
                        isOpened: _isOpened,
                        note:
                            _note.text.trim().isEmpty
                                ? null
                                : _note.text.trim(),
                        imagePath: _imagePath,
                      );

                      // 檢查用戶是否登入
                      final authProvider = context.read<AuthProvider>();
                      debugPrint('用戶登入狀態: ${authProvider.isLoggedIn}');
                      debugPrint('當前用戶ID: ${authProvider.currentUserId}');
                      debugPrint('FoodItem 資料: ${item.toMap()}');

                      if (!authProvider.isLoggedIn) {
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
        ),
        // Loading 遮罩層
        if (_isRecognizing)
          Container(
            color: Colors.black54,
            child: Center(
              child: Card(
                elevation: 8,
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircularProgressIndicator(),
                      const SizedBox(height: 16),
                      Text(
                        '正在辨識圖片...',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  /// 應用辨識結果到表單
  void _applyRecognitionResult(Map<String, dynamic> foodData) {
    final foodName = foodData['name'] as String;
    final quantity = foodData['quantity'] as int;
    final unit = foodData['unit'] as String;
    final categoryStr = foodData['category'] as String? ?? '其他';
    final category = mapCategoryStringToEnum(categoryStr);

    if (foodName.isNotEmpty && _name.text.trim().isEmpty) {
      setState(() {
        _name.text = foodName;
        _quantity.text = quantity.toString();
        _unit.text = unit;
        _category = category;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '已辨識為：$foodName $quantity$unit (${_getCategoryDisplayName(_category, context)})',
            ),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  Future<_BatchImportSheetResult?> _showBatchImportSheet(
    List<Map<String, dynamic>> foods,
  ) async {
    final selected = <int>{for (var i = 0; i < foods.length; i++) i};

    return showModalBottomSheet<_BatchImportSheetResult>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) {
        final bottomPadding = MediaQuery.of(sheetContext).padding.bottom;
        return FractionallySizedBox(
          heightFactor: 0.85,
          child: StatefulBuilder(
            builder: (context, setSheetState) {
              return SafeArea(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(16, 12, 16, bottomPadding + 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Center(
                        child: Container(
                          width: 48,
                          height: 4,
                          decoration: BoxDecoration(
                            color: Colors.grey[400],
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'YOLO 偵測到 ${foods.length} 種食材',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          TextButton.icon(
                            onPressed: () {
                              setSheetState(() {
                                if (selected.length == foods.length) {
                                  selected.clear();
                                } else {
                                  selected
                                    ..clear()
                                    ..addAll(
                                      List<int>.generate(
                                        foods.length,
                                        (index) => index,
                                      ),
                                    );
                                }
                              });
                            },
                            icon: Icon(
                              selected.length == foods.length
                                  ? Icons.select_all
                                  : Icons.done_all_outlined,
                            ),
                            label: Text(
                              selected.length == foods.length ? '取消全選' : '全選',
                            ),
                          ),
                          const Spacer(),
                          Text(
                            '已選 ${selected.length}/${foods.length}',
                            style: const TextStyle(fontSize: 12),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Expanded(
                        child: ListView.builder(
                          itemCount: foods.length,
                          itemBuilder: (context, index) {
                            final food = foods[index];
                            final confidence =
                                (food['confidence'] as num?)?.toDouble();
                            final quantity =
                                (food['quantity'] as num?)?.toInt() ?? 1;
                            final unit = food['unit']?.toString() ?? '件';
                            final categoryName =
                                food['category']?.toString() ?? '其他';

                            return CheckboxListTile(
                              value: selected.contains(index),
                              onChanged: (value) {
                                setSheetState(() {
                                  if (value == true) {
                                    selected.add(index);
                                  } else {
                                    selected.remove(index);
                                  }
                                });
                              },
                              title: Text(food['name']?.toString() ?? '未知食材'),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('分類：$categoryName'),
                                  if (confidence != null)
                                    Text(
                                      '信心：${(confidence * 100).toStringAsFixed(1)}%',
                                      style: const TextStyle(fontSize: 11),
                                    ),
                                ],
                              ),
                              secondary: Text('$quantity$unit'),
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 8),
                      ElevatedButton.icon(
                        onPressed:
                            selected.isEmpty
                                ? null
                                : () {
                                  Navigator.pop(
                                    sheetContext,
                                    _BatchImportSheetResult(
                                      _BatchSheetAction.batchImport,
                                      selected.toList(),
                                    ),
                                  );
                                },
                        icon: const Icon(Icons.playlist_add_check),
                        label: Text('加入管理頁 (${selected.length})'),
                      ),
                      TextButton(
                        onPressed: () {
                          Navigator.pop(
                            sheetContext,
                            const _BatchImportSheetResult(
                              _BatchSheetAction.pickSingle,
                              [],
                            ),
                          );
                        },
                        child: const Text('改為單筆填入表單'),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }

  Future<void> _batchAddDetectedFoods(
    List<Map<String, dynamic>> detectedFoods,
  ) async {
    if (detectedFoods.isEmpty) return;

    final authProvider = context.read<AuthProvider>();
    if (!authProvider.isLoggedIn) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('請先登入再使用批次新增功能'),
          duration: Duration(seconds: 3),
        ),
      );
      return;
    }

    final foodProvider = context.read<FoodProvider>();
    var successCount = 0;

    for (final food in detectedFoods) {
      try {
        final newItem = _createFoodItemFromDetection(food);
        await foodProvider.add(newItem);
        successCount++;
      } catch (e) {
        debugPrint('批次新增失敗：$e');
      }
    }

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('已新增 $successCount 筆食材'),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  FoodItem _createFoodItemFromDetection(Map<String, dynamic> foodData) {
    final name = (foodData['name'] ?? '未知食材').toString();
    final quantity = (foodData['quantity'] as num?)?.toInt() ?? 1;
    final unit = foodData['unit']?.toString() ?? '件';
    final category = mapCategoryStringToEnum(
      foodData['category'] as String? ?? '其他',
    );
    final purchaseDate = DateTime.now();
    final shelfLifeDays =
        (foodData['estimatedShelfLife'] as num?)?.toInt() ??
        suggestShelfLifeDays(category);
    final expiryDate = purchaseDate.add(Duration(days: shelfLifeDays));

    return FoodItem(
      name: name,
      quantity: quantity,
      unit: unit,
      purchaseDate: purchaseDate,
      expiryDate: expiryDate,
      shelfLifeDays: shelfLifeDays,
      category: category,
      storageLocation: StorageLocation.refrigerated,
      isOpened: false,
      imagePath: _imagePath,
    );
  }
}

enum _BatchSheetAction { batchImport, pickSingle }

class _BatchImportSheetResult {
  final _BatchSheetAction action;
  final List<int> selectedIndexes;

  const _BatchImportSheetResult(this.action, this.selectedIndexes);
}
