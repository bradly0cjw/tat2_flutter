/// 排名資訊
class RankInfo {
  final double rank; // 排名
  final double total; // 總人數
  
  RankInfo({
    required this.rank,
    required this.total,
  });
  
  double get percentage => total > 0 ? (rank / total) * 100 : 0;
  
  String get rankString => '${rank.toInt()}/${total.toInt()}';
  
  factory RankInfo.fromJson(Map<String, dynamic> json) {
    return RankInfo(
      rank: json['rank']?.toDouble() ?? 0,
      total: json['total']?.toDouble() ?? 0,
    );
  }
  
  Map<String, dynamic> toJson() {
    return {
      'rank': rank,
      'total': total,
    };
  }
}

/// 學期成績統計
class SemesterGradeStats {
  final String semester;
  final double averageScore; // 總平均（學分加權）
  final double? performanceScore; // 操行成績
  final double totalCredits; // 修習總學分數
  final double earnedCredits; // 實得學分數
  final RankInfo? classRank; // 班排名
  final RankInfo? departmentRank; // 系排名
  
  SemesterGradeStats({
    required this.semester,
    required this.averageScore,
    this.performanceScore,
    required this.totalCredits,
    required this.earnedCredits,
    this.classRank,
    this.departmentRank,
  });

  // Getters for display
  String get averageScoreString => averageScore.toStringAsFixed(2);
  String get totalCreditsString => totalCredits.toStringAsFixed(1);
  String get earnedCreditsString => earnedCredits.toStringAsFixed(1);
  
  // 計算通過和總課程數（假設每個課程平均3學分）
  int get totalCourses => (totalCredits / 3).round();
  int get passedCourses => (earnedCredits / 3).round();
  int get failedCourses => totalCourses - passedCourses;
  
  factory SemesterGradeStats.fromJson(Map<String, dynamic> json) {
    return SemesterGradeStats(
      semester: json['semester'] ?? '',
      averageScore: json['averageScore']?.toDouble() ?? 0,
      performanceScore: json['performanceScore']?.toDouble(),
      totalCredits: json['totalCredits']?.toDouble() ?? 0,
      earnedCredits: json['earnedCredits']?.toDouble() ?? 0,
      classRank: json['classRank'] != null 
          ? RankInfo.fromJson(json['classRank'])
          : null,
      departmentRank: json['departmentRank'] != null 
          ? RankInfo.fromJson(json['departmentRank'])
          : null,
    );
  }
  
  Map<String, dynamic> toJson() {
    return {
      'semester': semester,
      'averageScore': averageScore,
      'performanceScore': performanceScore,
      'totalCredits': totalCredits,
      'earnedCredits': earnedCredits,
      if (classRank != null) 'classRank': classRank!.toJson(),
      if (departmentRank != null) 'departmentRank': departmentRank!.toJson(),
    };
  }
}
