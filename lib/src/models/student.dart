/// 學生基本資料模型
class Student {
  final String studentId;
  final String? name;
  final String? email;
  final String? department;
  final int? grade;
  final DateTime? lastSync;

  Student({
    required this.studentId,
    this.name,
    this.email,
    this.department,
    this.grade,
    this.lastSync,
  });

  factory Student.fromJson(Map<String, dynamic> json) {
    return Student(
      studentId: json['studentId'] ?? json['student_id'] ?? '',
      name: json['name'],
      email: json['email'],
      department: json['department'],
      grade: json['grade'],
      lastSync: json['lastSync'] != null 
          ? DateTime.fromMillisecondsSinceEpoch(json['lastSync'] * 1000)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'studentId': studentId,
      'name': name,
      'email': email,
      'department': department,
      'grade': grade,
    };
  }

  Student copyWith({
    String? name,
    String? email,
    String? department,
    int? grade,
    DateTime? lastSync,
  }) {
    return Student(
      studentId: studentId,
      name: name ?? this.name,
      email: email ?? this.email,
      department: department ?? this.department,
      grade: grade ?? this.grade,
      lastSync: lastSync ?? this.lastSync,
    );
  }
}
