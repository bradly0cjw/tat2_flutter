/// 本地事件的重複類型
enum RecurrenceType {
  none,    // 不重複
  daily,   // 每天
  weekly,  // 每週
  monthly, // 每月
  yearly,  // 每年
}

/// 本地日曆事件模型（使用者自行建立的事件）
class LocalCalendarEvent {
  final int? id;
  final String title;
  final String? description;
  final DateTime startTime;
  final DateTime endTime;
  final String? location;
  final bool isAllDay;
  final RecurrenceType recurrenceType;
  final DateTime? recurrenceEndDate;
  final String color; // 事件顏色（十六進位字串，如 '#FF0000'）
  final DateTime? createdAt;
  final DateTime? updatedAt;

  LocalCalendarEvent({
    this.id,
    required this.title,
    this.description,
    required this.startTime,
    required this.endTime,
    this.location,
    this.isAllDay = false,
    this.recurrenceType = RecurrenceType.none,
    this.recurrenceEndDate,
    this.color = '#2196F3',
    this.createdAt,
    this.updatedAt,
  });

  /// 從資料庫 Map 創建事件（支援欄位容錯）
  factory LocalCalendarEvent.fromMap(Map<String, dynamic> map) {
    // 安全的字串轉日期方法
    DateTime? parseDateTime(dynamic value) {
      if (value == null) return null;
      if (value is String) {
        try {
          return DateTime.parse(value);
        } catch (e) {
          return null;
        }
      }
      return null;
    }

    // 安全的整數轉布林方法
    bool parseBool(dynamic value, {bool defaultValue = false}) {
      if (value == null) return defaultValue;
      if (value is int) return value == 1;
      if (value is bool) return value;
      return defaultValue;
    }

    // 安全的整數解析方法
    int parseInt(dynamic value, {int defaultValue = 0}) {
      if (value == null) return defaultValue;
      if (value is int) return value;
      if (value is String) {
        return int.tryParse(value) ?? defaultValue;
      }
      return defaultValue;
    }

    return LocalCalendarEvent(
      id: map['id'] as int?,
      title: (map['title'] ?? '') as String,
      description: map['description'] as String?,
      startTime: parseDateTime(map['start_time']) ?? DateTime.now(),
      endTime: parseDateTime(map['end_time']) ?? DateTime.now(),
      location: map['location'] as String?,
      isAllDay: parseBool(map['is_all_day']),
      recurrenceType: RecurrenceType.values[parseInt(map['recurrence_type'])],
      recurrenceEndDate: parseDateTime(map['recurrence_end_date']),
      color: (map['color'] as String?) ?? '#2196F3',
      createdAt: parseDateTime(map['created_at']),
      updatedAt: parseDateTime(map['updated_at']),
    );
  }

  /// 轉換為資料庫 Map
  Map<String, dynamic> toMap() {
    final now = DateTime.now();
    return {
      'id': id,
      'title': title,
      'description': description,
      'start_time': startTime.toIso8601String(),
      'end_time': endTime.toIso8601String(),
      'location': location,
      'is_all_day': isAllDay ? 1 : 0,
      'recurrence_type': recurrenceType.index,
      'recurrence_end_date': recurrenceEndDate?.toIso8601String(),
      'color': color,
      'created_at': (createdAt ?? now).toIso8601String(),
      'updated_at': (updatedAt ?? now).toIso8601String(),
    };
  }

  /// 複製事件並修改部分欄位
  LocalCalendarEvent copyWith({
    int? id,
    String? title,
    String? description,
    DateTime? startTime,
    DateTime? endTime,
    String? location,
    bool? isAllDay,
    RecurrenceType? recurrenceType,
    DateTime? recurrenceEndDate,
    String? color,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return LocalCalendarEvent(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      location: location ?? this.location,
      isAllDay: isAllDay ?? this.isAllDay,
      recurrenceType: recurrenceType ?? this.recurrenceType,
      recurrenceEndDate: recurrenceEndDate ?? this.recurrenceEndDate,
      color: color ?? this.color,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  /// 檢查事件是否在指定日期發生
  bool occursOnDate(DateTime date) {
    final eventDate = DateTime(startTime.year, startTime.month, startTime.day);
    final checkDate = DateTime(date.year, date.month, date.day);

    // 檢查基本日期範圍
    if (checkDate.isBefore(eventDate)) return false;
    if (recurrenceEndDate != null && checkDate.isAfter(recurrenceEndDate!)) {
      return false;
    }

    // 根據重複類型檢查
    switch (recurrenceType) {
      case RecurrenceType.none:
        return checkDate.isAtSameMomentAs(eventDate);
      case RecurrenceType.daily:
        return true;
      case RecurrenceType.weekly:
        return checkDate.weekday == eventDate.weekday;
      case RecurrenceType.monthly:
        return checkDate.day == eventDate.day;
      case RecurrenceType.yearly:
        return checkDate.month == eventDate.month &&
            checkDate.day == eventDate.day;
    }
  }

  /// 取得事件在指定日期的具體發生日期
  DateTime getOccurrenceDate(DateTime date) {
    if (recurrenceType == RecurrenceType.none) {
      return startTime;
    }

    // 對於重複事件，使用指定日期的日期部分 + 原始事件的時間部分
    return DateTime(
      date.year,
      date.month,
      date.day,
      startTime.hour,
      startTime.minute,
      startTime.second,
    );
  }

  /// 格式化顯示時間（全天事件不顯示時間）
  String get displayTime {
    if (isAllDay) {
      return '全天';
    }
    
    final startStr = '${startTime.hour.toString().padLeft(2, '0')}:${startTime.minute.toString().padLeft(2, '0')}';
    final endStr = '${endTime.hour.toString().padLeft(2, '0')}:${endTime.minute.toString().padLeft(2, '0')}';
    
    return '$startStr - $endStr';
  }

  /// 格式化顯示日期
  String get displayDate {
    final start = '${startTime.year}/${startTime.month}/${startTime.day}';
    
    // 如果是跨日事件，顯示結束日期
    if (!_isSameDay(startTime, endTime)) {
      final end = '${endTime.year}/${endTime.month}/${endTime.day}';
      return '$start - $end';
    }
    
    return start;
  }

  /// 完整的日期時間顯示
  String get displayDateTime {
    if (isAllDay) {
      return displayDate;
    }
    return '$displayDate $displayTime';
  }

  /// 檢查兩個日期是否是同一天
  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  @override
  String toString() {
    return 'LocalCalendarEvent(id: $id, title: $title, startTime: $startTime, endTime: $endTime, recurrence: $recurrenceType)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is LocalCalendarEvent &&
        other.id == id &&
        other.title == title &&
        other.startTime == startTime &&
        other.endTime == endTime;
  }

  @override
  int get hashCode {
    return Object.hash(id, title, startTime, endTime);
  }
}
