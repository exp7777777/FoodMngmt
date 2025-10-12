import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'providers.dart';

class AccountSettings extends StatefulWidget {
  @override
  State<AccountSettings> createState() => _AccountSettingsState();
}

class _AccountSettingsState extends State<AccountSettings> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _nickname = TextEditingController();
  final TextEditingController _email = TextEditingController();
  final TextEditingController _password = TextEditingController();
  final TextEditingController _confirm = TextEditingController();
  // 移除未使用的欄位
  final _oldPwd = TextEditingController();
  final _newPwd = TextEditingController();
  bool _listening = false;

  void _syncFromProvider(UserProfileProvider p) {
    final nick = p.nickname ?? '';
    final email = p.email ?? '';
    if (_nickname.text != nick) _nickname.text = nick;
    if (_email.text != email) _email.text = email;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final p = context.read<UserProfileProvider>();
    if (!_listening) {
      _listening = true;
      p.addListener(_onProfileChanged);
      // 確保頁面開啟時就同步一次最新資料
      p.load();
      _syncFromProvider(p);
    } else {
      _syncFromProvider(p);
    }
  }

  void _onProfileChanged() {
    if (!mounted) return;
    final p = context.read<UserProfileProvider>();
    _syncFromProvider(p);
  }

  @override
  void dispose() {
    _nickname.dispose();
    _email.dispose();
    _password.dispose();
    _confirm.dispose();
    super.dispose();
    _oldPwd.dispose();
    _newPwd.dispose();
    try {
      context.read<UserProfileProvider>().removeListener(_onProfileChanged);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('帳號設定'),
        backgroundColor:
            Theme.of(context).brightness == Brightness.dark
                ? const Color.fromARGB(5, 219, 84, 0) // 深色主題使用深橘色
                : const Color(0xFFFFB366), // 淺色主題使用淺橘色
        foregroundColor: Colors.white,
      ),
      body: Center(
        child: Container(
          width: MediaQuery.of(context).size.width * 0.9,
          padding: EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircleAvatar(
                  radius: 40,
                  backgroundColor: Colors.grey[300],
                  child: Icon(Icons.person, size: 40, color: Colors.white),
                ),
                SizedBox(height: 20),
                _label('暱稱'),
                TextFormField(
                  controller: _nickname,
                  decoration: _inputDecoration(hint: '輸入暱稱'),
                  validator:
                      (v) => (v == null || v.trim().isEmpty) ? '請輸入暱稱' : null,
                ),
                SizedBox(height: 12),
                _label('電子郵件'),
                TextFormField(
                  controller: _email,
                  decoration: _inputDecoration(hint: 'example@email.com'),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return '請輸入電子郵件';
                    final emailRegex = RegExp(
                      r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$',
                    );
                    if (!emailRegex.hasMatch(v.trim())) return '請輸入有效的電子郵件地址';
                    return null;
                  },
                ),
                SizedBox(height: 12),
                _label('修改密碼'),
                TextFormField(
                  controller: _oldPwd,
                  obscureText: true,
                  decoration: _inputDecoration(hint: '舊密碼'),
                ),
                SizedBox(height: 12),
                TextFormField(
                  controller: _newPwd,
                  obscureText: true,
                  decoration: _inputDecoration(hint: '新密碼'),
                ),
                SizedBox(height: 20),
                Align(
                  alignment: Alignment.centerRight,
                  child: ElevatedButton(
                    onPressed: () async {
                      if (!_formKey.currentState!.validate()) return;
                      await context.read<UserProfileProvider>().save(
                        nickname: _nickname.text.trim(),
                        email: _email.text.trim(),
                      );
                      if (_newPwd.text.isNotEmpty) {
                        final msg = await context
                            .read<AuthProvider>()
                            .changePassword(_newPwd.text);
                        if (msg != null) {
                          ScaffoldMessenger.of(
                            context,
                          ).showSnackBar(SnackBar(content: Text(msg)));
                          return;
                        }
                      }
                      if (!mounted) return;
                      ScaffoldMessenger.of(
                        context,
                      ).showSnackBar(SnackBar(content: Text('已更新帳號資料')));
                      _oldPwd.clear();
                      _newPwd.clear();
                    },
                    child: Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: 30,
                        vertical: 10,
                      ),
                      child: Text('更新', style: TextStyle(fontSize: 18)),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _label(String text) => Padding(
    padding: EdgeInsets.only(bottom: 5),
    child: Align(
      alignment: Alignment.centerLeft,
      child: Text(
        text,
        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
      ),
    ),
  );

  InputDecoration _inputDecoration({String? hint}) => InputDecoration(
    hintText: hint,
    filled: true,
    fillColor:
        Theme.of(context).brightness == Brightness.dark
            ? Colors.grey[800]
            : Colors.grey[200],
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: BorderSide.none,
    ),
  );
}
