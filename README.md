🔧 用 Android Studio 綁定 GitHub 帳號（HTTPS 版）

✅ 步驟一：開啟 Android Studio 的 GitHub 登入設定
開啟 Android Studio

點選上方選單：
File → Settings（mac 是 Android Studio → Preferences）

找到左側選單：
Version Control → GitHub

✅ 步驟二：登入 GitHub 帳號
點擊右側的 + 按鈕，選擇 Log in via GitHub

系統會跳出一個 GitHub 登入畫面，輸入你的帳號密碼

第一次登入時，GitHub 會問你是否授權 Android Studio
✅ 點選授權（Authorize）

登入成功後，你會看到帳號出現在清單中

✅ 步驟三：檢查 Git 設定（可選）
在 Settings → Version Control → Git

確保 Path to Git executable 是有效的 Git 安裝路徑
（例如 Windows 通常是 C:\Program Files\Git\bin\git.exe）

✅ 步驟四：Clone 專案
點選 Android Studio → File → New → Project from Version Control

選擇 Git

貼上專案的 HTTPS 位址，例如：

arduino
複製
編輯
https://github.com/Wujiaxun92/FoodMngmt.git
選擇儲存資料夾，點擊「Clone」

✅ 步驟五：Push 專案（以後都不需輸入帳密）
只要你登入過 GitHub 且專案有設好 remote，接下來就可以直接使用：

bash
複製
編輯
git add .
git commit -m "修改功能"
git push
Android Studio 會自動幫你處理 Token 的部分，不需再次輸入帳密或 PAT！
