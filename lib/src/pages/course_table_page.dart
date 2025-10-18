import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../services/ntut_api_service.dart';
import '../services/auth_service.dart';
import '../providers/auth_provider_v2.dart';
import '../services/course_color_service.dart';
import '../services/widget_service.dart' hide debugPrint; // 導入 Widget 服務,但隱藏 debugPrint 避免衝突
import '../widgets/weekly_course_table.dart';
import 'course_syllabus_page.dart';

class CourseTablePage extends StatefulWidget {
  const CourseTablePage({super.key});

  @override
  State<CourseTablePage> createState() => _CourseTablePageState();
}

class _CourseTablePageState extends State<CourseTablePage> {
  List<Map<String, dynamic>> _courses = [];
  bool _isLoading = false;
  String _error = '';
  
  // 追蹤是否已完成初始載入(用於區分「載入中」和「載入完成但沒資料」)
  bool _hasInitialLoaded = false;
  
  // 用於課表截圖的 GlobalKey
  final GlobalKey _courseTableKey = GlobalKey();
  
  // 當前選擇的學年學期
  int _selectedYear = 113;
  int _selectedSemester = 1;
  
  // 可選的學年學期列表（只顯示有課程的學期）
  List<Map<String, dynamic>> _availableSemesters = [];
  
  // 本地緩存
  static const String _cacheBoxName = 'course_table_cache';
  static const String _preferenceKey = 'selected_semester';
  Box? _cacheBox;
  DateTime? _lastCacheTime;
  
  // 追蹤是否正在等待登入
  bool _waitingForLogin = false;
  
