import 'package:flutter/material.dart' hide debugPrint;
import 'package:flutter/services.dart';
import 'package:flutter/rendering.dart';
import 'dart:convert';
import 'dart:ui' as ui;
import 'dart:io';
import 'package:path_provider/path_provider.dart';

/// 桌面小工具服務
/// 負責與 Android 桌面小工具通信，更新課表截圖
class WidgetService {
  static const MethodChannel _channel = MethodChannel('org.ntut.qaq/widget');

  /// 更新桌面小工具 - 使用課表截圖（類似 TAT）
  static Future<void> updateWidgetWithScreenshot(GlobalKey repaintKey) async {
    try {
      debugPrint('[WidgetService] 開始生成課表截圖...');
      
      // 等待一下確保渲染完成
      await Future.delayed(const Duration(milliseconds: 100));
      
      // 獲取 RenderObject
      final RenderRepaintBoundary boundary = 
          repaintKey.currentContext?.findRenderObject() as RenderRepaintBoundary;
      
  // 生成圖片（提高解析度）
  // 注意：pixelRatio 會直接乘上邏輯像素，過高可能導致記憶體不足，視實際效能可在 2.0~4.0 之間調整
  final ui.Image image = await boundary.toImage(pixelRatio: 3.0);
      final ByteData? byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      
      if (byteData == null) {
        debugPrint('[WidgetService] 無法生成圖片');
        return;
      }
      
      // 保存圖片到應用內部存儲
      // 使用固定文件名 course_table.png（與 Kotlin 中定義的一致）
      final directory = await getApplicationDocumentsDirectory();
      final imagePath = '${directory.path}/course_table.png';
      final file = File(imagePath);
      await file.writeAsBytes(byteData.buffer.asUint8List());

      debugPrint('[WidgetService] 課表截圖已保存: $imagePath, 大小: ${byteData.lengthInBytes} bytes');

      // 通知 Android 更新小工具
      await _channel.invokeMethod('updateWidgetImage', {
        'imagePath': imagePath,
      });

      debugPrint('[WidgetService] 小工具更新成功');
    } catch (e) {
      debugPrint('[WidgetService] 更新桌面小工具失敗: $e');
    }
  }

  /// 更新桌面小工具的今日課程（舊方法，保留以防需要）
  static Future<void> updateTodayCourses(List<Map<String, dynamic>> courses) async {
    try {
      // 獲取今天是星期幾
      final today = DateTime.now();
      final weekday = _getWeekdayString(today.weekday);

      debugPrint('[WidgetService] 更新小工具 - 今天是星期$weekday');

      // 過濾今日課程
      final todayCourses = _filterTodayCourses(courses, weekday);

      debugPrint('[WidgetService] 今日課程數量: ${todayCourses.length}');

      // 傳送到 Android
      await _channel.invokeMethod('updateWidget', {
        'courses': json.encode(todayCourses),
      });

      debugPrint('[WidgetService] 小工具更新成功');
    } catch (e) {
      debugPrint('[WidgetService] 更新桌面小工具失敗: $e');
    }
  }

  /// 過濾今日課程
  static List<Map<String, dynamic>> _filterTodayCourses(
    List<Map<String, dynamic>> courses,
    String weekday,
  ) {
    final todayCourses = <Map<String, dynamic>>[];
    
    for (final course in courses) {
      final schedule = course['schedule'] as String?;
      if (schedule == null || schedule.isEmpty) continue;
      
      try {
        // 解析 schedule JSON，格式如: {"一":"1 2","三":"5 6"}
        final scheduleMap = json.decode(schedule) as Map<String, dynamic>;
        
        // 檢查今天是否有課
        final todaySections = scheduleMap[weekday] as String?;
        if (todaySections != null && todaySections.isNotEmpty) {
          // 添加課程信息和節次
          todayCourses.add({
            'courseName': course['courseName'] ?? '未知課程',
            'courseId': course['courseId'] ?? '',
            'instructor': course['instructor'] ?? '',
            'classroom': course['classroom'] ?? '',
            'sections': todaySections, // 例如: "1 2" 或 "5 6"
            'credits': course['credits'] ?? '',
            'hours': course['hours'] ?? '',
          });
        }
      } catch (e) {
        debugPrint('[WidgetService] 解析課程時間失敗: $e, schedule: $schedule');
        continue;
      }
    }
    
    // 按節次排序
    todayCourses.sort((a, b) {
      final aSections = (a['sections'] as String).split(' ');
      final bSections = (b['sections'] as String).split(' ');
      
      final aFirst = _getSectionOrder(aSections.first);
      final bFirst = _getSectionOrder(bSections.first);
      
      return aFirst.compareTo(bFirst);
    });
    
    return todayCourses;
  }

  /// 獲取節次的排序順序
  static int _getSectionOrder(String section) {
    const sectionOrder = {
      '1': 1, '2': 2, '3': 3, '4': 4,
      'N': 5,
      '5': 6, '6': 7, '7': 8, '8': 9, '9': 10,
      'A': 11, 'B': 12, 'C': 13, 'D': 14,
    };
    return sectionOrder[section] ?? 99;
  }

  /// 將 weekday 數字轉換為中文
  static String _getWeekdayString(int weekday) {
    switch (weekday) {
      case 1: return '一';
      case 2: return '二';
      case 3: return '三';
      case 4: return '四';
      case 5: return '五';
      case 6: return '六';
      case 7: return '日';
      default: return '';
    }
  }

  /// 清除小工具數據
  static Future<void> clearWidget() async {
    try {
      await _channel.invokeMethod('updateWidget', {
        'courses': json.encode([]),
      });
      debugPrint('[WidgetService] 小工具已清除');
    } catch (e) {
      debugPrint('[WidgetService] 清除小工具失敗: $e');
    }
  }
}

void debugPrint(String message) {
  print(message);
}
