import 'firebase_service.dart';
import 'models.dart';

class FoodRepository {
  final FirebaseService _localService = FirebaseService.instance;

  Future<List<FoodItem>> getAll({
    String? keyword,
    bool? onlyExpiring,
    String? userId,
  }) async {
    return _localService.getFoodItems(
      keyword: keyword,
      onlyExpiring: onlyExpiring,
      userId: userId,
    );
  }

  Future<String> insert(FoodItem item) async {
    // 確保食物項目有關聯的用戶
    final itemWithUser = item.copyWith(account: _localService.currentUserId);
    return _localService.addFoodItem(itemWithUser);
  }

  Future<void> update(FoodItem item) async {
    await _localService.updateFoodItem(item);
  }

  Future<void> delete(String id) async {
    await _localService.deleteFoodItem(id);
  }

  // 即時監聽方法（已停用，使用本地狀態更新）
  Stream<List<FoodItem>> watchAll({
    String? keyword,
    bool? onlyExpiring,
    String? userId,
  }) {
    return Stream.value([]); // 返回空串流，避免重複更新
  }
}

class ShoppingRepository {
  final FirebaseService _localService = FirebaseService.instance;

  Future<List<ShoppingItem>> getAll({String? userId}) async {
    return _localService.getShoppingItems(userId: userId);
  }

  Future<String> insert(ShoppingItem item) async {
    // 確保項目有正確的 account 欄位
    final itemWithAccount = item.copyWith(
      account: _localService.currentUserId,
    );
    return _localService.addShoppingItem(itemWithAccount);
  }

  Future<void> toggleChecked(String id, bool checked) async {
    // 直接更新，不需要先查詢
    final updatedItem = ShoppingItem(id: id, name: '', checked: checked);
    await _localService.updateShoppingItem(updatedItem);
  }

  Future<void> delete(String id) async {
    await _localService.deleteShoppingItem(id);
  }

  // 即時監聽方法（已停用，使用本地狀態更新）
  Stream<List<ShoppingItem>> watchAll({String? userId}) {
    return Stream.value([]); // 返回空串流，避免重複更新
  }
}

// UserProfileRepository 已移除（使用 AuthRepository/users 表）

class AuthRepository {
  final FirebaseService _localService = FirebaseService.instance;

  Future<String?> register({
    required String email,
    required String password,
    String? nickname,
  }) async {
    return _localService.registerWithEmailAndPassword(
      email: email,
      password: password,
      displayName: nickname,
    );
  }

  Future<String?> signIn({
    required String email,
    required String password,
  }) async {
    return _localService.signInWithEmailAndPassword(
      email: email,
      password: password,
    );
  }

  Future<void> signOut() async {
    await _localService.signOut();
  }

  Future<String?> resetPassword(String email) async {
    return _localService.resetPassword(email);
  }

  Future<String?> signInWithGoogle() async {
    return _localService.signInWithGoogle();
  }

  Future<String?> signInAnonymously() async {
    return _localService.signInAnonymously();
  }

  Future<bool> isSignedIn() async {
    return _localService.currentUser != null;
  }

  Future<String?> getCurrentUserEmail() async {
    return _localService.currentUserEmail;
  }

  Future<String?> changePassword(String newPassword) async {
    return _localService.changePassword(newPassword);
  }

  Future<String?> updateProfile({String? displayName, String? email}) async {
    try {
      await _localService.updateUserProfile(
        displayName: displayName,
        email: email,
      );
      return null; // 成功
    } catch (e) {
      return '更新資料失敗：$e';
    }
  }

  // 儲存使用者密碼雜湊（僅供額外驗證使用）
  Future<void> saveUserPasswordHash(String userId, String password) async {
    await _localService.saveUserPasswordHash(userId, password);
  }

  // 驗證使用者密碼雜湊（僅供額外驗證使用）
  Future<bool> verifyUserPasswordHash(String userId, String password) async {
    return _localService.verifyUserPasswordHash(userId, password);
  }

  // 為了向下相容，提供舊的方法名稱
  Future<String?> login({
    required String account,
    required String password,
  }) async {
    return signIn(email: account, password: password);
  }

  Future<String?> verify({
    required String account,
    required String password,
  }) async {
    final result = await signIn(email: account, password: password);
    return result; // 如果為 null 表示登入成功（驗證通過）
  }
}