  @override
  void initState() {
    super.initState();
    debugPrint('[CourseTable] 初始化開始');
    _initServices();
    
    // 監聽登入狀態變化
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final authProvider = context.read<AuthProviderV2>();
      authProvider.addListener(_onAuthStateChanged);
    });
  }
  
  @override
  void dispose() {
    // 移除監聽器
    try {
      final authProvider = context.read<AuthProviderV2>();
      authProvider.removeListener(_onAuthStateChanged);
    } catch (e) {
      // Context 可能已經不可用
    }
    super.dispose();
  }
  
  /// 監聽登入狀態變化
  void _onAuthStateChanged() {
    final authProvider = context.read<AuthProviderV2>();
    
    // 如果正在等待登入，且現在已登入成功，則自動重新載入
    if (_waitingForLogin && authProvider.isLoggedIn && !authProvider.isLoading) {
      debugPrint('[CourseTable] 檢測到登入完成，重新載入學期列表');
      _waitingForLogin = false;
      _loadAvailableSemesters();
    }
  }
  
  /// 初始化服務
  Future<void> _initServices() async {
    await _initCache();
  }
  
  /// 初始化本地緩存
  Future<void> _initCache() async {
    try {
      _cacheBox = await Hive.openBox(_cacheBoxName);
      debugPrint('[CourseTable] 緩存已初始化');
      
      // 檢查登入狀態
      final authProvider = context.read<AuthProviderV2>();
      if (authProvider.isLoggedIn) {
        // 已登入，立即載入
        await _loadAvailableSemesters();
      } else if (authProvider.isLoading) {
        // 正在登入中，等待登入完成
        debugPrint('[CourseTable] 正在登入中，等待登入完成...');
        setState(() {
          _waitingForLogin = true;
          _isLoading = true;
        });
      } else {
        // 未登入也未在登入中，嘗試從緩存載入或顯示空白
        debugPrint('[CourseTable] 未登入，嘗試從緩存載入');
        await _loadAvailableSemesters();
      }
    } catch (e) {
      debugPrint('[CourseTable] 初始化緩存失敗: $e');
      await _loadAvailableSemesters();
    }
  }
  
  /// 更新桌面小工具截圖
  Future<void> _updateWidget() async {
    // 延遲確保 UI 渲染完成
    await Future.delayed(const Duration(milliseconds: 300));
    await WidgetService.updateWidgetWithScreenshot(_courseTableKey);
  }
  
  /// 載入可用的學年學期列表
  Future<void> _loadAvailableSemesters({int retryCount = 0}) async {
    setState(() => _isLoading = true);
    
    // 獲取當前時間判斷當前學期
    final now = DateTime.now();
    int currentYear = now.year - 1911; // 轉換為民國年
    int currentSemester = (now.month >= 2 && now.month <= 7) ? 2 : 1;
    
    final apiService = context.read<NtutApiService>();
    final authProvider = context.read<AuthProviderV2>();
    
    try {
      // 先嘗試從緩存讀取學期列表
      List<Map<String, dynamic>> availableSemesters = [];
      const semestersCacheKey = 'available_semesters';
      const semestersCacheTimeKey = 'available_semesters_time';
      final cachedSemesters = _cacheBox?.get(semestersCacheKey);
      final cachedTime = _cacheBox?.get(semestersCacheTimeKey);
      
      // 緩存永不過期（除非手動刷新）
      bool hasCache = false;
      
      if (cachedSemesters != null) {
        availableSemesters = (cachedSemesters as List)
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList();
        hasCache = true;
        
        if (cachedTime != null) {
          final cacheDateTime = DateTime.parse(cachedTime);
          final difference = DateTime.now().difference(cacheDateTime);
          debugPrint('[CourseTable] 使用緩存的學期列表（${availableSemesters.length} 個，${difference.inDays} 天前更新）');
        } else {
          debugPrint('[CourseTable] 使用緩存的學期列表（${availableSemesters.length} 個）');
        }
      }
      
      // 如果沒有緩存且未手動刷新，從 API 獲取
      // 注意：retryCount > 0 表示這是手動刷新
      if (!hasCache || retryCount > 0) {
        // 檢查是否已登入
        if (!authProvider.isLoggedIn) {
          // 如果有緩存，先使用緩存顯示
          if (hasCache && availableSemesters.isNotEmpty) {
            debugPrint('[CourseTable] 未登入，使用緩存的學期列表');
            // 繼續使用緩存，不中斷流程
          } else {
            debugPrint('[CourseTable] 未登入，等待登入完成');
            setState(() {
              _waitingForLogin = true;
              _isLoading = true;
            });
            return;
          }
        } else {
          debugPrint('[CourseTable] 從 API 獲取學期列表');
          
          try {
            final fetchedSemesters = await apiService.getAvailableSemesters();
            
            if (fetchedSemesters.isNotEmpty) {
              availableSemesters = fetchedSemesters;
              
              // 保存到緩存
              if (_cacheBox != null) {
                await _cacheBox!.put(semestersCacheKey, availableSemesters);
                await _cacheBox!.put(semestersCacheTimeKey, DateTime.now().toIso8601String());
                debugPrint('[CourseTable] 已更新學期列表緩存');
              }
            } else if (!hasCache) {
              // 沒有獲取到數據且沒有緩存
              debugPrint('[CourseTable] 無可用學期');
              setState(() {
                _isLoading = false;
                _error = '無法獲取可用學期列表';
              });
              return;
            }
            // 如果有緩存但新請求沒有數據，繼續使用緩存
          } catch (e) {
            debugPrint('[CourseTable] API 獲取學期列表失敗: $e');
            
            // 如果有緩存，使用緩存並顯示提示
            if (hasCache && availableSemesters.isNotEmpty) {
              debugPrint('[CourseTable] 使用緩存的學期列表');
              
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: const Text('更新失敗，使用緩存的學期列表'),
                    action: SnackBarAction(
                      label: '重試',
                      onPressed: () => _loadAvailableSemesters(retryCount: 1),
                    ),
                  ),
                );
              }
            } else {
              // 沒有緩存，拋出異常觸發重試邏輯
              rethrow;
            }
          }
        }
      } else {
        // 有緩存且非手動刷新，直接使用緩存
        debugPrint('[CourseTable] 直接使用緩存，跳過 API 請求');
      }
      
      if (availableSemesters.isEmpty) {
        debugPrint('[CourseTable] 無可用學期');
        setState(() {
          _isLoading = false;
          _error = '無法獲取可用學期列表';
        });
        return;
      }
      
      debugPrint('[CourseTable] 獲取到 ${availableSemesters.length} 個學期');
      
      // 檢查每個學期的緩存,計算課程數量
      final List<Map<String, dynamic>> semestersWithCount = [];
      
      for (final semesterInfo in availableSemesters) {
        final year = semesterInfo['year'] as int;
        final semester = semesterInfo['semester'] as int;
        final cacheKey = 'courses_${year}_$semester';
        final cachedData = _cacheBox?.get(cacheKey);
        
        int courseCount = 0;
        if (cachedData != null) {
          courseCount = (cachedData as List).length;
        }
        
        semestersWithCount.add({
          'year': year,
          'semester': semester,
          'courseCount': courseCount,
        });
      }
      
      // 優先選擇用戶上次選擇的學期，如果不存在則選擇當前學期
      int selectedYear = currentYear;
      int selectedSemester = currentSemester;
      bool foundPreferredSemester = false;
      
      // 1. 嘗試讀取用戶上次選擇的學期
      final savedSemester = _cacheBox?.get(_preferenceKey) as String?;
      if (savedSemester != null) {
        final parts = savedSemester.split('-');
        if (parts.length == 2) {
          final savedYear = int.tryParse(parts[0]);
          final savedSem = int.tryParse(parts[1]);
          
          if (savedYear != null && savedSem != null) {
            // 檢查保存的學期是否在可用列表中
            for (final s in semestersWithCount) {
              if (s['year'] == savedYear && s['semester'] == savedSem) {
                selectedYear = savedYear;
                selectedSemester = savedSem;
                foundPreferredSemester = true;
                break;
              }
            }
          }
        }
      }
      
      // 2. 如果沒有保存的學期或保存的學期不可用,嘗試當前學期
      if (!foundPreferredSemester) {
        for (final s in semestersWithCount) {
          if (s['year'] == currentYear && s['semester'] == currentSemester) {
            foundPreferredSemester = true;
            debugPrint('[CourseTable] 使用當前學期: $selectedYear-$selectedSemester');
            break;
          }
        }
        
        // 3. 如果當前學期也不在列表中,選擇第一個(最新的)
        if (!foundPreferredSemester && semestersWithCount.isNotEmpty) {
          selectedYear = semestersWithCount[0]['year'];
          selectedSemester = semestersWithCount[0]['semester'];
        }
      }
      
      setState(() {
        _availableSemesters = semestersWithCount;
        _selectedYear = selectedYear;
        _selectedSemester = selectedSemester;
        _isLoading = false;
      });
      
      // 檢查選中學期的緩存
      final selectedCacheKey = 'courses_${selectedYear}_$selectedSemester';
      final selectedCachedData = _cacheBox?.get(selectedCacheKey);
      
      if (selectedCachedData != null) {
        // 有緩存,使用延遲來確保 UI 預先構建,避免視覺卡頓
        final List<Map<String, dynamic>> cachedCourses = 
          (selectedCachedData as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();
        
        final cacheTimeKey = 'cache_time_${selectedYear}_$selectedSemester';
        final cachedTime = _cacheBox?.get(cacheTimeKey);
        
        debugPrint('[CourseTable] 使用緩存課表: ${cachedCourses.length} 門課程');
        
        // 關鍵優化:使用短暫延遲讓 UI 預先構建,避免視覺卡頓
        await Future.delayed(const Duration(milliseconds: 50));
        
        setState(() {
          _courses = cachedCourses;
          _lastCacheTime = cachedTime != null ? DateTime.parse(cachedTime) : null;
          _hasInitialLoaded = true; // 標記已完成初始載入
        });
      } else {
        // 沒有緩存,需要載入
        _loadCourseTable();
      }
      
    } catch (e) {
      debugPrint('[CourseTable] 載入學期失敗: $e');
      
      // 如果是未登入的錯誤，等待登入完成
      if (e.toString().contains('請先登入') || e.toString().contains('401')) {
        debugPrint('[CourseTable] 檢測到未登入錯誤，等待登入完成');
        setState(() {
          _waitingForLogin = true;
          _isLoading = true;
          _error = '';
        });
      } else {
        // 其他錯誤顯示錯誤訊息，並提供重試按鈕
        setState(() {
          _isLoading = false;
          _error = '載入學期列表失敗: $e';
        });
        
        // 顯示重試提示
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('載入失敗: $e'),
              duration: const Duration(seconds: 5),
              action: SnackBarAction(
                label: '重試',
                onPressed: () => _loadAvailableSemesters(retryCount: 1),
              ),
            ),
          );
        }
      }
    }
  }
  
  Future<void> _loadCourseTable({bool forceRefresh = false}) async {
    setState(() {
      _isLoading = true;
      _error = '';
    });
    
    final cacheKey = 'courses_${_selectedYear}_$_selectedSemester';
    final cacheTimeKey = 'cache_time_${_selectedYear}_$_selectedSemester';
    
    try {
      // 1. 先嘗試從緩存載入
      if (!forceRefresh && _cacheBox != null) {
        final cachedData = _cacheBox!.get(cacheKey);
        final cachedTime = _cacheBox!.get(cacheTimeKey);
        
        if (cachedData != null) {
          // 緩存存在，直接使用緩存（不檢查時效）
          final List<Map<String, dynamic>> cachedCourses = 
            (cachedData as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();
          
          setState(() {
            _courses = cachedCourses;
            _lastCacheTime = cachedTime != null ? DateTime.parse(cachedTime) : null;
            _isLoading = false;
            _hasInitialLoaded = true; // 標記已完成初始載入
          });
          
          // 更新桌面小工具
          _updateWidget();
          
          return; // 直接返回,不更新
        }
      }
      
      debugPrint('[CourseTable] 從 API 獲取課表...');
      
      // 2. 從 API 獲取最新數據
      final apiService = context.read<NtutApiService>();
      final courses = await apiService.getCourseTable(
        year: _selectedYear.toString(),
        semester: _selectedSemester,
      );
      
      // 3. 保存到緩存
      if (_cacheBox != null) {
        await _cacheBox!.put(cacheKey, courses);
        await _cacheBox!.put(cacheTimeKey, DateTime.now().toIso8601String());
        debugPrint('[CourseTable] 已緩存: ${courses.length} 門課');
      }
      
      setState(() {
        _courses = courses;
        _lastCacheTime = DateTime.now();
        _isLoading = false;
        _hasInitialLoaded = true; // 標記已完成初始載入
      });
      
      // 更新桌面小工具
      _updateWidget();
    } catch (e) {
      // 如果網路請求失敗但有緩存，使用緩存
      if (_courses.isNotEmpty) {
        setState(() {
          _error = '更新失敗,顯示緩存數據';
          _isLoading = false;
          _hasInitialLoaded = true; // 標記已完成初始載入
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('更新失敗:${e.toString()}'),
            action: SnackBarAction(
              label: '重試',
              onPressed: () => _loadCourseTable(forceRefresh: true),
            ),
          ),
        );
      } else {
        setState(() {
          _error = e.toString();
          _isLoading = false;
          _hasInitialLoaded = true; // 即使錯誤也標記已完成載入
        });
        
        // 如果是 session 失效,嘗試自動登入
        if (e.toString().contains('請先登入') || e.toString().contains('401')) {
          await _tryAutoLogin();
        }
      }
    }
  }
  
  Future<void> _tryAutoLogin() async {
    final authProvider = context.read<AuthProviderV2>();
    final result = await authProvider.tryAutoLogin();
    
    if (result) {
      // 自動登入成功，重新加載課表
      _loadCourseTable();
    } else {
      // 自動登入失敗，顯示登入提示對話框
      if (mounted) {
        _showLoginPrompt();
      }
    }
  }
  
  /// 顯示登入提示對話框
  void _showLoginPrompt() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('需要登入'),
        content: const Text('獲取最新課表需要登入。您可以選擇登入或繼續使用離線模式。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('稍後登入'),
          ),
          FilledButton(
            onPressed: () async {
              Navigator.of(context).pop();
              // 導航到登入頁面
              final result = await Navigator.of(context).pushNamed('/login');
              // 登入成功後重新載入
              if (result == true && mounted) {
                _loadCourseTable(forceRefresh: true);
              }
            },
            child: const Text('立即登入'),
          ),
        ],
      ),
    );
  }
  
  void _changeSemester(int year, int semester) {
    setState(() {
      _selectedYear = year;
      _selectedSemester = semester;
      _hasInitialLoaded = false; // 切換學期時重置標記
    });
    
    // 保存用戶的選擇
    _saveSelectedSemester(year, semester);
    
    _loadCourseTable();
  }
  
  /// 保存用戶選擇的學期
  Future<void> _saveSelectedSemester(int year, int semester) async {
    try {
      await _cacheBox?.put(_preferenceKey, '$year-$semester');
    } catch (e) {
      debugPrint('[CourseTable] 保存學期選擇失敗: $e');
    }
  }
  
  /// 格式化緩存時間顯示
  String _formatCacheTime(DateTime time) {
    final now = DateTime.now();
    final difference = now.difference(time);
    
    if (difference.inMinutes < 1) {
      return '剛剛';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes} 分鐘前';
    } else if (difference.inHours < 24) {
      return '${difference.inHours} 小時前';
    } else {
      return '${time.month}/${time.day} ${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
    }
  }
  
  /// 顯示課程詳情並提供跳轉到課程大綱
  void _showCourseDetail(Map<String, dynamic> course) {
    final courseId = course['courseId'] ?? '';
    // 判斷是否為無課號課程(如班會課、導師時間等)
    final hasNoCourseId = courseId.isEmpty || courseId.startsWith('NO_ID_');
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(course['courseName'] ?? ''),
        content: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // 只有有課號的課程才顯示課號
            if (!hasNoCourseId)
              Text('課號:$courseId'),
            Text('學分:${course['credits']} / 時數:${course['hours']}'),
            if (course['instructor']?.isNotEmpty == true)
              Text('教師：${course['instructor']}'),
            if (course['classroom']?.isNotEmpty == true)
              Text('教室：${course['classroom']}'),
            if (course['required']?.isNotEmpty == true)
              Text('修別：${course['required']}'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('關閉'),
          ),
          // 只有有課號的課程才顯示查看大綱按鈕
          if (!hasNoCourseId && courseId.isNotEmpty)
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                _navigateToSyllabus(course);
              },
              child: const Text('查看大綱'),
            ),
        ],
      ),
    );
  }
  
  /// 跳轉到課程大綱頁面
  void _navigateToSyllabus(Map<String, dynamic> course) {
    final syllabusNumber = course['syllabusNumber'] as String?;
    final teacherCode = course['teacherCode'] as String?;
    
    if (syllabusNumber == null || teacherCode == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('此課程無課程大綱資料')),
      );
      return;
    }
    
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CourseSyllabusPage(
          syllabusNumber: syllabusNumber,
          teacherCode: teacherCode,
          courseInfo: course,
        ),
      ),
    );
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_availableSemesters.isNotEmpty 
          ? '$_selectedYear 學年度 第 $_selectedSemester 學期'
          : '課表'),
        actions: [
          // 學期選擇
          if (_availableSemesters.isNotEmpty)
            PopupMenuButton<String>(
              icon: const Icon(Icons.calendar_today),
              tooltip: '選擇學期',
              onSelected: (value) {
                final parts = value.split('-');
                _changeSemester(int.parse(parts[0]), int.parse(parts[1]));
              },
              itemBuilder: (context) {
                return _availableSemesters.map((semesterInfo) {
                  final year = semesterInfo['year'] as int;
                  final semester = semesterInfo['semester'] as int;
                  final count = semesterInfo['courseCount'] as int? ?? 0;
                  final isSelected = year == _selectedYear && semester == _selectedSemester;
                  return PopupMenuItem<String>(
                    value: '$year-$semester',
                    child: Row(
                      children: [
                        if (isSelected)
                          const Icon(Icons.check, size: 16),
                        if (isSelected)
                          const SizedBox(width: 8),
                        Text('$year 學年度 第 $semester 學期${count > 0 ? " ($count 門課)" : ""}'),
                      ],
                    ),
                  );
                }).toList();
              },
            ),
          // 刷新菜單
          PopupMenuButton<String>(
            icon: const Icon(Icons.refresh),
            tooltip: '刷新',
            onSelected: (value) {
              if (value == 'refresh_table') {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('重新取得課表中...')),
                );
                _loadCourseTable(forceRefresh: true);
              } else if (value == 'refresh_semesters') {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('重新取得學期列表中...')),
                );
                _loadAvailableSemesters(retryCount: 1);
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem<String>(
                value: 'refresh_table',
                child: Row(
                  children: [
                    Icon(Icons.table_chart),
                    SizedBox(width: 8),
                    Text('刷新課表'),
                  ],
                ),
              ),
              const PopupMenuItem<String>(
                value: 'refresh_semesters',
                child: Row(
                  children: [
                    Icon(Icons.calendar_month),
                    SizedBox(width: 8),
                    Text('刷新學期列表'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: _buildBody(),
    );
  }
  
  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('載入中...'),
          ],
        ),
      );
    }
    
    if (_error.isNotEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 64, color: Colors.red),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Text(
                '錯誤：$_error',
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton.icon(
                  onPressed: () => _loadCourseTable(forceRefresh: true),
                  icon: const Icon(Icons.table_chart),
                  label: const Text('重試課表'),
                ),
                const SizedBox(width: 16),
                ElevatedButton.icon(
                  onPressed: () => _loadAvailableSemesters(retryCount: 1),
                  icon: const Icon(Icons.calendar_month),
                  label: const Text('重試學期'),
                ),
              ],
            ),
          ],
        ),
      );
    }
    
    // 只在已完成初始載入且確實沒有資料時才顯示「沒有課程資料」
    // 避免在載入緩存前閃現這個訊息
    if (_courses.isEmpty) {
      if (_hasInitialLoaded) {
        // 已完成載入但沒有資料
        return const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.inbox, size: 64, color: Colors.grey),
              SizedBox(height: 16),
              Text('沒有課程資料'),
            ],
          ),
        );
      } else {
        // 還在載入中（顯示佔位符避免閃現）
        return const SizedBox.shrink();
      }
    }
    
    final colorService = context.watch<CourseColorService>();
    
    return WeeklyCourseTable(
      courses: _courses,
      onCourseTap: _showCourseDetail,
      colorService: colorService,
      repaintKey: _courseTableKey,
    );
  }
}
