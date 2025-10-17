import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/theme_settings_service.dart';
import '../services/course_color_service.dart';
import '../l10n/app_localizations.dart';
import '../../ui/theme/app_theme.dart';

/// 個人化設定頁面
class PersonalizationPage extends StatelessWidget {
  const PersonalizationPage({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.personalization),
      ),
      body: ListView(
        children: [
          // 配色設定
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text(
              l10n.themeSettings,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
          ),
          Consumer<ThemeSettingsService>(
            builder: (context, themeService, child) {
              return Column(
                children: [
                  ListTile(
                    leading: const Icon(Icons.palette),
                    title: const Text('主題顏色'),
                    subtitle: Text(_getColorName(themeService.themeColorId)),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => _showThemeColorDialog(context, themeService),
                  ),
                  const Divider(),
                  ListTile(
                    leading: Icon(themeService.themeModeIcon),
                    title: Text(l10n.themeMode),
                    subtitle: Text(themeService.themeModeString),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => _showThemeModeDialog(context, themeService),
                  ),
                  const Divider(),
                  ListTile(
                    leading: Icon(themeService.localeIcon),
                    title: Text(l10n.language),
                    subtitle: Text(themeService.localeString),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => _showLanguageDialog(context, themeService),
                  ),
                ],
              );
            },
          ),
          const Divider(),
          
          // 課程設定
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text(
              l10n.courseSettings,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.color_lens),
            title: Text(l10n.courseColor),
            subtitle: Text(l10n.courseColorHint),
            trailing: const Icon(Icons.info_outline),
            onTap: () => _showCourseColorInfoDialog(context),
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.shuffle),
            title: const Text('重新隨機分配顏色'),
            subtitle: const Text('清除所有自訂顏色，重新自動分配'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _showReassignColorsDialog(context),
          ),
        ],
      ),
    );
  }

  String _getColorName(String colorId) {
    return AppTheme.themeColors[colorId]?.name ?? '藍色';
  }

  void _showThemeColorDialog(BuildContext context, ThemeSettingsService themeService) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('選擇主題顏色'),
        content: SingleChildScrollView(
          child: Wrap(
            spacing: 16,
            runSpacing: 16,
            children: AppTheme.themeColors.entries.map((entry) {
              final colorId = entry.key;
              final themeColor = entry.value;
              final isSelected = themeService.themeColorId == colorId;
              
              return InkWell(
                onTap: () {
                  themeService.setThemeColor(colorId);
                  Navigator.pop(context);
                },
                borderRadius: BorderRadius.circular(12),
                child: SizedBox(
                  width: 64,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 64,
                        height: 64,
                        decoration: BoxDecoration(
                          color: themeColor.seedColor,
                          borderRadius: BorderRadius.circular(12),
                          border: isSelected
                              ? Border.all(
                                  color: Theme.of(context).colorScheme.primary,
                                  width: 3,
                                )
                              : null,
                          boxShadow: [
                            BoxShadow(
                              color: themeColor.seedColor.withOpacity(0.3),
                              blurRadius: isSelected ? 12 : 6,
                              spreadRadius: isSelected ? 2 : 0,
                            ),
                          ],
                        ),
                        child: isSelected
                            ? Stack(
                                alignment: Alignment.center,
                                children: [
                                  Icon(
                                    Icons.check,
                                    color: Colors.white,
                                    size: 32,
                                  ),
                                ],
                              )
                            : null,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        themeColor.name,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('關閉'),
          ),
        ],
      ),
    );
  }

  void _showThemeModeDialog(BuildContext context, ThemeSettingsService themeService) {
    final l10n = AppLocalizations.of(context);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.selectThemeMode),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            RadioListTile<ThemeMode>(
              title: Text(l10n.followSystem),
              subtitle: Text(l10n.followSystemDesc),
              value: ThemeMode.system,
              groupValue: themeService.themeMode,
              onChanged: (value) {
                if (value != null) {
                  themeService.setThemeMode(value);
                  Navigator.pop(context);
                }
              },
            ),
            RadioListTile<ThemeMode>(
              title: Text(l10n.lightMode),
              subtitle: Text(l10n.lightModeDesc),
              value: ThemeMode.light,
              groupValue: themeService.themeMode,
              onChanged: (value) {
                if (value != null) {
                  themeService.setThemeMode(value);
                  Navigator.pop(context);
                }
              },
            ),
            RadioListTile<ThemeMode>(
              title: Text(l10n.darkMode),
              subtitle: Text(l10n.darkModeDesc),
              value: ThemeMode.dark,
              groupValue: themeService.themeMode,
              onChanged: (value) {
                if (value != null) {
                  themeService.setThemeMode(value);
                  Navigator.pop(context);
                }
              },
            ),
          ],
        ),
      ),
    );
  }
  
  void _showLanguageDialog(BuildContext context, ThemeSettingsService themeService) {
    final l10n = AppLocalizations.of(context);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.selectLanguage),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            RadioListTile<String>(
              title: Text(l10n.followSystem),
              subtitle: Text(l10n.followSystemLang),
              value: 'system',
              groupValue: themeService.locale == null 
                  ? 'system' 
                  : themeService.locale!.languageCode,
              onChanged: (value) {
                themeService.setLocale(null);
                Navigator.pop(context);
              },
            ),
            RadioListTile<String>(
              title: Text(l10n.traditionalChinese),
              subtitle: const Text('Traditional Chinese / 繁體中文'),
              value: 'zh',
              groupValue: themeService.locale == null 
                  ? 'system' 
                  : themeService.locale!.languageCode,
              onChanged: (value) {
                themeService.setLocale(const Locale('zh', 'TW'));
                Navigator.pop(context);
              },
            ),
            RadioListTile<String>(
              title: Text(l10n.english),
              subtitle: const Text('English'),
              value: 'en',
              groupValue: themeService.locale == null 
                  ? 'system' 
                  : themeService.locale!.languageCode,
              onChanged: (value) {
                themeService.setLocale(const Locale('en', 'US'));
                Navigator.pop(context);
              },
            ),
          ],
        ),
      ),
    );
  }
  
  void _showCourseColorInfoDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        icon: const Icon(Icons.palette, size: 48),
        title: const Text('課程顏色'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Material You 動態配色',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              '課程顏色會自動根據您選擇的主題色生成和諧的配色方案，確保：',
            ),
            const SizedBox(height: 8),
            _buildInfoPoint('•', '與主題完美融合'),
            _buildInfoPoint('•', '保持高辨識度'),
            _buildInfoPoint('•', '自動適配亮暗模式'),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.touch_app,
                    color: Theme.of(context).colorScheme.onPrimaryContainer,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      '長按課表中的任一課程\n即可自訂專屬顏色',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onPrimaryContainer,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('我知道了'),
          ),
        ],
      ),
    );
  }
  
  Widget _buildInfoPoint(String bullet, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            bullet,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(width: 8),
          Expanded(child: Text(text)),
        ],
      ),
    );
  }
  
  void _showReassignColorsDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        icon: Icon(
          Icons.shuffle,
          size: 48,
          color: Theme.of(context).colorScheme.primary,
        ),
        title: const Text('重新隨機分配顏色'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '此操作將：',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            _buildInfoPoint('•', '清除所有自訂顏色'),
            _buildInfoPoint('•', '重新自動分配課程顏色'),
            _buildInfoPoint('•', '使用主題漸變色系'),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.errorContainer,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.warning_amber_rounded,
                    color: Theme.of(context).colorScheme.onErrorContainer,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      '此操作無法復原',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onErrorContainer,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () async {
              final courseColorService = Provider.of<CourseColorService>(context, listen: false);
              await courseColorService.reassignAllColors();
              
              // 調試：顯示分配結果
              final colorIndices = courseColorService.getAllCourseColorIndices();
              print('📊 課程顏色分配結果（共 ${colorIndices.length} 個）：');
              final sortedEntries = colorIndices.entries.toList()
                ..sort((a, b) => a.key.compareTo(b.key));
              for (final entry in sortedEntries) {
                print('  ${entry.key}: 索引 ${entry.value}');
              }
              
              // 檢查重複
              final indexCounts = <int, List<String>>{};
              for (final entry in colorIndices.entries) {
                indexCounts[entry.value] ??= [];
                indexCounts[entry.value]!.add(entry.key);
              }
              print('📊 顏色使用統計：');
              for (final entry in indexCounts.entries) {
                if (entry.value.length > 1) {
                  print('  ⚠️  索引 ${entry.key} 被 ${entry.value.length} 個課程使用: ${entry.value.join(", ")}');
                } else {
                  print('  ✓ 索引 ${entry.key}: ${entry.value[0]}');
                }
              }
              
              if (context.mounted) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: const Text('已重新分配課程顏色'),
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    behavior: SnackBarBehavior.floating,
                    duration: const Duration(seconds: 2),
                  ),
                );
              }
            },
            child: const Text('確定重新分配'),
          ),
        ],
      ),
    );
  }
}
