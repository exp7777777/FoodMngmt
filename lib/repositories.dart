import 'package:sqflite/sqflite.dart';

import 'db.dart';
import 'models.dart';

class FoodRepository {
  Future<Database> get _db async => (await AppDatabase.instance.database);

  Future<List<FoodItem>> getAll({
    String? keyword,
    bool? onlyExpiring,
    String? account,
  }) async {
    final db = await _db;
    final where = <String>[];
    final args = <Object?>[];
    if (account != null && account.trim().isNotEmpty) {
      where.add('account = ?');
      args.add(account.trim());
    }
    if (keyword != null && keyword.trim().isNotEmpty) {
      where.add('name LIKE ?');
      args.add('%${keyword.trim()}%');
    }
    if (onlyExpiring == true) {
      where.add('DATE(expiryDate) <= DATE(?)');
      args.add(DateTime.now().add(Duration(days: 3)).toIso8601String());
    }
    final maps = await db.query(
      'food_items',
      where: where.isEmpty ? null : where.join(' AND '),
      whereArgs: args.isEmpty ? null : args,
      orderBy: 'expiryDate ASC',
    );
    return maps.map((e) => FoodItem.fromMap(e)).toList();
  }

  Future<int> insert(FoodItem item) async {
    final db = await _db;
    return db.insert('food_items', item.toMap());
  }

  Future<int> update(FoodItem item) async {
    final db = await _db;
    return db.update(
      'food_items',
      item.toMap(),
      where: 'id=?',
      whereArgs: [item.id],
    );
  }

  Future<int> delete(int id) async {
    final db = await _db;
    return db.delete('food_items', where: 'id=?', whereArgs: [id]);
  }
}

class ShoppingRepository {
  Future<Database> get _db async => (await AppDatabase.instance.database);

  Future<List<ShoppingItem>> getAll({String? account}) async {
    final db = await _db;
    final maps = await db.query(
      'shopping_items',
      orderBy: 'id DESC',
      where: account == null || account.trim().isEmpty ? null : 'account = ?',
      whereArgs:
          account == null || account.trim().isEmpty ? null : [account.trim()],
    );
    return maps.map((e) => ShoppingItem.fromMap(e)).toList();
  }

  Future<int> insert(ShoppingItem item) async {
    final db = await _db;
    return db.insert('shopping_items', item.toMap());
  }

  Future<int> toggleChecked(int id, bool checked) async {
    final db = await _db;
    return db.update(
      'shopping_items',
      {'checked': checked ? 1 : 0},
      where: 'id=?',
      whereArgs: [id],
    );
  }

  Future<int> delete(int id) async {
    final db = await _db;
    return db.delete('shopping_items', where: 'id=?', whereArgs: [id]);
  }

  Future<int> clearChecked() async {
    final db = await _db;
    return db.delete('shopping_items', where: 'checked=1');
  }
}

// UserProfileRepository 已移除（使用 AuthRepository/users 表）

class AuthRepository {
  Future<Database> get _db async => (await AppDatabase.instance.database);

  Future<int> register({
    required String account,
    required String password,
    String? nickname,
  }) async {
    final db = await _db;
    return db.insert('users', {
      'account': account.trim(),
      'password': password.trim(),
      'nickname': nickname?.trim(),
    });
  }

  Future<Map<String, Object?>?> findByAccount(String account) async {
    final db = await _db;
    final rows = await db.query(
      'users',
      where: 'account=?',
      whereArgs: [account.trim()],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return rows.first;
  }

  Future<bool> verify({
    required String account,
    required String password,
  }) async {
    final row = await findByAccount(account);
    if (row == null) return false;
    return (row['password'] as String) == password.trim();
  }

  Future<int> changePassword({
    required String account,
    required String oldPassword,
    required String newPassword,
  }) async {
    final db = await _db;
    final ok = await verify(account: account, password: oldPassword);
    if (!ok) return 0;
    return db.update(
      'users',
      {'password': newPassword.trim()},
      where: 'account=?',
      whereArgs: [account.trim()],
    );
  }

  Future<int> updateProfile({
    required String account,
    String? newAccount,
    String? nickname,
  }) async {
    final db = await _db;
    final values = <String, Object?>{};
    if (newAccount != null && newAccount.trim().isNotEmpty) {
      values['account'] = newAccount.trim();
    }
    if (nickname != null) {
      values['nickname'] = nickname.trim();
    }
    if (values.isEmpty) return 0;
    return db.update(
      'users',
      values,
      where: 'account=?',
      whereArgs: [account.trim()],
    );
  }
}
