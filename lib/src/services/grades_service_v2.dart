import 'package:flutter/foundation.dart';
import '../models/grade.dart';
import '../core/adapter/school_adapter.dart';
import '../core/retry/retry_policy.dart';
import '../core/auth/auth_manager.dart';
import 'grades_cache_service.dart';

/// 成績服務（重構版）
/// 
/// 使用 SchoolAdapter 抽象層，支援：
/// 1. 自動重新登入
/// 2. 失敗重試
/// 3. 緩存機制
class GradesService {
  final SchoolAdapter _adapter;
  final AuthManager _authManager;
  final GradesCacheService _cacheService;
  final RetryWithReloginPolicy _retryPolicy;

  GradesService({
    required SchoolAdapter adapter,
    required AuthManager authManager,
    GradesCacheService? cacheService,
  })  : _adapter = adapter,
        _authManager = authManager,
        _cacheService = cacheService ?? GradesCacheService(),
        _retryPolicy = RetryWithReloginPolicy(authManager: authManager);

  /// 獲取成績（優先使用緩存）
  /// 
  /// [studentId] 學號
  /// [semester] 學期（可選）
  /// [forceRefresh] 是否強制刷新（忽略緩存）
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
      
      // 2. 緩存過期或無緩存，從學校 API 獲取（帶自動重新登入）
      debugPrint('[GradesService] 從學校 API 獲取成績: $studentId');
      
      final grades = await _retryPolicy.execute(
        operation: () => _adapter.getGrades(studentId, semester: semester),
        operationName: '獲取成績',
      );
      
      if (grades.isEmpty) {
        debugPrint('[GradesService] 學校 API 未返回成績資料');
        return [];
      }
      
      // 3. 保存到緩存
      await _cacheService.saveGrades(grades);
      
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
      
      rethrow;
    }
  }

  /// 強制刷新成績
  Future<List<Grade>> refreshGrades({
    required String studentId,
    String? semester,
  }) async {
    return getGrades(
      studentId: studentId,
      semester: semester,
      forceRefresh: true,
    );
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

  /// 計算總學分
  double calculateTotalCredits(List<Grade> grades) {
    return grades.fold<double>(
      0.0,
      (sum, grade) => sum + (grade.credits ?? 0.0),
    );
  }

  /// 按學期分組
  Map<String, List<Grade>> groupBySemester(List<Grade> grades) {
    final grouped = <String, List<Grade>>{};
    for (final grade in grades) {
      final sem = grade.semester ?? '未知';
      grouped.putIfAbsent(sem, () => []).add(grade);
    }
    return grouped;
  }

  /// 清除緩存
  Future<void> clearCache() async {
    await _cacheService.clearCache();
    debugPrint('[GradesService] 已清除成績緩存');
  }
}
