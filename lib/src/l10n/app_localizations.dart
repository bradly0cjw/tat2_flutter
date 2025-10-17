import 'package:flutter/material.dart';

/// 應用程式本地化
class AppLocalizations {
  final Locale locale;

  AppLocalizations(this.locale);

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate = _AppLocalizationsDelegate();

  // 通用
  String get appName => _localizedValues[locale.languageCode]?['appName'] ?? 'QAQ 北科生活';
  String get ok => _localizedValues[locale.languageCode]?['ok'] ?? '確定';
  String get cancel => _localizedValues[locale.languageCode]?['cancel'] ?? '取消';
  String get save => _localizedValues[locale.languageCode]?['save'] ?? '儲存';
  String get delete => _localizedValues[locale.languageCode]?['delete'] ?? '刪除';
  String get edit => _localizedValues[locale.languageCode]?['edit'] ?? '編輯';
  String get close => _localizedValues[locale.languageCode]?['close'] ?? '關閉';
  String get search => _localizedValues[locale.languageCode]?['search'] ?? '搜尋';
  String get add => _localizedValues[locale.languageCode]?['add'] ?? '新增';
  String get remove => _localizedValues[locale.languageCode]?['remove'] ?? '移除';
  String get loading => _localizedValues[locale.languageCode]?['loading'] ?? '載入中...';
  String get error => _localizedValues[locale.languageCode]?['error'] ?? '錯誤';
  String get success => _localizedValues[locale.languageCode]?['success'] ?? '成功';
  String get confirm => _localizedValues[locale.languageCode]?['confirm'] ?? '確認';
  
  // 導航
  String get courseTable => _localizedValues[locale.languageCode]?['courseTable'] ?? '課表';
  String get calendar => _localizedValues[locale.languageCode]?['calendar'] ?? '日曆';
  String get courseSearch => _localizedValues[locale.languageCode]?['courseSearch'] ?? '課程查詢';
  String get grades => _localizedValues[locale.languageCode]?['grades'] ?? '成績';
  String get credits => _localizedValues[locale.languageCode]?['credits'] ?? '學分';
  String get campusMap => _localizedValues[locale.languageCode]?['campusMap'] ?? '校園地圖';
  String get emptyClassroom => _localizedValues[locale.languageCode]?['emptyClassroom'] ?? '空教室查詢';
  String get clubAnnouncements => _localizedValues[locale.languageCode]?['clubAnnouncements'] ?? '社團公告';
  String get personalization => _localizedValues[locale.languageCode]?['personalization'] ?? '個人化';
  String get adminSystem => _localizedValues[locale.languageCode]?['adminSystem'] ?? '校務系統';
  String get messages => _localizedValues[locale.languageCode]?['messages'] ?? '訊息';
  String get ntutLearn => _localizedValues[locale.languageCode]?['ntutLearn'] ?? '北科i學園';
  String get foodMap => _localizedValues[locale.languageCode]?['foodMap'] ?? '美食地圖';
  String get other => _localizedValues[locale.languageCode]?['other'] ?? '其他';
  
  // 個人化
  String get themeSettings => _localizedValues[locale.languageCode]?['themeSettings'] ?? '配色設定';
  String get themeMode => _localizedValues[locale.languageCode]?['themeMode'] ?? '主題模式';
  String get language => _localizedValues[locale.languageCode]?['language'] ?? '語言';
  String get followSystem => _localizedValues[locale.languageCode]?['followSystem'] ?? '跟隨系統';
  String get lightMode => _localizedValues[locale.languageCode]?['lightMode'] ?? '淺色模式';
  String get darkMode => _localizedValues[locale.languageCode]?['darkMode'] ?? '深色模式';
  String get courseSettings => _localizedValues[locale.languageCode]?['courseSettings'] ?? '課程設定';
  String get courseColor => _localizedValues[locale.languageCode]?['courseColor'] ?? '課程顏色';
  String get courseColorHint => _localizedValues[locale.languageCode]?['courseColorHint'] ?? '長按課表中的課程即可自訂顏色';
  
