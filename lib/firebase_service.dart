import 'dart:async';
import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'local_database.dart';
import 'models.dart';

class AppUser {
  final String uid;
  final String? email;
  final String? displayName;
  final bool isAnonymous;

  const AppUser({
    required this.uid,
    required this.email,
    required this.displayName,
    this.isAnonymous = false,
  });
}

class FirebaseService {
  static FirebaseService? _instance;
  static FirebaseService get instance => _instance ??= FirebaseService._();

  FirebaseService._();

  static const String _sessionUserIdKey = 'local_session_user_id';
  static const String _sessionEmailKey = 'local_session_email';
  static const String _sessionDisplayNameKey = 'local_session_display_name';

  AppUser? _currentUser;
  bool _initialized = false;

  Future<void> init() async {
    if (_initialized) return;
    await LocalDatabase.instance.database;
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getString(_sessionUserIdKey);
    if (userId != null && userId.isNotEmpty) {
      _currentUser = AppUser(
        uid: userId,
        email: prefs.getString(_sessionEmailKey),
        displayName: prefs.getString(_sessionDisplayNameKey),
      );
    }
    _initialized = true;
  }

  bool get isFirebaseAvailable => false;
  bool get isFirebaseDisabled => true;
  bool get isUsingFallbackStorage => true;
  AppUser? get currentUser => _currentUser;
  String? get currentUserId => _currentUser?.uid;
  String? get currentUserEmail => _currentUser?.email;

  String _hashPassword(String password) {
    return sha256.convert(utf8.encode(password.trim())).toString();
  }

  String _newId() => DateTime.now().microsecondsSinceEpoch.toString();

