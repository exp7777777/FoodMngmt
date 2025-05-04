import 'package:foodmngmt/foodmngmt_AccountRegister.dart';
import 'package:foodmngmt/foodmngmt_AccountSettings.dart';
import 'package:foodmngmt/foodmngmt_FoodManager.dart';
import 'package:foodmngmt/foodmngmt_HomePage.dart';
import 'package:flutter/material.dart';
import 'main.dart';

class HomePage extends StatefulWidget {
  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {

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
                    padding: MaterialStateProperty.all(EdgeInsets.all(0)), // 去除內邊距
                    backgroundColor: MaterialStateProperty.all(Colors.transparent), // 背景色透明
                    shadowColor: MaterialStateProperty.all(Colors.transparent), // 去除陰影
                  ),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => AccountSettings()),
                    );
                  },
                  child: CircleAvatar(
                    radius: 50, // 設定圓形大小
                    backgroundImage: AssetImage("assets/profile.jpg"), // 替換為你的圖片路徑
                    backgroundColor: Colors.grey[300], // 沒有圖片時的背景顏色
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
              border: TableBorder.all(color: Color(0xFFFF914D), width: 2), // 設定邊框顏色 & 粗細
              children: [
                TableRow(
                  decoration: BoxDecoration(color: Color(0xFFFF914D)), // 第一行背景
                  children: [
                    tableCell("即期食品"),
                    tableCell(""), // 空白格子
                  ],
                ),
                TableRow(children: [
                  tableCell("鮮乳優格(450g)"),
                  tableCell("23小時"),
                ]),
                TableRow(children: [
                  tableCell("提拉米蘇"),
                  tableCell("3天"),
                ]),
                TableRow(children: [
                  tableCell("統一布丁"),
                  tableCell("17天"),
                ]),
              ],
            ),
            const SizedBox(height: 20), // 隔間

            // ✅ 第二個表格 - 3x5 表格
            Table(
              border: TableBorder.all(color: Color(0xFFFF914D), width: 2), // 設定邊框顏色 & 粗細
              children: [
                TableRow(
                  decoration: BoxDecoration(color: Color(0xFFFF914D)), // 第一行背景
                  children: [
                    tableCell(""),
                    tableCell("購物清單"),
                    tableCell(""),
                  ],
                ),
                TableRow(children: [
                  tableCellWithCheckbox(0), // 改成顯示核取方塊
                  tableCell("雞腿肉"),
                  tableCell("125g"),
                ]),
                TableRow(children: [
                  tableCellWithCheckbox(1),
                  tableCell("薑"),
                  tableCell("1.3片"),
                ]),
                TableRow(children: [
                  tableCellWithCheckbox(2),
                  tableCell("乾香菇"),
                  tableCell("31.3g"),
                ]),
                TableRow(children: [
                  tableCellWithCheckbox(3),
                  tableCell("米"),
                  tableCell("75g"),
                ]),
                TableRow(children: [
                  tableCellWithCheckbox(4),
                  tableCell("麻油"),
                  tableCell("0.5匙"),
                ]),
              ],
            ),
          ],
        ),
      ),

      //  使用 BottomNavigationBar 建置功能欄位
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed, // 保持所有按鈕可見
        selectedItemColor: Color(0xFFFF914D), // 選中時的顏色
        unselectedItemColor: Colors.grey, // 未選中時的顏色
        showUnselectedLabels: true,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home, size: 30),
            label: "首頁",
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.list, size: 30),
            label: "清單",
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.add_circle, size: 40, color: Color(0xFFFF914D)), // 中間按鈕
            label: "新增",
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.calendar_today, size: 30),
            label: "日曆",
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.shopping_cart, size: 30),
            label: "購物車",
          ),
        ],
        onTap: (index) {
          if (index == 0) {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => MyApp()),
            );
            // 這裡可以加入 "首頁" 的功能
          }
          else if (index == 1) {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => FoodMngmtPage()),
            );
            // 這裡可以加入 "清單" 的功能
          }
          else if (index == 2) {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => AccountSettings()),
            );
            // 這裡可以加入 "新增" 的功能
          }
          else if (index == 3) {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => AccountSettings()),
            );
            // 這裡可以加入 "日曆" 的功能
          }
          else if (index == 4) {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => AccountSettings()),
            );
            // 這裡可以加入 "購物車" 的功能
          }
        },
      ),
    );
  }


  // 即期食品
  Widget tableCell(String text) {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Center(
        child: Text(text, style: const TextStyle(fontSize: 16)),
      ),
    );
  }

  // 購物清單
  Widget tableCellWithCheckbox(int index) {
    List<bool> checkboxValues = [false, false, false, false, false];
    return Padding(
      padding: const EdgeInsets.all(1.0),
      child: Center(
        child: Checkbox(
          value: checkboxValues[index],
          onChanged: (bool? value) {
            setState(() {
              checkboxValues[index] = value ?? false;
            });
          },
        ),
      ),
    );
  }
}
