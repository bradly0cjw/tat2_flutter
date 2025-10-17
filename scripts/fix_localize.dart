import 'dart:io';

/// 修復自動本地化腳本造成的錯誤
void main() {
  print('🔧 開始修復本地化錯誤...\n');
  
  final files = [
    'lib/src/pages/personalization_page.dart',
    'lib/src/pages/navigation_config_page.dart',
    'lib/src/pages/other_features_page.dart',
  ];
  
  for (final filePath in files) {
    print('📝 修復文件: $filePath');
    fixFile(filePath);
  }
  
  print('\n✅ 修復完成！');
}

void fixFile(String filePath) {
  final file = File(filePath);
  
  if (!file.existsSync()) {
    print('   ⚠️  文件不存在，跳過');
    return;
  }
  
  var content = file.readAsStringSync();
  int fixes = 0;
  
  // 修復 const $1l10n.xxx) -> Text(l10n.xxx)
  final pattern1 = RegExp(r'const \$1l10n\.(\w+)\)');
  content = content.replaceAllMapped(pattern1, (match) {
    fixes++;
    return 'Text(l10n.${match.group(1)})';
  });
  
  // 修復 const $1l10n.xxx, -> Text(l10n.xxx),
  final pattern2 = RegExp(r'const \$1l10n\.(\w+),');
  content = content.replaceAllMapped(pattern2, (match) {
    fixes++;
    return 'Text(l10n.${match.group(1)}),';
  });
  
  // 修復 $1l10n.xxx) -> l10n.xxx)
  final pattern3 = RegExp(r'\$1l10n\.(\w+)\)');
  content = content.replaceAllMapped(pattern3, (match) {
    fixes++;
    return 'l10n.${match.group(1)})';
  });
  
  // 修復 $1l10n.xxx, -> l10n.xxx,
  final pattern4 = RegExp(r'\$1l10n\.(\w+),');
  content = content.replaceAllMapped(pattern4, (match) {
    fixes++;
    return 'l10n.${match.group(1)},';
  });
  
  // 修復 $1l10n.xxx -> l10n.xxx (其他情況)
  final pattern5 = RegExp(r'\$1l10n\.(\w+)');
  content = content.replaceAllMapped(pattern5, (match) {
    fixes++;
    return 'l10n.${match.group(1)}';
  });
  
  // 修復錯誤的 Text 結構: child: const l10n.xxx, style: -> child: Text(l10n.xxx, style:
  final pattern6 = RegExp(r'child: const (l10n\.\w+), style:');
  content = content.replaceAllMapped(pattern6, (match) {
    fixes++;
    return 'child: Text(${match.group(1)}, style:';
  });
  
  file.writeAsStringSync(content);
  print('   ✅ 完成 $fixes 處修復');
}
