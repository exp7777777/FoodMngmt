# 🔥 Firebase 設定指南

## 📋 設定步驟

### 1. 創建 Firebase 專案

1. 前往 [Firebase Console](https://console.firebase.google.com/)
2. 點擊「建立專案」或選擇現有專案
3. 輸入專案名稱（例如：FoodMngmt）
4. 選擇 Google Analytics 設定（建議啟用）

### 2. 啟用所需服務

在 Firebase Console 中啟用以下服務：

#### 🔐 Authentication
- 前往「Authentication」>「開始使用」
- 選擇「登入方法」標籤
- 啟用「電子郵件/密碼」

#### 📊 Firestore 資料庫
- 前往「Firestore Database」>「建立資料庫」
- 選擇「測試模式」或「生產模式」（開發時建議測試模式）
- 選擇地區（建議選擇離你近的地區）

#### 📸 Storage (選用，用於圖片上傳)
- 前往「Storage」>「開始使用」
- 設定安全規則（開發時可設為測試模式）

### 3. 設定 Flutter 專案

#### 安裝 FlutterFire CLI（如果還沒安裝）
```bash
dart pub global activate flutterfire_cli
```

#### 設定 Firebase 專案
```bash
# 在專案根目錄執行
flutterfire configure

# 或手動設定：
# 1. 複製 google-services.json 到 android/app/
# 2. 複製 GoogleService-Info.plist 到 ios/Runner/
```

### 4. 更新 firebase_options.dart

編輯 `lib/firebase_options.dart` 檔案，將以下設定替換為你的 Firebase 專案設定：

```dart
static const FirebaseOptions web = FirebaseOptions(
  apiKey: 'your-api-key-here',
  appId: 'your-app-id-here',
  messagingSenderId: 'your-sender-id-here',
  projectId: 'your-project-id-here',
  authDomain: 'your-project-id.firebaseapp.com',
  storageBucket: 'your-project-id.appspot.com',
);

static const FirebaseOptions android = FirebaseOptions(
  apiKey: 'your-api-key-here',
  appId: 'your-app-id-here',
  messagingSenderId: 'your-sender-id-here',
  projectId: 'your-project-id-here',
  storageBucket: 'your-project-id.appspot.com',
);

static const FirebaseOptions ios = FirebaseOptions(
  apiKey: 'your-api-key-here',
  appId: 'your-app-id-here',
  messagingSenderId: 'your-sender-id-here',
  projectId: 'your-project-id-here',
  storageBucket: 'your-project-id.appspot.com',
  iosBundleId: 'com.example.foodmngmt',
);

static const FirebaseOptions macos = FirebaseOptions(
  apiKey: 'your-api-key-here',
  appId: 'your-app-id-here',
  messagingSenderId: 'your-sender-id-here',
  projectId: 'your-project-id-here',
  storageBucket: 'your-project-id.appspot.com',
  iosBundleId: 'com.example.foodmngmt',
);

static const FirebaseOptions windows = FirebaseOptions(
  apiKey: 'your-api-key-here',
  appId: 'your-app-id-here',
  messagingSenderId: 'your-sender-id-here',
  projectId: 'your-project-id-here',
  storageBucket: 'your-project-id.appspot.com',
);
```

### 5. 取得設定值

在 Firebase Console 中：

1. 前往「專案設定」>「一般」
2. 在「你的應用程式」部分找到設定值
3. 複製以下欄位的值：
   - API 金鑰
   - 應用程式 ID
   - 訊息傳送 ID
   - 專案 ID
   - 儲存貯體

### 6. 測試連線

執行應用程式，確認 Firebase 初始化成功：

```bash
flutter run
```

如果出現錯誤，請檢查：
- firebase_options.dart 中的設定是否正確
- Firebase 專案是否啟用了所需服務
- 網路連線是否正常

## 💡 進階設定（選用）

### 設定安全規則

#### Firestore 安全規則
```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    // 允許已驗證用戶讀取自己的資料
    match /food_items/{document} {
      allow read, write: if request.auth != null;
    }
    match /shopping_items/{document} {
      allow read, write: if request.auth != null;
    }
    match /users/{document} {
      allow read, write: if request.auth != null;
    }
  }
}
```

#### Storage 安全規則
```javascript
rules_version = '2';
service firebase.storage {
  match /b/{bucket}/o {
    match /{allPaths=**} {
      allow read, write: if request.auth != null;
    }
  }
}
```

### 設定離線支援

Firebase 預設支援離線功能，當網路連線恢復時會自動同步資料。

## 🔔 設定 Firebase Cloud Messaging (FCM)

1. **啟用服務**
   - 在 Firebase Console 左側選單選擇「Cloud Messaging」
   - 確認專案已啟用 Cloud Messaging API，並記下 Server key 與 Sender ID

2. **Android 設定**
   - `android/app/src/main/AndroidManifest.xml` 已加入 `POST_NOTIFICATIONS` 權限與預設通知頻道，可依需求調整 icon 與顏色
   - 確保 `google-services.json` 仍放在 `android/app/`，如需更換專案記得重新下載

3. **iOS / macOS 設定**
   - 於 Apple Developer 帳號建立 APNs Auth Key（.p8）並上傳到 Firebase Console
   - 在 Xcode `Signing & Capabilities` 新增 `Push Notifications`、`Background Modes` (Remote notifications)
   - AppDelegate 已註冊 `UNUserNotificationCenter`，若需要擴充請保留現有設定

4. **Web 設定**
   - `web/firebase-messaging-sw.js` 為服務工作器檔案，佈署 Web 版本時務必一併上傳
   - 前往 Firebase Console > Cloud Messaging > Web Push certificates，產生 VAPID Key
   - 執行 Web 構建時需加入 `--dart-define=FOODMNGMT_WEB_PUSH_KEY=<VAPID Key>`，否則 Web 端將跳過 Token 產生

5. **伺服端推播**
   - 呼叫 `https://fcm.googleapis.com/v1/projects/<projectId>/messages:send` 或使用 Legacy HTTP API
   - Authorization header 可使用 OAuth 2.0 存取權杖或 Server key
   - 範例 payload：
     ```json
     {
       "message": {
         "topic": "food-expiry",
         "notification": {
           "title": "雞胸肉即將過期",
           "body": "剩 2 天，記得優先烹調"
         },
         "data": {
           "type": "expiry",
           "foodId": "abc123"
         }
       }
     }
     ```

6. **裝置 Token 管理**
   - App 內的 `PushNotificationService` 會在登入後自動將 Token 儲存於 `users/{uid}/deviceTokens`
   - 登出時會清除對應 Token，避免舊用戶持續收到通知
   - 可依據 `deviceTokens` 子集合或 `latestFcmToken` 欄位進行個別推播

## ⏰ 本機到期提醒

1. App 啟動並登入後，`PushNotificationService` 會同步所有食材資料，在到期日前一日（預設 09:00）排程最多 10 則本機通知。
2. 若排程時間已過，系統會自動改為 1 分鐘後發出，以方便測試。
3. 測試方式：
   - 新增一筆到期日在未來 1～3 天內的食材
   - 等待 1 分鐘（或到達排程時間），就會看到系統通知「xxx 即將到期」
   - 登出或刪除該食材後，通知會被取消（可在系統設定的排程通知列表中確認）
4. 由於此提醒依賴本機排程，僅 Android / iOS / macOS 生效，Web 端會略過。
5. 若裝置所在區域非台灣，可在執行 `flutter run` 或建置時加上 `--dart-define=FOODMNGMT_TZ=<IANA Timezone>`（例如 `Asia/Tokyo`）以調整排程時區。

## 🚨 常見問題

1. **初始化錯誤**：檢查 firebase_options.dart 中的設定值
2. **權限錯誤**：確認 Firestore 安全規則設定正確
3. **網路錯誤**：確認網路連線和 Firebase 服務狀態
4. **建置錯誤**：執行 `flutter clean && flutter pub get`

## 📞 支援

如果遇到問題，請：
1. 檢查 Firebase Console 中的錯誤日誌
2. 查看 Flutter 應用程式的錯誤訊息
3. 確認網路連線正常
4. 檢查 Firebase 服務狀態
