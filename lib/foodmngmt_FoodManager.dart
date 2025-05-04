import 'package:flutter/material.dart';
import 'package:foodmngmt/foodmngmt_AccountRegister.dart';
import 'package:foodmngmt/foodmngmt_AccountSettings.dart';
import 'package:foodmngmt/foodmngmt_FoodManager.dart';
import 'package:foodmngmt/foodmngmt_HomePage.dart';
import 'main.dart';



@override
Widget build(BuildContext context) {
  return MaterialApp(
    debugShowCheckedModeBanner: false,
    home: FoodMngmtPage(),
  );
}

class FoodMngmtPage extends StatelessWidget {
  final List<Map<String, String>> foodItems = [
    {'name': '鮮乳優格(450g)', 'expiry': '2025.01.16', 'remaining': '23小時', 'image': 'assets/yogurt.png', 'quantity': '1件'},
    {'name': '提拉米蘇', 'expiry': '2025.01.18', 'remaining': '3天', 'image': 'assets/tiramisu.png', 'quantity': '1件'},
    {'name': '統一布丁', 'expiry': '2025.01.31', 'remaining': '17天', 'image': 'assets/pudding.png', 'quantity': '2件'},
    {'name': '香蕉', 'expiry': '2025.02.03', 'remaining': '20天', 'image': 'assets/banana.png', 'quantity': '1件'},
    {'name': '咖啡豆', 'expiry': '2025.04.16', 'remaining': '3個月', 'image': 'assets/coffee.png', 'quantity': '1件'},
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('食物總覽', style: TextStyle(color: Colors.black)),
        backgroundColor: Colors.white,
        elevation: 0,
        leading: Icon(Icons.menu, color: Colors.orange),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextField(
              decoration: InputDecoration(
                hintText: '搜尋',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: foodItems.length,
              itemBuilder: (context, index) {
                var item = foodItems[index];
                return ListTile(
                  leading: Image.asset(item['image']!, width: 50, height: 50),
                  title: Text(item['name']!),
                  subtitle: Text('${item['expiry']} 過期 (${item['remaining']})', style: TextStyle(color: Colors.red)),
                  trailing: Text(item['quantity']!),
                );
              },
            ),
          ),
        ],
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
              MaterialPageRoute(builder: (context) => HomePage()),
            );
            // 這裡可以加入 "首頁" 的功能
          }
          else if (index == 1) {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => FoodMngmtPage()),
            );
            // 這裡可以加入 "食物管理" 的功能
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
}

