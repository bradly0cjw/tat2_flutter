import 'package:flutter/material.dart';
import 'dart:convert';
import '../services/course_color_service.dart';

/// 可複用的週課表組件 - Material 3 風格
/// 
/// 支援顯示：
/// - 個人課表
/// - 微學程課表
/// - 學程課表
/// - 各班課表
class WeeklyCourseTable extends StatefulWidget {
  final List<Map<String, dynamic>> courses;
  final Function(Map<String, dynamic>)? onCourseTap;
  final CourseColorService? colorService;
  final GlobalKey? repaintKey; // 用於截圖的 key
  
  const WeeklyCourseTable({
    super.key,
    required this.courses,
    this.onCourseTap,
    this.colorService,
    this.repaintKey,
  });

  @override
  State<WeeklyCourseTable> createState() => _WeeklyCourseTableState();
}

/// 合併後的課程塊（用於相鄰課程合併）
class _MergedCourse {
  final Map<String, dynamic> course;
  final int dayIndex; // 0-4 對應週一到週五
  final int startSection; // 開始節次（0-based）
  final int endSection; // 結束節次（0-based，包含）
  
  _MergedCourse({
    required this.course,
    required this.dayIndex,
    required this.startSection,
    required this.endSection,
  });
  
  int get sectionCount => endSection - startSection + 1;
}

class _WeeklyCourseTableState extends State<WeeklyCourseTable> {
  // 緩存合併後的課程
  List<_MergedCourse>? _cachedMergedCourses;
  int _cachedCoursesLength = -1;
  bool _isInitialized = false;
  
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
    
