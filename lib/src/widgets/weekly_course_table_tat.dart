import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:auto_size_text/auto_size_text.dart';
import 'package:provider/provider.dart';
import '../services/course_color_service.dart';
import '../services/theme_settings_service.dart';

/// 週課表組件 - TAT 傳統風格
/// 
/// 完全參照 TAT 專案的課表設計：
/// - 緊湊的表格式佈局
/// - 柔和的馬卡龍色系
/// - 簡潔的卡片設計
/// - 自動隱藏空白時段
class WeeklyCourseTableTat extends StatefulWidget {
  final List<Map<String, dynamic>> courses;
  final Function(Map<String, dynamic>)? onCourseTap;
  final CourseColorService? colorService;
  final GlobalKey? repaintKey;
  
  const WeeklyCourseTableTat({
    super.key,
    required this.courses,
    this.onCourseTap,
    this.colorService,
    this.repaintKey,
  });

  @override
  State<WeeklyCourseTableTat> createState() => _WeeklyCourseTableTatState();
}

class _WeeklyCourseTableTatState extends State<WeeklyCourseTableTat> {
  // TAT 風格的馬卡龍色系（柔和的粉彩色調）
  static const List<Color> tatCourseColors = [
    Color(0xffffccbc), // 淺橙色
    Color(0xffffe0b2), // 淺琥珀色
    Color(0xffffecb3), // 淺黃色
    Color(0xfffff9c4), // 淺檸檬色
    Color(0xfff0f4c3), // 淺青檸色
    Color(0xffdcedc8), // 淺綠色
    Color(0xffc8e6c9), // 中綠色
    Color(0xffb2dfdb), // 淺青色
    Color(0xffb3e5fc), // 淺天藍色
    Color(0xffbbdefb), // 淺藍色
    Color(0xffe1bee7), // 淺紫色
    Color(0xfff8bbd0), // 淺粉色
    Color(0xffffcdd2), // 淺紅色
  ];
  
  // TAT 配色的課程映射表（課號 -> 顏色索引）
  Map<String, int> _colorMap = {};
  
  // 節次時間定義（與 TAT 一致）
  static const List<String> sectionTimes = [
    '08:10-09:00', // 1
    '09:10-10:00', // 2
    '10:10-11:00', // 3
    '11:10-12:00', // 4
    '12:10-13:00', // N
    '13:10-14:00', // 5
    '14:10-15:00', // 6
    '15:10-16:00', // 7
    '16:10-17:00', // 8
    '17:10-18:00', // 9
    '18:30-19:20', // A
    '19:25-20:15', // B
    '20:20-21:10', // C
    '21:15-22:05', // D
  ];
  
  // 節次標籤（與 TAT 一致）
  static const List<String> sectionLabels = [
    '1', '2', '3', '4', 'N', '5', '6', '7', '8', '9', 'A', 'B', 'C', 'D'
  ];
  
  static const List<String> weekDays = ['一', '二', '三', '四', '五'];
  
  // 星期映射表（用於解析）
  static const Map<String, int> dayIndexMap = {
    '一': 0, 'M': 0, 'Mon': 0,
    '二': 1, 'T': 1, 'Tue': 1,
    '三': 2, 'W': 2, 'Wed': 2,
    '四': 3, 'R': 3, 'Thu': 3,
    '五': 4, 'F': 4, 'Fri': 4,
  };
  
  // 課表尺寸常數（與 TAT 一致）
  static const double dayHeight = 25.0;
  static const double courseHeight = 60.0;
  static const double sectionWidth = 20.0;
  
  // 緩存課程網格
  Map<String, List<Map<String, dynamic>>>? _cachedCourseGrid;
  int _cachedCoursesLength = -1;
  
  @override
  void initState() {
    super.initState();
    if (widget.courses.isNotEmpty) {
      _cachedCoursesLength = widget.courses.length;
      _cachedCourseGrid = _buildCourseGrid();
      _initColorMap();
    }
  }
  
