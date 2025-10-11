import 'package:flutter/material.dart';
import 'package:foodmngmt/foodmngmt_AccountRegister.dart';
import 'package:provider/provider.dart';
import 'providers.dart';
import 'root_scaffold.dart';

class AccountLogin extends StatelessWidget {
  const AccountLogin({super.key});

  Widget _buildTextField(
    TextEditingController controller,
    String label,
    String note, {
    bool obscureText = false,
    String? hintText,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (label.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 5),
            child: Text(
              label,
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),
        TextFormField(
          controller: controller,
          obscureText: obscureText,
          decoration: InputDecoration(
            hintText: hintText,
            hintStyle: TextStyle(color: Colors.grey),
          ),
          validator: validator,
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
    final formKey = GlobalKey<FormState>();

    String? validateAccount(String? value) {
      final v = (value ?? '').trim();
      if (v.isEmpty) return '請輸入帳號/手機號碼';
      final isPhone = RegExp(r'^\d{8,15}$').hasMatch(v);
      final isId = RegExp(r'^[A-Za-z0-9_.-]{4,30}$').hasMatch(v);
      if (!(isPhone || isId)) return '帳號需為 8-15 位數字或 4-30 位英數字';
      return null;
    }

    String? validatePassword(String? value) {
      final v = (value ?? '').trim();
      if (v.isEmpty) return '請輸入密碼';
      if (v.length < 6 || v.length > 12) return '密碼需為 6-12 字元';
      final hasLetter = RegExp(r'[A-Za-z]').hasMatch(v);
      final hasDigit = RegExp(r'\d').hasMatch(v);
      if (!(hasLetter && hasDigit)) return '密碼需同時包含英文字母與數字';
      return null;
    }

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
              child: Form(
                key: formKey,
                autovalidateMode: AutovalidateMode.onUserInteraction,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 20),
                    _buildTextField(
                      emailController,
                      "",
                      "",
                      hintText: "帳號/手機號碼",
                      validator: validateAccount,
                    ),
                    const SizedBox(height: 10),
                    _buildTextField(
                      passwordController,
                      "",
                      "",
                      hintText: "密碼",
                      obscureText: true,
                      validator: validatePassword,
                    ),
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
                        onPressed: () async {
                          if (!(formKey.currentState?.validate() ?? false)) {
                            return;
                          }
                          final err = await context.read<AuthProvider>().login(
                            account: emailController.text,
                            password: passwordController.text,
                          );
                          if (err != null) {
                            ScaffoldMessenger.of(
                              context,
                            ).showSnackBar(SnackBar(content: Text(err)));
                            return;
                          }
                          if (!context.mounted) return;
                          // 重新載入與帳號關聯的資料
                          await context.read<UserProfileProvider>().load();
                          await context.read<FoodProvider>().refresh();
                          await context.read<ShoppingProvider>().refresh();
                          Navigator.pushReplacement(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const RootScaffold(),
                            ),
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(30), // 橢圓形按鈕
                          ),
                          padding: EdgeInsets.symmetric(
                            vertical: 10,
                            horizontal: 30,
                          ), // 調整大小
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
                    const SizedBox(height: 10),
                    Center(
                      child: OutlinedButton(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => AccountRegister(),
                            ),
                          );
                        },
                        child: Text("註冊", style: TextStyle(fontSize: 16)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
