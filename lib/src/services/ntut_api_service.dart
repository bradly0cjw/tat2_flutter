import 'package:cookie_jar/cookie_jar.dart';
import 'ntut/ntut_services.dart';

/// NTUT API Service（統一入口）
/// 
/// 這個類整合了所有 NTUT 相關的服務，提供統一的訪問接口。
/// 
/// 架構說明：
/// - NtutAuthService: 處理認證（登入、登出、Session）
/// - NtutCourseService: 處理課程相關（課表、學期、大綱）
/// - NtutGradeService: 處理成績和排名
/// - NtutAdminService: 處理校務系統 SSO
/// - CourseSearchService: 課程搜索（使用後端 API）
/// 
/// 使用方式：
/// ```dart
/// final ntutApi = NtutApiService();
/// 
/// // 方式 1: 直接訪問子服務（推薦）
/// await ntutApi.auth.login(username, password);
/// final courses = await ntutApi.course.getCourseTable(year: '113', semester: 2);
/// final grades = await ntutApi.grade.getGrades();
/// final searchResults = await ntutApi.courseSearch.searchCourses(keyword: '程式設計');
/// 
/// // 方式 2: 使用向後兼容的方法
/// await ntutApi.login(username, password);
/// final courses = await ntutApi.getCourseTable(year: '113', semester: 2);
/// ```
class NtutApiService {
  late final NtutAuthService _authService;
  late final NtutCourseService _courseService;
  late final NtutGradeService _gradeService;
  late final NtutAdminService _adminService;
  late final CourseSearchService _courseSearchService;

  // 提供訪問各個服務的 getter
  NtutAuthService get auth => _authService;
  NtutCourseService get course => _courseService;
  NtutGradeService get grade => _gradeService;
  NtutAdminService get admin => _adminService;
  CourseSearchService get courseSearch => _courseSearchService;

  // 便利的屬性（向後兼容）
  bool get isLoggedIn => _authService.isLoggedIn;
  String? get jsessionId => _authService.jsessionId;
  String? get userIdentifier => _authService.userIdentifier;
  CookieJar get cookieJar => _authService.cookieJar;

  static const String baseUrl = NtutAuthService.baseUrl;
  static const String courseBaseUrl = 'https://aps.ntut.edu.tw';
  static const String userAgent = NtutAuthService.userAgent;

  NtutApiService({CookieJar? cookieJar}) {
    // 初始化認證服務（核心服務）
    _authService = NtutAuthService(cookieJar: cookieJar);
    
    // 初始化其他依賴認證服務的服務
    _courseService = NtutCourseService(authService: _authService);
    _gradeService = NtutGradeService(authService: _authService);
    _adminService = NtutAdminService(authService: _authService);
    
    // 初始化獨立的課程搜索服務（使用後端 API）
    _courseSearchService = CourseSearchService();
  }

  // ==================== 認證相關（向後兼容） ====================

  /// 登入
  Future<Map<String, dynamic>> login(String username, String password) async {
    return await _authService.login(username, password);
  }

  /// 檢查 Session
  Future<bool> checkSession() async {
    return await _authService.checkSession();
  }

  /// 登出
  void logout() {
    _authService.logout();
  }

  // ==================== 課程相關（向後兼容） ====================

  /// 取得可用學期列表
  Future<List<Map<String, dynamic>>> getAvailableSemesters() async {
    return await _courseService.getAvailableSemesters();
  }

  /// 取得課表
  Future<List<Map<String, dynamic>>> getCourseTable({
    required String year,
    required int semester,
  }) async {
    return await _courseService.getCourseTable(year: year, semester: semester);
  }

  /// 取得課程大綱
  Future<Map<String, dynamic>?> getCourseSyllabus({
    required String syllabusNumber,
    required String teacherCode,
  }) async {
    return await _courseService.getCourseSyllabus(
      syllabusNumber: syllabusNumber,
      teacherCode: teacherCode,
    );
  }

  // ==================== 成績相關（向後兼容） ====================

  /// 取得成績
  Future<List<Map<String, dynamic>>> getGrades(String sessionId) async {
    return await _gradeService.getGrades();
  }

  /// 取得排名
  Future<Map<String, Map<String, dynamic>>> getScoreRanks() async {
    return await _gradeService.getScoreRanks();
  }

  // ==================== 校務系統相關（向後兼容） ====================

  /// 取得校務系統 URL
  Future<String?> getAdminSystemUrl(String serviceCode) async {
    return await _adminService.getAdminSystemUrl(serviceCode);
  }

  /// 取得校務系統樹狀結構
  Future<Map<String, dynamic>?> getAdminSystemTree({String? apDn}) async {
    return await _adminService.getAdminSystemTree(apDn: apDn);
  }

  /// 取得系統樹（已廢棄）
  @Deprecated('使用 getAdminSystemTree 代替')
  Future<Map<String, dynamic>> getSystemTree(String sessionId, String apDn) async {
    return await _adminService.getSystemTree(sessionId, apDn);
  }

  // ==================== 課程搜索相關（向後兼容） ====================

  /// 搜尋課程（使用後端 API）
  Future<List<Map<String, dynamic>>> searchCourses({
    String? keyword,
    String year = '114',
    String semester = '1',
    String? category,
    String? college,
    List<Map<String, dynamic>>? timeSlots,
    String? gradeCode,
    String? programCode,
    String? programType,
  }) async {
    return await _courseSearchService.searchCourses(
      keyword: keyword,
      year: year,
      semester: semester,
      category: category,
      college: college,
      timeSlots: timeSlots,
      gradeCode: gradeCode,
      programCode: programCode,
      programType: programType,
    );
  }

  /// 取得學院結構
  Future<Map<String, dynamic>?> getColleges({
    String year = '114',
    String semester = '1',
  }) async {
    return await _courseSearchService.getColleges(year: year, semester: semester);
  }

  /// 根據班級代碼查詢課程
  Future<List<Map<String, dynamic>>> getCoursesByGrade({
    required String gradeCode,
    String year = '114',
    String semester = '1',
  }) async {
    return await _courseSearchService.getCoursesByGrade(
      gradeCode: gradeCode,
      year: year,
      semester: semester,
    );
  }

  /// 取得學程列表
  Future<Map<String, dynamic>?> getPrograms({
    String year = '114',
    String semester = '1',
  }) async {
    return await _courseSearchService.getPrograms(year: year, semester: semester);
  }

  /// 根據學程代碼查詢課程
  Future<List<Map<String, dynamic>>> getCoursesByProgram({
    required String programCode,
    String type = 'micro-program',
    String year = '114',
    String semester = '1',
  }) async {
    return await _courseSearchService.getCoursesByProgram(
      programCode: programCode,
      type: type,
      year: year,
      semester: semester,
    );
  }

  /// 取得課程詳細資料
  Future<Map<String, dynamic>?> getCourseDetail(
    String courseId, {
    String year = '114',
    String semester = '1',
  }) async {
    return await _courseSearchService.getCourseDetail(
      courseId,
      year: year,
      semester: semester,
    );
  }

  // ==================== 向後兼容的方法 ====================

  /// 取得課表列表（已廢棄）
  @Deprecated('使用 getAvailableSemesters 代替')
  Future<List<Map<String, dynamic>>> getCourseTableList() async {
    return await getAvailableSemesters();
  }

  /// 取得 Cookies
  Future<List<Cookie>> getCookiesForUrl(Uri url) async {
    return await _authService.getCookiesForUrl(url);
  }
}
