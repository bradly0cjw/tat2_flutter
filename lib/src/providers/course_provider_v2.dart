import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../models/course.dart';
import '../core/adapter/school_adapter.dart';
import '../core/retry/retry_policy.dart';
import '../core/auth/auth_manager.dart';

/// 課表狀態 Provider（重構版）
/// 
/// 使用 SchoolAdapter 抽象層，支援：
/// 1. 自動重新登入
/// 2. 失敗重試
/// 3. 本地緩存（Hive）
class CourseProviderV2 with ChangeNotifier {
  final SchoolAdapter _adapter;
  final AuthManager _authManager;
  final RetryWithReloginPolicy _retryPolicy;

  List<Course> _courses = [];
  bool _isLoading = false;
  String? _error;
  DateTime? _lastSync;
  
  static const String _hiveBoxName = 'courses_v2';
  Box<Map>? _courseBox;

  CourseProviderV2({
    required SchoolAdapter adapter,
    required AuthManager authManager,
  })  : _adapter = adapter,
        _authManager = authManager,
        _retryPolicy = RetryWithReloginPolicy(authManager: authManager) {
    _initHive();
  }
  
  /// 初始化 Hive 本地儲存
  Future<void> _initHive() async {
    try {
      if (!Hive.isBoxOpen(_hiveBoxName)) {
        _courseBox = await Hive.openBox<Map>(_hiveBoxName);
        await _loadFromLocalCache();
        debugPrint('[CourseProvider] Hive 已初始化');
      }
    } catch (e) {
      debugPrint('[CourseProvider] Hive 初始化失敗: $e');
    }
  }

  // Getters
  List<Course> get courses => _courses;
  bool get isLoading => _isLoading;
  String? get error => _error;
  DateTime? get lastSync => _lastSync;
  bool get hasCourses => _courses.isNotEmpty;

  /// 獲取課表（帶自動重新登入和重試）
  /// 
  /// [studentId] 學號
  /// [semester] 學期（可選）
  /// [forceRefresh] 是否強制刷新（忽略緩存）
  Future<bool> fetchCourses({
    required String studentId,
    String? semester,
    bool forceRefresh = false,
  }) async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      // 如果不強制刷新且有本地緩存，直接使用緩存
      if (!forceRefresh && _courses.isNotEmpty) {
        debugPrint('[CourseProvider] 使用緩存的課表');
        _isLoading = false;
        notifyListeners();
        return true;
      }

      // 從學校 API 獲取課表（帶自動重新登入）
      final courses = await _retryPolicy.execute(
        operation: () => _adapter.getCourses(studentId, semester: semester),
        operationName: '獲取課表',
      );

      if (courses.isEmpty) {
        _error = '未找到課程資料';
        debugPrint('[CourseProvider] 未找到課程資料');
        _isLoading = false;
        notifyListeners();
        return false;
      }

      _courses = courses;
      _lastSync = DateTime.now();

      // 儲存到本地快取
      await _saveToLocalCache(studentId, _courses);

      _isLoading = false;
      notifyListeners();

      debugPrint('[CourseProvider] 成功獲取 ${_courses.length} 門課程');
      return true;
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      debugPrint('[CourseProvider] 獲取課表失敗: $e');
      return false;
    }
  }

  /// 刷新課表（強制從 API 獲取）
  Future<bool> refreshCourses({
    required String studentId,
    String? semester,
  }) async {
    return fetchCourses(
      studentId: studentId,
      semester: semester,
      forceRefresh: true,
    );
  }

  /// 從本地快取載入課表
  Future<void> _loadFromLocalCache() async {
    try {
      if (_courseBox == null) return;
      
      final cachedData = _courseBox!.get('courses');
      if (cachedData != null) {
        _courses = (cachedData['courses'] as List)
            .map((item) => Course.fromJson(Map<String, dynamic>.from(item)))
            .toList();
        _lastSync = DateTime.tryParse(cachedData['timestamp'] ?? '');
        notifyListeners();
      }
    } catch (e) {
      debugPrint('[CourseProvider] 載入緩存失敗: $e');
    }
  }
  
  /// 儲存到本地快取
  Future<void> _saveToLocalCache(String studentId, List<Course> courses) async {
    try {
      if (_courseBox == null) return;
      
      await _courseBox!.put('courses', {
        'studentId': studentId,
        'courses': courses.map((c) => c.toJson()).toList(),
        'timestamp': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      debugPrint('[CourseProvider] 儲存緩存失敗: $e');
    }
  }

  /// 按星期分組課程
  Map<int, List<Course>> get coursesByWeekday {
    final grouped = <int, List<Course>>{};
    
    for (final course in _courses) {
      if (course.timeSlots == null) continue;
      
      // 解析時間
      final weekdayMap = {
        '一': 1, '二': 2, '三': 3, '四': 4, 
        '五': 5, '六': 6, '日': 7,
      };
      
      final firstChar = course.timeSlots!.isNotEmpty 
          ? course.timeSlots!.substring(0, 1) 
          : '';
      final weekday = weekdayMap[firstChar];
      
      if (weekday != null) {
        grouped.putIfAbsent(weekday, () => []);
        grouped[weekday]!.add(course);
      }
    }
    
    return grouped;
  }

  /// 按學期分組
  Map<String, List<Course>> get coursesBySemester {
    final grouped = <String, List<Course>>{};
    for (final course in _courses) {
      final sem = course.semester ?? '未知';
      grouped.putIfAbsent(sem, () => []).add(course);
    }
    return grouped;
  }

  /// 取得當天課程
  List<Course> getTodayCourses() {
    final today = DateTime.now().weekday;
    return coursesByWeekday[today] ?? [];
  }

  /// 清除課表資料
  Future<void> clear() async {
    _courses = [];
    _error = null;
    _lastSync = null;
    
    // 清除本地快取
    if (_courseBox != null) {
      await _courseBox!.delete('courses');
    }
    
    notifyListeners();
    debugPrint('[CourseProvider] 已清除課表資料');
  }

  @override
  void dispose() {
    _courseBox?.close();
    super.dispose();
  }
}
