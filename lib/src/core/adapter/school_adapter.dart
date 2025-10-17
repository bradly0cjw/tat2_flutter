import '../auth/auth_credential.dart';
import '../auth/auth_result.dart';
import '../../models/course.dart';
import '../../models/grade.dart';
import '../../models/student.dart';

/// 學校 Adapter 抽象介面
/// 
/// 定義所有學校必須實作的標準介面
/// 讓應用能夠支援不同學校的 API，只需實作此介面即可
abstract class SchoolAdapter {
  /// 學校名稱（例如：NTUT, NTNU, NTU）
  String get schoolName;

  /// 是否已登入
  bool get isLoggedIn;

  /// 登入
  /// 
  /// 使用學校的認證系統進行登入
  /// 實作應該處理所有必要的 Cookie、Session 管理
  Future<AuthResult> login(AuthCredential credential);

  /// 檢查 Session 是否有效
  Future<bool> checkSession();

  /// 登出
  Future<void> logout();

  /// 獲取學生資料
  Future<Student?> getStudentProfile(String studentId);

  /// 獲取課表
  /// 
  /// [studentId] 學號
  /// [semester] 學期（可選，格式由各校定義，例如：'113-1'）
  Future<List<Course>> getCourses(String studentId, {String? semester});

  /// 獲取成績
  /// 
  /// [studentId] 學號
  /// [semester] 學期（可選）
  Future<List<Grade>> getGrades(String studentId, {String? semester});

  /// 獲取學校行事曆
  /// 
  /// 返回學校的官方行事曆事件
  /// 某些學校可能不提供此功能，可返回空列表
  Future<List<dynamic>> getCalendarEvents({bool forceRefresh = false}) async {
    // 預設實作：返回空列表（某些學校可能沒有行事曆 API）
    return [];
  }

  /// 同步所有資料到後端
  /// 
  /// 批量同步學生資料、課表、成績到後端 API
  Future<Map<String, dynamic>> syncToBackend({
    required String studentId,
    Student? student,
    List<Course>? courses,
    List<Grade>? grades,
  });
}

/// 學校 Adapter 異常
class SchoolAdapterException implements Exception {
  final String message;
  final dynamic originalError;
  
  SchoolAdapterException(this.message, [this.originalError]);
  
  @override
  String toString() => 'SchoolAdapterException: $message${originalError != null ? ' (原因: $originalError)' : ''}';
}

/// Session 過期異常
class SessionExpiredException extends SchoolAdapterException {
  SessionExpiredException([super.message = 'Session 已過期']);
}

/// 認證失敗異常
class AuthenticationException extends SchoolAdapterException {
  AuthenticationException([super.message = '認證失敗']);
}
