import 'package:flutter/material.dart';
import 'dart:io';
import 'dart:async';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'azure_food_recognition.dart';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

import 'models.dart';
import 'providers.dart';

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

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.initial != null;
    final df = DateFormat('yyyy-MM-dd');
    return Scaffold(
      appBar: AppBar(title: Text(isEdit ? '編輯食材' : '新增食材')),
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
                        // 呼叫 Azure Food Recognition（若設定了 project/publish）
                        try {
                          final preds = await AzureFoodRecognition().predict(
                            File(picked.path),
                            detect: true,
                          );
                          if (preds.isNotEmpty) {
                            // 取最高分
                            preds.sort(
                              (a, b) => (b['probability'] as num).compareTo(
                                a['probability'] as num,
                              ),
                            );
                            final best = preds.first;
                            final tag = (best['tagName'] as String?)?.trim();
                            if (tag != null &&
                                tag.isNotEmpty &&
                                _name.text.trim().isEmpty) {
                              setState(() {
                                _name.text = tag;
                              });
                            }
                          }
                        } catch (_) {
                          // 靜默失敗，不影響手動輸入
                        }
                      }
                    },
                    icon: Icon(Icons.image),
                    label: Text('選擇圖片'),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _name,
                decoration: InputDecoration(labelText: '名稱'),
                validator:
                    (v) => (v == null || v.trim().isEmpty) ? '請輸入名稱' : null,
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _quantity,
                      decoration: InputDecoration(labelText: '數量'),
                      keyboardType: TextInputType.number,
                      validator:
                          (v) =>
                              (int.tryParse(v ?? '') == null) ? '請輸入數字' : null,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _unit,
                      decoration: InputDecoration(labelText: '單位 (件/g/ml)'),
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
                          (e) =>
                              DropdownMenuItem(value: e, child: Text(e.name)),
                        )
                        .toList(),
                onChanged:
                    (v) => setState(() => _category = v ?? FoodCategory.other),
                decoration: InputDecoration(labelText: '分類'),
              ),
              const SizedBox(height: 12),
              TextFormField(
                readOnly: true,
                decoration: InputDecoration(
                  labelText: '到期日',
                  suffixIcon: IconButton(
                    icon: Icon(Icons.date_range),
                    onPressed: _pickDate,
                  ),
                ),
                controller: TextEditingController(text: df.format(_expiry)),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _note,
                decoration: InputDecoration(labelText: '備註'),
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
                  final provider = context.read<FoodProvider>();
                  if (isEdit) {
                    await provider.update(item);
                  } else {
                    await provider.add(item);
                  }
                  if (!mounted) return;
                  Navigator.pop(context);
                },
                child: Text(isEdit ? '儲存變更' : '新增'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
