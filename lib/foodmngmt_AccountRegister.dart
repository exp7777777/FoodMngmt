import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'providers.dart';
import 'foodmngmt_AccountLogin.dart';

class AccountRegister extends StatefulWidget {
  @override
  _AccountRegisterState createState() => _AccountRegisterState();
}

class _AccountRegisterState extends State<AccountRegister> {
  final TextEditingController _nicknameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
      TextEditingController();
  final TextEditingController _accountController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  String? _validateNickname(String? value) {
    final v = (value ?? '').trim();
    if (v.isEmpty) return '請輸入暱稱';
    if (v.length < 2 || v.length > 16) return '暱稱需為 2-16 字元';
    if (!RegExp(r'^\S+$').hasMatch(v)) return '暱稱不能包含空白';
    return null;
  }

  String? _validateAccount(String? value) {
    final v = (value ?? '').trim();
    if (v.isEmpty) return '請輸入帳號/手機號碼';
    final isPhone = RegExp(r'^\d{8,15}$').hasMatch(v);
    final isId = RegExp(r'^[A-Za-z0-9_.-]{4,30}$').hasMatch(v);
    if (!(isPhone || isId)) return '帳號需為 8-15 位數字或 4-30 位英數字';
    return null;
  }

  String? _validatePassword(String? value) {
    final v = (value ?? '').trim();
    if (v.isEmpty) return '請輸入密碼';
    if (v.length < 6 || v.length > 12) return '密碼需為 6-12 字元';
    final hasLetter = RegExp(r'[A-Za-z]').hasMatch(v);
    final hasDigit = RegExp(r'\d').hasMatch(v);
    if (!(hasLetter && hasDigit)) return '密碼需同時包含英文字母與數字';
    return null;
  }

  String? _validateConfirmPassword(String? value) {
    final v = (value ?? '').trim();
    if (v.isEmpty) return '請再次輸入密碼';
    if (v != _passwordController.text.trim()) return '兩次輸入的密碼不一致';
    return null;
  }

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
                  child: Form(
                    key: _formKey,
                    autovalidateMode: AutovalidateMode.onUserInteraction,
                    child: Column(
                      children: [
                        CircleAvatar(
                          radius: 40,
                          backgroundColor: Colors.grey[300],
                          child: Icon(
                            Icons.person,
                            size: 40,
                            color: Colors.white,
                          ),
                        ),
                        SizedBox(height: 20),
                        _buildTextField(
                          _nicknameController,
                          "暱稱",
                          "※不須特殊符號",
                          hintText: "六字元",
                          validator: _validateNickname,
                        ),
                        SizedBox(height: 10),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            "帳號",
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        SizedBox(height: 5),
                        _buildTextField(
                          _accountController,
                          "",
                          "",
                          hintText: "帳號/手機號碼",
                          obscureText: false,
                          validator: _validateAccount,
                        ),
                        SizedBox(height: 10),
                        _buildTextField(
                          _passwordController,
                          "密碼",
                          "※需6~12含英、數",
                          obscureText: true,
                          validator: _validatePassword,
                        ),
                        SizedBox(height: 10),
                        _buildTextField(
                          _confirmPasswordController,
                          "",
                          "",
                          obscureText: true,
                          hintText: "確認密碼",
                          validator: _validateConfirmPassword,
                        ),
                        SizedBox(height: 20),
                        Row(
                          children: [
                            OutlinedButton.icon(
                              onPressed: () async {
                                // 返回登入頁，並確保清空舊的列表快取
                                await context
                                    .read<UserProfileProvider>()
                                    .load();
                                await context.read<FoodProvider>().refresh();
                                await context
                                    .read<ShoppingProvider>()
                                    .refresh();
                                if (!mounted) return;
                                Navigator.pushAndRemoveUntil(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => const AccountLogin(),
                                  ),
                                  (route) => false,
                                );
                              },
                              icon: Icon(Icons.arrow_back),
                              label: Text('返回'),
                            ),
                            Spacer(),
                            ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(30),
                                ),
                                padding: EdgeInsets.symmetric(
                                  horizontal: 30,
                                  vertical: 10,
                                ),
                              ),
                              onPressed: () async {
                                if (!(_formKey.currentState?.validate() ??
                                    false)) {
                                  return;
                                }
                                final err = await context
                                    .read<AuthProvider>()
                                    .register(
                                      account: _accountController.text,
                                      password: _passwordController.text,
                                      nickname: _nicknameController.text,
                                    );
                                if (err != null) {
                                  ScaffoldMessenger.of(
                                    context,
                                  ).showSnackBar(SnackBar(content: Text(err)));
                                  return;
                                }
                                if (!mounted) return;
                                await showDialog<void>(
                                  context: context,
                                  builder:
                                      (_) => AlertDialog(
                                        title: Text('註冊成功'),
                                        content: Text('請使用您的帳號與密碼登入。'),
                                        actions: [
                                          TextButton(
                                            onPressed:
                                                () => Navigator.pop(context),
                                            child: Text('確定'),
                                          ),
                                        ],
                                      ),
                                );
                                if (!mounted) return;
                                Navigator.pushAndRemoveUntil(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => const AccountLogin(),
                                  ),
                                  (route) => false,
                                );
                              },
                              child: Text(
                                "確認",
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      // 底部導覽移至 RootScaffold
    );
  }

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
}
