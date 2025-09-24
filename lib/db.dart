import 'dart:async';
import 'package:flutter/foundation.dart';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart' as ffi;

class AppDatabase {
  AppDatabase._();
  static final AppDatabase instance = AppDatabase._();
  Database? _db;

  Future<Database> get database async {
    if (_db != null) return _db!;
    _db = await _init();
    return _db!;
  }

  Future<Database> _init() async {
    // Windows/Linux 桌面端使用 FFI 實作
    try {
      ffi.sqfliteFfiInit();
      databaseFactory = ffi.databaseFactoryFfi;
    } catch (_) {}
    final dir = await getApplicationDocumentsDirectory();
    final path = p.join(dir.path, 'foodmngmt.db');
    debugPrint('DB path: $path');
    return openDatabase(
      path,
      version: 6,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE food_items(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT NOT NULL,
            quantity INTEGER NOT NULL,
            unit TEXT NOT NULL,
            expiryDate TEXT NOT NULL,
            category TEXT NOT NULL,
            note TEXT,
            imagePath TEXT,
            account TEXT
          );
        ''');

        await db.execute('''
          CREATE TABLE shopping_items(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT NOT NULL,
            amount TEXT,
            checked INTEGER NOT NULL DEFAULT 0,
            account TEXT
          );
        ''');

        // 已改用 users 表，user_profile 不再建立

        // 使用者帳號表（用於登入/註冊）
        await db.execute('''
          CREATE TABLE users(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            account TEXT NOT NULL UNIQUE,
            password TEXT NOT NULL,
            nickname TEXT
          );
        ''');
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          // 舊版建立過 user_profile，保留升級流程
          try {
            await db.execute('''
              CREATE TABLE IF NOT EXISTS user_profile(
                id INTEGER PRIMARY KEY CHECK (id = 1),
                nickname TEXT,
                account TEXT,
                password TEXT
              );
            ''');
          } catch (_) {}
        }
        if (oldVersion < 3) {
          // 新增食材圖片欄位
          await db.execute('ALTER TABLE food_items ADD COLUMN imagePath TEXT;');
        }
        // 帳號分區欄位（冪等嘗試）
        try {
          await db.execute('ALTER TABLE food_items ADD COLUMN account TEXT;');
        } catch (_) {}
        try {
          await db.execute(
            'ALTER TABLE shopping_items ADD COLUMN account TEXT;',
          );
        } catch (_) {}
        if (oldVersion < 4) {
          await db.execute('''
            CREATE TABLE IF NOT EXISTS users(
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              account TEXT NOT NULL UNIQUE,
              password TEXT NOT NULL,
              nickname TEXT
            );
          ''');
        }
        if (oldVersion < 5) {
          // 重新嘗試補上欄位，避免先前版本缺欄位
          try {
            await db.execute('ALTER TABLE food_items ADD COLUMN account TEXT;');
          } catch (_) {}
          try {
            await db.execute(
              'ALTER TABLE shopping_items ADD COLUMN account TEXT;',
            );
          } catch (_) {}
        }
        if (oldVersion < 6) {
          // 將 user_profile 的資料（若存在且 users 沒有同帳號）遷移到 users
          try {
            final rows = await db.rawQuery(
              'SELECT nickname, account, password FROM user_profile WHERE id=1',
            );
            if (rows.isNotEmpty) {
              final r = rows.first;
              final acc = r['account'] as String?;
              if (acc != null && acc.isNotEmpty) {
                final exists = await db.rawQuery(
                  'SELECT 1 FROM users WHERE account=? LIMIT 1',
                  [acc],
                );
                if (exists.isEmpty) {
                  await db.insert('users', {
                    'account': acc,
                    'password': (r['password'] as String?) ?? '',
                    'nickname': r['nickname'] as String?,
                  });
                }
              }
            }
          } catch (_) {}
          // 丟棄舊的 user_profile 表
          try {
            await db.execute('DROP TABLE IF EXISTS user_profile;');
          } catch (_) {}
        }
      },
    );
  }
}
