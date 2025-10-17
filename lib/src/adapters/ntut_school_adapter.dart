import 'package:flutter/foundation.dart';
import '../core/adapter/school_adapter.dart';
import '../core/auth/auth_credential.dart';
import '../core/auth/auth_result.dart';
import '../models/course.dart';
import '../models/grade.dart';
import '../models/student.dart';
import '../services/ntut_api_service.dart';
import '../services/backend_api_service.dart';

/// NTUT 學校 Adapter
/// 
/// 封裝所有 NTUT 相關的 API 呼叫邏輯
class NtutSchoolAdapter implements SchoolAdapter {
  final NtutApiService _apiService;
  final BackendApiService _backendService;

  NtutSchoolAdapter({
    required NtutApiService apiService,
    required BackendApiService backendService,
  })  : _apiService = apiService,
        _backendService = backendService;

  @override
  String get schoolName => 'NTUT';

  @override
  bool get isLoggedIn => _apiService.isLoggedIn;

  @override
  Future<AuthResult> login(AuthCredential credential) async {
    try {
      debugPrint('[NtutAdapter] 開始登入: ${credential.username}');
      
      final result = await _apiService.login(
        credential.username,
        credential.password,
      );
      
      if (result['success'] == true) {
        debugPrint('[NtutAdapter] 登入成功');
        return AuthResult.success(
          message: result['message'] ?? '登入成功',
          sessionId: result['sessionId'],
          userData: result,
        );
      } else {
        debugPrint('[NtutAdapter] 登入失敗: ${result['message']}');
        return AuthResult.failure(message: result['message'] ?? '登入失敗');
      }
    } catch (e, stackTrace) {
      debugPrint('[NtutAdapter] 登入錯誤: $e');
      throw SchoolAdapterException('NTUT 登入錯誤: $e', e);
    }
  }

  @override
  Future<bool> checkSession() async {
    try {
      return await _apiService.checkSession();
    } catch (e) {
      debugPrint('[NtutAdapter] 檢查 Session 失敗: $e');
      return false;
    }
  }

  @override
  Future<void> logout() async {
    debugPrint('[NtutAdapter] 登出');
    _apiService.logout();
  }

  @override
  Future<Student?> getStudentProfile(String studentId) async {
    try {
      debugPrint('[NtutAdapter] 獲取學生資料: $studentId');
      
      // NTUT API 目前沒有專門的學生資料端點
      // 可以從登入結果中取得基本資料，或從後端獲取
      return await _backendService.getProfile(studentId);
    } catch (e) {
      debugPrint('[NtutAdapter] 獲取學生資料失敗: $e');
      
      if (_isSessionExpired(e)) {
        throw SessionExpiredException();
      }
      
      throw SchoolAdapterException('獲取學生資料失敗: $e', e);
    }
  }

  @override
  Future<List<Course>> getCourses(String studentId, {String? semester}) async {
    try {
      debugPrint('[NtutAdapter] 獲取課表: $studentId, semester: $semester');
      
      // 如果沒有指定學期，獲取所有可用學期的課表
      if (semester == null) {
        debugPrint('[NtutAdapter] 獲取所有學期的課表');
        final allCourses = <Course>[];
        
        // 獲取可用學期列表
        final availableSemesters = await _apiService.getAvailableSemesters();
        debugPrint('[NtutAdapter] 找到 ${availableSemesters.length} 個可用學期');
        
        for (final sem in availableSemesters) {
          final year = sem['year'].toString();
          final semNum = sem['semester'] as int;
          
          try {
            final semCourses = await _getCoursesBySemester(studentId, year, semNum);
            allCourses.addAll(semCourses);
          } catch (e) {
            debugPrint('[NtutAdapter] 獲取學期 $year-$semNum 課表失敗: $e');
          }
        }
        
        return allCourses;
      } else {
        // 解析學期格式（例如：113-1）
        final parts = semester.split('-');
        if (parts.length != 2) {
          throw SchoolAdapterException('無效的學期格式: $semester（應為 year-semester，例如：113-1）');
        }
        
        final year = parts[0];
        final semNum = int.parse(parts[1]);
        
        return await _getCoursesBySemester(studentId, year, semNum);
      }
    } catch (e) {
      debugPrint('[NtutAdapter] 獲取課表失敗: $e');
      
      if (_isSessionExpired(e)) {
        throw SessionExpiredException();
      }
      
      throw SchoolAdapterException('獲取課表失敗: $e', e);
    }
  }

