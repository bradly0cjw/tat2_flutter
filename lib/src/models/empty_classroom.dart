/// 空教室資料模型
class EmptyClassroom {
  final String name;
  final String category;
  final List<String> timetable; // 空閒時段
  final String? link;

  EmptyClassroom({
    required this.name,
    required this.category,
    required this.timetable,
    this.link,
  });

  factory EmptyClassroom.fromJson(Map<String, dynamic> json) {
    return EmptyClassroom(
      name: json['name'] as String,
      category: json['category'] as String,
      timetable: (json['timetable'] as List<dynamic>)
          .map((e) => e.toString())
          .toList(),
      link: json['link'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'category': category,
      'timetable': timetable,
      'link': link,
    };
  }

  /// 檢查指定時段是否空閒
  bool isAvailableAt(String period) {
    return timetable.contains(period);
  }

  /// 取得空閒時段數量
  int get availablePeriodsCount => timetable.length;
}

/// 教室查詢回應
class EmptyClassroomResponse {
  final bool success;
  final String dayOfWeek;
  final List<String> periods;
  final int count;
  final List<EmptyClassroom> data;

  EmptyClassroomResponse({
    required this.success,
    required this.dayOfWeek,
    required this.periods,
    required this.count,
    required this.data,
  });

  factory EmptyClassroomResponse.fromJson(Map<String, dynamic> json) {
    return EmptyClassroomResponse(
      success: json['success'] as bool,
      dayOfWeek: json['dayOfWeek'] as String,
      periods: (json['periods'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      count: json['count'] as int,
      data: (json['data'] as List<dynamic>)
          .map((e) => EmptyClassroom.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}
