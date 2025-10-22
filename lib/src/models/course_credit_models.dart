import 'college_requirements.dart';

/// 課程類別常數（完全按照 TAT）
const List<String> courseTypes = [
  "○", // 必 部訂共同必修
  "△", // 必 校訂共同必修
  "☆", // 選 共同選修
  "●", // 必 部訂專業必修
  "▲", // 必 校訂專業必修
  "★", // 選 專業選修
];

/// 課程學分資訊（對應 TAT 的 CourseScoreInfoJson）
class CourseCreditInfo {
  final String courseId;      // 六碼課程代號
  final String courseCode;    // 七碼課程編號（課號），用於對應課程標準
  final String nameZh;
  final String nameEn;
  final String score;
  final double credit;        // 學分
  final String openClass;     // 開課班級
  final String category;      // 課程類別
  final String notes;         // 備註（包含博雅向度資訊）
  final String dimension;     // 博雅向度（直接從 API 取得）

  CourseCreditInfo({
    required this.courseId,
    this.courseCode = '',     // 新增：七碼課程編號
    required this.nameZh,
    required this.nameEn,
    required this.score,
    required this.credit,
    required this.openClass,
    required this.category,
    this.notes = '',
    this.dimension = '',
  });

  String get name => nameZh; // 目前主要使用中文名稱

  /// 是否通過（取得學分）- 完全按照 TAT 的 isPass
  bool get isPassed {
    try {
      final s = int.parse(score);
      return s >= 60;
    } catch (e) {
      return false;
    }
  }

  /// 是否是外系課程 - 完全按照 TAT 的 isOtherDepartment
  bool isOtherDepartment(String department) {
    final containClass = ["最後一哩"]; // 包含就是外系
    final excludeClass = ["體育"]; // 包含就不是外系

    // 是校內共同必修就不是外系
    if (category.contains("△")) return false;

    // 先用開設班級是否是本系判斷
    bool isOther = !openClass.contains(department);
    for (final key in excludeClass) {
      isOther &= !openClass.contains(key);
    }

    for (final key in containClass) {
      isOther |= openClass.contains(key);
    }

    if (category.contains("▲") && openClass.contains("重補修")) {
      isOther = false;
    }

    return isOther;
  }

  /// 是否是博雅課程 - 完全按照 TAT 的 isGeneralLesson
  bool get isGeneralLesson =>
      openClass.contains("博雅") || openClass.contains("職通識課程");

  /// 是否是博雅核心課程 - 完全按照 TAT 的 isCoreGeneralLesson
  bool get isCoreGeneralLesson => openClass.contains("核心");

