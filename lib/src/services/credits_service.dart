import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../models/course_credit_models.dart';
import '../models/grade.dart';
import 'ntut_api_service.dart';
import 'grades_service.dart';

/// 學分計算服務
class CreditsService {
  final GradesService _gradesService;
  final NtutApiService _ntutApi;
  
  // 記憶體緩存，提升效能
  final Map<String, Map<String, String>> _syllabusCache = {};
  
  CreditsService({
    required GradesService gradesService,
    NtutApiService? ntutApi,
  })  : _gradesService = gradesService,
        _ntutApi = ntutApi ?? NtutApiService();

  static const String _graduationInfoKey = 'graduation_information';
  static const String _syllabusCacheKey = 'course_syllabus_cache';
  
  /// 載入持久化的課程大綱緩存
  Future<void> _loadSyllabusCache() async {
    if (_syllabusCache.isNotEmpty) return; // 已載入過
    
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonStr = prefs.getString(_syllabusCacheKey);
      
      if (jsonStr != null) {
        final Map<String, dynamic> cache = jsonDecode(jsonStr);
        cache.forEach((key, value) {
          if (value is Map) {
            _syllabusCache[key] = Map<String, String>.from(value);
          }
        });
        debugPrint('[CreditsService] 已載入 ${_syllabusCache.length} 筆課程大綱緩存');
      }
    } catch (e) {
      debugPrint('[CreditsService] 載入課程大綱緩存失敗: $e');
    }
  }
  
  /// 儲存課程大綱緩存到持久化儲存
  Future<void> _saveSyllabusCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonStr = jsonEncode(_syllabusCache);
      await prefs.setString(_syllabusCacheKey, jsonStr);
      debugPrint('[CreditsService] 已儲存 ${_syllabusCache.length} 筆課程大綱緩存');
    } catch (e) {
      debugPrint('[CreditsService] 儲存課程大綱緩存失敗: $e');
    }
  }
  
  /// 清除課程大綱緩存
  Future<void> clearSyllabusCache() async {
    try {
      _syllabusCache.clear();
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_syllabusCacheKey);
      debugPrint('[CreditsService] 已清除課程大綱緩存');
    } catch (e) {
      debugPrint('[CreditsService] 清除課程大綱緩存失敗: $e');
    }
  }

  /// 從學號推斷入學年度（對應 TAT 的邏輯）
  String _getYearFromStudentId(String studentId) {
    if (studentId.length < 3) return '';
    // 學號前三碼是學年度,例如 109xxxxxx 代表 109 學年度入學
    return studentId.substring(0, 3);
  }

  /// 獲取所有學年度列表（使用 NtutCourseService）
  Future<List<String>> getYearList() async {
    try {
      return await _ntutApi.course.getYearList();
    } catch (e) {
      debugPrint('[CreditsService] 獲取學年度列表失敗: $e');
      rethrow;
    }
  }

  /// 獲取學制列表（使用 NtutCourseService）
  Future<List<Map<String, dynamic>>> getDivisionList(String year) async {
    try {
      return await _ntutApi.course.getDivisionList(year);
    } catch (e) {
      debugPrint('[CreditsService] 獲取學制列表失敗: $e');
      rethrow;
    }
  }

  /// 獲取系所列表（使用 NtutCourseService）
  Future<List<Map<String, dynamic>>> getDepartmentList(
    Map<String, String> code,
  ) async {
    try {
      return await _ntutApi.course.getDepartmentList(code);
    } catch (e) {
      debugPrint('[CreditsService] 獲取系所列表失敗: $e');
      rethrow;
    }
  }

  /// 獲取課程標準資訊（使用 NtutCourseService）
  Future<GraduationInformation?> getCreditInfo(
    Map<String, String> code,
    String departmentName,
  ) async {
    try {
      final result = await _ntutApi.course.getCreditInfo(code, departmentName);
      if (result == null) return null;

      // 將結果轉換為 GraduationInformation
      final courseTypeMinCredit = <String, int>{};
      for (final type in courseTypes) {
        courseTypeMinCredit[type] = result[type] ?? 0;
      }

      return GraduationInformation(
        selectYear: '',
        selectDivision: '',
        selectDepartment: departmentName,
        lowCredit: result['lowCredit'] ?? 0,
        outerDepartmentMaxCredit: result['outerDepartmentMaxCredit'] ?? 0,
        courseTypeMinCredit: courseTypeMinCredit,
      );
    } catch (e) {
      debugPrint('[CreditsService] 獲取課程標準失敗: $e');
      rethrow;
    }
  }

  /// 獲取課程大綱（帶緩存）
  Future<Map<String, String>?> _getCachedSyllabus(String courseId, {bool forceRefresh = false}) async {
    // 如果強制刷新，清除該課程的緩存
    if (forceRefresh) {
      _syllabusCache.remove(courseId);
    }
    
    // 先從緩存讀取
    if (_syllabusCache.containsKey(courseId)) {
      return _syllabusCache[courseId];
    }
    
    // 查詢 API
    try {
      final syllabus = await _ntutApi.course.getPublicCourseSyllabus(courseId);
      if (syllabus != null) {
        _syllabusCache[courseId] = syllabus;
        // 儲存到持久化緩存
        await _saveSyllabusCache();
      }
      return syllabus;
    } catch (e) {
      debugPrint('[CreditsService] 查詢課程大綱失敗 $courseId: $e');
      return null;
    }
  }

  /// 從成績轉換為課程學分資訊
  Future<List<CourseCreditInfo>> _convertGradesToCourseCredits(
    List<Grade> grades, {
    bool forceRefresh = false,
    void Function(int current, int total, String courseName)? onProgress,
  }) async {
    final courseCredits = <CourseCreditInfo>[];

    // 載入持久化緩存
    await _loadSyllabusCache();
    
    debugPrint('[CreditsService] 開始轉換 ${grades.length} 筆成績並查詢課程資訊 (forceRefresh: $forceRefresh)');
    
    int successCount = 0;
    int failCount = 0;
    int cachedCount = 0;
    int processedCount = 0;

    for (final grade in grades) {
      processedCount++;
      
      // 回報進度
      if (onProgress != null) {
        onProgress(processedCount, grades.length, grade.courseName);
      }
      // 將成績轉換為字串格式
      String scoreStr = '';
      if (grade.score != null) {
        scoreStr = grade.score!.toStringAsFixed(0);
      } else if (grade.grade != null) {
        scoreStr = grade.grade!;
      }

      // 查詢課程資訊以獲取 category、openClass 和 dimension
      String category = grade.category ?? '';
      String openClass = grade.openClass ?? '';
      String dimension = ''; // 博雅向度
      
      if (category.isEmpty || openClass.isEmpty) {
        final wasCached = _syllabusCache.containsKey(grade.courseId);
        final syllabus = await _getCachedSyllabus(grade.courseId, forceRefresh: forceRefresh);
        
        if (syllabus != null) {
          category = syllabus['category'] ?? '';
          openClass = syllabus['openClass'] ?? '';
          dimension = syllabus['dimension'] ?? ''; // 從 API 取得向度
          
          // 存入緩存（包含 dimension）
          _syllabusCache[grade.courseId] = {
            'category': category,
            'openClass': openClass,
            'dimension': dimension, // 儲存向度
          };
          
          if (wasCached && !forceRefresh) {
            cachedCount++;
          } else {
            successCount++;
            debugPrint('[CreditsService] ${grade.courseName}: category="$category", openClass="$openClass", dimension="$dimension"');
          }
        } else {
          failCount++;
          debugPrint('[CreditsService] ${grade.courseName}: 無法取得課程大綱');
        }
      } else {
        cachedCount++;
      }

      final courseCredit = CourseCreditInfo(
        courseId: grade.courseId,
        nameZh: grade.courseName,
        nameEn: grade.courseName, // QAQ 目前沒有英文名稱
        score: scoreStr,
        credit: grade.credits ?? 0,
        openClass: openClass,
        category: category,
        notes: '', // 暫時無法取得 notes
        dimension: dimension, // 傳入向度
      );

      courseCredits.add(courseCredit);
    }

    debugPrint('[CreditsService] 課程資訊查詢完成: 新查詢 $successCount 筆, 失敗 $failCount 筆, 緩存 $cachedCount 筆');
    return courseCredits;
  }

  /// 獲取學分統計
  Future<CreditStatistics> getCreditStatistics({
    required String studentId,
    bool forceRefresh = false,
    void Function(int current, int total, String courseName)? onProgress,
  }) async {
    try {
      // 1. 獲取所有成績
      final grades = await _gradesService.getGrades(
        studentId: studentId,
        forceRefresh: forceRefresh,
      );

      // 2. 轉換為課程學分資訊（並查詢課程大綱）
      // 只有在 forceRefresh 時才重新查詢課程大綱
      final courseCredits = await _convertGradesToCourseCredits(
        grades,
        forceRefresh: forceRefresh,
        onProgress: onProgress,
      );

      // 3. 載入畢業資訊
      final graduationInfo = await loadGraduationInformation(studentId: studentId);

      // 4. 建立學分統計
      final stats = CreditStatistics(
        graduationInfo: graduationInfo,
        courses: courseCredits,
      );

      return stats;
    } catch (e) {
      debugPrint('[CreditsService] 獲取學分統計失敗: $e');
      rethrow;
    }
  }

  /// 儲存畢業資訊
  Future<void> saveGraduationInformation(GraduationInformation info) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final json = jsonEncode(info.toJson());
      await prefs.setString(_graduationInfoKey, json);
      debugPrint('[CreditsService] 已儲存畢業資訊');
    } catch (e) {
      debugPrint('[CreditsService] 儲存畢業資訊失敗: $e');
      rethrow;
    }
  }

  /// 載入畢業資訊
  Future<GraduationInformation> loadGraduationInformation({String? studentId}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonStr = prefs.getString(_graduationInfoKey);
      
      // 如果有保存的設定，直接返回
      if (jsonStr != null) {
        final json = jsonDecode(jsonStr) as Map<String, dynamic>;
        final info = GraduationInformation.fromJson(json);
        if (info.isSelected) {
          return info;
        }
      }
      
      // 否則返回空的畢業資訊
      return GraduationInformation.empty();
    } catch (e) {
      debugPrint('[CreditsService] 載入畢業資訊失敗: $e');
      return GraduationInformation.empty();
    }
  }

  /// 清除畢業資訊
  Future<void> clearGraduationInformation() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_graduationInfoKey);
      debugPrint('[CreditsService] 已清除畢業資訊');
    } catch (e) {
      debugPrint('[CreditsService] 清除畢業資訊失敗: $e');
      rethrow;
    }
  }
}