  @override
  void didUpdateWidget(WeeklyCourseTableTat oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.courses.length != widget.courses.length) {
      _cachedCoursesLength = widget.courses.length;
      if (widget.courses.isNotEmpty) {
        _cachedCourseGrid = _buildCourseGrid();
        _initColorMap();
      } else {
        _cachedCourseGrid = null;
      }
    }
  }
  
  /// 初始化顏色映射表（採用 TAT 的隨機打亂策略）
  void _initColorMap() {
    _colorMap = {};
    
    // 獲取所有課號列表
    final courseIds = <String>{};
    for (final course in widget.courses) {
      final courseId = course['courseId'] ?? '';
      if (courseId.isNotEmpty) {
        courseIds.add(courseId);
      }
    }
    
    // 打亂顏色索引順序（與 TAT 一致）
    final colorIndices = List<int>.generate(tatCourseColors.length, (i) => i)..shuffle();
    
    // 分配顏色索引
    int index = 0;
    for (final courseId in courseIds) {
      _colorMap[courseId] = colorIndices[index % colorIndices.length];
      index++;
    }
  }
  
  @override
  Widget build(BuildContext context) {
    if (widget.courses.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32.0),
          child: Text(
            '目前沒有課程',
            style: TextStyle(fontSize: 16, color: Colors.grey),
          ),
        ),
      );
    }
    
    final courseGrid = _getCachedCourseGrid();
    final sectionRange = _calculateSectionRange(courseGrid);
    
    // 構建完整課表
    final shouldSkipN = sectionRange.containsKey('skipN');
    final tableContent = Column(
      children: [
        _buildHeader(context),
        ...() {
          final widgets = <Widget>[];
          for (int i = sectionRange['min']!; i <= sectionRange['max']!; i++) {
            // 如果需要跳過 N 節（index = 4）且當前是 N 節，則跳過
            if (shouldSkipN && i == 4) {
              continue;
            }
            widgets.add(_buildSection(context, i, courseGrid));
          }
          return widgets;
        }(),
      ],
    );
    
    // 根據是否需要截圖來決定佈局
    if (widget.repaintKey != null) {
      return Stack(
        children: [
          // 正常顯示的課表（可滾動）
          SingleChildScrollView(
            child: tableContent,
          ),
          // 隱藏的截圖用課表
          Positioned(
            left: -10000,
            top: 0,
            child: RepaintBoundary(
              key: widget.repaintKey,
              child: tableContent,
            ),
          ),
        ],
      );
    }
    
    return SingleChildScrollView(
      child: tableContent,
    );
  }
  
  /// 構建表頭（星期列）
  Widget _buildHeader(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final colorScheme = Theme.of(context).colorScheme;
    
    return Container(
      color: isDark 
          ? colorScheme.surfaceContainerHighest.withOpacity(0.5)
          : colorScheme.surface.withOpacity(0.3),
      height: dayHeight,
      child: Row(
        children: [
          // 左上角空格（節次欄位置）
          SizedBox(width: sectionWidth),
          // 星期列
          ...weekDays.map((day) {
            return Expanded(
              child: Center(
                child: Text(
                  day,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: colorScheme.onSurface,
                  ),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
  
  /// 構建一列課程（一個節次的所有星期）
  Widget _buildSection(BuildContext context, int sectionIndex, Map<String, List<Map<String, dynamic>>> courseGrid) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final colorScheme = Theme.of(context).colorScheme;
    
    // 交替背景色（與 TAT 一致）
    final bgColor = sectionIndex % 2 == 1
        ? colorScheme.surface
        : colorScheme.surfaceContainerHighest.withOpacity(0.3);
    
    return Container(
      color: bgColor,
      height: courseHeight,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 節次編號
          Container(
            width: sectionWidth,
            alignment: Alignment.center,
            child: Text(
              sectionLabels[sectionIndex],
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: colorScheme.onSurface,
              ),
            ),
          ),
          // 每天的課程
          ...weekDays.map((day) {
            final key = '$day-${sectionLabels[sectionIndex]}';
            final coursesInSlot = courseGrid[key] ?? [];
            
            return Expanded(
              child: coursesInSlot.isEmpty
                  ? const SizedBox.expand()  // 保持格子大小，確保可以點擊
                  : _buildCourseCard(context, coursesInSlot.first),
            );
          }),
        ],
      ),
    );
  }
  
  /// 構建課程卡片（TAT 風格）
  Widget _buildCourseCard(BuildContext context, Map<String, dynamic> course) {
    final courseId = course['courseId'] ?? '';
    final courseName = course['courseName'] ?? '';
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final seedColor = Theme.of(context).colorScheme.primary;
    
    // 使用 Provider.of 而非 context.watch，避免在構建過程中導致佈局問題
    final themeSettings = Provider.of<ThemeSettingsService>(context, listen: false);
    final colorStyle = themeSettings.courseColorStyle;
    
    // 根據配色風格獲取顏色
    final color = widget.colorService != null
        ? widget.colorService!.getCourseColor(
            courseId,
            courseName,
            isDark: isDark,
            seedColor: seedColor,
            colorStyle: colorStyle,
          )
        : _generateColorFromCourseId(courseId);
    
    // 獲取文字顏色
    final textColor = widget.colorService != null
        ? widget.colorService!.getOnCourseColor(
            courseId,
            courseName,
            isDark: isDark,
            seedColor: seedColor,
            colorStyle: colorStyle,
          )
        : Colors.black87;
    
    return Container(
      margin: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        borderRadius: const BorderRadius.all(Radius.circular(5)),
        color: color,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: const BorderRadius.all(Radius.circular(5)),
          highlightColor: isDark ? Colors.white.withOpacity(0.1) : Colors.black12,
          onTap: widget.onCourseTap != null 
              ? () => widget.onCourseTap!(course) 
              : null,
          onLongPress: widget.colorService != null 
              ? () => _showColorPicker(context, course) 
              : null,
          child: Stack(
            children: [
              Align(
                alignment: Alignment.center,
                child: Padding(
                  padding: const EdgeInsets.all(2),
                  child: AutoSizeText(
                    courseName,
                    style: TextStyle(
                      color: textColor,
                      fontSize: 14,
                      overflow: TextOverflow.ellipsis,
                    ),
                    minFontSize: 6,
                    maxLines: 3,
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
  
  /// 根據課號生成顏色（後備方案）
  Color _generateColorFromCourseId(String courseId) {
    if (courseId.isEmpty) return Colors.blue;
    
    final hash = courseId.hashCode;
    final colors = [
      Colors.blue,
      Colors.green,
      Colors.orange,
      Colors.purple,
      Colors.teal,
      Colors.pink,
      Colors.indigo,
      Colors.amber,
      Colors.cyan,
      Colors.lime,
    ];
    
    return colors[hash.abs() % colors.length];
  }
  
  /// 顯示顏色選擇器（支援三種配色風格）
  void _showColorPicker(BuildContext context, Map<String, dynamic> course) {
    final courseName = course['courseName'] ?? '';
    final courseId = course['courseId'] ?? '';
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final seedColor = Theme.of(context).colorScheme.primary;
    final themeSettings = Provider.of<ThemeSettingsService>(context, listen: false);
    final colorStyle = themeSettings.courseColorStyle;
    
    // 獲取當前顏色
    final currentColor = widget.colorService?.getCourseColor(
      courseId, 
      courseName,
      isDark: isDark,
      seedColor: seedColor,
      colorStyle: colorStyle,
    );
    
    // 根據配色風格獲取可用顏色
    final availableColors = colorStyle == CourseColorStyle.tat
        ? CourseColorService.tatCourseColors
        : (widget.colorService?.getAvailableColors(
            isDark: isDark,
            seedColor: seedColor,
          ) ?? []);
    
    // 獲取當前顏色的索引
    final currentIndex = widget.colorService?.getColorIndex(
      courseId,
      courseName,
      currentColor!,
      isDark: isDark,
      seedColor: seedColor,
      colorStyle: colorStyle,
    );
    
    // TAT 配色：顯示 13 種馬卡龍色
    if (colorStyle == CourseColorStyle.tat) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '選擇課程顏色',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 6),
              Text(
                courseName,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 8),
              Text(
                'TAT 馬卡龍色系',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.primary,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          content: SizedBox(
            width: double.maxFinite,
            child: Wrap(
              spacing: 12,
              runSpacing: 12,
              alignment: WrapAlignment.start,
              children: List.generate(availableColors.length, (index) {
                final color = availableColors[index];
                final isSelected = currentIndex == index;
                return GestureDetector(
                  onTap: () async {
                    await widget.colorService?.setCourseColorIndex(
                      courseId, 
                      courseName, 
                      index,
                    );
                    if (context.mounted) {
                      Navigator.pop(context);
                      setState(() {});
                    }
                  },
                  child: Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                      border: isSelected 
                          ? Border.all(
                              color: Theme.of(context).colorScheme.primary,
                              width: 3.5,
                            )
                          : Border.all(
                              color: Theme.of(context).colorScheme.outline.withOpacity(0.2),
                              width: 1,
                            ),
                      boxShadow: [
                        BoxShadow(
                          color: color.withOpacity(isSelected ? 0.5 : 0.3),
                          blurRadius: isSelected ? 8 : 4,
                          offset: const Offset(0, 2),
                          spreadRadius: isSelected ? 1 : 0,
                        ),
                      ],
                    ),
                    child: isSelected
                        ? const Icon(
                            Icons.check_rounded,
                            color: Colors.black87,
                            size: 26,
                          )
                        : null,
                  ),
                );
              }).toList(),
            ),
          ),
          actions: [
            TextButton.icon(
              onPressed: () async {
                await widget.colorService?.resetCourseColor(courseId, courseName);
                if (context.mounted) {
                  Navigator.pop(context);
                  setState(() {});
                }
              },
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('重置'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('完成'),
            ),
          ],
        ),
      );
      return;
    }
    
    // 主題配色 / 彩虹配色：顯示 32 種顏色
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '選擇課程顏色',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 6),
            Text(
              courseName,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 8),
            Text(
              colorStyle == CourseColorStyle.theme 
                  ? '16 種主題漸變色' 
                  : '16 種彩虹色系',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.primary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(
            child: Wrap(
              spacing: 12,
              runSpacing: 12,
              alignment: WrapAlignment.start,
              children: List.generate(16, (index) {
                // 主題配色使用索引 0-15，彩虹配色使用索引 16-31
                final actualIndex = colorStyle == CourseColorStyle.theme 
                    ? index 
                    : index + 16;
                final color = availableColors[actualIndex];
                final isSelected = currentIndex == actualIndex;
                return GestureDetector(
                  onTap: () async {
                    await widget.colorService?.setCourseColorIndex(
                      courseId, 
                      courseName, 
                      actualIndex,
                    );
                    if (context.mounted) {
                      Navigator.pop(context);
                      setState(() {});
                    }
                  },
                  child: Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                      border: isSelected 
                          ? Border.all(
                              color: Theme.of(context).colorScheme.primary,
                              width: 3.5,
                            )
                          : Border.all(
                              color: Theme.of(context).colorScheme.outline.withOpacity(0.2),
                              width: 1,
                            ),
                      boxShadow: [
                        BoxShadow(
                          color: color.withOpacity(isSelected ? 0.5 : 0.3),
                          blurRadius: isSelected ? 8 : 4,
                          offset: const Offset(0, 2),
                          spreadRadius: isSelected ? 1 : 0,
                        ),
                      ],
                    ),
                    child: isSelected
                        ? Icon(
                            Icons.check_rounded,
                            color: color.computeLuminance() > 0.5 
                                ? Colors.black87 
                                : Colors.white,
                            size: 26,
                          )
                        : null,
                  ),
                );
              }).toList(),
            ),
          ),
        ),
        actions: [
          TextButton.icon(
            onPressed: () async {
              await widget.colorService?.resetCourseColor(courseId, courseName);
              if (context.mounted) {
                Navigator.pop(context);
                setState(() {});
              }
            },
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('重置'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('完成'),
          ),
        ],
      ),
    );
  }
  
  /// 計算實際有課的節次範圍（TAT 風格：N 節只在有課時顯示）
  Map<String, int> _calculateSectionRange(Map<String, List<Map<String, dynamic>>> courseGrid) {
    if (courseGrid.isEmpty) {
      return {'min': 0, 'max': 9}; // 預設顯示 1-9 節
    }
    
    int minSection = 13;
    int maxSection = 0;
    bool hasNSection = false; // 追蹤是否有 N 節課程
    
    // 遍歷所有課程格子
    for (final key in courseGrid.keys) {
      if (courseGrid[key]?.isEmpty ?? true) continue;
      
      final parts = key.split('-');
      if (parts.length != 2) continue;
      
      final sectionLabel = parts[1];
      final sectionIndex = sectionLabels.indexOf(sectionLabel);
      
      if (sectionIndex >= 0 && sectionIndex < 14) {
        // 檢查是否有 N 節課程（index = 4）
        if (sectionIndex == 4) {
          hasNSection = true;
        }
        
        minSection = minSection < sectionIndex ? minSection : sectionIndex;
        maxSection = maxSection > sectionIndex ? maxSection : sectionIndex;
      }
    }
    
    if (minSection > maxSection) {
      return {'min': 0, 'max': 9};
    }
    
    // 如果沒有 N 節課程，且範圍包含 N 節，則調整範圍
    // 如果最小節次在 N 節之前（1-4節），最大節次在 N 節之後（5-D節）
    // 但沒有 N 節課程，則跳過 N 節
    if (!hasNSection && minSection < 4 && maxSection > 4) {
      // 保持原範圍，但在渲染時跳過 N 節
      return {'min': minSection, 'max': maxSection, 'skipN': 1};
    }
    
    return {'min': minSection, 'max': maxSection};
  }
  
  /// 獲取緩存的課程網格
  Map<String, List<Map<String, dynamic>>> _getCachedCourseGrid() {
    final currentLength = widget.courses.length;
    if (_cachedCoursesLength != currentLength || _cachedCourseGrid == null) {
      _cachedCoursesLength = currentLength;
      _cachedCourseGrid = _buildCourseGrid();
    }
    return _cachedCourseGrid!;
  }
  
  /// 解析課程到網格
  Map<String, List<Map<String, dynamic>>> _buildCourseGrid() {
    final grid = <String, List<Map<String, dynamic>>>{};
    
    for (final course in widget.courses) {
      final scheduleJson = course['schedule'] as String?;
      if (scheduleJson == null || scheduleJson.isEmpty) continue;
      
      try {
        final schedule = json.decode(scheduleJson) as Map<String, dynamic>;
        
        schedule.forEach((day, sections) {
          if (sections == null || sections.toString().trim().isEmpty) return;
          
          // 解析節次
          final sectionList = sections.toString().trim().split(' ');
          
          for (final sectionStr in sectionList) {
            if (sectionStr.isEmpty) continue;
            
            // 轉換節次格式（數字 -> 標籤）
            // QAQ 系統的節次編號：1-4(上午), 5-9(下午), 10-14(晚上)
            // TAT 系統的標籤：1-4(上午), N(午休), 5-9(下午), A-D(晚上)
            String sectionLabel;
            if (int.tryParse(sectionStr) != null) {
              final num = int.parse(sectionStr);
              if (num >= 1 && num <= 4) {
                // 上午 1-4 節
                sectionLabel = num.toString();
              } else if (num >= 5 && num <= 9) {
                // 下午 5-9 節（對應索引 5-9）
                sectionLabel = sectionLabels[num];
              } else if (num >= 10 && num <= 13) {
                // 晚上 10-13 節 → A-D（對應索引 10-13）
                sectionLabel = sectionLabels[num];
              } else if (num == 14) {
                // 第 14 節 → D（對應索引 13）
                sectionLabel = sectionLabels[13];
              } else {
                continue;
              }
            } else {
              // 已經是標籤格式（1-4, N, 5-9, A-D）
              sectionLabel = sectionStr;
            }
            
            final key = '$day-$sectionLabel';
            grid[key] = grid[key] ?? [];
            grid[key]!.add(course);
          }
        });
      } catch (e) {
        debugPrint('[WeeklyCourseTableTat] 解析課程時間失敗: $e');
      }
    }
    
    return grid;
  }
}
