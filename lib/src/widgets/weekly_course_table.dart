import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/course_color_service.dart';
import '../services/theme_settings_service.dart';
import 'weekly_course_table_material3.dart';
import 'weekly_course_table_classic.dart';
import 'weekly_course_table_tat.dart';

/// 週課表組件統一入口
/// 
/// 根據用戶設定自動選擇課表風格：
/// - Material 3 風格（懸浮卡片設計）
/// - 經典風格（表格式、緊湊佈局）
/// 
/// 支援顯示：
/// - 個人課表
/// - 微學程課表
/// - 學程課表
/// - 各班課表
class WeeklyCourseTable extends StatelessWidget {
  final List<Map<String, dynamic>> courses;
  final Function(Map<String, dynamic>)? onCourseTap;
  final CourseColorService? colorService;
  final GlobalKey? repaintKey;
  
  const WeeklyCourseTable({
    super.key,
    required this.courses,
    this.onCourseTap,
    this.colorService,
    this.repaintKey,
  });

  @override
  Widget build(BuildContext context) {
    // 從設定服務獲取當前課表風格
    final themeSettings = context.watch<ThemeSettingsService>();
    final courseTableStyle = themeSettings.courseTableStyle;
    
    // 根據風格選擇對應的組件
    switch (courseTableStyle) {
      case CourseTableStyle.material3:
        return WeeklyCourseTableMaterial3(
          courses: courses,
          onCourseTap: onCourseTap,
          colorService: colorService,
          repaintKey: repaintKey,
        );
      
      case CourseTableStyle.classic:
        return WeeklyCourseTableClassic(
          courses: courses,
          onCourseTap: onCourseTap,
          colorService: colorService,
          repaintKey: repaintKey,
        );
      
      // TAT 傳統風格
      case CourseTableStyle.tat:
        return WeeklyCourseTableTat(
          courses: courses,
          onCourseTap: onCourseTap,
          colorService: colorService,
          repaintKey: repaintKey,
        );
      
      default:
        // 預設使用 Material 3 風格
        return WeeklyCourseTableMaterial3(
          courses: courses,
          onCourseTap: onCourseTap,
          colorService: colorService,
          repaintKey: repaintKey,
        );
    }
  }
}
