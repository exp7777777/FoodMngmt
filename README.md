#  操作手冊

## 如何將專案Clone至個人設備

**步驟一：開啟 Android Studio 並登入個人 GitHub**
1. 開啟 Android Studio

2. 進入設定(`File` -> `Settings` or 右上角齒輪)

3. 找到GitHub(`Vertion Contorl` -> `GitHub` or 直接搜尋GitHub

4. 點擊 `+` ->  `Log In via GitHub`

5. 登入完成後，選取列表中會出現個人帳號，並打勾

**步驟二：進行專案clone**
1. 跳回至首頁(左上角選單 `File` -> `Close Project`)

2. 點選`Get from Version Control` or `Clone Repository`

3. 複製 `https://github.com/exp7777777/FoodMngmt.git` 至URL欄位中

4. `Directory`欄位中確認檔案名稱設為`FoodMngmt`

5. 完成Clone

# 實機測試
## iOS（macOS + Xcode）

1. 安裝環境
   - 安裝 Xcode（打開一次讓其安裝 Command Line Tools）
   - 安裝 CocoaPods（若未安裝）
     ```bash
     sudo gem install cocoapods
     ```
   - 於專案根目錄安裝相依：
     ```bash
     flutter clean
     flutter pub get
     cd ios && pod install && cd ..
     ```

2. 設定簽署（Signing）
   - 以 Xcode 開啟 `ios/Runner.xcworkspace`
   - 點選專案 Runner → TARGETS: Runner → Signing & Capabilities
     - Team：選擇你的 Apple ID 團隊
     - Bundle Identifier：改成唯一名稱（例：`com.yourname.foodmngmt`）
     - 勾選 Automatically manage signing

3. 連接 iPhone
   - USB 連接 iPhone，手機上「信任此電腦」
   - Xcode 左上角裝置選單選擇你的 iPhone
   - 首次部署：iPhone → 設定 → 一般 → 裝置管理 → 信任開發者

4. 執行
   - 在 Xcode 直接按 Run，或用命令：
     ```bash
     flutter run -d <your-device-id>
     ```

5. 常見設定
   - 權限（如相機）可於 `ios/Runner/Info.plist` 加入 `NSCameraUsageDescription` 等
   - Pods 問題可嘗試：
     ```bash
     cd ios && pod repo update && pod install && cd ..
     ```

6. 發佈測試（選用）
   - 透過 TestFlight 派送測試版（需要 Apple Developer 帳號與簽章設定）
