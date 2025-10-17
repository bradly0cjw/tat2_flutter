/// i學院課程基本資訊
class ISchoolPlusCourseInfo {
  /// 課程 ID (對應選課系統的課號)
  final String courseId;
  
  /// 課程名稱
  final String courseName;
  
  /// i學院內部 bid
  final String? bid;

  ISchoolPlusCourseInfo({
    required this.courseId,
    required this.courseName,
    this.bid,
  });
}
