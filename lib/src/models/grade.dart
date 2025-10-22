/// 成績模型
class Grade {
  final String courseId;
  final String courseName;
  final String semester;
  final double? credits;
  final String? grade;
  final double? score; // 數字成績 (0-100)
  final double? gradePoint;
  final String? openClass; // 開課班級（用於學分計算）
  final String? category; // 課程類別（用於學分計算）
  final Map<String, dynamic>? extra;

  Grade({
    required this.courseId,
    required this.courseName,
    required this.semester,
    this.credits,
    this.grade,
    this.score,
    this.gradePoint,
    this.openClass,
    this.category,
    this.extra,
  });

  factory Grade.fromJson(Map<String, dynamic> json) {
    // 合併 gradeData、semesterStats 和 extra 到 extra
    Map<String, dynamic>? extraData;
    
    if (json['gradeData'] != null) {
      extraData = Map<String, dynamic>.from(json['gradeData']);
    }
    
    if (json['semesterStats'] != null) {
      extraData ??= {};
      extraData['semesterStats'] = json['semesterStats'];
    }
    
    if (json['extra'] != null) {
      extraData = Map<String, dynamic>.from(json['extra']);
    }
    
    return Grade(
      courseId: json['courseId'] ?? json['course_id'] ?? '',
      courseName: json['courseName'] ?? json['course_name'] ?? '',
      semester: json['semester'] ?? '',
      credits: json['credits']?.toDouble(),
      grade: json['grade'],
      score: json['score']?.toDouble(),
      gradePoint: json['gradePoint']?.toDouble() ?? json['grade_point']?.toDouble(),
      openClass: json['openClass'] ?? json['open_class'],
      category: json['category'],
      extra: extraData,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'courseId': courseId,
      'courseName': courseName,
      'semester': semester,
      'credits': credits,
      'grade': grade,
      'score': score,
      'gradePoint': gradePoint,
      if (openClass != null) 'openClass': openClass,
      if (category != null) 'category': category,
      if (extra != null) 'extra': extra,
    };
  }

  /// 成績是否及格
  bool get isPassed {
    if (grade == null) return false;
    return !['F', 'X', '不及格'].contains(grade);
  }

  /// 成績顏色（用於 UI 顯示）
  GradeColor get gradeColor {
    if (gradePoint == null) return GradeColor.unknown;
    if (gradePoint! >= 4.0) return GradeColor.excellent; // A+, A
    if (gradePoint! >= 3.7) return GradeColor.good;      // A-
    if (gradePoint! >= 3.3) return GradeColor.good;      // B+
    if (gradePoint! >= 3.0) return GradeColor.average;   // B
    if (gradePoint! >= 2.0) return GradeColor.average;   // B-, C+, C
    return GradeColor.poor;                              // C-, D, F
  }
}

enum GradeColor {
  excellent, // >= A
  good,      // A-, B+
  average,   // B, B-, C+, C
  poor,      // < C
  unknown,   // 未知
}
