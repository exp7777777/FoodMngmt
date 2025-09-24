import 'package:foodmngmt/foodmngmt_AccountSettings.dart';
import 'package:provider/provider.dart';

import 'providers.dart';
// 自身檔案不需要重複匯入
import 'package:flutter/material.dart';

class HomePage extends StatefulWidget {
  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  // 儲存購物清單的核取方塊狀態
  final List<bool> _shoppingCheckboxValues = [
    false,
    false,
    false,
    false,
    false,
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFFFCF7EF), // 設定整個頁面的背景顏色
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start, // 子组件在水平方向上靠左对齐

          children: [
            const SizedBox(height: 30),
            // 左上角 - 用戶照片（改為按鈕）
            Row(
              children: [
                ElevatedButton(
                  style: ButtonStyle(
                    shape: MaterialStateProperty.all(CircleBorder()), // 圓形按鈕
                    padding: MaterialStateProperty.all(
                      EdgeInsets.all(0),
                    ), // 去除內邊距
                    backgroundColor: MaterialStateProperty.all(
                      Colors.transparent,
                    ), // 背景色透明
                    shadowColor: MaterialStateProperty.all(
                      Colors.transparent,
                    ), // 去除陰影
                  ),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => AccountSettings(),
                      ),
                    );
                  },
                  child: CircleAvatar(
                    radius: 50, // 設定圓形大小
                    backgroundColor: Colors.grey[300], // 沒有圖片時的背景顏色
                    child: Icon(Icons.person, size: 48, color: Colors.white),
                  ),
                ),
                const SizedBox(width: 16), // 間距
                const Text(
                  "卯咪愛喝茶",
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // ✅ 第一個表格 - 2x4 表格
            Table(
              border: TableBorder.all(
                color:
                    Theme.of(context).brightness == Brightness.dark
                        ? Colors
                            .white // 深色主題使用白色邊框
                        : Color(0xFFFF914D), // 淺色主題使用深橘色邊框
                width: 2,
              ), // 設定邊框顏色 & 粗細
              children: [
                TableRow(
                  decoration: BoxDecoration(
                    color:
                        Theme.of(context).brightness == Brightness.dark
                            ? Colors
                                .white // 深色主題使用白色背景
                            : Color(0xFFFF914D),
                  ), // 淺色主題使用深橘色背景
                  children: [
                    tableCell("即期食品"),
                    tableCell(""), // 空白格子
                  ],
                ),
                ...context.watch<FoodProvider>().items.take(3).map((f) {
                  final left = f.daysLeft;
                  final text =
                      left >= 0
                          ? (left == 0 ? '今天' : '$left天')
                          : '已過期${-left}天';
                  return TableRow(
                    children: [tableCell(f.name), tableCell(text)],
                  );
                }),
              ],
            ),
            const SizedBox(height: 20), // 隔間
            // ✅ 第二個表格 - 3x5 表格
            Table(
              border: TableBorder.all(
                color:
                    Theme.of(context).brightness == Brightness.dark
                        ? Colors
                            .white // 深色主題使用白色邊框
                        : Color(0xFFFF914D), // 淺色主題使用深橘色邊框
                width: 2,
              ), // 設定邊框顏色 & 粗細
              children: [
                TableRow(
                  decoration: BoxDecoration(
                    color:
                        Theme.of(context).brightness == Brightness.dark
                            ? Colors
                                .white // 深色主題使用白色背景
                            : Color(0xFFFF914D),
                  ), // 淺色主題使用深橘色背景
                  children: [tableCell(""), tableCell("購物清單"), tableCell("")],
                ),
                ...List.generate(
                  context.watch<ShoppingProvider>().items.take(5).length,
                  (i) {
                    final it = context.watch<ShoppingProvider>().items[i];
                    return TableRow(
                      children: [
                        tableCellWithCheckboxDynamic(it.id!, it.checked),
                        tableCell(it.name),
                        tableCell(it.amount ?? ''),
                      ],
                    );
                  },
                ),
              ],
            ),
          ],
        ),
      ),

      // 底部導覽移至 RootScaffold
    );
  }

  // 即期食品
  Widget tableCell(String text) {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Center(child: Text(text, style: const TextStyle(fontSize: 16))),
    );
  }

  // 購物清單
  Widget tableCellWithCheckbox(int index) {
    return Padding(
      padding: const EdgeInsets.all(1.0),
      child: Center(
        child: Checkbox(
          value: _shoppingCheckboxValues[index],
          onChanged: (bool? value) {
            setState(() {
              _shoppingCheckboxValues[index] = value ?? false;
            });
          },
        ),
      ),
    );
  }

  // 連動 Provider 的購物清單核取框
  Widget tableCellWithCheckboxDynamic(int id, bool checked) {
    return Padding(
      padding: const EdgeInsets.all(1.0),
      child: Center(
        child: Checkbox(
          value: checked,
          onChanged: (bool? value) {
            context.read<ShoppingProvider>().toggle(id, value ?? false);
          },
        ),
      ),
    );
  }
}
