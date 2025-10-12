import 'package:flutter/material.dart';

class AppLocalizations {
  final Locale locale;

  AppLocalizations(this.locale);

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  // 頁面標題
  String get calendarTitle =>
      locale.languageCode == 'en' ? 'Expiry Calendar' : '到期日曆';
  String get settingsTitle => locale.languageCode == 'en' ? 'Settings' : '設定';
  String get shoppingListTitle =>
      locale.languageCode == 'en' ? 'Shopping List' : '購物清單';
  String get foodManagerTitle =>
      locale.languageCode == 'en' ? 'Food Management' : '食材管理';
  String get accountSettingsTitle =>
      locale.languageCode == 'en' ? 'Account Settings' : '帳號設定';

  // 導航標籤
  String get listTab => locale.languageCode == 'en' ? 'List' : '清單';
  String get calendarTab => locale.languageCode == 'en' ? 'Calendar' : '日曆';
  String get shoppingTab => locale.languageCode == 'en' ? 'Shopping' : '購物車';
  String get settingsTab => locale.languageCode == 'en' ? 'Settings' : '設定';

  // 設定頁面
  String get accountSettings =>
      locale.languageCode == 'en' ? 'Account Settings' : '帳號設定';
  String get themeSettings =>
      locale.languageCode == 'en' ? 'Theme Settings' : '主題設定';
  String get languageSettings =>
      locale.languageCode == 'en' ? 'Language Settings' : '語言設定';
  String get selectTheme =>
      locale.languageCode == 'en' ? 'Select Theme' : '選擇主題';
  String get selectLanguage =>
      locale.languageCode == 'en' ? 'Select Language' : '選擇語言';
  String get invoiceCarrierSettings =>
      locale.languageCode == 'en' ? 'Invoice Carrier Settings' : '發票載具設定';
  String get bindCarrier =>
      locale.languageCode == 'en' ? 'Bind Carrier' : '綁定載具';
  String get unbindCarrier =>
      locale.languageCode == 'en' ? 'Unbind Carrier' : '解除綁定';
  String get syncInvoices =>
      locale.languageCode == 'en' ? 'Sync Invoices' : '同步發票';
  String get noCarriersBound =>
      locale.languageCode == 'en' ? 'No carriers bound' : '尚未綁定載具';
  String get carrierBound =>
      locale.languageCode == 'en' ? 'Carrier Bound' : '載具已綁定';
  String get enterCarrierId =>
      locale.languageCode == 'en' ? 'Enter Carrier ID' : '輸入載具號碼';
  String get carrierId => locale.languageCode == 'en' ? 'Carrier ID' : '載具號碼';
  String get carrierType =>
      locale.languageCode == 'en' ? 'Carrier Type' : '載具類型';
  String get mobileCarrier =>
      locale.languageCode == 'en' ? 'Mobile Carrier' : '手機載具';
  String get cardCarrier =>
      locale.languageCode == 'en' ? 'Card Carrier' : '卡片載具';
  String get lightTheme => locale.languageCode == 'en' ? 'Light Theme' : '淺色主題';
  String get darkTheme => locale.languageCode == 'en' ? 'Dark Theme' : '深色主題';
  String get systemTheme =>
      locale.languageCode == 'en' ? 'Follow System' : '跟隨系統';
  String get traditionalChinese =>
      locale.languageCode == 'en' ? 'Traditional Chinese' : '繁體中文';
  String get english => locale.languageCode == 'en' ? 'English' : 'English';

  // 日曆頁面
  String get expiryDate =>
      locale.languageCode == 'en' ? 'Expiry Date: ' : '到期日：';

  // 購物清單頁面
  String get itemName => locale.languageCode == 'en' ? 'Item Name' : '項目名稱';
  String get quantityUnit =>
      locale.languageCode == 'en' ? 'Quantity/Unit' : '數量/單位';
  String get add => locale.languageCode == 'en' ? 'Add' : '新增';
  String get noItems => locale.languageCode == 'en' ? 'No items' : '尚無項目';
  String get locationReminders =>
      locale.languageCode == 'en' ? 'Location Reminders' : '位置提醒';
  String get nearbyStores =>
      locale.languageCode == 'en' ? 'Nearby Stores' : '附近商店';
  String get getLocation =>
      locale.languageCode == 'en' ? 'Get Location' : '獲取位置';
  String get locationPermissionDenied =>
      locale.languageCode == 'en' ? 'Location permission denied' : '位置權限被拒絕';
  String get locationServiceDisabled =>
      locale.languageCode == 'en' ? 'Location service disabled' : '位置服務已停用';
  String get tapToViewStores =>
      locale.languageCode == 'en' ? 'Tap to view nearby stores' : '點擊查看附近商店';
  String get storeType => locale.languageCode == 'en' ? 'Store Type' : '商店類型';
  String get distance => locale.languageCode == 'en' ? 'Distance' : '距離';

  // 食材管理頁面
  String get searchName => locale.languageCode == 'en' ? 'Search Name' : '搜尋名稱';
  String get expiringIn3Days =>
      locale.languageCode == 'en' ? 'Expiring in 3 days' : '3日內到期';
  String get remainingDays => locale.languageCode == 'en' ? 'days left' : '剩餘天';
  String get expiredDays =>
      locale.languageCode == 'en' ? 'days expired' : '已過期天';
  String get deleteConfirm =>
      locale.languageCode == 'en' ? 'Delete Confirmation' : '刪除確認';
  String get deleteItem => locale.languageCode == 'en' ? 'Delete' : '刪除';
  String get cancel => locale.languageCode == 'en' ? 'Cancel' : '取消';
  String get aiMenuRecommendation =>
      locale.languageCode == 'en' ? 'Leftovers Recipe' : '剩食譜';
  String get confirmDelete =>
      locale.languageCode == 'en' ? 'Confirm delete' : '確定刪除';