  // 設定
  String get settings => _localizedValues[locale.languageCode]?['settings'] ?? '設定';
  String get customNavBar => _localizedValues[locale.languageCode]?['customNavBar'] ?? '自訂導航欄';
  String get customNavBarHint => _localizedValues[locale.languageCode]?['customNavBarHint'] ?? '選擇常用功能顯示在導航欄';
  String get about => _localizedValues[locale.languageCode]?['about'] ?? '關於我們';
  String get aboutHint => _localizedValues[locale.languageCode]?['aboutHint'] ?? '應用程式資訊與版本';
  String get feedback => _localizedValues[locale.languageCode]?['feedback'] ?? '意見反饋';
  String get feedbackHint => _localizedValues[locale.languageCode]?['feedbackHint'] ?? '提供建議或回報問題';
  String get relogin => _localizedValues[locale.languageCode]?['relogin'] ?? '重新登入';
  String get reloginHint => _localizedValues[locale.languageCode]?['reloginHint'] ?? '重新登入學校帳號';
  String get reloginConfirm => _localizedValues[locale.languageCode]?['reloginConfirm'] ?? '將清除當前登入狀態並跳轉到登入頁面';
  String get logout => _localizedValues[locale.languageCode]?['logout'] ?? '登出';
  String get logoutConfirm => _localizedValues[locale.languageCode]?['logoutConfirm'] ?? '確定要登出嗎？';
  
  // 導航配置
  String get navConfigTitle => _localizedValues[locale.languageCode]?['navConfigTitle'] ?? '導航列設定';
  String get customNavBarTitle => _localizedValues[locale.languageCode]?['customNavBarTitle'] ?? '自訂底部導航列';
  String get customNavBarDesc => _localizedValues[locale.languageCode]?['customNavBarDesc'] ?? '點擊項目更換功能，長按可拖曳排序';
  String get selectedCount => _localizedValues[locale.languageCode]?['selectedCount'] ?? '已選擇';
  String get resetToDefault => _localizedValues[locale.languageCode]?['resetToDefault'] ?? '重設為預設';
  String get selectFunction => _localizedValues[locale.languageCode]?['selectFunction'] ?? '選擇功能';
  String get addFunction => _localizedValues[locale.languageCode]?['addFunction'] ?? '選擇要新增的功能';
  String get unsavedChanges => _localizedValues[locale.languageCode]?['unsavedChanges'] ?? '未儲存的變更';
  String get unsavedChangesDesc => _localizedValues[locale.languageCode]?['unsavedChangesDesc'] ?? '您有未儲存的設定，確定要離開嗎？';
  String get leave => _localizedValues[locale.languageCode]?['leave'] ?? '離開';
  String get settingsSaved => _localizedValues[locale.languageCode]?['settingsSaved'] ?? '設定已儲存，重啟 App 後生效';
  
  // 主題對話框
  String get selectThemeMode => _localizedValues[locale.languageCode]?['selectThemeMode'] ?? '選擇主題模式';
  String get followSystemDesc => _localizedValues[locale.languageCode]?['followSystemDesc'] ?? '自動切換淺色/深色模式';
  String get lightModeDesc => _localizedValues[locale.languageCode]?['lightModeDesc'] ?? '使用淺色背景主題';
  String get darkModeDesc => _localizedValues[locale.languageCode]?['darkModeDesc'] ?? '使用深色背景主題';
  
  // 語言對話框
  String get selectLanguage => _localizedValues[locale.languageCode]?['selectLanguage'] ?? '選擇語言';
  String get followSystemLang => _localizedValues[locale.languageCode]?['followSystemLang'] ?? '使用系統預設語言';
  String get traditionalChinese => _localizedValues[locale.languageCode]?['traditionalChinese'] ?? '繁體中文';
  String get english => _localizedValues[locale.languageCode]?['english'] ?? 'English';
  
