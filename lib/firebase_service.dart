import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart'
    show kIsWeb, defaultTargetPlatform, TargetPlatform;
import 'package:google_sign_in/google_sign_in.dart';
import 'package:crypto/crypto.dart';
import 'dart:convert';
import 'models.dart';
import 'firebase_options.dart';
import 'fallback_storage.dart';

class FirebaseService {
  static FirebaseService? _instance;
  static FirebaseService get instance => _instance ??= FirebaseService._();

  FirebaseService._() {
    init(); // 在構造函數中初始化
  }

  bool _initialized = false;
  bool _useFirebase = true;
  User? _currentUser;

  Future<void> init() async {
    if (_initialized) return;

    debugPrint('開始初始化 Firebase...');

    // 檢查是否為支援的平台並嘗試初始化
    _useFirebase = await _shouldUseFirebase();

    if (_useFirebase) {
      // Firebase 已經在 _shouldUseFirebase 中初始化
      _initialized = true;
      debugPrint('Firebase 初始化成功，可用狀態: $_useFirebase');

      // 立即獲取當前用戶狀態
      try {
        _currentUser = FirebaseAuth.instance.currentUser;
      } catch (e) {
        debugPrint('Firebase 獲取當前用戶失敗: $e');
      }

      // 延遲監聽身份驗證狀態變化，避免初始化時機問題
      Future.delayed(const Duration(milliseconds: 100), () {
        try {
          FirebaseAuth.instance.authStateChanges().listen((User? user) {
            _currentUser = user;
          });
        } catch (e) {
          debugPrint('Firebase Auth 監聽設定失敗: $e');
        }
      });
    } else {
      _initialized = true;
      debugPrint('Firebase disabled for this platform');
    }
  }

  Future<bool> _shouldUseFirebase() async {
    // 在 Web 平台總是使用 Firebase
    if (kIsWeb) {
      try {
        // 檢查是否已經初始化過
        if (Firebase.apps.isNotEmpty) return true;

        // 嘗試初始化 Firebase
        await Firebase.initializeApp(
          options: DefaultFirebaseOptions.currentPlatform,
        );
        debugPrint('Firebase Web 初始化成功');
        return true;
      } catch (e) {
        debugPrint('Firebase Web 初始化失敗: $e');
        return false;
      }
    }

    // 檢查是否已經初始化過
    if (Firebase.apps.isNotEmpty) return true;

    // 嘗試初始化 Firebase 來檢查是否可用
    try {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
      return true;
    } catch (e) {
      debugPrint('Firebase not available on this platform: $e');

      // 根據平台決定是否使用備用機制
      switch (defaultTargetPlatform) {
        case TargetPlatform.windows:
        case TargetPlatform.linux:
        case TargetPlatform.macOS:
          // 桌面平台如果 Firebase 失敗，使用備用儲存
          debugPrint('Using fallback storage for desktop platform');
          return false;
        case TargetPlatform.android:
        case TargetPlatform.iOS:
          // 行動平台如果 Firebase 失敗，回傳 false 讓上層處理
          return false;
        default:
          return false;
      }
    }
  }

  bool get isFirebaseAvailable => _initialized && _useFirebase;
  bool get isFirebaseDisabled => !_useFirebase;
  bool get isUsingFallbackStorage => !isFirebaseAvailable;

  // 當前使用者
  User? get currentUser => _currentUser;
  String? get currentUserId => _currentUser?.uid;
  String? get currentUserEmail => _currentUser?.email;

  // Collection 參考
  CollectionReference<Map<String, dynamic>> get _foodItems =>
      FirebaseFirestore.instance.collection('food_items');

  CollectionReference<Map<String, dynamic>> get _shoppingItems =>
      FirebaseFirestore.instance.collection('shopping_items');

  CollectionReference<Map<String, dynamic>> get _users =>
      FirebaseFirestore.instance.collection('users');

  // ==================== 身份驗證相關方法 ====================

  Future<String?> registerWithEmailAndPassword({
    required String email,
    required String password,
    String? displayName,
  }) async {
    if (!isFirebaseAvailable) {
      return '此平台不支援 Firebase 身份驗證';
    }

    try {
      final userCredential = await FirebaseAuth.instance
          .createUserWithEmailAndPassword(email: email, password: password);

      // 更新顯示名稱
      if (displayName != null && userCredential.user != null) {
        await userCredential.user!.updateDisplayName(displayName);
      }

      // 在 Firestore 中創建用戶檔案
      await _users.doc(userCredential.user!.uid).set({
        'createdAt': FieldValue.serverTimestamp(),
        'displayName': displayName,
        'email': email,
        'password': password, // ⚠️ 警告：明文儲存密碼是不安全的！
        'updatedAt': FieldValue.serverTimestamp(),
      });

      return null; // 成功
    } on FirebaseAuthException catch (e) {
      return _getAuthErrorMessage(e);
    } catch (e) {
      return '註冊失敗：$e';
    }
  }

