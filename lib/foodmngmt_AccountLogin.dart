import 'package:flutter/material.dart';
import 'package:foodmngmt/foodmngmt_AccountRegister.dart';
import 'package:foodmngmt/foodmngmt_AccountSettings.dart';



class AccoutLogin extends StatelessWidget {
  const AccoutLogin({super.key});

  Widget _buildTextField(TextEditingController controller, String label, String note, {bool obscureText = false, String? hintText}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (label.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 5), // 避免上框線被遮擋
            child: Text(label, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ),
        Container(
          decoration: BoxDecoration(
            color: Color(0xFFE0E0E0), // ProfileAccountPage 的灰色無框樣式
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

  @override
  Widget build(BuildContext context) {
    TextEditingController emailController = TextEditingController();
    TextEditingController passwordController = TextEditingController();

    return Scaffold(
      backgroundColor: const Color(0xFFFCF7EF), // 設定背景顏色
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min, // 讓內容靠近中心
          children: [
            Text(
              "EXP食材管理",
              style: TextStyle(
                fontSize: 40, // 文字大小
                fontWeight: FontWeight.bold, // 粗體
                color: Colors.black, // 文字顏色
                letterSpacing: 12.0, // 調整字母之間的間距
              ),
            ),
            const SizedBox(height: 10), // 增加與框的間距
            Container(
              width: 300, // 調整寬度
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white, // 白色背景
                borderRadius: BorderRadius.circular(20), // 圓角
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Align(
                    alignment: Alignment.centerLeft,
                    child: GestureDetector(
                      onTap: () {
                        // 點擊後跳轉到 ProfileSetupPage
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => AccountRegister()),
                        );
                      },
                      child: Text(
                        "註冊新帳號",
                        style: TextStyle(
                          color: Colors.blue, // 設定顏色為藍色
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),
                  _buildTextField(emailController, "", "",hintText: "帳號/手機號碼"),
                  const SizedBox(height: 10),
                  _buildTextField(passwordController, "", "", hintText: "密碼",obscureText: true),
                  const SizedBox(height: 5),
                  Align(
                    alignment: Alignment.centerRight,
                    child: GestureDetector(
                      onTap: () {
                        // 忘記密碼點擊事件
                      },
                      child: Text(
                        "如忘記密碼可重新建立",
                        style: TextStyle(
                          color: Colors.red, // 設定顏色為紅色
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Center(
                    child: ElevatedButton(
                      onPressed: () {
                        // 登入按鈕點擊事件
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Color(0xFFFF914D), // 設定按鈕顏色
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30), // 橢圓形按鈕
                        ),
                        padding: EdgeInsets.symmetric(vertical: 10, horizontal: 30), // 調整大小
                      ),
                      child: Text(
                        "登入",
                        style: TextStyle(
                          color: Colors.white, // 設定文字顏色
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