  /// 博雅課程的向度（改進版：直接使用 API 返回的 dimension 欄位）
  /// 
  /// 北科的四大博雅向度：
  /// 1. 創新與創業向度
  /// 2. 人文與藝術向度
  /// 3. 社會與法治向度
  /// 4. 自然與科學向度
  String? get generalLessonDimension {
    if (!isGeneralLesson) return null;
    
    // 優先使用從 ShowSyllabus.jsp API 取得的 dimension 欄位
    if (dimension.isNotEmpty) {
      final cleanDimension = dimension.trim();
      
      // 直接返回，因為 API 已經提供了標準格式
      // 例如："人文與藝術向度"、"社會與法治向度" 等
      if (cleanDimension.contains('向度')) {
        return cleanDimension;
      }
      
      // 如果只有部分名稱，補全為完整向度名稱
      if (cleanDimension.contains('創新') || cleanDimension.contains('創業')) {
        return '創新與創業向度';
      }
      if (cleanDimension.contains('人文') || cleanDimension.contains('藝術')) {
        return '人文與藝術向度';
      }
      if (cleanDimension.contains('社會') || cleanDimension.contains('法治')) {
        return '社會與法治向度';
      }
      if (cleanDimension.contains('自然') || cleanDimension.contains('科學')) {
        return '自然與科學向度';
      }
      
      // 直接返回原始值（可能是舊制或特殊向度）
      return cleanDimension;
    }
    
    // 方案 2: 如果 notes 有資料，使用 notes（舊制課程可能需要）
    if (notes.isNotEmpty) {
      // 清理備註文字：移除符號、分割學年度規則
      final cleanNotes = notes.replaceAll(RegExp(r'◎|\*'), '');
      final parts = cleanNotes.split(RegExp(r'106-108：|。109 ?\(含\) ?後：'));
      
      // 取最後一個部分（最新的規則）
      String noteDimension = parts.isNotEmpty ? parts.last.trim() : '';
      
      // 根據北科的四大博雅向度分類
      if (noteDimension.contains('創新與創業') || noteDimension.contains('創創')) {
        return '創新與創業向度';
      }
      if (noteDimension.contains('人文與藝術') || noteDimension.contains('文化') || noteDimension.contains('美學')) {
        return '人文與藝術向度';
      }
      if (noteDimension.contains('社會與法治') || noteDimension.contains('社會') || noteDimension.contains('法治')) {
        return '社會與法治向度';
      }
      if (noteDimension.contains('自然') || noteDimension.contains('科學')) {
        return '自然與科學向度';
      }
      
      if (noteDimension.isNotEmpty) return noteDimension;
    }
    
    // 方案 3: 從 openClass 推斷（最終備用方案）
    final className = openClass.toLowerCase();
    
    // 完整關鍵字匹配
    if (className.contains('人文')) return '人文與藝術向度';
    if (className.contains('藝術')) return '人文與藝術向度';
    if (className.contains('文化')) return '人文與藝術向度';
    if (className.contains('美學')) return '人文與藝術向度';
    
    if (className.contains('社會')) return '社會與法治向度';
    if (className.contains('法治')) return '社會與法治向度';
    if (className.contains('哲學')) return '社會與法治向度';
    
    if (className.contains('自然')) return '自然與科學向度';
    if (className.contains('科學')) return '自然與科學向度';
    if (className.contains('科技')) return '自然與科學向度';
    
    if (className.contains('創新')) return '創新與創業向度';
    if (className.contains('創業')) return '創新與創業向度';
    if (className.contains('創創')) return '創新與創業向度';
    
    // 無法識別，返回 "其他"
    return '其他';
  }

  factory CourseCreditInfo.fromJson(Map<String, dynamic> json) {
    return CourseCreditInfo(
      courseId: json['courseId'] ?? '',
      courseCode: json['courseCode'] ?? '',
      nameZh: json['nameZh'] ?? '',
      nameEn: json['nameEn'] ?? '',
      score: json['score'] ?? '',
      credit: (json['credit'] ?? 0).toDouble(),
      openClass: json['openClass'] ?? '',
      category: json['category'] ?? '',
      notes: json['notes'] ?? '',
      dimension: json['dimension'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'courseId': courseId,
      'courseCode': courseCode,
      'nameZh': nameZh,
      'nameEn': nameEn,
      'score': score,
      'credit': credit,
      'openClass': openClass,
      'category': category,
      'notes': notes,
      'dimension': dimension, // 🎯 新增
    };
  }

  @override
  String toString() {
    return 'CourseCreditInfo(name: $nameZh, score: $score, credit: $credit, category: $category)';
  }
}

/// 畢業資訊（對應 TAT 的 GraduationInformationJson）
class GraduationInformation {
  final String selectYear; // 選擇的學年度
  final String selectDivision; // 選擇的學制
  final String selectDepartment; // 選擇的系所
  final int lowCredit; // 最低畢業學分數
  final int outerDepartmentMaxCredit; // 外系最多承認學分
  final Map<String, int> courseTypeMinCredit; // 各類課程最低學分

  GraduationInformation({
    required this.selectYear,
    required this.selectDivision,
    required this.selectDepartment,
    required this.lowCredit,
    required this.outerDepartmentMaxCredit,
    required this.courseTypeMinCredit,
  });

