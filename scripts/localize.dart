import 'dart:io';

/// 自動將硬編碼中文替換為本地化字串的腳本
void main() {
  print('🚀 開始自動本地化替換...\n');
  
  // 定義需要替換的文件和對應的替換規則
  final files = [
    'lib/src/pages/personalization_page.dart',
    'lib/src/pages/navigation_config_page.dart',
    'lib/src/pages/other_features_page.dart',
  ];
  
  for (final filePath in files) {
    print('📝 處理文件: $filePath');
    localizeFile(filePath);
  }
  
  print('\n✅ 本地化替換完成！');
}

void localizeFile(String filePath) {
  final file = File(filePath);
  
  if (!file.existsSync()) {
    print('   ⚠️  文件不存在，跳過');
    return;
  }
  
  var content = file.readAsStringSync();
  int replacements = 0;
  
  // 檢查是否已經導入 AppLocalizations
  if (!content.contains("import '../l10n/app_localizations.dart';")) {
    // 在第一個 import 之後添加
    content = content.replaceFirst(
      RegExp(r"(import 'package:flutter/material.dart';)"),
      "\$1\nimport '../l10n/app_localizations.dart';",
    );
    replacements++;
  }
  
  // 檢查是否已經定義 l10n 變量
  if (!content.contains('final l10n = AppLocalizations.of(context);')) {
    // 在 build 方法開始處添加
    content = content.replaceAllMapped(
      RegExp(r'(@override\s+Widget build\(BuildContext context\)\s*\{)'),
      (match) => '${match.group(1)}\n    final l10n = AppLocalizations.of(context);',
    );
    replacements++;
  }
  
  // 定義替換映射表
  final replacementsMap = <String, String>{
    // 通用
    r"'確定'": "l10n.ok",
    r'"確定"': "l10n.ok",
    r"'取消'": "l10n.cancel",
    r'"取消"': "l10n.cancel",
    r"'儲存'": "l10n.save",
    r'"儲存"': "l10n.save",
    r"'關閉'": "l10n.close",
    r'"關閉"': "l10n.close",
    r"'新增'": "l10n.add",
    r'"新增"': "l10n.add",
    r"'移除'": "l10n.remove",
    r'"移除"': "l10n.remove",
    
    // 導航
    r"'課表'": "l10n.courseTable",
    r'"課表"': "l10n.courseTable",
    r"'日曆'": "l10n.calendar",
    r'"日曆"': "l10n.calendar",
    r"'課程查詢'": "l10n.courseSearch",
    r'"課程查詢"': "l10n.courseSearch",
    r"'成績'": "l10n.grades",
    r'"成績"': "l10n.grades",
    r"'校園地圖'": "l10n.campusMap",
    r'"校園地圖"': "l10n.campusMap",
    r"'空教室查詢'": "l10n.emptyClassroom",
    r'"空教室查詢"': "l10n.emptyClassroom",
    r"'社團公告'": "l10n.clubAnnouncements",
    r'"社團公告"': "l10n.clubAnnouncements",
    r"'個人化'": "l10n.personalization",
    r'"個人化"': "l10n.personalization",
    r"'校務系統'": "l10n.adminSystem",
    r'"校務系統"': "l10n.adminSystem",
    r"'訊息'": "l10n.messages",
    r'"訊息"': "l10n.messages",
    r"'北科i學院'": "l10n.ntutLearn",
    r'"北科i學院"': "l10n.ntutLearn",
    r"'美食地圖'": "l10n.foodMap",
    r'"美食地圖"': "l10n.foodMap",
    r"'其他'": "l10n.other",
    r'"其他"': "l10n.other",
    
    // 個人化
    r"'配色設定'": "l10n.themeSettings",
    r'"配色設定"': "l10n.themeSettings",
    r"'主題模式'": "l10n.themeMode",
    r'"主題模式"': "l10n.themeMode",
    r"'語言'": "l10n.language",
    r'"語言"': "l10n.language",
    r"'跟隨系統'": "l10n.followSystem",
    r'"跟隨系統"': "l10n.followSystem",
    r"'淺色模式'": "l10n.lightMode",
    r'"淺色模式"': "l10n.lightMode",
    r"'深色模式'": "l10n.darkMode",
    r'"深色模式"': "l10n.darkMode",
    r"'課程設定'": "l10n.courseSettings",
    r'"課程設定"': "l10n.courseSettings",
    r"'課程顏色'": "l10n.courseColor",
    r'"課程顏色"': "l10n.courseColor",
    r"'長按課表中的課程即可自訂顏色'": "l10n.courseColorHint",
    r'"長按課表中的課程即可自訂顏色"': "l10n.courseColorHint",
    
    // 設定
    r"'設定'": "l10n.settings",
    r'"設定"': "l10n.settings",
    r"'自訂導航欄'": "l10n.customNavBar",
    r'"自訂導航欄"': "l10n.customNavBar",
    r"'選擇常用功能顯示在導航欄'": "l10n.customNavBarHint",
    r'"選擇常用功能顯示在導航欄"': "l10n.customNavBarHint",
    r"'關於我們'": "l10n.about",
    r'"關於我們"': "l10n.about",
    r"'應用程式資訊與版本'": "l10n.aboutHint",
    r'"應用程式資訊與版本"': "l10n.aboutHint",
    r"'登出'": "l10n.logout",
    r'"登出"': "l10n.logout",
    r"'確定要登出嗎？'": "l10n.logoutConfirm",
    r'"確定要登出嗎？"': "l10n.logoutConfirm",
    r"'確認登出'": "'確認登出'", // 保持不變
    
    // 導航配置
    r"'導航列設定'": "l10n.navConfigTitle",
    r'"導航列設定"': "l10n.navConfigTitle",
    r"'自訂底部導航列'": "l10n.customNavBarTitle",
    r'"自訂底部導航列"': "l10n.customNavBarTitle",
    r"'點擊項目更換功能，長按可拖曳排序'": "l10n.customNavBarDesc",
    r'"點擊項目更換功能，長按可拖曳排序"': "l10n.customNavBarDesc",
    r"'已選擇'": "l10n.selectedCount",
    r'"已選擇"': "l10n.selectedCount",
    r"'重設為預設'": "l10n.resetToDefault",
    r'"重設為預設"': "l10n.resetToDefault",
    r"'選擇功能'": "l10n.selectFunction",
    r'"選擇功能"': "l10n.selectFunction",
    r"'選擇要新增的功能'": "l10n.addFunction",
    r'"選擇要新增的功能"': "l10n.addFunction",
    r"'未儲存的變更'": "l10n.unsavedChanges",
    r'"未儲存的變更"': "l10n.unsavedChanges",
    r"'您有未儲存的設定，確定要離開嗎？'": "l10n.unsavedChangesDesc",
    r'"您有未儲存的設定，確定要離開嗎？"': "l10n.unsavedChangesDesc",
    r"'離開'": "l10n.leave",
    r'"離開"': "l10n.leave",
    r"'設定已儲存，重啟 App 後生效'": "l10n.settingsSaved",
    r'"設定已儲存，重啟 App 後生效"': "l10n.settingsSaved",
    
    // 主題對話框
    r"'選擇主題模式'": "l10n.selectThemeMode",
    r'"選擇主題模式"': "l10n.selectThemeMode",
    r"'自動切換淺色/深色模式'": "l10n.followSystemDesc",
    r'"自動切換淺色/深色模式"': "l10n.followSystemDesc",
    r"'使用淺色背景主題'": "l10n.lightModeDesc",
    r'"使用淺色背景主題"': "l10n.lightModeDesc",
    r"'使用深色背景主題'": "l10n.darkModeDesc",
    r'"使用深色背景主題"': "l10n.darkModeDesc",
    
    // 語言對話框
    r"'選擇語言'": "l10n.selectLanguage",
    r'"選擇語言"': "l10n.selectLanguage",
    r"'使用系統預設語言'": "l10n.followSystemLang",
    r'"使用系統預設語言"': "l10n.followSystemLang",
    r"'繁體中文'": "l10n.traditionalChinese",
    r'"繁體中文"': "l10n.traditionalChinese",
    r"'系統'": "'系統'", // 保持不變
  };
  
  // 執行替換
  for (final entry in replacementsMap.entries) {
    final pattern = entry.key;
    final replacement = entry.value;
    
    // 只替換 Text() 和 SnackBar 中的字串
    final contexts = [
      r'Text\(',
      r'title:\s*',
      r'subtitle:\s*',
      r'label:\s*',
      r'content:\s*',
    ];
    
    for (final ctx in contexts) {
      final regex = RegExp('($ctx)${RegExp.escape(pattern)}');
      if (content.contains(regex)) {
        content = content.replaceAll(regex, '\$1$replacement');
        replacements++;
      }
    }
  }
  
  // 處理 const Text -> Text
  content = content.replaceAll(RegExp(r'const Text\(l10n\.'), 'Text(l10n.');
  
  // 寫回文件
  file.writeAsStringSync(content);
  print('   ✅ 完成 $replacements 處替換');
}