    // 在 initState 時立即構建合併後的課程,避免首次渲染時的延遲
    if (widget.courses.isNotEmpty) {
      _cachedCoursesLength = widget.courses.length;
      _cachedMergedCourses = _buildMergedCourses();
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
      // sectionNumber=10 -> 'A'(65), sectionNumber=11 -> 'B'(66)
      return String.fromCharCode(65 + sectionNumber - 10); // A=65, 10節開始
    }
  }
  
  /// 構建合併後的課程列表（相鄰的同一課程合併成一個大卡片）
  List<_MergedCourse> _buildMergedCourses() {
    final mergedCourses = <_MergedCourse>[];
    
    // 首先構建課程網格
    final courseGrid = <String, Map<String, dynamic>>{};
    
    for (final course in widget.courses) {
      final scheduleJson = course['schedule'] as String?;
      if (scheduleJson == null || scheduleJson.isEmpty) continue;
      
      try {
        final schedule = json.decode(scheduleJson) as Map<String, dynamic>;
        
        schedule.forEach((day, sections) {
          if (sections == null || sections.toString().trim().isEmpty) return;
          
          final sectionList = sections.toString().trim().split(' ');
          
          for (final sectionStr in sectionList) {
            if (sectionStr.isEmpty) continue;
            final key = '$day-$sectionStr';
            courseGrid[key] = course;
          }
        });
      } catch (e) {
        debugPrint('[WeeklyCourseTable] 解析課程時間失敗: $e');
      }
    }
    
    // 對每個星期的每個課程進行合併
    for (int dayIndex = 0; dayIndex < weekDays.length; dayIndex++) {
      final day = weekDays[dayIndex];
      final processedSections = <int>{};
      
      // 遍歷所有可能的節次
      for (int section = 0; section < sectionTimes.length; section++) {
        if (processedSections.contains(section)) continue;
        
        // 支援數字和字母兩種格式查找
        final keyNum = '$day-${section + 1}';
        final keyLetter = '$day-${_getSectionLabel(section)}';
        final course = courseGrid[keyNum] ?? courseGrid[keyLetter];
        
        if (course == null) continue;
        
        final courseId = course['courseId'] ?? '';
        
        // 找出連續的相同課程
        int endSection = section;
        for (int nextSection = section + 1; nextSection < sectionTimes.length; nextSection++) {
          final nextKeyNum = '$day-${nextSection + 1}';
          final nextKeyLetter = '$day-${_getSectionLabel(nextSection)}';
          final nextCourse = courseGrid[nextKeyNum] ?? courseGrid[nextKeyLetter];
          
          if (nextCourse != null && (nextCourse['courseId'] ?? '') == courseId) {
            endSection = nextSection;
            processedSections.add(nextSection);
          } else {
            break;
          }
        }
        
        processedSections.add(section);
        
        mergedCourses.add(_MergedCourse(
          course: course,
          dayIndex: dayIndex,
          startSection: section,
          endSection: endSection,
        ));
      }
    }
    
    return mergedCourses;
  }
  
  @override
  Widget build(BuildContext context) {
    // 如果還沒初始化完成,顯示佔位符避免閃現空課表
    if (!_isInitialized && widget.courses.isEmpty) {
      return const SizedBox.shrink();
    }
    
    // 使用緩存的合併課程
    final mergedCourses = _getCachedMergedCourses();
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    
    // 計算實際有課的節次範圍
    final sectionRange = _calculateSectionRange(mergedCourses);
    final minSection = sectionRange['min'] ?? 0;
    final maxSection = sectionRange['max'] ?? 13;
    
    // 構建主課表視圖
    final courseTableWidget = _buildCourseTableView(
      context,
      mergedCourses,
      minSection,
      maxSection,
      screenWidth - 8, // 扣除左右 padding (4 + 4)
    );
    
    // 如果有 repaintKey，需要提供截圖用的視圖
    if (widget.repaintKey != null) {
      return Stack(
        children: [
          // 正常顯示的課表
          courseTableWidget,
          // 隱藏的截圖用課表（移到螢幕外，完整高度）
          Positioned(
            left: -10000,
            top: 0,
            child: SizedBox(
              width: screenWidth - 8,
              child: RepaintBoundary(
                key: widget.repaintKey,
                child: _buildCourseTableView(
                  context,
                  mergedCourses,
                  minSection,
                  maxSection,
                  screenWidth - 8,
                  isCapture: true,
                ),
              ),
            ),
          ),
        ],
      );
    }
    
    return courseTableWidget;
  }
  
  /// 構建課表視圖（Material 3 風格 - 懸浮卡片疊加設計）
  Widget _buildCourseTableView(
    BuildContext context,
    List<_MergedCourse> mergedCourses,
    int minSection,
    int maxSection,
    double width, {
    bool isCapture = false,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final colorScheme = Theme.of(context).colorScheme;
    
    // 標籤尺寸（增大，添加徽章背景）
    const labelHeight = 36.0; // 縮小頂部高度
    const labelWidth = 36.0; // 增加左側寬度
    const sectionHeight = 70.0;
    const lunchBreakHeight = 26.0; // 午休欄本身高度（縮小）
    const lunchBreakTopMargin = 4.0; // 午休欄上方間距
    const lunchBreakBottomMargin = 4.0; // 午休欄下方間距（縮小）
    
    // 計算內容區域尺寸
    final contentWidth = width - labelWidth - 8; // 8 for horizontal padding (left 4 + right 4)
    final dayWidth = contentWidth / 5;
    
    // 計算是否需要午休欄及總高度
    final hasLunchBreak = minSection <= 3 && maxSection >= 4;
    final lunchBreakTotalHeight = hasLunchBreak 
        ? (lunchBreakHeight + lunchBreakTopMargin + lunchBreakBottomMargin) 
        : 0;
    final totalHeight = labelHeight + 
                       (maxSection - minSection + 1) * sectionHeight + 
                       lunchBreakTotalHeight;
    
    // 午休欄位置（在第4節後）
    final lunchBreakPosition = hasLunchBreak ? labelHeight + (4 - minSection) * sectionHeight : null;
    final lunchBreakActualHeight = lunchBreakHeight + lunchBreakTopMargin + lunchBreakBottomMargin;
    
    // 構建課表內容
    final courseTableContent = Container(
      width: width,
      height: totalHeight,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // 背景層：低調的標籤和參考線
          _buildBackgroundLayer(
            context,
            minSection,
            maxSection,
            labelHeight,
            labelWidth,
            sectionHeight,
            dayWidth,
            contentWidth,
            lunchBreakPosition,
            lunchBreakHeight,
            lunchBreakTopMargin,
            lunchBreakBottomMargin,
            hasLunchBreak,
          ),
          
          // 課程層：懸浮的課程卡片
          _buildCourseLayer(
            context,
            mergedCourses,
            minSection,
            labelHeight,
            labelWidth,
            sectionHeight,
            dayWidth,
            lunchBreakPosition,
            lunchBreakActualHeight,
          ),
        ],
      ),
    );
    
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.only(left: 4, right: 4, top: 4, bottom: 16),
        child: courseTableContent,
      ),
    );
  }
  
  /// 背景層：徽章標籤和格線
  Widget _buildBackgroundLayer(
    BuildContext context,
    int minSection,
    int maxSection,
    double labelHeight,
    double labelWidth,
    double sectionHeight,
    double dayWidth,
    double contentWidth,
    double? lunchBreakPosition,
    double lunchBreakHeight,
    double lunchBreakTopMargin,
    double lunchBreakBottomMargin,
    bool hasLunchBreak,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final colorScheme = Theme.of(context).colorScheme;
    
    final widgets = <Widget>[];
    double currentTop = 0;
    
    // 頂部：星期標籤（徽章風格）
    widgets.add(
      Positioned(
        top: currentTop,
        left: 0,
        child: Row(
          children: [
            // 左上角空白
            SizedBox(width: labelWidth, height: labelHeight),
            
            // 星期標籤（徽章風格）
            ...List.generate(5, (index) {
              return Container(
                width: dayWidth,
                height: labelHeight,
                alignment: Alignment.center,
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2), // 縮小上下 padding
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5), // 縮小上下 padding
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        colorScheme.primaryContainer,
                        colorScheme.secondaryContainer,
                      ],
                    ),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: colorScheme.primary.withOpacity(0.15),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Text(
                    '週${weekDays[index]}',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: colorScheme.onPrimaryContainer,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              );
            }),
          ],
        ),
      ),
    );
    
    currentTop += labelHeight;
    
    // 節次標籤和內容區域（添加格線）
    for (int index = 0; index <= maxSection - minSection; index++) {
      final sectionIndex = minSection + index;
      
      // 如果需要在第4節後插入午休欄
      if (hasLunchBreak && sectionIndex == 4) {
        // 午休欄（增強視覺效果，調整間距）
        widgets.add(
          Positioned(
            top: currentTop + lunchBreakTopMargin,
            left: labelWidth,
            child: Container(
              width: contentWidth,
              height: lunchBreakHeight,
              margin: const EdgeInsets.symmetric(horizontal: 4), // 只保留左右間距
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                  colors: isDark 
                      ? [
                          colorScheme.tertiaryContainer.withOpacity(0.4),
                          colorScheme.tertiaryContainer.withOpacity(0.25),
                          colorScheme.tertiaryContainer.withOpacity(0.4),
                        ]
                      : [
                          colorScheme.tertiaryContainer.withOpacity(0.5),
                          colorScheme.tertiaryContainer.withOpacity(0.35),
                          colorScheme.tertiaryContainer.withOpacity(0.5),
                        ],
                ),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: colorScheme.outline.withOpacity(0.15),
                  width: 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: colorScheme.tertiary.withOpacity(0.1),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Center(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.restaurant_rounded,
                      size: 16,
                      color: colorScheme.onTertiaryContainer.withOpacity(0.8),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '午休時間',
                      style: TextStyle(
                        fontSize: 13,
                        color: colorScheme.onTertiaryContainer.withOpacity(0.8),
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
        currentTop += lunchBreakHeight + lunchBreakTopMargin + lunchBreakBottomMargin;
      }
      
      // 節次行（添加背景格線）
      widgets.add(
        Positioned(
          top: currentTop,
          left: 0,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 左側節次標籤（徽章風格）
              Container(
                width: labelWidth,
                height: sectionHeight,
                alignment: Alignment.center,
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                child: Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        colorScheme.secondaryContainer,
                        colorScheme.tertiaryContainer,
                      ],
                    ),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: colorScheme.secondary.withOpacity(0.2),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Center(
                    child: Text(
                      _getSectionLabel(sectionIndex),
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: colorScheme.onSecondaryContainer,
                      ),
                    ),
                  ),
                ),
              ),
              
              // 內容區域（添加格線背景）
              SizedBox(
                width: contentWidth,
                height: sectionHeight,
                child: CustomPaint(
                  painter: _GridPainter(
                    dayWidth: dayWidth,
                    gridColor: colorScheme.outline.withOpacity(0.08),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
      
      currentTop += sectionHeight;
    }
    
    return Stack(
      children: widgets,
    );
  }
  
  /// 課程層：懸浮的課程卡片
  Widget _buildCourseLayer(
    BuildContext context,
    List<_MergedCourse> mergedCourses,
    int minSection,
    double labelHeight,
    double labelWidth,
    double sectionHeight,
    double dayWidth,
    double? lunchBreakPosition,
    double lunchBreakActualHeight,
  ) {
    return Stack(
      children: mergedCourses.map((merged) {
        // 計算卡片位置和尺寸
        final left = labelWidth + merged.dayIndex * dayWidth;
        
        // 計算 top 位置，需要考慮午休欄的影響
        var top = labelHeight + (merged.startSection - minSection) * sectionHeight;
        
        // 如果課程在第5節（午休後）或更晚，需要加上午休欄高度
        if (lunchBreakPosition != null && merged.startSection >= 4) {
          top += lunchBreakActualHeight;
        }
        
        final height = merged.sectionCount * sectionHeight;
        
        return Positioned(
          left: left,
          top: top,
          width: dayWidth,
          height: height,
          child: _buildFloatingCourseCard(context, merged),
        );
      }).toList(),
    );
  }
  
  /// 構建懸浮的課程卡片（Material 3 風格 - 增強層次感）
  Widget _buildFloatingCourseCard(BuildContext context, _MergedCourse merged) {
    final course = merged.course;
    final courseId = course['courseId'] ?? '';
    final courseName = course['courseName'] ?? '';
    final classroom = course['classroom'] ?? '';
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final seedColor = Theme.of(context).colorScheme.primary;
    
    // 使用顏色服務獲取課程顏色
    final color = widget.colorService != null 
        ? widget.colorService!.getCourseColor(
            courseId, 
            courseName,
            isDark: isDark,
            seedColor: seedColor,
          )
        : _generateColorFromCourseId(courseId);
    
    final gradientColors = widget.colorService != null
        ? widget.colorService!.getCourseGradientColors(
            courseId,
            courseName,
            isDark: isDark,
            seedColor: seedColor,
          )
        : [color, color.withOpacity(0.85), color.withOpacity(0.7)];
    
    final textColor = widget.colorService != null
        ? widget.colorService!.getOnCourseColor(
            courseId,
            courseName,
            isDark: isDark,
            seedColor: seedColor,
          )
        : Colors.white;
    
    // Material 3 懸浮卡片，增強層次感
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 3),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: gradientColors,
          stops: const [0.0, 0.5, 1.0],
        ),
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          // 主陰影 - 近距離深色陰影
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.5 : 0.25),
            blurRadius: 8,
            offset: const Offset(0, 3),
            spreadRadius: 0,
          ),
          // 次陰影 - 遠距離柔和陰影
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.3 : 0.12),
            blurRadius: 16,
            offset: const Offset(0, 6),
            spreadRadius: -2,
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: widget.onCourseTap != null ? () => widget.onCourseTap!(course) : null,
          onLongPress: widget.colorService != null ? () => _showColorPicker(context, course) : null,
          borderRadius: BorderRadius.circular(14),
          splashColor: Colors.white.withOpacity(0.2),
          highlightColor: Colors.white.withOpacity(0.15),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // 課程名稱（縮小字體以顯示四個字）
                Text(
                  courseName,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: textColor,
                    height: 1.3,
                    letterSpacing: 0.2,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                ),
                
                // 教室
                if (classroom.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text(
                    classroom,
                    style: TextStyle(
                      fontSize: 8.5,
                      color: textColor.withOpacity(0.9),
                      fontWeight: FontWeight.w600,
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
  }  /// 計算實際有課的節次範圍
  /// 返回 {'min': 最早節次索引, 'max': 最晚節次索引}
  Map<String, int> _calculateSectionRange(List<_MergedCourse> mergedCourses) {
    if (mergedCourses.isEmpty) {
      // 沒有課程，顯示預設範圍（第1節到第10節）
      return {'min': 0, 'max': 9};
    }
    
    int minSection = 13; // 最晚可能的節次
    int maxSection = 0;  // 最早可能的節次
    
    // 遍歷所有合併的課程，找出最早和最晚的節次
    for (final merged in mergedCourses) {
      if (merged.startSection < minSection) {
        minSection = merged.startSection;
      }
      if (merged.endSection > maxSection) {
        maxSection = merged.endSection;
      }
    }
    
    // 如果沒有找到任何課程，返回預設範圍
    if (minSection > maxSection) {
      return {'min': 0, 'max': 9};
    }
    
    return {'min': minSection, 'max': maxSection};
  }
  

  
  /// 獲取緩存的合併課程,避免重複計算
  List<_MergedCourse> _getCachedMergedCourses() {
    // 使用課程數量來判斷是否需要重新計算
    final currentLength = widget.courses.length;
    if (_cachedCoursesLength != currentLength || _cachedMergedCourses == null) {
      _cachedCoursesLength = currentLength;
      _cachedMergedCourses = _buildMergedCourses();
    }
    return _cachedMergedCourses!;
  }
  
  @override
  void didUpdateWidget(WeeklyCourseTable oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 當課程數據改變時,立即重新構建合併課程
    if (oldWidget.courses.length != widget.courses.length) {
      _cachedCoursesLength = widget.courses.length;
      if (widget.courses.isNotEmpty) {
        _cachedMergedCourses = _buildMergedCourses();
        _isInitialized = true;
      } else {
        _cachedMergedCourses = null;
        _isInitialized = false;
      }
    }
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
  
  /// 顯示顏色選擇器 - Material You 風格
  void _showColorPicker(BuildContext context, Map<String, dynamic> course) {
    final courseName = course['courseName'] ?? '';
    final courseId = course['courseId'] ?? '';
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final seedColor = Theme.of(context).colorScheme.primary;
    
    // 獲取當前顏色
    final currentColor = widget.colorService?.getCourseColor(
      courseId, 
      courseName,
      isDark: isDark,
      seedColor: seedColor,
    );
    
    // 獲取可用顏色（Material You 風格 - 16 種）
    final availableColors = widget.colorService?.getAvailableColors(
      isDark: isDark,
      seedColor: seedColor,
    ) ?? [];
    
    // 獲取當前顏色的索引
    final currentIndex = widget.colorService?.getColorIndex(
      courseId,
      courseName,
      currentColor!,
      isDark: isDark,
      seedColor: seedColor,
    );
    
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
              '32 種精選配色：主題漸變 + 彩虹色系',
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
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // 第一組：主題漸變色
                Row(
                  children: [
                    Icon(
                      Icons.palette,
                      size: 18,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '主題漸變色',
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: Theme.of(context).colorScheme.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  alignment: WrapAlignment.start,
                  children: List.generate(16, (index) {
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
                
                const SizedBox(height: 24),
                
                // 第二組：通用彩虹色
                Row(
                  children: [
                    Icon(
                      Icons.color_lens,
                      size: 18,
                      color: Theme.of(context).colorScheme.secondary,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '彩虹色系',
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: Theme.of(context).colorScheme.secondary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  alignment: WrapAlignment.start,
                  children: List.generate(16, (index) {
                    final actualIndex = index + 16;
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
              ],
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

/// 格線繪製器
class _GridPainter extends CustomPainter {
  final double dayWidth;
  final Color gridColor;
  
  _GridPainter({
    required this.dayWidth,
    required this.gridColor,
  });
  
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = gridColor
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;
    
    // 繪製垂直線（分隔星期）
    for (int i = 1; i < 5; i++) {
      final x = i * dayWidth;
      canvas.drawLine(
        Offset(x, 0),
        Offset(x, size.height),
        paint,
      );
    }
    
    // 繪製水平線（底部邊界）
    canvas.drawLine(
      Offset(0, size.height),
      Offset(size.width, size.height),
      paint,
    );
  }
  
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