  Future<String?> signInWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    if (!isFirebaseAvailable) {
      return '此平台不支援 Firebase 身份驗證';
    }

    try {
      final userCredential = await FirebaseAuth.instance
          .signInWithEmailAndPassword(email: email, password: password);

      // 更新當前用戶狀態
      _currentUser = userCredential.user;

      // 登入成功後儲存密碼雜湊（用於額外驗證）
      if (_currentUser != null) {
        await saveUserPasswordHash(_currentUser!.uid, password);
      }

      return null; // 成功
    } on FirebaseAuthException catch (e) {
      return _getAuthErrorMessage(e);
    } catch (e) {
      return '登入失敗：$e';
    }
  }

  Future<void> signOut() async {
    await FirebaseAuth.instance.signOut();
  }

  Future<String?> resetPassword(String email) async {
    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
      return null; // 成功
    } on FirebaseAuthException catch (e) {
      return _getAuthErrorMessage(e);
    } catch (e) {
      return '密碼重設失敗：$e';
    }
  }

  Future<String?> signInWithGoogle() async {
    if (!isFirebaseAvailable) {
      return '此平台不支援 Google 登入';
    }

    try {
      // 觸發 Google 登入流程
      final GoogleSignInAccount? googleUser = await GoogleSignIn().signIn();

      if (googleUser == null) {
        return 'Google 登入取消';
      }

      // 從 Google 登入獲得授權碼
      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;

      // 創建 Firebase 憑證
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      // 使用憑證登入 Firebase
      final userCredential = await FirebaseAuth.instance.signInWithCredential(
        credential,
      );

      // 更新當前用戶狀態
      _currentUser = userCredential.user;

      // 在 Firestore 中創建或更新用戶檔案
      if (userCredential.user != null) {
        await _users.doc(userCredential.user!.uid).set({
          'createdAt': FieldValue.serverTimestamp(),
          'displayName': userCredential.user!.displayName,
          'email': userCredential.user!.email,
          'loginMethod': 'google',
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }

      return null; // 成功
    } on FirebaseAuthException catch (e) {
      return _getAuthErrorMessage(e);
    } catch (e) {
      return 'Google 登入失敗：$e';
    }
  }

  Future<String?> signInAnonymously() async {
    if (!isFirebaseAvailable) {
      return '此平台不支援匿名登入';
    }

    try {
      final userCredential = await FirebaseAuth.instance.signInAnonymously();

      // 更新當前用戶狀態
      _currentUser = userCredential.user;

      // 為匿名用戶創建一個基本的 Firestore 檔案
      if (userCredential.user != null) {
        await _users.doc(userCredential.user!.uid).set({
          'createdAt': FieldValue.serverTimestamp(),
          'isAnonymous': true,
          'loginMethod': 'anonymous',
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }

      return null; // 成功
    } on FirebaseAuthException catch (e) {
      return _getAuthErrorMessage(e);
    } catch (e) {
      return '匿名登入失敗：$e';
    }
  }

  // 安全的密碼雜湊儲存方法（僅供參考，不建議在生產環境中使用明文雜湊）
  String _hashPassword(String password) {
    final bytes = utf8.encode(password + 'foodmngmt_salt_2024'); // 加入鹽值
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  // 儲存使用者密碼雜湊（僅供額外驗證使用）
  Future<void> saveUserPasswordHash(String userId, String password) async {
    try {
      final passwordHash = _hashPassword(password);
      await _users.doc(userId).set({
        'passwordHash': passwordHash,
        'password': password, // ⚠️ 警告：明文儲存密碼是不安全的！
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('Error saving password hash: ${e.toString()}');
    }
  }

  // 驗證使用者密碼雜湊（僅供額外驗證使用）
  Future<bool> verifyUserPasswordHash(String userId, String password) async {
    try {
      final doc = await _users.doc(userId).get();
      if (doc.exists) {
        final data = doc.data();
        final storedHash = data?['passwordHash'] as String?;
        if (storedHash != null) {
          final inputHash = _hashPassword(password);
          return storedHash == inputHash;
        }
      }
      return false;
    } catch (e) {
      debugPrint('Error verifying password hash: ${e.toString()}');
      return false;
    }
  }

  // ==================== 食物項目相關方法 ====================

  Future<List<FoodItem>> getFoodItems({
    String? keyword,
    bool? onlyExpiring,
    String? userId,
  }) async {
    if (isFirebaseAvailable) {
      try {
        // 簡化查詢以避免複合索引需求
        Query<Map<String, dynamic>> query = _foodItems;

        // 只使用 userId 篩選，移除 Filter.or 以避免索引需求
        if (userId != null) {
          query = query.where('userId', isEqualTo: userId);
        }

        // 獲取所有符合條件的資料
        final snapshot = await query.get();
        List<FoodItem> items =
            snapshot.docs
                .map((doc) => FoodItem.fromMap({...doc.data(), 'id': doc.id}))
                .toList();

        // 在記憶體中進行篩選和排序
        if (keyword != null && keyword.isNotEmpty) {
          items =
              items
                  .where(
                    (item) =>
                        item.name.toLowerCase().contains(keyword.toLowerCase()),
                  )
                  .toList();
        }

        if (onlyExpiring == true) {
          final threeDaysFromNow = DateTime.now().add(const Duration(days: 3));
          items =
              items
                  .where((item) => item.expiryDate.isBefore(threeDaysFromNow))
                  .toList();
        }

        // 按到期日期排序
        items.sort((a, b) => a.expiryDate.compareTo(b.expiryDate));

        return items;
      } catch (e) {
        debugPrint('Error getting food items from Firebase: $e');
        // 如果 Firebase 失敗，回退到備用儲存
        return FallbackStorage.instance.getFoodItems(
          keyword: keyword,
          onlyExpiring: onlyExpiring,
          userId: userId,
        );
      }
    }

    // 使用備用儲存
    return FallbackStorage.instance.getFoodItems(
      keyword: keyword,
      onlyExpiring: onlyExpiring,
      userId: userId,
    );
  }

  Future<String> addFoodItem(FoodItem item) async {
    if (isFirebaseAvailable) {
      try {
        // 確保使用正確的欄位名稱
        final itemData = item.toMap();
        // 移除舊的 account 欄位，改用 userId
        itemData.remove('account');
        itemData['userId'] = currentUserId;

        final docRef = await _foodItems.add({
          ...itemData,
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
        return docRef.id;
      } catch (e) {
        debugPrint('Error adding food item to Firebase: $e');
        // 如果 Firebase 失敗，回退到備用儲存
      }
    }

    // 使用備用儲存
    return FallbackStorage.instance.addFoodItem(item, userId: currentUserId);
  }

  Future<void> updateFoodItem(FoodItem item) async {
    try {
      // 確保使用正確的欄位名稱
      final itemData = item.toMap();
      // 移除舊的 account 欄位，改用 userId
      itemData.remove('account');
      itemData['userId'] = currentUserId;

      await _foodItems.doc(item.id).update({
        ...itemData,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('Error updating food item: $e');
      throw Exception('更新食物項目失敗：$e');
    }
  }

  Future<void> deleteFoodItem(String id) async {
    try {
      await _foodItems.doc(id).delete();
    } catch (e) {
      debugPrint('Error deleting food item: $e');
      throw Exception('刪除食物項目失敗：$e');
    }
  }

  // ==================== 購物清單相關方法 ====================

  Future<List<ShoppingItem>> getShoppingItems({String? userId}) async {
    if (isFirebaseAvailable) {
      try {
        Query<Map<String, dynamic>> query = _shoppingItems;

        // 使用傳入的 userId 或當前用戶 ID
        final targetUserId = userId ?? currentUserId;

        if (targetUserId != null) {
          // 簡化查詢，只使用 userId
          query = query.where('userId', isEqualTo: targetUserId);
        }

        final snapshot = await query.get();

        List<ShoppingItem> items =
            snapshot.docs.map((doc) {
              final data = {...doc.data(), 'id': doc.id};
              return ShoppingItem.fromMap(data);
            }).toList();

        // 按名稱排序
        items.sort((a, b) => a.name.compareTo(b.name));

        return items;
      } catch (e) {
        debugPrint('Error getting shopping items from Firebase: $e');
        // 如果 Firebase 失敗，回退到備用儲存
        return FallbackStorage.instance.getShoppingItems(userId: userId);
      }
    }

    // 使用備用儲存
    return FallbackStorage.instance.getShoppingItems(userId: userId);
  }

  Future<String> addShoppingItem(ShoppingItem item) async {
    if (isFirebaseAvailable) {
      try {
        final docRef = await _shoppingItems.add({
          'name': item.name,
          'amount': item.amount,
          'checked': item.checked,
          'userId': currentUserId, // 統一使用 userId
          'account': currentUserId, // 同時儲存 account 以相容備用儲存
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
        return docRef.id;
      } catch (e) {
        debugPrint('Error adding shopping item to Firebase: $e');
        throw Exception('新增購物項目失敗：$e');
      }
    }

    // 如果 Firebase 不可用，使用備用儲存
    return FallbackStorage.instance.addShoppingItem(item);
  }

  Future<void> updateShoppingItem(ShoppingItem item) async {
    try {
      // 只更新 checked 狀態，避免完整更新
      await _shoppingItems.doc(item.id).update({
        'checked': item.checked,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('Error updating shopping item: $e');
      throw Exception('更新購物項目失敗：$e');
    }
  }

  Future<void> deleteShoppingItem(String id) async {
    try {
      await _shoppingItems.doc(id).delete();
    } catch (e) {
      debugPrint('Error deleting shopping item: $e');
      throw Exception('刪除購物項目失敗：$e');
    }
  }

  // ==================== 使用者資料相關方法 ====================

  Future<void> updateUserProfile({String? displayName, String? email}) async {
    try {
      if (_currentUser == null) throw Exception('用戶未登入');

      final updates = <String, dynamic>{};
      if (displayName != null) {
        updates['displayName'] = displayName;
        await _currentUser!.updateDisplayName(displayName);
      }
      if (email != null) {
        updates['email'] = email;
        await _currentUser!.verifyBeforeUpdateEmail(email);
      }

      if (updates.isNotEmpty) {
        await _users.doc(_currentUser!.uid).update(updates);
      }
    } catch (e) {
      debugPrint('Error updating user profile: $e');
      throw Exception('更新用戶資料失敗：$e');
    }
  }

  Future<String?> changePassword(String newPassword) async {
    try {
      if (_currentUser == null) return '用戶未登入';
      await _currentUser!.updatePassword(newPassword);
      return null;
    } catch (e) {
      debugPrint('Error changing password: $e');
      return '密碼變更失敗：$e';
    }
  }

  // ==================== 即時監聽 ====================

  Stream<List<FoodItem>> watchFoodItems({
    String? keyword,
    bool? onlyExpiring,
    String? userId,
  }) {
    if (!isFirebaseAvailable) {
      return Stream.value([]); // 返回空串流
    }

    // 簡化查詢以避免複合索引需求
    Query<Map<String, dynamic>> query = _foodItems;

    if (userId != null) {
      query = query.where('userId', isEqualTo: userId);
    }

    return query.snapshots().map((snapshot) {
      List<FoodItem> items =
          snapshot.docs
              .map((doc) => FoodItem.fromMap({...doc.data(), 'id': doc.id}))
              .toList();

      // 在記憶體中進行篩選
      if (keyword != null && keyword.isNotEmpty) {
        items =
            items
                .where(
                  (item) =>
                      item.name.toLowerCase().contains(keyword.toLowerCase()),
                )
                .toList();
      }

      if (onlyExpiring == true) {
        final threeDaysFromNow = DateTime.now().add(const Duration(days: 3));
        items =
            items
                .where((item) => item.expiryDate.isBefore(threeDaysFromNow))
                .toList();
      }

      // 按到期日期排序
      items.sort((a, b) => a.expiryDate.compareTo(b.expiryDate));

      return items;
    });
  }

  Stream<List<ShoppingItem>> watchShoppingItems({String? userId}) {
    if (!isFirebaseAvailable) {
      return Stream.value([]); // 返回空串流
    }

    Query<Map<String, dynamic>> query = _shoppingItems;

    if (userId != null) {
      // 簡化查詢，只使用 userId
      query = query.where('userId', isEqualTo: userId);
    }

    return query.snapshots().map((snapshot) {
      List<ShoppingItem> items =
          snapshot.docs
              .map((doc) => ShoppingItem.fromMap({...doc.data(), 'id': doc.id}))
              .toList();

      // 按名稱排序
      items.sort((a, b) => a.name.compareTo(b.name));

      return items;
    });
  }

  // ==================== 工具方法 ====================

  String _getAuthErrorMessage(FirebaseAuthException e) {
    switch (e.code) {
      case 'email-already-in-use':
        return '該電子郵件已被註冊';
      case 'invalid-email':
        return '電子郵件格式無效';
      case 'weak-password':
        return '密碼強度不足';
      case 'user-not-found':
        return '找不到該用戶';
      case 'wrong-password':
        return '密碼錯誤';
      case 'user-disabled':
        return '該用戶帳號已被停用';
      case 'too-many-requests':
        return '請求過於頻繁，請稍後再試';
      case 'network-request-failed':
        return '網路連線失敗';
      default:
        return '驗證失敗：${e.message ?? '未知錯誤'}';
    }
  }
}
