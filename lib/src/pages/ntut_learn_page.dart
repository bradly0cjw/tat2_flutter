import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../l10n/app_localizations.dart';
import '../services/ischool_plus_service.dart';
import '../services/ntut_api_service.dart';
import '../services/ischool_plus_cache_service.dart';
import '../services/badge_service.dart';
import 'ischool_plus/announcement_list_page.dart';
import 'ischool_plus/course_files_page.dart';

/// 北科i學園頁面
class NtutLearnPage extends StatefulWidget {
  const NtutLearnPage({super.key});

  @override
  State<NtutLearnPage> createState() => _NtutLearnPageState();
}

class _NtutLearnPageState extends State<NtutLearnPage> {
  bool _isLoggingIn = false;
  bool _isLoggedIn = false;
  bool _isInitialized = false;
  bool _isLoadingCourses = false;
  
  // 從課表取得的課程列表
  List<Map<String, dynamic>> _courses = [];

  @override
  void initState() {
    super.initState();
    // 監聽 BadgeService 變化
    BadgeService().addListener(_onBadgeChanged);
    _initializeService();
  }

  @override
  void dispose() {
    BadgeService().removeListener(_onBadgeChanged);
    super.dispose();
  }

  void _onBadgeChanged() {
    if (mounted) {
      setState(() {}); // 紅點狀態改變時重新整理
    }
  }

  void _initializeService() async {
    // 從 Provider 取得 NtutApiService 並初始化 ISchoolPlusService
    final ntutApiService = context.read<NtutApiService>();
    ISchoolPlusService.initialize(ntutApiService);
    setState(() {
      _isInitialized = true;
    });
    _loadCourses();
    // 自動開始登入流程
    await _login();
  }
  
  Future<void> _loadCourses() async {
    if (!mounted) return;
    
    setState(() {
      _isLoadingCourses = true;
    });

    try {
      // 取得當前學期
      final now = DateTime.now();
      final year = now.year - 1911; // 轉換為民國年
      final semester = now.month >= 2 && now.month <= 7 ? 2 : 1; // 2-7月為第二學期，其他為第一學期
      
      // 只從緩存中讀取課表，不發起網路請求
      List<Map<String, dynamic>> courses = [];
      try {
        final cacheBox = await Hive.openBox('course_table_cache');
        final cacheKey = 'courses_${year}_$semester';
        final cachedData = cacheBox.get(cacheKey);
        
        if (cachedData != null && cachedData is List) {
          courses = (cachedData).map((e) => Map<String, dynamic>.from(e as Map)).toList();
          print('[NtutLearn] 從緩存獲取課表成功，共 ${courses.length} 門課程');
        } else {
          print('[NtutLearn] 緩存中沒有課表數據（需要用戶先進入課表頁面）');
        }
      } catch (e) {
        print('[NtutLearn] 從緩存獲取課表失敗: $e');
      }
      
      if (mounted) {
        setState(() {
          _courses = courses;
          _isLoadingCourses = false;
        });
      }
    } catch (e) {
      print('[NtutLearn] Failed to load courses: $e');
      if (mounted) {
        setState(() {
          _isLoadingCourses = false;
        });
      }
    }
  }

  void _checkLoginStatus() {
    if (!_isInitialized) return;
    final service = ISchoolPlusService.instance;
    setState(() {
      _isLoggedIn = service.isLoggedIn;
    });
  }

