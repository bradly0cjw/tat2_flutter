/// 課程模型
class Course {
  final String courseId;
  final String courseName;
  final String? instructor;
  final String? location;
  final String? timeSlots;
  final String semester;
  final double? credits;
  final Map<String, dynamic>? extra;

  Course({
    required this.courseId,
    required this.courseName,
    this.instructor,
    this.location,
    this.timeSlots,
    required this.semester,
    this.credits,
    this.extra,
  });

  factory Course.fromJson(Map<String, dynamic> json) {
    return Course(
      courseId: json['courseId'] ?? json['course_id'] ?? '',
      courseName: json['courseName'] ?? json['course_name'] ?? '',
      instructor: json['instructor'],
      location: json['location'],
      timeSlots: json['timeSlots'] ?? json['time_slots'],
      semester: json['semester'] ?? '',
      credits: json['credits']?.toDouble(),
      extra: json['courseData'] != null 
          ? Map<String, dynamic>.from(json['courseData'])
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'courseId': courseId,
      'courseName': courseName,
      'instructor': instructor,
      'location': location,
      'timeSlots': timeSlots,
      'semester': semester,
      'credits': credits,
    };
  }

  /// 解析上課時間（例如 "二234" → "週二 10:10-13:00"）
  String get formattedTime {
    if (timeSlots == null || timeSlots!.isEmpty) return '時間未定';
    
    // 簡化版，實際需要更複雜的解析
    final weekdayMap = {
      '一': '週一', '二': '週二', '三': '週三', 
      '四': '週四', '五': '週五', '六': '週六', '日': '週日',
    };
    
    final firstChar = timeSlots!.substring(0, 1);
    final weekday = weekdayMap[firstChar] ?? '';
    return '$weekday $timeSlots';
  }
}
