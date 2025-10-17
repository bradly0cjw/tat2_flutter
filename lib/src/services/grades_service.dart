import 'package:flutter/foundation.dart';
import '../models/grade.dart';
import '../models/semester_grade_stats.dart';
import 'backend_api_service.dart';
import 'ntut_api_service.dart';
import 'grades_cache_service.dart';

/// 成績服務
class GradesService {
  final NtutApiService _ntutApi;
  final BackendApiService _backendApi;
  final GradesCacheService _cacheService;

  GradesService({
    required NtutApiService ntutApi,
    required BackendApiService backendApi,
    GradesCacheService? cacheService,
  })  : _ntutApi = ntutApi,
        _backendApi = backendApi,
        _cacheService = cacheService ?? GradesCacheService();

  /// 獲取成績（優先使用緩存）
  Future<List<Grade>> getGrades({
    required String studentId,
    String? semester,
    bool forceRefresh = false,
  }) async {
    try {
      // 1. 如果不強制刷新，先檢查緩存
      if (!forceRefresh) {
        final isCacheExpired = await _cacheService.isCacheExpired();
        
        if (!isCacheExpired) {
          final cachedGrades = await _cacheService.loadGrades();
          if (cachedGrades != null && cachedGrades.isNotEmpty) {
            debugPrint('[GradesService] 使用緩存的成績資料 (${cachedGrades.length} 筆)');
            
            if (semester != null) {
              return cachedGrades.where((g) => g.semester == semester).toList();
            }
            return cachedGrades;
          }
        }
      }
      
      // 2. 緩存過期或無緩存，從 NTUT API 獲取
      debugPrint('[GradesService] 從 NTUT API 獲取成績: $studentId');
      final gradesData = await _ntutApi.getGrades(studentId);
      
      if (gradesData.isEmpty) {
        debugPrint('[GradesService] NTUT API 未返回成績資料');
        return [];
      }
      
      // 3. 轉換為 Grade 物件
      final grades = gradesData.map((data) => Grade.fromJson(data)).toList();
      
      // 4. 保存到緩存
      await _cacheService.saveGrades(grades);
      
      // 5. 如果指定了學期，過濾出該學期的成績
      if (semester != null) {
        return grades.where((g) => g.semester == semester).toList();
      }
      
      debugPrint('[GradesService] 成功獲取 ${grades.length} 筆成績');
      return grades;
    } catch (e) {
      debugPrint('[GradesService] 獲取成績失敗: $e');
      
      // 發生錯誤時嘗試返回緩存資料
      final cachedGrades = await _cacheService.loadGrades();
      if (cachedGrades != null) {
        debugPrint('[GradesService] 使用緩存的成績資料 (錯誤回退)');
        if (semester != null) {
          return cachedGrades.where((g) => g.semester == semester).toList();
        }
        return cachedGrades;
      }
      
      return [];
    }
  }
  
  /// 從 NTUT API 獲取成績（舊方法，保留兼容性）
  @Deprecated('使用 getGrades 替代')
  Future<List<Grade>> fetchAndSyncGrades({
    required String studentId,
    String? semester,
  }) async {
    return getGrades(
      studentId: studentId,
      semester: semester,
      forceRefresh: true,
    );
  }

  /// 從 Backend 獲取已緩存的成績
  Future<List<Grade>> getGradesFromBackend({
    required String studentId,
    String? semester,
  }) async {
    try {
      debugPrint('[GradesService] 從 Backend 獲取成績: $studentId, semester: $semester');
      final grades = await _backendApi.getGrades(
        studentId,
        semester: semester,
      );
      debugPrint('[GradesService] 獲取到 ${grades.length} 筆成績');
      return grades;
    } catch (e) {
      debugPrint('[GradesService] 從 Backend 獲取成績失敗: $e');
      return [];
    }
  }

  /// 計算學分加權平均成績（非 GPA）
  double calculateWeightedAverage(List<Grade> grades) {
    if (grades.isEmpty) {
      return 0.0;
    }

    final validGrades = grades.where(
      (g) => g.score != null && g.credits != null && g.credits! > 0,
    ).toList();

    if (validGrades.isEmpty) {
      debugPrint('[GradesService] 沒有有效的成績數據');
      return 0.0;
    }

    double totalWeightedScore = 0;
    double totalCredits = 0;

    for (final grade in validGrades) {
      totalWeightedScore += grade.score! * grade.credits!;
      totalCredits += grade.credits!;
    }

    return totalCredits > 0 ? totalWeightedScore / totalCredits : 0.0;
  }

  /// 計算 GPA（已廢棄，學校不使用 GPA）
  @Deprecated('學校不使用 GPA，請使用 calculateWeightedAverage')
  double calculateGPA(List<Grade> grades) {
    return calculateWeightedAverage(grades);
  }

  /// 計算總學分
  double calculateTotalCredits(List<Grade> grades) {
    return grades
        .where((g) => g.credits != null && g.isPassed)
        .fold(0.0, (sum, g) => sum + g.credits!);
  }

