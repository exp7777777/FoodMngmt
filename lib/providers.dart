import 'package:flutter/foundation.dart';

import 'models.dart';
import 'repositories.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';

class FoodProvider extends ChangeNotifier {
  final FoodRepository _repo;
  FoodProvider(this._repo);

  List<FoodItem> _items = [];
  String _keyword = '';
  bool _onlyExpiring = false;

  List<FoodItem> get items => _items;
  String get keyword => _keyword;
  bool get onlyExpiring => _onlyExpiring;

  Future<void> refresh() async {
    final prefs = await SharedPreferences.getInstance();
    final account = prefs.getString('session_account');
    _items = await _repo.getAll(
      keyword: _keyword,
      onlyExpiring: _onlyExpiring,
      account: account,
    );
    notifyListeners();
  }

  void setFilter({String? keyword, bool? onlyExpiring}) {
    if (keyword != null) _keyword = keyword;
    if (onlyExpiring != null) _onlyExpiring = onlyExpiring;
    refresh();
  }

  Future<void> add(FoodItem item) async {
    // 確保寫入時帶入帳號
    final prefs = await SharedPreferences.getInstance();
    final account = prefs.getString('session_account');
    final withAccount =
        item.account == null ? item.copyWith(account: account) : item;
    await _repo.insert(withAccount);
    await refresh();
  }

  Future<void> update(FoodItem item) async {
    final prefs = await SharedPreferences.getInstance();
    final account = prefs.getString('session_account');
    final withAccount =
        item.account == null ? item.copyWith(account: account) : item;
    await _repo.update(withAccount);
    await refresh();
  }

  Future<void> remove(int id) async {
    await _repo.delete(id);
    await refresh();
  }
}

class ShoppingProvider extends ChangeNotifier {
  final ShoppingRepository _repo;
  ShoppingProvider(this._repo);

  List<ShoppingItem> _items = [];
  List<ShoppingItem> get items => _items;

  Future<void> refresh() async {
    final prefs = await SharedPreferences.getInstance();
    final account = prefs.getString('session_account');
    _items = await _repo.getAll(account: account);
    notifyListeners();
  }

  Future<void> add(String name, {String? amount}) async {
    final prefs = await SharedPreferences.getInstance();
    final account = prefs.getString('session_account');
    await _repo.insert(
      ShoppingItem(name: name, amount: amount, account: account),
    );
    await refresh();
  }

  Future<void> toggle(int id, bool checked) async {
    await _repo.toggleChecked(id, checked);
    await refresh();
  }

  Future<void> remove(int id) async {
    await _repo.delete(id);
    await refresh();
  }

  Future<void> clearChecked() async {
    await _repo.clearChecked();
    await refresh();
  }
}

class UserProfileProvider extends ChangeNotifier {
  final AuthRepository _authRepo = AuthRepository();
  UserProfileProvider();

  String? nickname;
  String? account;
  String? password;

  Future<void> load() async {
    // 以目前登入帳號為主，若 users 表有資料就優先顯示
    final prefs = await SharedPreferences.getInstance();
    final current = prefs.getString('session_account');
    if (current != null) {
      final usr = await _authRepo.findByAccount(current);
      if (usr != null) {
        account = usr['account'] as String?;
        nickname = usr['nickname'] as String?;
        password = null;
        notifyListeners();
        return;
      }
    }
    // 若無資料，清空顯示
    nickname = null;
    account = null;
    password = null;
    notifyListeners();
  }

  Future<void> save({
    String? nickname,
    String? account,
    String? password,
  }) async {
    if (nickname != null) this.nickname = nickname;
    if (account != null) this.account = account;
    if (password != null) this.password = password;
    // 同步到 users 表（以 session 帳號為 key）
    final prefs = await SharedPreferences.getInstance();
    final current = prefs.getString('session_account');
    if (current != null) {
      await _authRepo.updateProfile(
        account: current,
        newAccount: this.account,
        nickname: this.nickname,
      );
      if (this.account != null && this.account != current) {
        await prefs.setString('session_account', this.account!);
      }
    }
    notifyListeners();
  }
}

class AppSettingsProvider extends ChangeNotifier {
  ThemeMode _themeMode = ThemeMode.light;
  Locale _locale = const Locale('zh', 'TW');

  ThemeMode get themeMode => _themeMode;
  Locale get locale => _locale;

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final theme = prefs.getString('themeMode');
    final localeStr = prefs.getString('locale');
    if (theme == 'dark') _themeMode = ThemeMode.dark;
    if (theme == 'system') _themeMode = ThemeMode.system;
    if (localeStr == 'en') {
      _locale = const Locale('en');
      Intl.defaultLocale = 'en';
    } else {
      _locale = const Locale('zh', 'TW');
      Intl.defaultLocale = 'zh_TW';
    }
    notifyListeners();
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    _themeMode = mode;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      'themeMode',
      mode == ThemeMode.dark
          ? 'dark'
          : (mode == ThemeMode.system ? 'system' : 'light'),
    );
    notifyListeners();
  }

  Future<void> setLocale(Locale locale) async {
    _locale = locale;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('locale', locale.languageCode);

    // 更新 Intl 的預設語言並重新初始化日期格式
    if (locale.languageCode == 'en') {
      Intl.defaultLocale = 'en';
      await initializeDateFormatting('en');
    } else {
      Intl.defaultLocale = 'zh_TW';
      await initializeDateFormatting('zh_TW');
    }

    notifyListeners();
  }
}

class AuthProvider extends ChangeNotifier {
  final AuthRepository _repo;
  AuthProvider(this._repo);

  String? _currentAccount;
  String? get currentAccount => _currentAccount;
  bool get isLoggedIn => _currentAccount != null;

  Future<void> loadSession() async {
    final prefs = await SharedPreferences.getInstance();
    _currentAccount = prefs.getString('session_account');
    notifyListeners();
  }

  Future<String?> register({
    required String account,
    required String password,
    String? nickname,
  }) async {
    final exists = await _repo.findByAccount(account);
    if (exists != null) return '帳號已存在';
    await _repo.register(
      account: account,
      password: password,
      nickname: nickname,
    );
    // 僅註冊，不自動登入
    return null;
  }

  Future<String?> login({
    required String account,
    required String password,
  }) async {
    final ok = await _repo.verify(account: account, password: password);
    if (!ok) return '帳號或密碼錯誤';
    _currentAccount = account.trim();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('session_account', _currentAccount!);
    notifyListeners();
    return null;
  }

  Future<String?> changePassword({
    required String oldPassword,
    required String newPassword,
  }) async {
    if (_currentAccount == null) return '尚未登入';
    final n = await _repo.changePassword(
      account: _currentAccount!,
      oldPassword: oldPassword,
      newPassword: newPassword,
    );
    if (n <= 0) return '舊密碼不正確';
    return null;
  }

  Future<void> logout() async {
    _currentAccount = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('session_account');
    notifyListeners();
  }
}
