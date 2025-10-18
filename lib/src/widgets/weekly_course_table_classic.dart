import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:provider/provider.dart';
import '../services/course_color_service.dart';
import '../services/theme_settings_service.dart';

/// 週課表組件 - 經典風格（表格式、緊湊佈局）
/// 
/// 支援顯示：
/// - 個人課表
/// - 微學程課表
/// - 學程課表
/// - 各班課表
class WeeklyCourseTableClassic extends StatefulWidget {
  final List<Map<String, dynamic>> courses;
  final Function(Map<String, dynamic>)? onCourseTap;
  final CourseColorService? colorService;
  final GlobalKey? repaintKey; // 用於截圖的 key
  
  const WeeklyCourseTableClassic({
    super.key,
    required this.courses,
    this.onCourseTap,
    this.colorService,
    this.repaintKey,
  });

  @override
  State<WeeklyCourseTableClassic> createState() => _WeeklyCourseTableClassicState();
}

class _WeeklyCourseTableClassicState extends State<WeeklyCourseTableClassic> {
  // 緩存課程網格,避免每次 build 都重新計算
  Map<String, List<Map<String, dynamic>>>? _cachedCourseGrid;
  int _cachedCoursesLength = -1; // 使用課程數量來判斷是否需要重新計算
  bool _isInitialized = false; // 追蹤是否已完成初始化
  
  // 節次時間定義
  static const List<String> sectionTimes = [
    '08:10-09:00',
    '09:10-10:00',
    '10:10-11:00',
    '11:10-12:00',
    '12:10-13:00',
    '13:10-14:00',
    '14:10-15:00',
    '15:10-16:00',
    '16:10-17:00',
    '17:10-18:00',
    '18:30-19:20',
    '19:25-20:15',
    '20:20-21:10',
    '21:15-22:05',
  ];
  
  static const List<String> weekDays = ['一', '二', '三', '四', '五'];
  
  @override
  void initState() {
    super.initState();
    
    // 監聽顏色服務的變化（主題色變更時會觸發）
    widget.colorService?.addListener(_onColorServiceChanged);
    
    // 在 initState 時立即構建課程網格,避免首次渲染時的延遲
    if (widget.courses.isNotEmpty) {
      _cachedCoursesLength = widget.courses.length;
      _cachedCourseGrid = _buildCourseGrid();
      _isInitialized = true;
    }
  }
  
  @override
  void dispose() {
    widget.colorService?.removeListener(_onColorServiceChanged);
    super.dispose();
  }
  
  void _onColorServiceChanged() {
    // 當顏色服務通知變更時，重新繪製課表
    if (mounted) {
      setState(() {});
    }
  }
  
  /// 將節次索引轉換為顯示文字（10+ 節次顯示為 A, B, C...）
  String _getSectionLabel(int sectionIndex) {
    final sectionNumber = sectionIndex + 1;
    if (sectionNumber <= 9) {
      return sectionNumber.toString();
    } else {
      // 10=A, 11=B, 12=C, 13=D, 14=E
      return String.fromCharCode(55 + sectionNumber); // 65='A', 所以 65-10=55
    }
  }
  