  Future<void> _login() async {
    setState(() {
      _isLoggingIn = true;
    });

    try {
      final service = ISchoolPlusService.instance;
      final success = await service.login();

      if (mounted) {
        setState(() {
          _isLoggedIn = success;
          _isLoggingIn = false;
        });

        if (!success) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('登入 i學院失敗，請確認已登入學校帳號'),
              backgroundColor: Colors.red,
            ),
          );
        } else {
          // 登入成功後，檢查是否需要同步公告
          if (await BadgeService().canAutoCheckISchool()) {
            _syncAllAnnouncements();
          }
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoggingIn = false;
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('登入時發生錯誤：$e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// 顯示清除快取對話框
  void _showClearCacheDialog() async {
    final cacheService = ISchoolPlusCacheService();
    
    // 計算大小
    final cacheSize = await cacheService.getCacheSize();
    final downloadSize = await cacheService.getDownloadSize();
    final totalSize = cacheSize + downloadSize;
    
    if (!mounted) return;
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('清除 i學院 資料'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('這將會清除：'),
            const SizedBox(height: 8),
            Text('• 公告快取：${ISchoolPlusCacheService.formatSize(cacheSize)}'),
            Text('• 下載檔案：${ISchoolPlusCacheService.formatSize(downloadSize)}'),
            const SizedBox(height: 8),
            Text(
              '總計：${ISchoolPlusCacheService.formatSize(totalSize)}',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            const Text(
              '此操作無法復原',
              style: TextStyle(color: Colors.red, fontSize: 12),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await _clearAllData();
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('清除'),
          ),
        ],
      ),
    );
  }

  /// 同步所有課程公告（背景執行，使用並行處理）
  Future<void> _syncAllAnnouncements() async {
    if (_courses.isEmpty) return;
    
    try {
      final service = ISchoolPlusService.instance;
      
      // 更新最後檢查時間
      await BadgeService().updateISchoolCheckTime();
      
      // 過濾有效的課程 ID
      final validCourses = _courses.where((course) {
        final courseId = course['courseId'] as String? ?? '';
        return courseId.isNotEmpty && !courseId.startsWith('NO_ID');
      }).toList();
      
      // 記錄初始未讀數
      final oldCount = await BadgeService().getUnreadCount(BadgeFeature.ischool);
      
      int successCount = 0;
      
      // 並行處理所有課程
      final results = await Future.wait(
        validCourses.map((course) async {
          final courseId = course['courseId'] as String? ?? '';
          
          try {
            final announcements = await service.connector.getCourseAnnouncements(courseId);
            final announcementIds = announcements
                .where((a) => a.nid != null && a.nid!.isNotEmpty)
                .map((a) => a.nid!)
                .toList();
            
            await BadgeService().syncCourseAnnouncements(courseId, announcementIds);
            return true;
          } catch (e) {
            return false;
          }
        }),
      );
      
      successCount = results.where((r) => r).length;
      
      // 計算新增的公告數量
      final newCount = await BadgeService().getUnreadCount(BadgeFeature.ischool) - oldCount;
      
      // 同步完成後更新 UI
      if (mounted) {
        if (newCount > 0) {
          setState(() {});
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('同步完成：$successCount 門課程，$newCount 則新公告'),
              backgroundColor: Colors.blue,
              duration: const Duration(seconds: 2),
            ),
          );
        }
      }
    } catch (e) {
      // 靜默失敗
    }
  }

  /// 清除所有資料
  Future<void> _clearAllData() async {
    try {
      final cacheService = ISchoolPlusCacheService();
      
      // 顯示進度對話框
      if (mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => const Center(
            child: Card(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 16),
                    Text('清除中...'),
                  ],
                ),
              ),
            ),
          ),
        );
      }
      
      // 清除快取、檔案和紅點標記
      await cacheService.clearAllCache();
      await cacheService.clearAllDownloads();
      await BadgeService().clearAllISchoolBadges();
      
      if (mounted) {
        Navigator.pop(context); // 關閉進度對話框
        
        // 強制重新整理頁面
        setState(() {});
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('已清除所有 i學院 資料'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context); // 關閉進度對話框
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('清除失敗：$e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// 清除所有紅點
  Future<void> _clearAllBadges() async {
    try {
      await BadgeService().clearAllISchoolBadges();
      
      if (mounted) {
        setState(() {}); // 重新整理以更新紅點顯示
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('已清除所有 i學院 紅點'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('清除紅點失敗：$e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// 復原所有紅點為未讀（測試用）
  Future<void> _resetAllBadges() async {
    try {
      await BadgeService().resetAllISchoolBadges();
      
      if (mounted) {
        setState(() {}); // 重新整理以更新紅點顯示
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('已復原所有 i學院 紅點為未讀'),
            backgroundColor: Colors.orange,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('復原紅點失敗：$e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }



  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    
    // 等待初始化完成
    if (!_isInitialized) {
      return Scaffold(
        appBar: AppBar(title: Text(l10n.ntutLearn)),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.ntutLearn),
        actions: [
          if (_isLoggedIn)
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert),
              onSelected: (value) async {
                switch (value) {
                  case 'clear_cache':
                    _showClearCacheDialog();
                    break;
                  case 'clear_badges':
                    await _clearAllBadges();
                    break;
                  case 'reset_badges':
                    await _resetAllBadges();
                    break;
                }
              },
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'clear_cache',
                  child: Text('清除快取與檔案'),
                ),
                const PopupMenuItem(
                  value: 'clear_badges',
                  child: Text('清除所有紅點'),
                ),
                const PopupMenuItem(
                  value: 'reset_badges',
                  child: Text('復原所有紅點 (測試)'),
                ),
              ],
            ),
        ],
      ),
      body: _isLoggingIn
          ? const Center(child: CircularProgressIndicator())
          : !_isLoggedIn
              ? _buildLoginPrompt()
              : _buildCourseList(),
    );
  }

  Widget _buildLoginPrompt() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.school, size: 80, color: Colors.grey.withOpacity(0.5)),
          const SizedBox(height: 24),
          const Text(
            '北科i學園',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              '查看課程公告、下載教材',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey[600]),
            ),
          ),
          const SizedBox(height: 32),
          ElevatedButton.icon(
            onPressed: _login,
            icon: const Icon(Icons.login),
            label: const Text('登入 i學園'),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCourseList() {
    if (_isLoadingCourses) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('載入課程中...'),
          ],
        ),
      );
    }

    if (_courses.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.inbox, size: 80, color: Colors.grey.withOpacity(0.5)),
            const SizedBox(height: 16),
            const Text('沒有找到課程'),
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: _loadCourses,
              icon: const Icon(Icons.refresh),
              label: const Text('重新載入'),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(8),
      itemCount: _courses.length,
      itemBuilder: (context, index) {
        final course = _courses[index];
        final courseName = course['courseName'] as String? ?? '未知課程';
        final courseId = course['courseId'] as String? ?? '';
        
        // 如果沒有 courseId 或是 NO_ID 開頭（班會課等特殊課程），跳過這個課程
        if (courseId.isEmpty || courseId.startsWith('NO_ID')) {
          return const SizedBox.shrink();
        }

        return _buildCourseCard(courseId, courseName);
      },
    );
  }

  /// 建立課程卡片
  Widget _buildCourseCard(String courseId, String courseName) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: FutureBuilder<bool>(
        future: BadgeService().hasCourseUnreadAnnouncements(courseId),
        builder: (context, courseSnapshot) {
          final hasUnread = courseSnapshot.data ?? false;
          return Theme(
            data: Theme.of(context).copyWith(
              dividerColor: Colors.transparent,
            ),
            child: ExpansionTile(
              leading: Stack(
                clipBehavior: Clip.none,
                children: [
                  const Icon(Icons.class_, color: Colors.blue),
                  if (hasUnread)
                    Positioned(
                      right: -4,
                      top: -4,
                      child: Container(
                        width: 10,
                        height: 10,
                        decoration: const BoxDecoration(
                          color: Colors.red,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                ],
              ),
              title: Text(
                courseName,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: Text('課號：$courseId'),
              children: [
                _buildAnnouncementTile(courseId, courseName),
                _buildMaterialTile(courseId, courseName),
              ],
            ),
          );
        },
      ),
    );
  }

  /// 建立公告列表項
  Widget _buildAnnouncementTile(String courseId, String courseName) {
    return FutureBuilder<bool>(
      future: BadgeService().hasCourseUnreadAnnouncements(courseId),
      builder: (context, snapshot) {
        final hasUnread = snapshot.data ?? false;
        return ListTile(
          leading: Stack(
            clipBehavior: Clip.none,
            children: [
              const Icon(Icons.notifications, color: Colors.orange),
              if (hasUnread)
                Positioned(
                  right: -2,
                  top: -2,
                  child: Container(
                    width: 10,
                    height: 10,
                    decoration: const BoxDecoration(
                      color: Colors.red,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
            ],
          ),
          title: const Text('課程公告'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => AnnouncementListPage(
                  courseId: courseId,
                  courseName: courseName,
                ),
              ),
            ).then((_) {
              // 返回時重新整理以更新紅點狀態
              if (mounted) setState(() {});
            });
          },
        );
      },
    );
  }

  /// 建立教材列表項
  Widget _buildMaterialTile(String courseId, String courseName) {
    return ListTile(
      leading: const Icon(Icons.folder, color: Colors.green),
      title: const Text('課程教材'),
      trailing: const Icon(Icons.chevron_right),
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => CourseFilesPage(
              courseId: courseId,
              courseName: courseName,
            ),
          ),
        );
      },
    );
  }
}
