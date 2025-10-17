import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../services/ntut_api_service.dart';
import '../services/auth_service.dart';

/// 課程大綱頁面 - 原生顯示課程大綱
class CourseSyllabusPage extends StatefulWidget {
  final String syllabusNumber;
  final String teacherCode;
  final Map<String, dynamic> courseInfo;

  const CourseSyllabusPage({
    super.key,
    required this.syllabusNumber,
    required this.teacherCode,
    required this.courseInfo,
  });

  @override
  State<CourseSyllabusPage> createState() => _CourseSyllabusPageState();
}

class _CourseSyllabusPageState extends State<CourseSyllabusPage> {
  bool _isLoading = true;
  String _error = '';
  Map<String, dynamic>? _syllabus;
  
  // 本地緩存
  static const String _cacheBoxName = 'course_syllabus_cache';
  Box? _cacheBox;
  DateTime? _lastCacheTime;

  @override
  void initState() {
    super.initState();
    _initCache();
  }

  /// 初始化本地緩存
  Future<void> _initCache() async {
    try {
      _cacheBox = await Hive.openBox(_cacheBoxName);
      debugPrint('[CourseSyllabus] 緩存已初始化');
      await _loadSyllabus();
    } catch (e) {
      debugPrint('[CourseSyllabus] 初始化緩存失敗: $e');
      await _loadSyllabus();
    }
  }

  @override
  void dispose() {
    // 不需要關閉 box，Hive 會自動管理
    super.dispose();
  }

  /// 獲取緩存鍵
  String get _cacheKey => 'syllabus_${widget.syllabusNumber}_${widget.teacherCode}';