  /// 獲取指定學期的課表
  Future<List<Course>> _getCoursesBySemester(
    String studentId,
    String year,
    int semester,
  ) async {
    debugPrint('[NtutAdapter] 獲取學期課表: $year-$semester');
    
    final coursesData = await _apiService.getCourseTable(
      year: year,
      semester: semester,
    );
    
    if (coursesData.isEmpty) {
      debugPrint('[NtutAdapter] 該學期沒有課程: $year-$semester');
      return [];
    }
    
    // 轉換為 Course 物件
    final courses = <Course>[];
    for (final data in coursesData) {
      try {
        // 補充學期資訊
        final enrichedData = {
          ...data,
          'semester': '$year-$semester',
          'studentId': studentId,
        };
        courses.add(Course.fromJson(enrichedData));
      } catch (e) {
        debugPrint('[NtutAdapter] 解析課程失敗: ${data['courseName']}, 錯誤: $e');
      }
    }
    
    debugPrint('[NtutAdapter] 成功獲取 ${courses.length} 門課程');
    return courses;
  }

  @override
  Future<List<Grade>> getGrades(String studentId, {String? semester}) async {
    try {
      debugPrint('[NtutAdapter] 獲取成績: $studentId, semester: $semester');
      
      // 從 NTUT API 獲取成績（需要 sessionId，但 getGrades 目前沒有用到）
      final gradesData = await _apiService.getGrades(_apiService.isLoggedIn ? 'dummy' : '');
      
      if (gradesData.isEmpty) {
        debugPrint('[NtutAdapter] 未獲取到成績資料');
        return [];
      }
      
      // 轉換為 Grade 物件
      final grades = <Grade>[];
      for (final data in gradesData) {
        try {
          grades.add(Grade.fromJson(data));
        } catch (e) {
          debugPrint('[NtutAdapter] 解析成績失敗: ${data['courseName']}, 錯誤: $e');
        }
      }
      
      // 如果指定了學期，過濾出該學期的成績
      if (semester != null) {
        final filteredGrades = grades.where((g) => g.semester == semester).toList();
        debugPrint('[NtutAdapter] 成功獲取 ${filteredGrades.length} 筆成績（學期: $semester）');
        return filteredGrades;
      }
      
      debugPrint('[NtutAdapter] 成功獲取 ${grades.length} 筆成績');
      return grades;
    } catch (e) {
      debugPrint('[NtutAdapter] 獲取成績失敗: $e');
      
      if (_isSessionExpired(e)) {
        throw SessionExpiredException();
      }
      
      throw SchoolAdapterException('獲取成績失敗: $e', e);
    }
  }

  @override
  Future<Map<String, dynamic>> syncToBackend({
    required String studentId,
    Student? student,
    List<Course>? courses,
    List<Grade>? grades,
  }) async {
    try {
      debugPrint('[NtutAdapter] 同步資料到後端: $studentId');
      
      final result = await _backendService.syncData(
        studentId: studentId,
        student: student,
        courses: courses,
        grades: grades,
      );
      
      debugPrint('[NtutAdapter] 同步完成: ${result['synced']}');
      return result;
    } catch (e) {
      debugPrint('[NtutAdapter] 同步失敗: $e');
      throw SchoolAdapterException('同步到後端失敗: $e', e);
    }
  }

  @override
  Future<List<dynamic>> getCalendarEvents({bool forceRefresh = false}) async {
    try {
      debugPrint('[NtutAdapter] 獲取學校行事曆');
      
      // NTUT API 沒有專門的行事曆 API
      // 可以從課表或其他來源獲取
      // 目前返回空列表，讓 CalendarProvider 使用本地事件
      return [];
    } catch (e) {
      debugPrint('[NtutAdapter] 獲取行事曆失敗: $e');
      return [];
    }
  }

  /// 判斷錯誤是否為 Session 過期
  bool _isSessionExpired(dynamic error) {
    final errorStr = error.toString().toLowerCase();
    return errorStr.contains('session') ||
        errorStr.contains('登入') ||
        errorStr.contains('login') ||
        errorStr.contains('unauthorized') ||
        errorStr.contains('401');
  }
}