  Future<void> _saveSession(AppUser user) async {
    _currentUser = user;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_sessionUserIdKey, user.uid);
    if (user.email != null) {
      await prefs.setString(_sessionEmailKey, user.email!);
    } else {
      await prefs.remove(_sessionEmailKey);
    }
    if (user.displayName != null) {
      await prefs.setString(_sessionDisplayNameKey, user.displayName!);
    } else {
      await prefs.remove(_sessionDisplayNameKey);
    }
  }

  Future<void> _clearSession() async {
    _currentUser = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_sessionUserIdKey);
    await prefs.remove(_sessionEmailKey);
    await prefs.remove(_sessionDisplayNameKey);
  }

  Future<String?> registerWithEmailAndPassword({
    required String email,
    required String password,
    String? displayName,
  }) async {
    try {
      final db = await LocalDatabase.instance.database;
      final normalizedEmail = email.trim().toLowerCase();
      final existed = await db.query(
        'users',
        columns: ['id'],
        where: 'email = ?',
        whereArgs: [normalizedEmail],
        limit: 1,
      );
      if (existed.isNotEmpty) return '此電子郵件已註冊';

      final now = DateTime.now().toIso8601String();
      await db.insert('users', {
        'id': _newId(),
        'email': normalizedEmail,
        'password_hash': _hashPassword(password),
        'display_name': (displayName ?? '').trim().isEmpty ? null : displayName!.trim(),
        'created_at': now,
        'updated_at': now,
      });
      return null;
    } catch (e) {
      return '註冊失敗：$e';
    }
  }

  Future<String?> signInWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    try {
      final db = await LocalDatabase.instance.database;
      final normalizedEmail = email.trim().toLowerCase();
      final rows = await db.query(
        'users',
        where: 'email = ?',
        whereArgs: [normalizedEmail],
        limit: 1,
      );
      if (rows.isEmpty) return '帳號或密碼錯誤';

      final row = rows.first;
      final hash = _hashPassword(password);
      if (row['password_hash'] != hash) return '帳號或密碼錯誤';

      await _saveSession(
        AppUser(
          uid: row['id'] as String,
          email: row['email'] as String?,
          displayName: row['display_name'] as String?,
        ),
      );
      return null;
    } catch (e) {
      return '登入失敗：$e';
    }
  }

  Future<void> signOut() async {
    await _clearSession();
  }

  Future<String?> resetPassword(String email) async {
    return '本機模式暫不提供重設密碼郵件';
  }

  Future<String?> signInWithGoogle() async {
    return '本機模式不支援 Google 登入';
  }

  Future<String?> signInAnonymously() async {
    final nowId = 'guest_${_newId()}';
    await _saveSession(
      AppUser(
        uid: nowId,
        email: null,
        displayName: '訪客',
        isAnonymous: true,
      ),
    );
    return null;
  }

  Future<void> saveUserPasswordHash(String userId, String password) async {
    final db = await LocalDatabase.instance.database;
    await db.update(
      'users',
      {
        'password_hash': _hashPassword(password),
        'updated_at': DateTime.now().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [userId],
    );
  }

  Future<bool> verifyUserPasswordHash(String userId, String password) async {
    final db = await LocalDatabase.instance.database;
    final rows = await db.query(
      'users',
      columns: ['password_hash'],
      where: 'id = ?',
      whereArgs: [userId],
      limit: 1,
    );
    if (rows.isEmpty) return false;
    return rows.first['password_hash'] == _hashPassword(password);
  }

  Future<List<FoodItem>> getFoodItems({
    String? keyword,
    bool? onlyExpiring,
    String? userId,
  }) async {
    final targetUserId = userId ?? currentUserId;
    if (targetUserId == null) return [];

    final db = await LocalDatabase.instance.database;
    final rows = await db.query(
      'food_items',
      where: 'user_id = ?',
      whereArgs: [targetUserId],
      orderBy: 'expiry_date ASC',
    );
    var items = rows
        .map(
          (row) => FoodItem.fromMap({
            'id': row['id'],
            'name': row['name'],
            'quantity': row['quantity'],
            'unit': row['unit'],
            'purchaseDate': row['purchase_date'],
            'expiryDate': row['expiry_date'],
            'shelfLifeDays': row['shelf_life_days'],
            'category': row['category'],
            'storageLocation': row['storage_location'],
            'isOpened': (row['is_opened'] as int) == 1,
            'note': row['note'],
            'imagePath': row['image_path'],
            'account': row['user_id'],
          }),
        )
        .toList();

    if (keyword != null && keyword.isNotEmpty) {
      items = items
          .where((item) => item.name.toLowerCase().contains(keyword.toLowerCase()))
          .toList();
    }
    if (onlyExpiring == true) {
      final threeDaysFromNow = DateTime.now().add(const Duration(days: 3));
      items = items.where((item) => item.expiryDate.isBefore(threeDaysFromNow)).toList();
    }
    return items;
  }

  Future<String> addFoodItem(FoodItem item) async {
    final targetUserId = currentUserId;
    if (targetUserId == null) throw Exception('請先登入');

    final db = await LocalDatabase.instance.database;
    final id = _newId();
    final now = DateTime.now().toIso8601String();
    await db.insert('food_items', {
      'id': id,
      'user_id': targetUserId,
      'name': item.name,
      'quantity': item.quantity,
      'unit': item.unit,
      'purchase_date': item.purchaseDate.toIso8601String(),
      'expiry_date': item.expiryDate.toIso8601String(),
      'shelf_life_days': item.shelfLifeDays,
      'category': item.category.name,
      'storage_location': item.storageLocation.name,
      'is_opened': item.isOpened ? 1 : 0,
      'note': item.note,
      'image_path': item.imagePath,
      'created_at': now,
      'updated_at': now,
    });
    return id;
  }

  Future<void> updateFoodItem(FoodItem item) async {
    final targetUserId = currentUserId;
    if (targetUserId == null || item.id == null) throw Exception('資料不完整');

    final db = await LocalDatabase.instance.database;
    await db.update(
      'food_items',
      {
        'name': item.name,
        'quantity': item.quantity,
        'unit': item.unit,
        'purchase_date': item.purchaseDate.toIso8601String(),
        'expiry_date': item.expiryDate.toIso8601String(),
        'shelf_life_days': item.shelfLifeDays,
        'category': item.category.name,
        'storage_location': item.storageLocation.name,
        'is_opened': item.isOpened ? 1 : 0,
        'note': item.note,
        'image_path': item.imagePath,
        'updated_at': DateTime.now().toIso8601String(),
      },
      where: 'id = ? AND user_id = ?',
      whereArgs: [item.id, targetUserId],
    );
  }

  Future<void> deleteFoodItem(String id) async {
    final targetUserId = currentUserId;
    if (targetUserId == null) return;
    final db = await LocalDatabase.instance.database;
    await db.delete(
      'food_items',
      where: 'id = ? AND user_id = ?',
      whereArgs: [id, targetUserId],
    );
  }

  Future<List<ShoppingItem>> getShoppingItems({String? userId}) async {
    final targetUserId = userId ?? currentUserId;
    if (targetUserId == null) return [];

    final db = await LocalDatabase.instance.database;
    final rows = await db.query(
      'shopping_items',
      where: 'user_id = ?',
      whereArgs: [targetUserId],
      orderBy: 'name ASC',
    );
    return rows
        .map(
          (row) => ShoppingItem.fromMap({
            'id': row['id'],
            'name': row['name'],
            'amount': row['amount'],
            'checked': row['checked'],
            'account': row['user_id'],
          }),
        )
        .toList();
  }

  Future<String> addShoppingItem(ShoppingItem item) async {
    final targetUserId = currentUserId;
    if (targetUserId == null) throw Exception('請先登入');

    final db = await LocalDatabase.instance.database;
    final id = _newId();
    final now = DateTime.now().toIso8601String();
    await db.insert('shopping_items', {
      'id': id,
      'user_id': targetUserId,
      'name': item.name,
      'amount': item.amount,
      'checked': item.checked ? 1 : 0,
      'created_at': now,
      'updated_at': now,
    });
    return id;
  }

  Future<void> updateShoppingItem(ShoppingItem item) async {
    final targetUserId = currentUserId;
    if (targetUserId == null || item.id == null) return;

    final db = await LocalDatabase.instance.database;
    await db.update(
      'shopping_items',
      {
        'name': item.name,
        'amount': item.amount,
        'checked': item.checked ? 1 : 0,
        'updated_at': DateTime.now().toIso8601String(),
      },
      where: 'id = ? AND user_id = ?',
      whereArgs: [item.id, targetUserId],
    );
  }

  Future<void> deleteShoppingItem(String id) async {
    final targetUserId = currentUserId;
    if (targetUserId == null) return;

    final db = await LocalDatabase.instance.database;
    await db.delete(
      'shopping_items',
      where: 'id = ? AND user_id = ?',
      whereArgs: [id, targetUserId],
    );
  }

  Future<void> updateUserProfile({String? displayName, String? email}) async {
    final user = _currentUser;
    if (user == null) throw Exception('尚未登入');
    final db = await LocalDatabase.instance.database;

    final updates = <String, Object?>{
      'updated_at': DateTime.now().toIso8601String(),
    };
    if (displayName != null) updates['display_name'] = displayName.trim();
    if (email != null) updates['email'] = email.trim().toLowerCase();

    if (updates.length > 1) {
      await db.update('users', updates, where: 'id = ?', whereArgs: [user.uid]);
    }

    final updatedUser = AppUser(
      uid: user.uid,
      email: (updates['email'] as String?) ?? user.email,
      displayName: (updates['display_name'] as String?) ?? user.displayName,
      isAnonymous: user.isAnonymous,
    );
    await _saveSession(updatedUser);
  }

  Future<String?> changePassword(String newPassword) async {
    try {
      final user = _currentUser;
      if (user == null || user.isAnonymous) return '匿名使用者無法變更密碼';
      final db = await LocalDatabase.instance.database;
      await db.update(
        'users',
        {
          'password_hash': _hashPassword(newPassword),
          'updated_at': DateTime.now().toIso8601String(),
        },
        where: 'id = ?',
        whereArgs: [user.uid],
      );
      return null;
    } catch (e) {
      return '修改密碼失敗：$e';
    }
  }

  Stream<List<FoodItem>> watchFoodItems({
    String? keyword,
    bool? onlyExpiring,
    String? userId,
  }) {
    return Stream.value([]);
  }

  Stream<List<ShoppingItem>> watchShoppingItems({String? userId}) {
    return Stream.value([]);
  }
}
