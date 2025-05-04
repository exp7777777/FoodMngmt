import 'package:flutter/material.dart';
import 'package:foodmngmt/foodmngmt_AccountSettings.dart';
import 'package:foodmngmt/foodmngmt_FoodManager.dart';
import 'package:foodmngmt/foodmngmt_HomePage.dart';

class AccountRegister extends StatefulWidget {
  @override
  _AccountRegisterState createState() => _AccountRegisterState();
}

class _AccountRegisterState extends State<AccountRegister> {
  final TextEditingController _nicknameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController = TextEditingController();
  final TextEditingController _accountController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: false,
      backgroundColor: Color(0xFFFFF5E1),
      body: Center(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Column(
                    children: [
                      CircleAvatar(
                        radius: 40,
                        backgroundImage: AssetImage("assets/profile_placeholder.png"),
                        backgroundColor: Colors.grey[300],
                      ),
                      SizedBox(height: 20),
                      _buildTextField(_nicknameController, "暱稱", "※不須特殊符號", hintText: "六字元"),
                      SizedBox(height: 10),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text("帳號", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      ),
                      SizedBox(height: 5),
                      _buildTextField(_accountController, "", "", hintText: "帳號/手機號碼", obscureText: false),
                      SizedBox(height: 10),
                      _buildTextField(_passwordController, "密碼", "※需6~12含英、數", obscureText: true),
                      SizedBox(height: 10),
                      _buildTextField(_confirmPasswordController, "", "", obscureText: true, hintText: "確認密碼"),
                      SizedBox(height: 20),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(30),
                          ),
                          backgroundColor: Color(0xFFFF914D),
                          padding: EdgeInsets.symmetric(horizontal: 30, vertical: 10),
                        ),
                        onPressed: () {},
                        child: Text(
                          "確認",
                          style: TextStyle(color: Colors.white, fontSize: 18),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        selectedItemColor: Color(0xFFFF914D),
        unselectedItemColor: Colors.grey,
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
            icon: Icon(Icons.add_circle, size: 40), // 中間按鈕
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
          } else if (index == 1) {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => FoodMngmtPage()),
            );
          } else if (index == 2) {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => AccountSettings()),
            );
          } else if (index == 3) {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => AccountSettings()),
            );
          } else if (index == 4) {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => AccountSettings()),
            );
          }
        },
      ),
    );
  }

  Widget _buildTextField(TextEditingController controller, String label, String note, {bool obscureText = false, String? hintText}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (label.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 5),
            child: Text(label, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ),
        Container(
          decoration: BoxDecoration(
            color: Color(0xFFE0E0E0),
            borderRadius: BorderRadius.circular(10),
          ),
          padding: EdgeInsets.symmetric(horizontal: 12),
          child: TextField(
            controller: controller,
            obscureText: obscureText,
            decoration: InputDecoration(
              hintText: hintText,
              hintStyle: TextStyle(color: Colors.grey),
              border: InputBorder.none,
            ),
          ),
        ),
        if (note.isNotEmpty)
          Align(
            alignment: Alignment.bottomRight,
            child: Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                note,
                style: TextStyle(fontSize: 12, color: Colors.black),
              ),
            ),
          ),
      ],
    );
  }
}