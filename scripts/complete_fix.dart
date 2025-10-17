import 'dart:io';

/// 完整修復所有本地化錯誤
void main() {
  print('🔧 開始完整修復...\n');
  
  final files = {
    'lib/src/pages/personalization_page.dart': _fixPersonalizationPage,
    'lib/src/pages/navigation_config_page.dart': _fixNavigationConfigPage,
    'lib/src/pages/other_features_page.dart': _fixOtherFeaturesPage,
  };
  
  for (final entry in files.entries) {
    print('📝 修復文件: ${entry.key}');
    entry.value(entry.key);
  }
  
  print('\n✅ 完整修復完成！');
}

void _fixPersonalizationPage(String filePath) {
  final file = File(filePath);
  if (!file.existsSync()) {
    print('   ⚠️  文件不存在');
    return;
  }
  
  var content = file.readAsStringSync();
  int fixes = 0;
  
  // 修復所有獨立的 l10n 引用（需要在方法內添加 AppLocalizations.of(context)）
  // 在 _showThemeModeDialog 和 _showLanguageDialog 方法的開頭添加 l10n
  content = content.replaceAllMapped(
    RegExp(r'void (_show\w+Dialog\(BuildContext context[^)]*\)) \{'),
    (match) {
      fixes++;
      return 'void ${match.group(1)} {\n    final l10n = AppLocalizations.of(context);';
    },
  );
  
  file.writeAsStringSync(content);
  print('   ✅ 完成 $fixes 處修復');
}

void _fixNavigationConfigPage(String filePath) {
  // 已經在之前修復過了
  print('   ✅ 已修復');
}

void _fixOtherFeaturesPage(String filePath) {
  final file = File(filePath);
  if (!file.existsSync()) {
    print('   ⚠️  文件不存在');
    return;
  }
  
  var content = file.readAsStringSync();
  int fixes = 0;
  
  // 修復 const ListTile 中的 l10n
  content = content.replaceAll(
    'const ListTile(\n            leading: Icon(Icons.info),\n            title: l10n.about),\n            subtitle: l10n.aboutHint),\n            trailing: Icon(Icons.chevron_right),\n          ),',
    'ListTile(\n            leading: const Icon(Icons.info),\n            title: Text(l10n.about),\n            subtitle: Text(l10n.aboutHint),\n            trailing: const Icon(Icons.chevron_right),\n            onTap: () {\n              // TODO: 實現關於頁面\n            },\n          ),',
  );
  fixes++;
  
  // 修復 ListTile 中的 Text style
  content = content.replaceAll(
    'title: Text(l10n.logout), style: TextStyle(color: Colors.red)),',
    'title: Text(l10n.logout, style: const TextStyle(color: Colors.red)),',
  );
  fixes++;
  
  // 修復 const $1'確認登出'
  content = content.replaceAll(
    "title: const \$1'確認登出'),",
    "title: const Text('確認登出'),",
  );
  fixes++;
  
  // 在 _handleLogout 方法中添加 l10n
  content = content.replaceAllMapped(
    RegExp(r'Future<void> _handleLogout\(BuildContext context\) async \{'),
    (match) {
      fixes++;
      return 'Future<void> _handleLogout(BuildContext context) async {\n    final l10n = AppLocalizations.of(context);';
    },
  );
  
  file.writeAsStringSync(content);
  print('   ✅ 完成 $fixes 處修復');
}
