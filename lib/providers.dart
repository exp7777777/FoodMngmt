import 'models.dart';
import 'repositories.dart';
import 'firebase_service.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:firebase_auth/firebase_auth.dart';

class FoodProvider extends ChangeNotifier {
  final FoodRepository _repo;
  final FirebaseService _firebaseService = FirebaseService.instance;

  FoodProvider(this._repo) {
    // 延遲監聽身份驗證狀態變化，確保Firebase已初始化
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _listenToAuthChanges();
    });
  }

  List<FoodItem> _allItems = []; // 儲存所有資料
  List<FoodItem> _items = []; // 儲存篩選後的資料
  String _keyword = '';
  bool _onlyExpiring = false;
  String? _lastUserId; // 追蹤上次載入資料的用戶 ID
  bool _isLoading = false;
  String? _errorMessage;

  List<FoodItem> get items => _items;
  String get keyword => _keyword;
  bool get onlyExpiring => _onlyExpiring;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  void _listenToAuthChanges() {
    // 延遲監聽Firebase Auth狀態變化，避免初始化時機問題
    Future.delayed(const Duration(milliseconds: 200), () {
      try {
        FirebaseAuth.instance.authStateChanges().listen((User? user) {
          final currentUserId = user?.uid;
          if (currentUserId != _lastUserId) {
            _lastUserId = currentUserId;
            if (currentUserId != null) {
              debugPrint('用戶已登入，載入食材資料: $currentUserId');
              _loadData();
            } else {
              debugPrint('用戶已登出，清空食材資料');
              _allItems = [];
              _items = [];
              _errorMessage = null;
              notifyListeners();
            }
          }
        });
      } catch (e) {
        debugPrint('FoodProvider Auth 監聽設定失敗: $e');
      }
    });
  }

  Future<void> _loadData() async {
    // 防止重複載入
    if (_isLoading) {
      debugPrint('FoodProvider 正在載入中，忽略重複請求');
      return;
    }

    try {
      _isLoading = true;
      _errorMessage = null;
      notifyListeners();

      // 確保用戶已登入
      if (_firebaseService.currentUserId == null) {
        debugPrint('用戶未登入，無法載入食材資料');
        _items = [];
        _isLoading = false;
        notifyListeners();
        return;
      }

      final items = await _firebaseService.getFoodItems(
        keyword: null, // 載入時不篩選，在本地篩選
        onlyExpiring: false,
        userId: _firebaseService.currentUserId,
      );
      _allItems = items;
      _lastUserId = _firebaseService.currentUserId; // 更新上次載入的用戶 ID
      _applyFilters(); // 應用篩選條件
      debugPrint('成功載入 ${items.length} 個食材項目');
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      debugPrint('FoodProvider 載入資料錯誤: $e');
      _allItems = [];
      _items = [];
      _errorMessage = '載入資料失敗: $e';
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> refresh() async {
    _lastUserId = null; // 重置用戶 ID 以強制重新載入
    await _loadData(); // 直接載入資料，避免重複註冊監聽器
  }

  void setFilter({String? keyword, bool? onlyExpiring}) {
    if (keyword != null) _keyword = keyword;
    if (onlyExpiring != null) _onlyExpiring = onlyExpiring;

    // 直接應用篩選條件，不需要重新載入
    _applyFilters();
    notifyListeners();
  }

  void _applyFilters() {
    List<FoodItem> filteredItems = List.from(_allItems);

    // 應用關鍵字篩選
    if (_keyword.isNotEmpty) {
      filteredItems =
          filteredItems
              .where(
                (item) =>
                    item.name.toLowerCase().contains(_keyword.toLowerCase()),
              )
              .toList();
    }

    // 應用到期日篩選
    if (_onlyExpiring) {
      final threeDaysFromNow = DateTime.now().add(const Duration(days: 3));
      filteredItems =
          filteredItems
              .where((item) => item.expiryDate.isBefore(threeDaysFromNow))
              .toList();
    }

    // 按到期日期排序
    filteredItems.sort((a, b) => a.expiryDate.compareTo(b.expiryDate));

    _items = filteredItems;
  }

  Future<void> add(FoodItem item) async {
    try {
      final itemId = await _repo.insert(item);
      debugPrint('新增食材成功，ID: $itemId');

      // 直接更新本地狀態，避免重新載入
      final newItem = item.copyWith(id: itemId);
      _allItems.add(newItem);
      _applyFilters();
      notifyListeners();
    } catch (e) {
      debugPrint('Error adding food item: $e');
      rethrow;
    }
  }

  Future<void> update(FoodItem item) async {
    try {
      await _repo.update(item);
      debugPrint('更新食材成功，ID: ${item.id}');

      // 直接更新本地狀態，避免重新載入
      final index = _allItems.indexWhere((i) => i.id == item.id);
      if (index != -1) {
        _allItems[index] = item;
        _applyFilters();
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Error updating food item: $e');
      rethrow;
    }
  }

  Future<void> remove(String id) async {
    try {
      await _repo.delete(id);
      debugPrint('刪除食材成功，ID: $id');

      // 直接從本地狀態移除，避免重新載入
      _allItems.removeWhere((item) => item.id == id);
      _applyFilters();
      notifyListeners();
    } catch (e) {
      debugPrint('Error removing food item: $e');
      rethrow;
    }
  }
}

class ShoppingProvider extends ChangeNotifier {
  final ShoppingRepository _repo;
  final FirebaseService _firebaseService = FirebaseService.instance;

  ShoppingProvider(this._repo) {
    // 延遲初始化資料，確保Firebase已完全初始化
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeData();
    });
  }

  List<ShoppingItem> _allItems = []; // 儲存所有資料
  List<ShoppingItem> _items = []; // 儲存篩選後的資料
  bool _isLoading = false;
  String? _errorMessage;
  bool _isAdding = false; // 防止重複新增

  List<ShoppingItem> get items {
    return _items;
  }

  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  void _initializeData() async {
    // 等待 Firebase 完全初始化
    await Future.delayed(const Duration(milliseconds: 500));

    // 檢查當前用戶狀態
    final currentUserId = _firebaseService.currentUserId;

    if (currentUserId != null) {
      await _loadData();
    }

    // 開始監聽 Auth 狀態變化
    _listenToAuthChanges();
  }

  void _listenToAuthChanges() {
    // 不再直接監聽 Firebase Auth，而是通過 FirebaseService 的狀態變化
    // 避免與 FirebaseService 的監聽器衝突
  }

  Future<void> _loadData() async {
    // 防止重複載入
    if (_isLoading) {
      return;
    }

    try {
      _isLoading = true;
      _errorMessage = null;
      notifyListeners();

      // 確保用戶已登入
      if (_firebaseService.currentUserId == null) {
        _allItems = [];
        _items = List.from(_allItems);
        _isLoading = false;
        notifyListeners();
        return;
      }

      final items = await _firebaseService.getShoppingItems(
        userId: _firebaseService.currentUserId,
      );

      // 去重：根據 ID 移除重複項目
      final uniqueItems = <String, ShoppingItem>{};
      for (final item in items) {
        if (item.id != null) {
          uniqueItems[item.id!] = item;
        }
      }
      final deduplicatedItems = uniqueItems.values.toList();

      _allItems = deduplicatedItems;
      _items = List.from(_allItems);
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _allItems = [];
      _items = List.from(_allItems);
      _errorMessage = '載入資料失敗: $e';
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> refresh() async {
    await _loadData(); // 直接載入資料，避免重複註冊監聽器
  }

  Future<void> add(String name, {String? amount}) async {
    // 防止重複新增
    if (_isAdding) {
      return;
    }

    // 檢查是否已存在相同名稱的項目（未完成狀態）
    final existingItem = _allItems.firstWhere(
      (item) => item.name == name && !item.checked,
      orElse: () => ShoppingItem(name: '', amount: ''),
    );

    if (existingItem.name.isNotEmpty) {
      return;
    }

    try {
      _isAdding = true;

      final itemId = await _repo.insert(
        ShoppingItem(name: name, amount: amount),
      );

      // 直接更新本地狀態，避免重新載入
      final newItem = ShoppingItem(id: itemId, name: name, amount: amount);

      // 檢查是否已存在相同 ID 的項目（防止重複）
      final existingIndex = _allItems.indexWhere((item) => item.id == itemId);

      if (existingIndex == -1) {
        _allItems.add(newItem);
        // 同步更新 _items（購物清單不需要篩選）
        _items = List.from(_allItems);
        notifyListeners();
      }
    } catch (e) {
      rethrow;
    } finally {
      _isAdding = false;
    }
  }

  Future<void> toggle(String id, bool checked) async {
    // 樂觀更新：先更新 UI，再同步到後端
    final index = _allItems.indexWhere((item) => item.id == id);
    if (index == -1) return;

    // 保存原始狀態以便回滾
    final originalItem = _allItems[index];

    try {
      // 立即更新 UI
      _allItems[index] = _allItems[index].copyWith(checked: checked);
      // 同步更新 _items
      _items = List.from(_allItems);
      notifyListeners();

      // 異步同步到後端
      await _repo.toggleChecked(id, checked);
    } catch (e) {
      // 回滾到原始狀態
      _allItems[index] = originalItem;
      // 同步更新 _items
      _items = List.from(_allItems);
      notifyListeners();

      rethrow;
    }
  }

  Future<void> remove(String id) async {
    // 樂觀更新：先移除 UI，再同步到後端
    final originalItems = List<ShoppingItem>.from(_allItems);

    try {
      // 立即從 UI 移除
      _allItems.removeWhere((item) => item.id == id);
      // 同步更新 _items
      _items = List.from(_allItems);
      notifyListeners();

      // 異步同步到後端
      await _repo.delete(id);
    } catch (e) {
      // 回滾到原始狀態
      _allItems = originalItems;
      _items = List.from(_allItems);
      notifyListeners();

      rethrow;
    }
  }
}

class UserProfileProvider extends ChangeNotifier {
  final AuthRepository _authRepo = AuthRepository();
  final FirebaseService _firebaseService = FirebaseService.instance;

  UserProfileProvider() {
    // 監聽用戶資料變化
    _loadUserData();
  }

  String? _nickname;
  String? _email;

  String? get nickname => _nickname;
  String? get email => _email;

  Future<void> _loadUserData() async {
    if (_firebaseService.currentUser != null) {
      _email = _firebaseService.currentUserEmail;
      _nickname = _firebaseService.currentUser?.displayName;
      notifyListeners();
    }
  }

  Future<void> load() async {
    await _loadUserData();
  }

  Future<void> save({String? nickname, String? email}) async {
    if (nickname != null) _nickname = nickname;
    if (email != null) _email = email;

    // 更新 Firebase 中的用戶資料
    await _authRepo.updateProfile(displayName: nickname, email: email);

    notifyListeners();
  }

  Future<String?> changePassword(String newPassword) async {
    return _authRepo.changePassword(newPassword);
  }

  Future<String?> resetPassword(String email) async {
    return _authRepo.resetPassword(email);
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
  final FirebaseService _firebaseService = FirebaseService.instance;

  AuthProvider(this._repo) {
    // 監聽身份驗證狀態變化
    _firebaseService.currentUser; // 觸發初始化
  }

  String? _currentEmail;
  String? get currentEmail => _currentEmail;
  String? get currentUserId => _firebaseService.currentUserId;
  bool get isLoggedIn => _firebaseService.currentUser != null;

  Future<void> loadSession() async {
    // Firebase Auth 會自動處理會話狀態
    _currentEmail = _firebaseService.currentUserEmail;
    notifyListeners();
  }

  Future<String?> register({
    required String email,
    required String password,
    String? nickname,
  }) async {
    return _repo.register(email: email, password: password, nickname: nickname);
  }

  Future<String?> login({
    required String email,
    required String password,
  }) async {
    final result = await _repo.signIn(email: email, password: password);
    if (result == null) {
      // 登入成功，更新本地狀態
      _currentEmail = email;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('session_email', email);

      // 觸發其他 Provider 的資料載入（通過延遲確保狀態正確設定）
      Future.delayed(const Duration(milliseconds: 100), () {
        // 這裡無法直接訪問其他 Provider，因為這是 AuthProvider
        // 資料載入會在頁面重新渲染時自動觸發
        notifyListeners();
      });
    }
    return result;
  }

  Future<String?> changePassword(String newPassword) async {
    return _repo.changePassword(newPassword);
  }

  Future<String?> resetPassword(String email) async {
    return _repo.resetPassword(email);
  }

  Future<String?> updateProfile({String? displayName, String? email}) async {
    return _repo.updateProfile(displayName: displayName, email: email);
  }

  Future<String?> signInWithGoogle() async {
    final result = await _repo.signInWithGoogle();
    if (result == null) {
      // 登入成功，更新本地狀態
      _currentEmail = _firebaseService.currentUserEmail;
      notifyListeners();
    }
    return result;
  }

  Future<String?> signInAnonymously() async {
    final result = await _repo.signInAnonymously();
    if (result == null) {
      // 登入成功，更新本地狀態
      _currentEmail = _firebaseService.currentUserEmail;
      notifyListeners();
    }
    return result;
  }

  Future<void> logout() async {
    await _repo.signOut();
    _currentEmail = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('session_email');
    notifyListeners();
  }

  // 為了向下相容，提供舊的方法名稱
  Future<String?> verify({
    required String account,
    required String password,
  }) async {
    return login(email: account, password: password);
  }
}
