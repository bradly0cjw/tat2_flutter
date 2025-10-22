import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/theme_settings_service.dart';
import '../services/course_color_service.dart';
import '../services/badge_service.dart';
import '../l10n/app_localizations.dart';
import '../../ui/theme/app_theme.dart';

/// 個人化設定頁面
class PersonalizationPage extends StatefulWidget {
  const PersonalizationPage({super.key});

  @override
  State<PersonalizationPage> createState() => _PersonalizationPageState();
}

class _PersonalizationPageState extends State<PersonalizationPage> {
  @override
  void initState() {
    super.initState();
    _checkAndShowIntroDialog();
  }

  /// 檢查是否首次訪問，如果是則顯示介紹彈窗
  Future<void> _checkAndShowIntroDialog() async {
    final shouldShow = await BadgeService().shouldShowPersonalizationBadge();
    
    if (shouldShow && mounted) {
      // 標記為已訪問
      await BadgeService().markPersonalizationAsVisited();
      
      // 延遲一下讓頁面完全加載後再顯示彈窗
      await Future.delayed(const Duration(milliseconds: 300));
      
      if (mounted) {
        _showIntroDialog();
      }
    }
  }

  /// 顯示個人化功能介紹彈窗
  void _showIntroDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        icon: Icon(
          Icons.palette,
          size: 48,
          color: Theme.of(context).colorScheme.primary,
        ),
        title: const Text('歡迎來到個人化設定'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '這裡可以自訂 App 的外觀與體驗：',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                ),
              ),
              const SizedBox(height: 16),
              _buildIntroPoint(
                Icons.color_lens,
                '主題顏色',
                '選擇你喜歡的主題色調',
              ),
              const SizedBox(height: 12),
              _buildIntroPoint(
                Icons.brightness_6,
                '深淺模式',
                '切換亮色或暗色主題',
              ),
              const SizedBox(height: 12),
              _buildIntroPoint(
                Icons.language,
                '語言設定',
                '支援繁體中文和英文',
              ),
              const SizedBox(height: 12),
              _buildIntroPoint(
                Icons.grid_view,
                '課表風格',
                '選擇喜歡的課表顯示方式',
              ),
              const SizedBox(height: 12),
              _buildIntroPoint(
                Icons.palette_outlined,
                '課程配色',
                '自訂課表的配色方案',
              ),
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
                      Icons.tips_and_updates,
                      color: Theme.of(context).colorScheme.onPrimaryContainer,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        '長按課表中的課程可以自訂顏色喔！',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onPrimaryContainer,
                          fontWeight: FontWeight.w500,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('開始探索'),
          ),
        ],
      ),
    );
  }

  Widget _buildIntroPoint(IconData icon, String title, String description) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          icon,
          size: 20,
          color: Theme.of(context).colorScheme.primary,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
              Text(
                description,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

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
          Consumer<ThemeSettingsService>(
            builder: (context, themeService, child) {
              return ListTile(
                leading: Icon(themeService.courseTableStyleIcon),
                title: const Text('課表風格'),
                subtitle: Text(themeService.courseTableStyleName),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _showCourseTableStyleDialog(context, themeService),
              );
            },
          ),
          const Divider(),
          Consumer<ThemeSettingsService>(
            builder: (context, themeService, child) {
              return ListTile(
                leading: Icon(themeService.courseColorStyleIcon),
                title: const Text('課程配色'),
                subtitle: Text(themeService.courseColorStyleName),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _showCourseColorStyleDialog(context, themeService),
              );
            },
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.info_outline),
            title: const Text('課程顏色說明'),
            subtitle: const Text('訂製屬於你自己的課表'),
            trailing: const Icon(Icons.chevron_right),
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
                            ? const Stack(
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
  
  void _showCourseTableStyleDialog(BuildContext context, ThemeSettingsService themeService) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('選擇課表風格'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            RadioListTile<CourseTableStyle>(
              title: const Text('Material 3 風格'),
              subtitle: const Text('懸浮卡片設計，現代化視覺'),
              secondary: const Icon(Icons.layers),
              value: CourseTableStyle.material3,
              groupValue: themeService.courseTableStyle,
              onChanged: (value) {
                if (value != null) {
                  themeService.setCourseTableStyle(value);
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: const Text('已切換至 Material 3 風格課表'),
                      backgroundColor: Theme.of(context).colorScheme.primary,
                      behavior: SnackBarBehavior.floating,
                      duration: const Duration(seconds: 2),
                    ),
                  );
                }
              },
            ),
            RadioListTile<CourseTableStyle>(
              title: const Text('經典風格'),
              subtitle: const Text('表格式佈局，緊湊簡潔'),
              secondary: const Icon(Icons.grid_on),
              value: CourseTableStyle.classic,
              groupValue: themeService.courseTableStyle,
              onChanged: (value) {
                if (value != null) {
                  themeService.setCourseTableStyle(value);
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: const Text('已切換至經典風格課表'),
                      backgroundColor: Theme.of(context).colorScheme.primary,
                      behavior: SnackBarBehavior.floating,
                      duration: const Duration(seconds: 2),
                    ),
                  );
                }
              },
            ),
            RadioListTile<CourseTableStyle>(
              title: const Text('TAT 傳統風格'),
              subtitle: const Text('緊湊表格，馬卡龍色系'),
              secondary: const Icon(Icons.table_chart),
              value: CourseTableStyle.tat,
              groupValue: themeService.courseTableStyle,
              onChanged: (value) {
                if (value != null) {
                  themeService.setCourseTableStyle(value);
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: const Text('已切換至 TAT 傳統風格課表'),
                      backgroundColor: Theme.of(context).colorScheme.primary,
                      behavior: SnackBarBehavior.floating,
                      duration: const Duration(seconds: 2),
                    ),
                  );
                }
              },
            ),
          ],
        ),
      ),
    );
  }
  
  void _showCourseColorStyleDialog(BuildContext context, ThemeSettingsService themeService) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('選擇課程配色'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            RadioListTile<CourseColorStyle>(
              title: const Text('TAT 配色'),
              subtitle: const Text('柔和的馬卡龍色系'),
              secondary: const Icon(Icons.palette_outlined),
              value: CourseColorStyle.tat,
              groupValue: themeService.courseColorStyle,
              onChanged: (value) {
                if (value != null) {
                  themeService.setCourseColorStyle(value);
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: const Text('已切換至 TAT 配色'),
                      backgroundColor: Theme.of(context).colorScheme.primary,
                      behavior: SnackBarBehavior.floating,
                      duration: const Duration(seconds: 2),
                    ),
                  );
                }
              },
            ),
            RadioListTile<CourseColorStyle>(
              title: const Text('主題配色'),
              subtitle: const Text('根據主題色生成'),
              secondary: const Icon(Icons.color_lens),
              value: CourseColorStyle.theme,
              groupValue: themeService.courseColorStyle,
              onChanged: (value) {
                if (value != null) {
                  themeService.setCourseColorStyle(value);
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: const Text('已切換至主題配色'),
                      backgroundColor: Theme.of(context).colorScheme.primary,
                      behavior: SnackBarBehavior.floating,
                      duration: const Duration(seconds: 2),
                    ),
                  );
                }
              },
            ),
            RadioListTile<CourseColorStyle>(
              title: const Text('彩虹配色'),
              subtitle: const Text('經典彩虹色系'),
              secondary: const Icon(Icons.gradient),
              value: CourseColorStyle.rainbow,
              groupValue: themeService.courseColorStyle,
              onChanged: (value) {
                if (value != null) {
                  themeService.setCourseColorStyle(value);
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: const Text('已切換至彩虹配色'),
                      backgroundColor: Theme.of(context).colorScheme.primary,
                      behavior: SnackBarBehavior.floating,
                      duration: const Duration(seconds: 2),
                    ),
                  );
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
    final themeService = Provider.of<ThemeSettingsService>(context, listen: false);
    final colorStyle = themeService.courseColorStyle;
    
    // 根據配色風格顯示不同的說明
    String title;
    String description;
    List<String> features;
    
    switch (colorStyle) {
      case CourseColorStyle.tat:
        title = 'TAT 馬卡龍配色';
        description = '柔和的粉彩色系，提供 13 種精選顏色：';
        features = [
          '柔和的馬卡龍色調',
          '保護眼睛的淺色系',
          '高辨識度的色彩搭配',
        ];
        break;
      case CourseColorStyle.theme:
        title = '主題動態配色';
        description = '根據您的主題色生成 16 種和諧配色：';
        features = [
          '與主題色完美融合',
          '冷暖色調漸變搭配',
          '自動適配亮暗模式',
        ];
        break;
      case CourseColorStyle.rainbow:
        title = '彩虹色系配色';
        description = '經典的彩虹色譜，提供 16 種鮮明顏色：';
        features = [
          '色相均勻分布',
          '最大化辨識度',
          '獨立於主題色',
        ];
        break;
    }
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        icon: Icon(
          colorStyle == CourseColorStyle.tat 
              ? Icons.palette_outlined
              : colorStyle == CourseColorStyle.theme
                  ? Icons.color_lens
                  : Icons.gradient,
          size: 48,
        ),
        title: Text(title),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                description,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                ),
              ),
              const SizedBox(height: 12),
              ...features.map((feature) => _buildInfoPoint('•', feature)),
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
    final themeService = Provider.of<ThemeSettingsService>(context, listen: false);
    final colorStyle = themeService.courseColorStyle;
    
    // 根據配色風格顯示不同的說明
    String colorSystemName;
    switch (colorStyle) {
      case CourseColorStyle.tat:
        colorSystemName = 'TAT 馬卡龍色系';
        break;
      case CourseColorStyle.theme:
        colorSystemName = '主題漸變色系';
        break;
      case CourseColorStyle.rainbow:
        colorSystemName = '彩虹色系';
        break;
    }
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        icon: Icon(
          Icons.shuffle,
          size: 48,
          color: Theme.of(context).colorScheme.primary,
        ),
        title: const Text('重新隨機分配顏色'),
        content: SingleChildScrollView(
          child: Column(
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
              _buildInfoPoint('•', '使用 $colorSystemName'),
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
              print(' 課程顏色分配結果（共 ${colorIndices.length} 個）：');
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
              print(' 顏色使用統計：');
              for (final entry in indexCounts.entries) {
                if (entry.value.length > 1) {
                  print('    索引 ${entry.key} 被 ${entry.value.length} 個課程使用: ${entry.value.join(", ")}');
                } else {
                  print('   索引 ${entry.key}: ${entry.value[0]}');
                }
              }
              
              if (context.mounted) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('已使用 $colorSystemName 重新分配課程顏色'),
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    behavior: SnackBarBehavior.floating,
                    duration: const Duration(seconds: 2),
                  ),
                );
              }
            },
            child: const Text('確定'),
          ),
        ],
      ),
    );
  }
}