  Future<void> _loadSyllabus({bool forceRefresh = false}) async {
    setState(() {
      _isLoading = true;
      _error = '';
    });

    try {
      // 先檢查緩存
      if (!forceRefresh && _cacheBox != null) {
        final cachedData = _cacheBox!.get(_cacheKey);
        if (cachedData != null) {
          debugPrint('[CourseSyllabus] 從緩存載入: ${widget.syllabusNumber}');
          final cachedSyllabus = Map<String, dynamic>.from(cachedData as Map);
          
          // 讀取緩存時間
          final cacheTimeKey = 'cache_time_$_cacheKey';
          final cachedTime = _cacheBox!.get(cacheTimeKey);
          
          setState(() {
            _syllabus = cachedSyllabus;
            _lastCacheTime = cachedTime != null ? DateTime.parse(cachedTime) : null;
            _isLoading = false;
          });
          return;
        }
      }

      // 緩存未命中或強制刷新,從 API 載入
      debugPrint('[CourseSyllabus] 從 API 載入: ${widget.syllabusNumber}');
      final apiService = context.read<NtutApiService>();
      final authService = context.read<AuthService>();
      
      Map<String, dynamic>? syllabus;
      
      try {
        syllabus = await apiService.getCourseSyllabus(
          syllabusNumber: widget.syllabusNumber,
          teacherCode: widget.teacherCode,
        );
      } catch (e) {
        // 如果是 Session 失效,嘗試自動重新登入
        if (e.toString().contains('Session') || 
            e.toString().contains('401') || 
            e.toString().contains('登入')) {
          debugPrint('[CourseSyllabus] Session 失效,嘗試自動登入');
          
          final loginResult = await authService.tryAutoLogin();
          
          if (loginResult == true) {
            // 重新登入成功,再試一次
            debugPrint('[CourseSyllabus] 自動登入成功,重試載入');
            syllabus = await apiService.getCourseSyllabus(
              syllabusNumber: widget.syllabusNumber,
              teacherCode: widget.teacherCode,
            );
          } else if (loginResult == false) {
            // 帳密錯誤或網路問題
            throw Exception('自動重新登入失敗，請重新登入');
          } else {
            // 沒有保存的帳密
            throw Exception('Session 失效，請重新登入');
          }
        } else {
          rethrow;
        }
      }

      if (!mounted) return;

      // 合併課表資訊和大綱資訊
      final mergedData = {
        ...widget.courseInfo,
        if (syllabus != null) ...syllabus,
      };

      // 保存到緩存
      if (_cacheBox != null && syllabus != null) {
        await _cacheBox!.put(_cacheKey, mergedData);
        final cacheTimeKey = 'cache_time_$_cacheKey';
        await _cacheBox!.put(cacheTimeKey, DateTime.now().toIso8601String());
        debugPrint('[CourseSyllabus] 已保存到緩存');
      }

      setState(() {
        _syllabus = mergedData;
        _lastCacheTime = DateTime.now();
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      
      debugPrint('[CourseSyllabus] 載入失敗: $e');
      
      // 如果是需要重新登入的錯誤,跳轉到登入頁面
      if (e.toString().contains('請重新登入')) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
        
        // 延遲跳轉，讓用戶看到錯誤訊息
        Future.delayed(const Duration(seconds: 2), () {
          if (mounted) {
            Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false);
          }
        });
      } else {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.courseInfo['courseName'] ?? '課程大綱'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: '重新載入',
            onPressed: () => _loadSyllabus(forceRefresh: true),
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
            Text('載入課程大綱中...'),
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
                '載入失敗：$_error',
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 16),
            if (!_error.contains('請重新登入'))
              ElevatedButton(
                onPressed: () => _loadSyllabus(forceRefresh: true),
                child: const Text('重試'),
              ),
            if (_error.contains('請重新登入'))
              ElevatedButton(
                onPressed: () {
                  Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false);
                },
                child: const Text('前往登入'),
              ),
          ],
        ),
      );
    }

    if (_syllabus == null) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.inbox, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text('無課程大綱資料'),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 基本資訊
          _buildSection(
            title: '基本資訊',
            icon: Icons.info_outline,
            children: [
              _buildInfoRow('課程名稱', _syllabus!['courseName']?.toString()),
              _buildInfoRow('課號', _syllabus!['courseId']?.toString()),
              Row(
                children: [
                  Expanded(
                    child: _buildInfoRow('學分', _syllabus!['credits']?.toString()),
                  ),
                  Expanded(
                    child: _buildInfoRow('時數', _syllabus!['hours']?.toString()),
                  ),
                ],
              ),
              _buildInfoRow('授課教師', _syllabus!['instructor']?.toString()),
              _buildInfoRow('教室', _syllabus!['classroom']?.toString()),
              _buildInfoRow('授課語言', _syllabus!['language']?.toString()),
              if (_syllabus!['department']?.toString().isNotEmpty == true)
                _buildInfoRow('開課系所', _syllabus!['department']?.toString()),
            ],
          ),
          const SizedBox(height: 24),
          
          // 課程目標
          if (_syllabus!['objective']?.toString().isNotEmpty == true) ...[
            _buildSection(
              title: '課程目標',
              icon: Icons.flag_outlined,
              children: [
                Text(
                  _syllabus!['objective']?.toString() ?? '',
                  style: TextStyle(
                    fontSize: 14, 
                    height: 1.6,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
          ],
          
          // 課程大綱
          if (_syllabus!['outline']?.toString().isNotEmpty == true) ...[
            _buildSection(
              title: '課程大綱',
              icon: Icons.description_outlined,
              children: [
                Text(
                  _syllabus!['outline']?.toString() ?? '',
                  style: TextStyle(
                    fontSize: 14, 
                    height: 1.6,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
          ],
          
          // 老師聯絡資訊
          if (_syllabus!['textbooks']?.toString().isNotEmpty == true) ...[
            _buildSection(
              title: '老師聯絡資訊',
              icon: Icons.contact_mail_outlined,
              children: [
                Text(
                  _syllabus!['textbooks']?.toString() ?? '',
                  style: TextStyle(
                    fontSize: 14, 
                    height: 1.6,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
          ],
          
          // 參考書目
          if (_syllabus!['references']?.toString().isNotEmpty == true) ...[
            _buildSection(
              title: '參考書目',
              icon: Icons.library_books_outlined,
              children: [
                Text(
                  _syllabus!['references']?.toString() ?? '',
                  style: TextStyle(
                    fontSize: 14, 
                    height: 1.6,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
          ],
          
          // 評量方式
          if (_syllabus!['gradingCriteria']?.toString().isNotEmpty == true) ...[
            _buildSection(
              title: '評量方式',
              icon: Icons.assignment_outlined,
              children: [
                Text(
                  _syllabus!['gradingCriteria']?.toString() ?? '',
                  style: TextStyle(
                    fontSize: 14, 
                    height: 1.6,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
          ],
          
          // 評量標準
          if (_syllabus!['schedule']?.toString().isNotEmpty == true) ...[
            _buildSection(
              title: '評量標準',
              icon: Icons.rule_outlined,
              children: [
                Text(
                  _syllabus!['schedule']?.toString() ?? '',
                  style: TextStyle(
                    fontSize: 14, 
                    height: 1.6,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
          ],
        ],
      ),
    );
  }

  Widget _buildSection({
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              icon, 
              size: 24, 
              color: isDark 
                  ? Theme.of(context).colorScheme.primary
                  : Theme.of(context).primaryColor,
            ),
            const SizedBox(width: 8),
            Text(
              title,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: isDark 
                        ? Theme.of(context).colorScheme.onSurface
                        : Theme.of(context).primaryColor,
                  ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDark
                ? Theme.of(context).colorScheme.surfaceContainerHighest
                : Theme.of(context).primaryColor.withOpacity(0.05),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isDark
                  ? Theme.of(context).colorScheme.outline
                  : Theme.of(context).primaryColor.withOpacity(0.2),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: children,
          ),
        ),
      ],
    );
  }

  Widget _buildInfoRow(String label, String? value) {
    if (value == null || value.isEmpty) return const SizedBox.shrink();
    
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 14,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