  // 其他常用文字
  String get system => _localizedValues[locale.languageCode]?['system'] ?? '系統';
  String get otherFeatures => _localizedValues[locale.languageCode]?['otherFeatures'] ?? '更多功能';
  String get confirmLogout => _localizedValues[locale.languageCode]?['confirmLogout'] ?? '確認登出';
  String get maxNavItems => _localizedValues[locale.languageCode]?['maxNavItems'] ?? '最多只能設定 5 個導航項目';
  String get noMoreFunctions => _localizedValues[locale.languageCode]?['noMoreFunctions'] ?? '沒有更多功能可以新增';
  String get minOneNavItem => _localizedValues[locale.languageCode]?['minOneNavItem'] ?? '至少需要保留一個導航項目';
  String get hint => _localizedValues[locale.languageCode]?['hint'] ?? '提示';

  // 本地化資料
  static const Map<String, Map<String, String>> _localizedValues = {
    'zh': {
      'appName': 'QAQ 北科生活',
      'ok': '確定',
      'cancel': '取消',
      'save': '儲存',
      'delete': '刪除',
      'edit': '編輯',
      'close': '關閉',
      'search': '搜尋',
      'add': '新增',
      'remove': '移除',
      'loading': '載入中...',
      'error': '錯誤',
      'success': '成功',
      'confirm': '確認',
      
      // 導航
      'courseTable': '課表',
      'calendar': '日曆',
      'courseSearch': '課程查詢',
      'grades': '成績',
      'credits': '學分',
      'campusMap': '校園地圖',
      'emptyClassroom': '空教室查詢',
      'clubAnnouncements': '社團公告',
      'personalization': '個人化',
      'adminSystem': '校務系統',
      'messages': '訊息',
      'ntutLearn': '北科i學園',
      'foodMap': '美食地圖',
      'other': '其他',
      
      // 個人化
      'themeSettings': '配色設定',
      'themeMode': '主題模式',
      'language': '語言',
      'followSystem': '跟隨系統',
      'lightMode': '淺色模式',
      'darkMode': '深色模式',
      'courseSettings': '課程設定',
      'courseColor': '課程顏色',
      'courseColorHint': '長按課表中的課程即可自訂顏色',
      
      // 設定
      'settings': '設定',
      'customNavBar': '自訂導航欄',
      'customNavBarHint': '選擇常用功能顯示在導航欄',
      'about': '關於我們',
      'aboutHint': '應用程式資訊與版本',
      'feedback': '意見反饋',
      'feedbackHint': '提供建議或回報問題',
      'relogin': '重新登入',
      'reloginHint': '重新登入學校帳號',
      'reloginConfirm': '將清除當前登入狀態並跳轉到登入頁面',
      'logout': '登出',
      'logoutConfirm': '確定要登出嗎？',
      
      // 導航配置
      'navConfigTitle': '導航列設定',
      'customNavBarTitle': '自訂底部導航列',
      'customNavBarDesc': '點擊項目更換功能，長按可拖曳排序',
      'selectedCount': '已選擇',
      'resetToDefault': '重設為預設',
      'selectFunction': '選擇功能',
      'addFunction': '選擇要新增的功能',
      'unsavedChanges': '未儲存的變更',
      'unsavedChangesDesc': '您有未儲存的設定，確定要離開嗎？',
      'leave': '離開',
      'settingsSaved': '設定已儲存，重啟 App 後生效',
      
      // 主題對話框
      'selectThemeMode': '選擇主題模式',
      'followSystemDesc': '自動切換淺色/深色模式',
      'lightModeDesc': '使用淺色背景主題',
      'darkModeDesc': '使用深色背景主題',
      
      // 語言對話框
      'selectLanguage': '選擇語言',
      'followSystemLang': '使用系統預設語言',
      'traditionalChinese': '繁體中文',
      'english': 'English',
      
      // 其他
      'system': '系統',
      'otherFeatures': '更多功能',
      'confirmLogout': '確認登出',
      'maxNavItems': '最多只能設定 5 個導航項目',
      'noMoreFunctions': '沒有更多功能可以新增',
      'minOneNavItem': '至少需要保留一個導航項目',
      'hint': '提示',
    },
    'en': {
      'appName': 'QAQ NTUT Life',
      'ok': 'OK',
      'cancel': 'Cancel',
      'save': 'Save',
      'delete': 'Delete',
      'edit': 'Edit',
      'close': 'Close',
      'search': 'Search',
      'add': 'Add',
      'remove': 'Remove',
      'loading': 'Loading...',
      'error': 'Error',
      'success': 'Success',
      'confirm': 'Confirm',
      
      // Navigation
      'courseTable': 'Course Table',
      'calendar': 'Calendar',
      'courseSearch': 'Course Search',
      'grades': 'Grades',
      'credits': 'Credits',
      'campusMap': 'Campus Map',
      'emptyClassroom': 'Empty Classroom',
      'clubAnnouncements': 'Club Announcements',
      'personalization': 'Personalization',
      'adminSystem': 'Admin System',
      'messages': 'Messages',
      'ntutLearn': 'NTUT i-Learn',
      'foodMap': 'Food Map',
      'other': 'Other',
      
      // Personalization
      'themeSettings': 'Theme Settings',
      'themeMode': 'Theme Mode',
      'language': 'Language',
      'followSystem': 'Follow System',
      'lightMode': 'Light Mode',
      'darkMode': 'Dark Mode',
      'courseSettings': 'Course Settings',
      'courseColor': 'Course Color',
      'courseColorHint': 'Long press on course to customize color',
      
      // Settings
      'settings': 'Settings',
      'customNavBar': 'Custom Navigation Bar',
      'customNavBarHint': 'Select frequently used functions for navigation bar',
      'about': 'About',
      'aboutHint': 'App information and version',
      'feedback': 'Feedback',
      'feedbackHint': 'Provide suggestions or report issues',
      'relogin': 'Re-login',
      'reloginHint': 'Re-login to school account',
      'reloginConfirm': 'This will clear the current login status and redirect to login page',
      'logout': 'Logout',
      'logoutConfirm': 'Are you sure you want to logout?',
      
      // Navigation Config
      'navConfigTitle': 'Navigation Settings',
      'customNavBarTitle': 'Custom Bottom Navigation',
      'customNavBarDesc': 'Tap to change function, long press to reorder',
      'selectedCount': 'Selected',
      'resetToDefault': 'Reset to Default',
      'selectFunction': 'Select Function',
      'addFunction': 'Select Function to Add',
      'unsavedChanges': 'Unsaved Changes',
      'unsavedChangesDesc': 'You have unsaved settings. Are you sure you want to leave?',
      'leave': 'Leave',
      'settingsSaved': 'Settings saved, restart app to take effect',
      
      // Theme Dialog
      'selectThemeMode': 'Select Theme Mode',
      'followSystemDesc': 'Auto switch light/dark mode',
      'lightModeDesc': 'Use light background theme',
      'darkModeDesc': 'Use dark background theme',
      
      // Language Dialog
      'selectLanguage': 'Select Language',
      'followSystemLang': 'Use system default language',
      'traditionalChinese': '繁體中文',
      'english': 'English',
      
      // Other
      'system': 'System',
      'otherFeatures': 'More Features',
      'confirmLogout': 'Confirm Logout',
      'maxNavItems': 'Maximum 5 navigation items',
      'noMoreFunctions': 'No more functions to add',
      'minOneNavItem': 'At least one navigation item required',
      'hint': 'Hint',
    },
  };
}

class _AppLocalizationsDelegate extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) {
    return ['zh', 'en'].contains(locale.languageCode);
  }

  @override
  Future<AppLocalizations> load(Locale locale) async {
    return AppLocalizations(locale);
  }

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}
