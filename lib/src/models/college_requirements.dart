/// 北科大學院博雅向度需求配置
/// 
/// 機電學院：人文與藝術 4 學分、社會與法治 4 學分、創新與創業 4 學分
/// 電資學院：人文與藝術 4 學分、自然與科學 4 學分、創新與創業 4 學分
/// 工程學院：人文與藝術 4 學分、社會與法治 4 學分、創新與創業 4 學分
/// 管理學院：人文與藝術 4 學分、社會與法治 4 學分、自然與科學 4 學分
/// 設計學院：人文與藝術 4 學分、社會與法治 4 學分、創新與創業 4 學分
/// 人社學院：社會與法治 4 學分、自然與科學 4 學分、創新與創業 4 學分
/// 
/// 修完學院指定向度課程 12 學分，剩餘 3 學分可在 4 向度自由修滿，達到通識畢業 15 學分。

/// 博雅向度列表
const List<String> boyaDimensions = [
  '人文與藝術向度',
  '社會與法治向度',
  '自然與科學向度',
  '創新與創業向度',
];

/// 學院列表
enum College {
  mechanical('機電學院'),
  electrical('電資學院'),
  engineering('工程學院'),
  management('管理學院'),
  design('設計學院'),
  humanitiesSocial('人社學院'),
  unknown('未知學院');

  const College(this.displayName);
  final String displayName;
}

/// 學院博雅向度需求
class CollegeBoyaRequirement {
  final College college;
  final Map<String, int> requiredDimensions; // 向度 => 最低學分
  final int totalRequired; // 總共需要的博雅學分
  final int mandatoryTotal; // 指定向度總學分 (12學分)
  final int freeChoice; // 自由選修學分 (3學分)

  const CollegeBoyaRequirement({
    required this.college,
    required this.requiredDimensions,
    this.totalRequired = 15,
    this.mandatoryTotal = 12,
    this.freeChoice = 3,
  });

  /// 檢查某個學院的博雅學分是否達標
  bool checkRequirement(Map<String, int> actualCredits) {
    // 1. 檢查必修向度是否都達標
    for (final entry in requiredDimensions.entries) {
      final dimension = entry.key;
      final required = entry.value;
      final actual = actualCredits[dimension] ?? 0;
      
      if (actual < required) {
        return false; // 有向度未達標
      }
    }

    // 2. 檢查總學分是否達標
    int total = actualCredits.values.fold(0, (sum, credit) => sum + credit);
    return total >= totalRequired;
  }

  /// 取得缺少的向度學分
  Map<String, int> getMissingCredits(Map<String, int> actualCredits) {
    final missing = <String, int>{};
    
    for (final entry in requiredDimensions.entries) {
      final dimension = entry.key;
      final required = entry.value;
      final actual = actualCredits[dimension] ?? 0;
      
      if (actual < required) {
        missing[dimension] = required - actual;
      }
    }

    return missing;
  }
}

/// 學院博雅需求配置表
class CollegeBoyaRequirements {
  static const Map<College, CollegeBoyaRequirement> requirements = {
    College.mechanical: CollegeBoyaRequirement(
      college: College.mechanical,
      requiredDimensions: {
        '人文與藝術向度': 4,
        '社會與法治向度': 4,
        '創新與創業向度': 4,
      },
    ),
    College.electrical: CollegeBoyaRequirement(
      college: College.electrical,
      requiredDimensions: {
        '人文與藝術向度': 4,
        '自然與科學向度': 4,
        '創新與創業向度': 4,
      },
    ),
    College.engineering: CollegeBoyaRequirement(
      college: College.engineering,
      requiredDimensions: {
        '人文與藝術向度': 4,
        '社會與法治向度': 4,
        '創新與創業向度': 4,
      },
    ),
    College.management: CollegeBoyaRequirement(
      college: College.management,
      requiredDimensions: {
        '人文與藝術向度': 4,
        '社會與法治向度': 4,
        '自然與科學向度': 4,
      },
    ),
    College.design: CollegeBoyaRequirement(
      college: College.design,
      requiredDimensions: {
        '人文與藝術向度': 4,
        '社會與法治向度': 4,
        '創新與創業向度': 4,
      },
    ),
    College.humanitiesSocial: CollegeBoyaRequirement(
      college: College.humanitiesSocial,
      requiredDimensions: {
        '社會與法治向度': 4,
        '自然與科學向度': 4,
        '創新與創業向度': 4,
      },
    ),
  };

  /// 從系所名稱推斷學院
  static College getCollegeFromDepartment(String department) {
    // 機電學院
    if (department.contains('機械') ||
        department.contains('車輛') ||
        department.contains('能源') ||
        department.contains('自動化') ||
        department.contains('機電')) {
      return College.mechanical;
    }

    // 電資學院
    if (department.contains('電機') ||
        department.contains('電子') ||
        department.contains('資工') ||
        department.contains('光電') ||
        department.contains('資訊')) {
      return College.electrical;
    }

    // 工程學院
    if (department.contains('土木') ||
        department.contains('化工') ||
        department.contains('材料') ||
        department.contains('資源') ||
        department.contains('環境') ||
        department.contains('分子')) {
      return College.engineering;
    }

    // 管理學院
    if (department.contains('經營') ||
        department.contains('管理') ||
        department.contains('工業') ||
        department.contains('資財') ||
        department.contains('企業') ||
        department.contains('商業')) {
      return College.management;
    }

    // 設計學院
    if (department.contains('設計') ||
        department.contains('建築') ||
        department.contains('互動') ||
        department.contains('創意')) {
      return College.design;
    }

    // 人社學院
    if (department.contains('英文') ||
        department.contains('文化') ||
        department.contains('智財') ||
        department.contains('技職') ||
        department.contains('應用')) {
      return College.humanitiesSocial;
    }

    return College.unknown;
  }

  /// 取得學院的博雅需求
  static CollegeBoyaRequirement? getRequirement(College college) {
    return requirements[college];
  }
}