  @override
  Widget build(BuildContext context) {
    // 如果課程為空，直接返回空視圖
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
    
    // 使用緩存的課程網格,只在課程數據改變時才重新計算
    final courseGrid = _getCachedCourseGrid();
    final screenWidth = MediaQuery.of(context).size.width;
    
    // 計算實際有課的節次範圍
    final sectionRange = _calculateSectionRange(courseGrid);
    final minSection = sectionRange['min'] ?? 0;
    final maxSection = sectionRange['max'] ?? 13;
    
    // 計算每列寬度(扣除節次欄和邊距)
    final dayWidth = (screenWidth - 16 - 32) / 5; // 16 for section, 32 for padding, 5 days
    
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    // 構建課表列
    final tableColumns = [
      // 表頭：星期
      _buildHeader(context, dayWidth),
      // 課表內容（只顯示有課的節次範圍）
      ...() {
        final widgets = <Widget>[];
        for (int sectionIndex = minSection; sectionIndex <= maxSection; sectionIndex++) {
          widgets.add(_buildSection(context, sectionIndex, courseGrid, dayWidth));
          
          // 在第 4 節後添加午休分隔（第 4 節的 index 是 3）
          // 只在午休時間在顯示範圍內時才顯示
          if (sectionIndex == 3 && maxSection >= 4) {
            widgets.add(_buildLunchBreak(context, dayWidth));
          }
        }
        return widgets;
      }(),
    ];
    
    // 正常顯示的課表（可滾動）
    final scrollableTable = Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.3 : 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: SingleChildScrollView(
          child: Column(children: tableColumns),
        ),
      ),
    );
    
    // 截圖用的課表（完整高度、無滾動）
    final captureTable = Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: tableColumns,
        ),
      ),
    );
    
    // 如果有 repaintKey，需要同時顯示正常課表和隱藏的截圖用課表
    if (widget.repaintKey != null) {
      return Stack(
        children: [
          // 正常顯示的課表
          scrollableTable,
          // 隱藏的截圖用課表（移到螢幕外，完整高度）
          Positioned(
            left: -10000,
            top: 0,
            child: SizedBox(
              width: screenWidth - 32, // 與正常課表寬度一致
              child: RepaintBoundary(
                key: widget.repaintKey,
                child: captureTable,
              ),
            ),
          ),
        ],
      );
    }
    
    // 沒有 repaintKey 時，只顯示正常課表
    return scrollableTable;
  }
  
  /// 計算實際有課的節次範圍
  /// 返回 {'min': 最早節次索引, 'max': 最晚節次索引}
  Map<String, int> _calculateSectionRange(Map<String, List<Map<String, dynamic>>> courseGrid) {
    if (courseGrid.isEmpty) {
      // 沒有課程，顯示預設範圍（第1節到第10節）
      return {'min': 0, 'max': 9};
    }
    
    int minSection = 13; // 最晚可能的節次
    int maxSection = 0;  // 最早可能的節次
    
    // 遍歷所有課程格子，找出最早和最晚的節次
    for (final key in courseGrid.keys) {
      if (courseGrid[key]?.isEmpty ?? true) continue;
      
      // 解析 key，格式為 "星期-節次"，例如 "一-3" 或 "一-A"
      final parts = key.split('-');
      if (parts.length != 2) continue;
      
      final sectionStr = parts[1];
      int sectionIndex;
      
      // 處理數字和字母形式的節次
      if (int.tryParse(sectionStr) != null) {
        sectionIndex = int.parse(sectionStr) - 1; // 轉換為 0-based index
      } else {
        // 字母形式：A=第10節(index=9), B=第11節(index=10), C=第12節(index=11)...
        final charCode = sectionStr.codeUnitAt(0);
        sectionIndex = charCode - 56; // 'A'=65, 65-56=9
      }
      
      if (sectionIndex >= 0 && sectionIndex < 14) {
        minSection = minSection < sectionIndex ? minSection : sectionIndex;
        maxSection = maxSection > sectionIndex ? maxSection : sectionIndex;
      }
    }
    
    // 如果沒有找到任何課程，返回預設範圍
    if (minSection > maxSection) {
      return {'min': 0, 'max': 9};
    }
    
    // 智能調整顯示範圍:只顯示有課的節次範圍
    // 不再強制從第 1 節開始或顯示到中午
    
    return {'min': minSection, 'max': maxSection};
  }
  
  Widget _buildLunchBreak(BuildContext context, double dayWidth) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final colorScheme = Theme.of(context).colorScheme;
    
    return Container(
      height: 24,
      color: isDark 
          ? colorScheme.surfaceContainerHighest
          : colorScheme.surfaceContainerHigh,
      child: Row(
        children: [
          // 左側節次欄位置
          Container(
            width: 16,
            color: isDark 
                ? colorScheme.surfaceContainerHighest
                : Colors.grey.shade50,
            child: Center(
              child: Icon(
                Icons.restaurant,
                size: 12,
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          // 午休文字橫跨所有天
          Expanded(
            child: Center(
              child: Text(
                '午休時間',
                style: TextStyle(
                  fontSize: 12,
                  color: colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildHeader(BuildContext context, double dayWidth) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Container(
      decoration: BoxDecoration(
        color: isDark 
            ? Theme.of(context).colorScheme.surfaceContainerHighest
            : Theme.of(context).primaryColor.withOpacity(0.08),
      ),
      child: Row(
        children: [
          // 左上角：節次（極度壓縮空間）
          SizedBox(
            width: 16,
            height: 32,
            child: Center(
              child: Text(
                '',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 10,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
            ),
          ),
          // 星期
          ...weekDays.map((day) {
            return SizedBox(
              width: dayWidth,
              height: 32,
              child: Center(
                child: Text(
                  '週$day',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
  
  Widget _buildSection(BuildContext context, int sectionIndex, Map<String, List<Map<String, dynamic>>> courseGrid, double dayWidth) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Container(
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: isDark 
                ? Theme.of(context).colorScheme.outline.withOpacity(0.3)
                : Colors.grey.shade200,
            width: 0.5,
          ),
        ),
      ),
      child: Row(
        children: [
          // 節次編號（支援 A/B/C 顯示，極度壓縮空間）
          Container(
            width: 16,
            height: 65,
            color: isDark 
                ? Theme.of(context).colorScheme.surfaceContainerHighest
                : Colors.grey.shade50,
            child: Center(
              child: Text(
                _getSectionLabel(sectionIndex),
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 11,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
            ),
          ),
          // 每天的課程
          ...weekDays.map((day) {
            // 支援數字和字母形式查找（例如 "一-10" 或 "一-A"）
            final sectionNumber = sectionIndex + 1;
            String keyNum = '$day-$sectionNumber';
            String keyLetter = '$day-${_getSectionLabel(sectionIndex)}';
            
            // 先嘗試數字形式，再嘗試字母形式
            final coursesInSlot = courseGrid[keyNum] ?? courseGrid[keyLetter] ?? [];
            
            return Container(
              width: dayWidth,
              height: 65,
              decoration: BoxDecoration(
                border: Border(
                  left: BorderSide(
                    color: isDark 
                        ? Theme.of(context).colorScheme.outline.withOpacity(0.3)
                        : Colors.grey.shade200,
                    width: 0.5,
                  ),
                ),
              ),
              child: coursesInSlot.isEmpty
                  ? const SizedBox.expand()  // 保持格子大小，確保可以點擊
                  : _buildCourseCard(context, coursesInSlot.first),
            );
          }),
        ],
      ),
    );
  }
  
  Widget _buildCourseCard(BuildContext context, Map<String, dynamic> course) {
    final courseId = course['courseId'] ?? '';
    final courseName = course['courseName'] ?? '';
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final seedColor = Theme.of(context).colorScheme.primary;
    
    // 使用 Provider.of 而非 context.watch，避免在構建過程中導致佈局問題
    final themeSettings = Provider.of<ThemeSettingsService>(context, listen: false);
    final colorStyle = themeSettings.courseColorStyle;
    
    // 使用 Material You 風格的顏色服務
    final color = widget.colorService != null 
        ? widget.colorService!.getCourseColor(
            courseId, 
            courseName,
            isDark: isDark,
            seedColor: seedColor,
            colorStyle: colorStyle,
          )
        : _generateColorFromCourseId(courseId);
    
    // 獲取漸層顏色組
    final gradientColors = widget.colorService != null
        ? widget.colorService!.getCourseGradientColors(
            courseId,
            courseName,
            isDark: isDark,
            seedColor: seedColor,
            colorStyle: colorStyle,
          )
        : [
            color,
            color.withOpacity(0.85),
            color.withOpacity(0.7),
          ];
    
    final textColor = widget.colorService != null
        ? widget.colorService!.getOnCourseColor(
            courseId,
            courseName,
            isDark: isDark,
            seedColor: seedColor,
            colorStyle: colorStyle,
          )
        : Colors.white;
    
    return Container(
      margin: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        // 優雅的三色漸層，營造柔和的深度感
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: gradientColors,
          stops: const [0.0, 0.5, 1.0], // 漸層過渡點
        ),
        borderRadius: BorderRadius.circular(10),
        // Material You 風格的柔和陰影
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.25),
            blurRadius: 6,
            offset: const Offset(0, 2),
            spreadRadius: 0,
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: widget.onCourseTap != null ? () => widget.onCourseTap!(course) : null,
          onLongPress: widget.colorService != null ? () => _showColorPicker(context, course) : null,
          borderRadius: BorderRadius.circular(10),
          splashColor: Colors.white.withOpacity(0.2),
          highlightColor: Colors.white.withOpacity(0.1),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 7),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text(
                  courseName,
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w600,
                    color: textColor,
                    height: 1.2,
                    letterSpacing: 0.2,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                ),
                if (course['classroom']?.isNotEmpty == true) ...[
                  const SizedBox(height: 3),
                  Text(
                    course['classroom'],
                    style: TextStyle(
                      fontSize: 8.5,
                      color: textColor.withOpacity(0.85),
                      fontWeight: FontWeight.w500,
                      letterSpacing: 0.1,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
  
  /// 解析課程到網格(星期-節次)
  /// 獲取緩存的課程網格,避免重複計算
  Map<String, List<Map<String, dynamic>>> _getCachedCourseGrid() {
    // 使用課程數量來判斷是否需要重新計算,避免引用比較導致的重複計算
    final currentLength = widget.courses.length;
    if (_cachedCoursesLength != currentLength || _cachedCourseGrid == null) {
      _cachedCoursesLength = currentLength;
      _cachedCourseGrid = _buildCourseGrid();
    }
    return _cachedCourseGrid!;
  }
  
  @override
  void didUpdateWidget(WeeklyCourseTableClassic oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 當課程數據改變時,立即重新構建課程網格
    if (oldWidget.courses.length != widget.courses.length) {
      _cachedCoursesLength = widget.courses.length;
      if (widget.courses.isNotEmpty) {
        _cachedCourseGrid = _buildCourseGrid();
        _isInitialized = true;
      } else {
        _cachedCourseGrid = null;
        _isInitialized = false;
      }
    }
  }
  
  Map<String, List<Map<String, dynamic>>> _buildCourseGrid() {
    final grid = <String, List<Map<String, dynamic>>>{};
    
    for (final course in widget.courses) {
      // 解析時間資訊
      final scheduleJson = course['schedule'] as String?;
      if (scheduleJson == null || scheduleJson.isEmpty) continue;
      
      try {
        final schedule = json.decode(scheduleJson) as Map<String, dynamic>;
        
        // 遍歷每個星期
        schedule.forEach((day, sections) {
          if (sections == null || sections.toString().trim().isEmpty) return;
          
          // 解析節次（例如："3 4" 或 "7 8"）
          final sectionList = sections.toString().trim().split(' ');
          
          for (final sectionStr in sectionList) {
            if (sectionStr.isEmpty) continue;
            
            final key = '$day-$sectionStr';
            grid[key] = grid[key] ?? [];
            grid[key]!.add(course);
          }
        });
      } catch (e) {
        debugPrint('[WeeklyCourseTable] 解析課程時間失敗: $e');
      }
    }
    
    return grid;
  }
  
  /// 根據課號生成顏色
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
  
  /// 顯示顏色選擇器 - Material You 風格（支援三種配色風格）
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
    
    // 主題配色 / 彩虹配色：顯示 16 種顏色
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
}
