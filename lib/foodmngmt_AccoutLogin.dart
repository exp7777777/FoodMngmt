import 'package:flutter/material.dart';
import 'package:foodmngmt/foodmngmt_AccountSettings.dart';
import 'package:foodmngmt/foodmngmt_AccoutLogin.dart';
import 'package:foodmngmt/foodmngmt_FoodManager.dart';
import 'package:foodmngmt/foodmngmt_HomePage.dart';
import 'main.dart';

import 'package:lucide_icons/lucide_icons.dart';


class AccoutLogin extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFFFFF5E1), // 奶油色背景
      body: Center(
        child: Container(
          width: MediaQuery.of(context).size.width * 0.9,
          padding: EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white, // 白色背景
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Align(
                alignment: Alignment.topLeft,
                child: Icon(LucideIcons.home, size: 30), // 左上角房子 icon
              ),
              SizedBox(height: 10),
              Stack(
                clipBehavior: Clip.none,
                children: [
                  CircleAvatar(
                    radius: 40,
                    backgroundColor: Colors.grey[300],
                    backgroundImage: AssetImage('assets/profile_pic.png'), // 頭像
                  ),
                  Positioned(
                    right: -10,
                    bottom: -10,
                    child: Icon(LucideIcons.edit, size: 24, color: Colors.black), // 右下角 edit icon
                  ),
                ],
              ),
              SizedBox(height: 20),
              _buildTextField('暱稱', '卯咪愛喝茶', false, showEditIcon: true),
              _buildTextField('帳號', 'I5like2co0k', false, showEditIcon: true),
              Stack(
                clipBehavior: Clip.none,
                children: [
                  _buildTextField('修改密碼', '******', true),
                  Positioned(
                    right: 10,
                    bottom: -18, // ✅ **調整與 ProfileSetupPage 保持一致**
                    child: Padding(
                      padding: const EdgeInsets.only(top: 4), // ✅ **讓間隔與 ProfileSetupPage 一致**
                      child: Text(
                        '※需6~12含英、數',
                        style: TextStyle(fontSize: 12, color: Colors.black),
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 30), // ✅ 增加間距，防止確認密碼框與修改密碼框過於接近
              _buildTextField('', '確認密碼', true, isHint: true, showEditIcon: true),
              SizedBox(height: 20),
              Align(
                alignment: Alignment.centerRight,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                  ),
                  onPressed: () {},
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 30, vertical: 10),
                    child: Text('更新', style: TextStyle(color: Colors.white,fontSize: 18)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
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
              MaterialPageRoute(builder: (context) => FoodMngmtPage()),
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

  Widget _buildTextField(String label, String hint, bool obscureText,
      {bool isHint = false, bool showEditIcon = false}) {
    return Padding(
      padding: EdgeInsets.only(bottom: 15),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (label.isNotEmpty)
            Padding(
              padding: EdgeInsets.only(bottom: 5),
              child: Text(label, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ),
          TextField(
            obscureText: obscureText,
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: TextStyle(color: isHint ? Colors.grey : Colors.black),
              filled: true,
              fillColor: Colors.grey[200],
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
              suffixIcon: showEditIcon ? Icon(LucideIcons.edit, color: Colors.grey) : null,
            ),
          ),
        ],
      ),
    );
  }
}