  /// 按學期分組成績
  Map<String, List<Grade>> groupBySemester(List<Grade> grades) {
    final Map<String, List<Grade>> grouped = {};

    for (final grade in grades) {
      final semester = grade.semester;
      if (!grouped.containsKey(semester)) {
        grouped[semester] = [];
      }
      grouped[semester]!.add(grade);
    }

    // 按學期排序 (降序)
    final sortedKeys = grouped.keys.toList()
      ..sort((a, b) => b.compareTo(a));

    return Map.fromEntries(
      sortedKeys.map((key) => MapEntry(key, grouped[key]!)),
    );
  }
  
  /// 獲取學期統計信息（包含排名）
  Future<Map<String, SemesterGradeStats>> getSemesterStatsWithRanks({
    required String studentId,
    bool forceRefresh = false,
  }) async {
    try {
      // 1. 獲取成績
      final grades = await getGrades(studentId: studentId, forceRefresh: forceRefresh);
      
      // 2. 獲取排名（先檢查緩存）
      Map<String, Map<String, dynamic>> ranks;
      
      if (!forceRefresh) {
        final cachedRanks = await _cacheService.loadRanks();
        if (cachedRanks != null && cachedRanks.isNotEmpty) {
          debugPrint('[GradesService] 使用緩存的排名資料 (${cachedRanks.length} 個學期)');
          ranks = cachedRanks;
        } else {
          debugPrint('[GradesService] 從 API 獲取排名');
          ranks = await _ntutApi.getScoreRanks();
          await _cacheService.saveRanks(ranks);
        }
      } else {
        debugPrint('[GradesService] 強制刷新，從 API 獲取排名');
        ranks = await _ntutApi.getScoreRanks();
        await _cacheService.saveRanks(ranks);
      }
      
      // 3. 按學期分組並計算統計
      final grouped = groupBySemester(grades);
      final statsMap = <String, SemesterGradeStats>{};
      
      // 處理總排名（如果有）
      if (ranks.containsKey('_overall')) {
        final overallRankData = ranks['_overall'];
        final classRankData = overallRankData?['classRank'];
        final deptRankData = overallRankData?['departmentRank'];
        
        statsMap['_overall'] = SemesterGradeStats(
          semester: '_overall',
          averageScore: 0.0,
          totalCredits: 0.0,
          earnedCredits: 0.0,
          classRank: classRankData != null 
              ? RankInfo(
                  rank: classRankData['rank'],
                  total: classRankData['total'],
                )
              : null,
          departmentRank: deptRankData != null 
              ? RankInfo(
                  rank: deptRankData['rank'],
                  total: deptRankData['total'],
                )
              : null,
        );
      }
      
      for (final entry in grouped.entries) {
        final semester = entry.key;
        final semesterGrades = entry.value;
        
        // 從成績數據中提取統計信息（如果有）
        final firstGrade = semesterGrades.firstOrNull;
        final semesterStats = firstGrade?.extra?['semesterStats'];
        
        final averageScore = semesterStats?['averageScore']?.toDouble() ?? 
                            calculateWeightedAverage(semesterGrades);
        final performanceScore = semesterStats?['performanceScore']?.toDouble();
        final totalCredits = semesterStats?['totalCredits']?.toDouble() ?? 
                            semesterGrades
                                .where((g) => g.credits != null)
                                .fold(0.0, (sum, g) => sum + g.credits!);
        final earnedCredits = semesterStats?['earnedCredits']?.toDouble() ?? 
                             calculateTotalCredits(semesterGrades);
        
        // 獲取排名信息
        final rankInfo = ranks[semester];
        final classRankData = rankInfo?['classRank'];
        final deptRankData = rankInfo?['departmentRank'];
        
        statsMap[semester] = SemesterGradeStats(
          semester: semester,
          averageScore: averageScore,
          performanceScore: performanceScore,
          totalCredits: totalCredits,
          earnedCredits: earnedCredits,
          classRank: classRankData != null 
              ? RankInfo(
                  rank: classRankData['rank'],
                  total: classRankData['total'],
                )
              : null,
          departmentRank: deptRankData != null 
              ? RankInfo(
                  rank: deptRankData['rank'],
                  total: deptRankData['total'],
                )
              : null,
        );
      }
      
      return statsMap;
    } catch (e) {
      debugPrint('[GradesService] 獲取學期統計信息失敗: $e');
      return {};
    }
  }

  /// 獲取學期統計資訊
  SemesterGradeStats getSemesterStats(List<Grade> semesterGrades, {String semester = ''}) {
    if (semesterGrades.isEmpty) {
      return SemesterGradeStats(
        semester: semester,
        averageScore: 0.0,
        totalCredits: 0.0,
        earnedCredits: 0.0,
      );
    }

    final averageScore = calculateWeightedAverage(semesterGrades);
    final totalCredits = semesterGrades
        .where((g) => g.credits != null)
        .fold(0.0, (sum, g) => sum + g.credits!);
    final earnedCredits = calculateTotalCredits(semesterGrades);

    return SemesterGradeStats(
      semester: semester,
      averageScore: averageScore,
      totalCredits: totalCredits,
      earnedCredits: earnedCredits,
    );
  }
}
