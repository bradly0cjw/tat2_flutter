import 'dart:io';

/// 批量替換硬編碼中文為 i18n
void main() {
  print('🌐 開始批量替換硬編碼中文...\n');
  
  // navigation_config_page
  print('📝 處理 navigation_config_page.dart');
  _fixNavigationConfigPage();
  
  // home_page
  print('📝 處理 home_page.dart');
  _fixHomePage();
  
  print('\n✅ 批量替換完成！');
}

void _fixNavigationConfigPage() {
  final file = File('lib/src/pages/navigation_config_page.dart');
  var content = file.readAsStringSync();
  
  // 替換錯誤訊息
  content = content.replaceAll(
    "const SnackBar(content: Text('最多只能設定 5 個導航項目'))",
    "SnackBar(content: Text(l10n.maxNavItems))"
  );
  
  content = content.replaceAll(
    "const SnackBar(content: Text('沒有更多功能可以新增'))",
    "SnackBar(content: Text(l10n.noMoreFunctions))"
  );
  
  content = content.replaceAll(
    "const SnackBar(content: Text('至少需要保留一個導航項目'))",
    "SnackBar(content: Text(l10n.minOneNavItem))"
  );
  
  // 替換 tooltips
  content = content.replaceAll(
    "tooltip: '重設為預設'",
    "tooltip: l10n.resetToDefault"
  );
  
  content = content.replaceAll(
    "tooltip: '儲存'",
    "tooltip: l10n.save"
  );
  
  content = content.replaceAll(
    "tooltip: '移除'",
    "tooltip: l10n.remove"
  );
  
  // 替換標題文字
  content = content.replaceAll(
    "'自訂底部導航列'",
    "l10n.customNavBarTitle"
  );
  
  content = content.replaceAll(
    "const Text('其他功能')",
    "Text(l10n.otherFeatures)"
  );
  
  content = content.replaceAll(
    "'提示'",
    "l10n.hint"
  );
  
  file.writeAsStringSync(content);
  print('   ✅ 完成');
}

void _fixHomePage() {
  final file = File('lib/src/pages/home_page.dart');
  var content = file.readAsStringSync();
  
  // 替換 "其他" 標籤
  content = content.replaceAll(
    "label: '其他'",
    "label: l10n.other"
  );
  
  file.writeAsStringSync(content);
  print('   ✅ 完成');
}
