/// 日曆事件模型
/// 用於表示學校行事曆的事件資訊
class CalendarEvent {
  final String id;
  final String summary; // 事件標題
  final DateTime start;
  final DateTime end;
  final String? description;
  final String? location;
  final bool isAllDay;
  final String? type; // 事件類型：school, course, personal 等

  CalendarEvent({
    required this.id,
    required this.summary,
    required this.start,
    required this.end,
    this.description,
    this.location,
    this.isAllDay = false,
    this.type = 'school',
  });

  /// 從 JSON 創建事件（用於解析 ntut-course-crawler-node 的 calendar.json）
  factory CalendarEvent.fromJson(Map<String, dynamic> json) {
    DateTime parseDate(dynamic dateStr) {
      if (dateStr is DateTime) return dateStr;
      if (dateStr is String) {
        return DateTime.parse(dateStr);
      }
      return DateTime.now();
    }

    return CalendarEvent(
      id: json['uid']?.toString() ?? '',
      summary: json['summary']?.toString() ?? '',
      start: parseDate(json['start']),
      end: parseDate(json['end']),
      description: json['description']?.toString(),
      location: json['location']?.toString(),
      isAllDay: json['datetype'] == 'date',
      type: json['type']?.toString() ?? 'school',
    );
  }

  /// 轉換為 JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'summary': summary,
      'start': start.toIso8601String(),
      'end': end.toIso8601String(),
      'description': description,
      'location': location,
      'isAllDay': isAllDay,
      'type': type,
    };
  }

  /// 檢查事件是否在指定日期
  bool isOnDate(DateTime date) {
    // 標準化為日期（去除時間部分）
    final checkDate = DateTime(date.year, date.month, date.day);
    final eventStartDate = DateTime(start.year, start.month, start.day);
    final eventEndDate = DateTime(end.year, end.month, end.day);
    
    // 檢查日期是否在事件的開始和結束日期之間（包含邊界）
    return (checkDate.isAtSameMomentAs(eventStartDate) || 
            checkDate.isAtSameMomentAs(eventEndDate) ||
            (checkDate.isAfter(eventStartDate) && checkDate.isBefore(eventEndDate)));
  }
  
  /// 檢查事件是否只在指定日期開始（用於避免重複顯示跨日事件）
  bool startsOnDate(DateTime date) {
    final checkDate = DateTime(date.year, date.month, date.day);
    final eventStartDate = DateTime(start.year, start.month, start.day);
    return checkDate.isAtSameMomentAs(eventStartDate);
  }

  /// 格式化日期範圍顯示
  String get dateRangeText {
    if (isAllDay) {
      if (isSameDay(start, end)) {
        return '${start.year}/${start.month}/${start.day}';
      } else {
        return '${start.year}/${start.month}/${start.day} - ${end.year}/${end.month}/${end.day}';
      }
    } else {
      return '${start.year}/${start.month}/${start.day} ${start.hour}:${start.minute.toString().padLeft(2, '0')}';
    }
  }

  /// 檢查兩個日期是否是同一天
  static bool isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  @override
  String toString() => summary;
}

/// 課程事件（從課程表衍生的日曆事件）
class CourseEvent extends CalendarEvent {
  final String courseId;
  final String courseName;
  final String? instructor;
  final String? classroom;

  CourseEvent({
    required super.id,
    required this.courseId,
    required this.courseName,
    required super.start,
    required super.end,
    this.instructor,
    this.classroom,
    super.description,
  }) : super(
          summary: courseName,
          location: classroom,
          type: 'course',
        );

  /// 從課程資料創建課程事件
  factory CourseEvent.fromCourse({
    required String courseId,
    required String courseName,
    required DateTime dateTime,
    required int startPeriod,
    required int endPeriod,
    String? instructor,
    String? classroom,
  }) {
    // 計算課程開始和結束時間
    final startTime = _getPeriodTime(dateTime, startPeriod);
    final endTime = _getPeriodTime(dateTime, endPeriod, isEnd: true);

    return CourseEvent(
      id: '${courseId}_${dateTime.millisecondsSinceEpoch}',
      courseId: courseId,
      courseName: courseName,
      start: startTime,
      end: endTime,
      instructor: instructor,
      classroom: classroom,
      description: instructor != null ? '授課教師：$instructor' : null,
    );
  }

  /// 獲取節次對應的時間
  static DateTime _getPeriodTime(DateTime date, int period, {bool isEnd = false}) {
    // 北科大課程時間表（可以根據實際情況調整）
    final Map<int, List<int>> periodTimes = {
      1: [8, 10],   // 08:10-09:00
      2: [9, 10],   // 09:10-10:00
      3: [10, 10],  // 10:10-11:00
      4: [11, 10],  // 11:10-12:00
      5: [12, 10],  // 12:10-13:00 (午休)
      6: [13, 10],  // 13:10-14:00
      7: [14, 10],  // 14:10-15:00
      8: [15, 10],  // 15:10-16:00
      9: [16, 10],  // 16:10-17:00
      10: [17, 10], // 17:10-18:00
      11: [18, 25], // 18:25-19:15
      12: [19, 20], // 19:20-20:10
      13: [20, 15], // 20:15-21:05
      14: [21, 10], // 21:10-22:00
    };

    final time = periodTimes[period] ?? [8, 10];
    final minute = isEnd ? time[1] + 50 : time[1];
    final hour = minute >= 60 ? time[0] + 1 : time[0];
    final adjustedMinute = minute >= 60 ? minute - 60 : minute;

    return DateTime(date.year, date.month, date.day, hour, adjustedMinute);
  }
}