  /// 是否已選擇（對應 TAT 的 isSelect）
  bool get isSelected =>
      selectYear.isNotEmpty &&
      selectDivision.isNotEmpty &&
      selectDepartment.isNotEmpty;

  factory GraduationInformation.empty() {
    final courseTypeMinCredit = <String, int>{};
    for (final type in courseTypes) {
      courseTypeMinCredit[type] = 0;
    }
    return GraduationInformation(
      selectYear: '',
      selectDivision: '',
      selectDepartment: '',
      lowCredit: 0,
      outerDepartmentMaxCredit: 0,
      courseTypeMinCredit: courseTypeMinCredit,
    );
  }

  factory GraduationInformation.fromJson(Map<String, dynamic> json) {
    final courseTypeMinCredit = <String, int>{};
    if (json['courseTypeMinCredit'] != null) {
      (json['courseTypeMinCredit'] as Map<String, dynamic>).forEach((k, v) {
        courseTypeMinCredit[k] = v as int;
      });
    } else {
      for (final type in courseTypes) {
        courseTypeMinCredit[type] = 0;
      }
    }

    return GraduationInformation(
      selectYear: json['selectYear'] ?? '',
      selectDivision: json['selectDivision'] ?? '',
      selectDepartment: json['selectDepartment'] ?? '',
      lowCredit: json['lowCredit'] ?? 0,
      outerDepartmentMaxCredit: json['outerDepartmentMaxCredit'] ?? 0,
      courseTypeMinCredit: courseTypeMinCredit,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'selectYear': selectYear,
      'selectDivision': selectDivision,
      'selectDepartment': selectDepartment,
      'lowCredit': lowCredit,
      'outerDepartmentMaxCredit': outerDepartmentMaxCredit,
      'courseTypeMinCredit': courseTypeMinCredit,
    };
  }

  @override
  String toString() {
    return 'GraduationInformation(year: $selectYear, division: $selectDivision, '
        'department: $selectDepartment, lowCredit: $lowCredit, '
        'outerMax: $outerDepartmentMaxCredit, types: $courseTypeMinCredit)';
  }
}

/// 學分統計資訊（對應 TAT 的 CourseScoreCreditJson）
class CreditStatistics {
  final GraduationInformation graduationInfo;
  final List<CourseCreditInfo> courses;

  CreditStatistics({
    required this.graduationInfo,
    required this.courses,
  });

  /// 取得總學分（對應 TAT 的 getTotalCourseCredit）
  int get totalCredits {
    int credit = 0;
    for (final course in courses) {
      if (course.isPassed) {
        credit += course.credit.toInt();
      }
    }
    return credit;
  }

  /// 取得特定類型的學分（對應 TAT 的 getCreditByType）
  int getCreditByType(String type) {
    int credit = 0;
    for (final course in courses) {
      if (course.category.contains(type) && course.isPassed) {
        credit += course.credit.toInt();
      }
    }
    return credit;
  }

  /// 取得特定類型的課程列表（對應 TAT 的 getCourseByType，但簡化版）
  List<CourseCreditInfo> getCoursesByType(String type) {
    return courses
        .where((c) => c.category.contains(type) && c.isPassed)
        .toList();
  }

  /// 取得博雅課程（對應 TAT 的 getGeneralLesson）
  List<CourseCreditInfo> get generalLessonCourses {
    return courses.where((c) => c.isGeneralLesson && c.isPassed).toList();
  }

  /// 取得博雅核心課程學分
  int get coreGeneralLessonCredits {
    int credit = 0;
    for (final course in generalLessonCourses) {
      if (course.isCoreGeneralLesson) {
        credit += course.credit.toInt();
      }
    }
    return credit;
  }

  /// 取得博雅選修課程學分
  int get selectGeneralLessonCredits {
    int credit = 0;
    for (final course in generalLessonCourses) {
      if (!course.isCoreGeneralLesson) {
        credit += course.credit.toInt();
      }
    }
    return credit;
  }