  // 食材表單頁面
  String get editFood => locale.languageCode == 'en' ? 'Edit Food' : '編輯食材';
  String get addFood => locale.languageCode == 'en' ? 'Add Food' : '新增食材';
  String get selectImage =>
      locale.languageCode == 'en' ? 'Select Image' : '選擇圖片';
  String get name => locale.languageCode == 'en' ? 'Name' : '名稱';
  String get pleaseEnterName =>
      locale.languageCode == 'en' ? 'Please enter name' : '請輸入名稱';
  String get quantity => locale.languageCode == 'en' ? 'Quantity' : '數量';
  String get pleaseEnterNumber =>
      locale.languageCode == 'en' ? 'Please enter number' : '請輸入數字';
  String get unit =>
      locale.languageCode == 'en' ? 'Unit (piece/g/ml)' : '單位 (件/g/ml)';
  String get category => locale.languageCode == 'en' ? 'Category' : '分類';
  String get expiryDateLabel =>
      locale.languageCode == 'en' ? 'Expiry Date' : '到期日';

  // 食物分類選項
  String get categoryDairy => locale.languageCode == 'en' ? 'Dairy' : '乳製品';
  String get categoryDessert => locale.languageCode == 'en' ? 'Dessert' : '甜點';
  String get categoryFruit => locale.languageCode == 'en' ? 'Fruit' : '水果';
  String get categoryStaple => locale.languageCode == 'en' ? 'Staple' : '主食';
  String get categoryBeverage =>
      locale.languageCode == 'en' ? 'Beverage' : '飲料';
  String get categoryOther => locale.languageCode == 'en' ? 'Other' : '其他';
  String get note => locale.languageCode == 'en' ? 'Note' : '備註';
  String get saveChanges =>
      locale.languageCode == 'en' ? 'Save Changes' : '儲存變更';
  String get addNew => locale.languageCode == 'en' ? 'Add' : '新增';
  String get piece => locale.languageCode == 'en' ? 'piece' : '件';

  // 剩食譜頁面
  String get aiMenuTitle =>
      locale.languageCode == 'en' ? 'Leftovers Recipe' : '剩食譜';
  String get allIngredients =>
      locale.languageCode == 'en' ? 'All ingredients available' : '材料齊全';
  String get missingItems =>
      locale.languageCode == 'en' ? 'missing items' : '缺少項';
  String get steps => locale.languageCode == 'en' ? 'Steps:' : '步驟：';
  String get requiredIngredients =>
      locale.languageCode == 'en' ? 'Required ingredients:' : '所需材料：';
  String get missingIngredients =>
      locale.languageCode == 'en' ? 'Missing ingredients:' : '缺少材料：';
  String get addedToShoppingList =>
      locale.languageCode == 'en' ? 'Added to shopping list' : '已加入項目到購物清單';
  String get addMissingToShoppingList =>
      locale.languageCode == 'en' ? 'Add missing to shopping list' : '缺料加入購物清單';

  // 底部操作選單
  String get manualEntry =>
      locale.languageCode == 'en' ? 'Manual Entry' : '手動登錄';
  String get voiceEntry => locale.languageCode == 'en' ? 'Voice Entry' : '語音登錄';
  String get scan => locale.languageCode == 'en' ? 'Identify' : '辨識';
  String get recognitionFailed =>
      locale.languageCode == 'en' ? 'Recognition failed:' : '辨識失敗：';

  // 帳號設定頁面
  String get nickname => locale.languageCode == 'en' ? 'Nickname' : '暱稱';
  String get enterNickname =>
      locale.languageCode == 'en' ? 'Enter nickname' : '輸入暱稱';
  String get pleaseEnterNickname =>
      locale.languageCode == 'en' ? 'Please enter nickname' : '請輸入暱稱';
  String get account => locale.languageCode == 'en' ? 'Account' : '帳號';
  String get accountPhone =>
      locale.languageCode == 'en' ? 'Account/Phone' : '帳號/手機號碼';
  String get pleaseEnterAccount =>
      locale.languageCode == 'en' ? 'Please enter account' : '請輸入帳號';
  String get changePassword =>
      locale.languageCode == 'en' ? 'Change Password' : '修改密碼';
  String get newPassword =>
      locale.languageCode == 'en'
          ? 'New password (leave empty to keep unchanged)'
          : '新密碼（留空則不變）';
  String get passwordRequirement =>
      locale.languageCode == 'en'
          ? '6-12 characters with letters and numbers'
          : '需 6~12 含英數';
  String get confirmPassword =>
      locale.languageCode == 'en' ? 'Confirm Password' : '確認密碼';
  String get passwordMismatch =>
      locale.languageCode == 'en' ? 'Password mismatch' : '密碼不一致';
  String get accountUpdated =>
      locale.languageCode == 'en' ? 'Account updated' : '已更新帳號資料';
  String get update => locale.languageCode == 'en' ? 'Update' : '更新';

  // 首頁
  String get today => locale.languageCode == 'en' ? 'Today' : '今天';
  String get days => locale.languageCode == 'en' ? 'days' : '天';
  String get expired => locale.languageCode == 'en' ? 'expired' : '已過期';
}

class AppLocalizationsDelegate extends LocalizationsDelegate<AppLocalizations> {
  const AppLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) {
    return ['en', 'zh'].contains(locale.languageCode);
  }

  @override
  Future<AppLocalizations> load(Locale locale) async {
    return AppLocalizations(locale);
  }

  @override
  bool shouldReload(AppLocalizationsDelegate old) => false;
}