  /// 取得各向度的博雅學分
  /// 北科的博雅四大向度：創新與創業向度、人文與藝術向度、社會與法治向度、自然與科學向度
  Map<String, int> get generalLessonCreditsByDimension {
    final result = <String, int>{
      '創新與創業向度': 0,
      '人文與藝術向度': 0,
      '社會與法治向度': 0,
      '自然與科學向度': 0,
      '其他': 0,
    };

    for (final course in generalLessonCourses) {
      final dimension = course.generalLessonDimension;
      if (dimension != null) {
        // 如果該向度已存在於 map 中，累加學分
        if (result.containsKey(dimension)) {
          result[dimension] = result[dimension]! + course.credit.toInt();
        } else {
          // 如果是新向度（可能是舊制或特殊向度），加入 "其他"
          result['其他'] = result['其他']! + course.credit.toInt();
        }
      }
    }

    // 移除學分為 0 的向度（保持結果簡潔）
    result.removeWhere((key, value) => value == 0);

    return result;
  }

  /// 檢查博雅學分是否達標（根據學院要求）
  /// 規則：三個學院指定向度達到4學分 + 總共至少15學分
  bool get isGeneralLessonQualified {
    if (!graduationInfo.isSelected) return false;

    // 根據系所推斷學院
    final college = CollegeBoyaRequirements.getCollegeFromDepartment(
      graduationInfo.selectDepartment,
    );

    // 取得學院的博雅需求
    final requirement = CollegeBoyaRequirements.getRequirement(college);
    
    if (requirement == null) {
      // 如果沒有找到學院需求，使用通用規則：三個向度達標
      final dimensionCredits = generalLessonCreditsByDimension;
      int qualifiedDimensions = 0;
      
      for (final credit in dimensionCredits.values) {
        if (credit >= 4) {
          qualifiedDimensions++;
        }
      }

      final totalGeneralCredits = coreGeneralLessonCredits + selectGeneralLessonCredits;
      
      // 三個向度達標 且 總學分至少15
      return qualifiedDimensions >= 3 && totalGeneralCredits >= 15;
    }

    // 使用學院要求檢查
    final dimensionCredits = generalLessonCreditsByDimension;
    return requirement.checkRequirement(dimensionCredits);
  }

  /// 取得學院的博雅需求
  CollegeBoyaRequirement? get collegeBoyaRequirement {
    if (!graduationInfo.isSelected) return null;

    final college = CollegeBoyaRequirements.getCollegeFromDepartment(
      graduationInfo.selectDepartment,
    );

    return CollegeBoyaRequirements.getRequirement(college);
  }

  /// 取得缺少的博雅向度學分
  Map<String, int> get missingBoyaCredits {
    final requirement = collegeBoyaRequirement;
    if (requirement == null) return {};

    final dimensionCredits = generalLessonCreditsByDimension;
    return requirement.getMissingCredits(dimensionCredits);
  }

  /// 取得外系課程（對應 TAT 的 getOtherDepartmentCourse）
  List<CourseCreditInfo> getOtherDepartmentCourses() {
    if (graduationInfo.selectDepartment.length < 2) {
      return [];
    }
    
    final department = graduationInfo.selectDepartment.substring(0, 2);
    return courses
        .where((c) => c.isOtherDepartment(department) && c.isPassed)
        .toList();
  }

  /// 取得外系學分
  int get otherDepartmentCredits {
    int credit = 0;
    for (final course in getOtherDepartmentCourses()) {
      credit += course.credit.toInt();
    }
    return credit;
  }

  /// 檢查畢業學分是否達標
  bool get isGraduationQualified {
    if (!graduationInfo.isSelected) return false;
    return totalCredits >= graduationInfo.lowCredit;
  }

  /// 距離畢業還需要的學分
  int get creditsNeededForGraduation {
    final needed = graduationInfo.lowCredit - totalCredits;
    return needed > 0 ? needed : 0;
  }
}
