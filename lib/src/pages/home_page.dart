import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../services/navigation_config_service.dart';
import '../services/badge_service.dart';
import '../services/ischool_plus_service.dart';
import '../services/ntut_api_service.dart';
import '../services/auth_service.dart';
import '../providers/auth_provider_v2.dart';
import '../l10n/app_localizations.dart';
import 'other_features_page.dart';

/// 主頁面 - 包含底部導航欄和各個功能模組
class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _currentIndex = 0;
  bool _hasSyncedAnnouncements = false;
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    // 監聽 BadgeService 變化
    BadgeService().addListener(_onBadgeChanged);
    
    // 延遲初始化，等待 context 可用
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initialize();
    });
  }
  
  /// 初始化頁面
  Future<void> _initialize() async {
    if (_isInitialized) return;
    _isInitialized = true;
    
    debugPrint('[HomePage] 開始初始化');
    
    try {
      final authProvider = context.read<AuthProviderV2>();
      
      // 檢查是否有保存的憑證
      final authService = context.read<AuthService>();
      final credentials = await authService.getSavedCredentials();
      
      if (credentials == null) {
        // 沒有保存的憑證，跳轉到登入頁面
        debugPrint('[HomePage] 沒有保存的憑證，跳轉到登入頁面');
        if (mounted) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            Navigator.of(context).pushReplacementNamed('/login');
          });
        }
        return;
      }
      
      // 有憑證，檢查是否已登入
      if (authProvider.isLoggedIn) {
        debugPrint('[HomePage] 已登入，跳過後台登入');
        // 延遲同步公告
        Future.delayed(const Duration(seconds: 2), () {
          if (mounted) {
            _syncISchoolAnnouncements();
          }
        });
        return;
      }
      
      // 在後台嘗試自動登入（非阻塞）
      debugPrint('[HomePage] 開始後台自動登入...');
      final success = await authProvider.tryAutoLogin();
      
      if (success) {
        debugPrint('[HomePage] 後台自動登入成功');
        // 延遲同步公告
        Future.delayed(const Duration(seconds: 2), () {
          if (mounted) {
            _syncISchoolAnnouncements();
          }
        });
      } else {
        debugPrint('[HomePage] 後台自動登入失敗');
        // 登入失敗，跳轉到登入頁面
        if (mounted) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            Navigator.of(context).pushReplacementNamed('/login');
          });
        }
      }
    } catch (e) {
      debugPrint('[HomePage] 初始化異常: $e');
      // 異常時跳轉到登入頁面
      if (mounted) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          Navigator.of(context).pushReplacementNamed('/login');
        });
      }
    }
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

  /// 背景同步 i學院公告
  Future<void> _syncISchoolAnnouncements() async {
    if (_hasSyncedAnnouncements) return;
    _hasSyncedAnnouncements = true;

    // 檢查是否可以進行自動檢查
    if (!await BadgeService().canAutoCheckISchool()) {
      return;
    }

    try {
      final ntutApiService = context.read<NtutApiService>();
      ISchoolPlusService.initialize(ntutApiService);
      final service = ISchoolPlusService.instance;

      // 嘗試登入 i學院
      if (!await service.login()) {
        return;
      }

      // 取得當前學期的課程（只從緩存中獲取）
      final now = DateTime.now();
      final year = now.year - 1911;
      final semester = now.month >= 2 && now.month <= 7 ? 2 : 1;
      
      List<Map<String, dynamic>> courses = [];
      try {
        final cacheBox = await Hive.openBox('course_table_cache');
        final cacheKey = 'courses_${year}_$semester';
        final cachedData = cacheBox.get(cacheKey);
        
        if (cachedData != null && cachedData is List) {
          courses = (cachedData).map((e) => Map<String, dynamic>.from(e as Map)).toList();
        }
      } catch (e) {
        // 靜默失敗
      }
      
      if (courses.isEmpty) return;

      // 更新最後檢查時間
      await BadgeService().updateISchoolCheckTime();

      // 過濾有效的課程 ID
      final validCourses = courses.where((course) {
        final courseId = course['courseId'] as String? ?? '';
        return courseId.isNotEmpty && !courseId.startsWith('NO_ID');
      }).toList();

      // 根據本地記錄的上次同步時間排序（最久沒更新的優先）
      final courseWithSyncTime = <Map<String, dynamic>>[];
      
      for (final course in validCourses) {
        final courseId = course['courseId'] as String? ?? '';
        final lastSyncTime = await BadgeService().getCourseLastSyncTime(courseId);
        
        courseWithSyncTime.add({
          'course': course,
          'courseId': courseId,
          'lastSyncTime': lastSyncTime ?? 0, // 從未同步過的課程優先
        });
      }
      
      // 按照上次同步時間排序（最久沒更新的在前面）
      courseWithSyncTime.sort((a, b) {
        final timeA = a['lastSyncTime'] as int;
        final timeB = b['lastSyncTime'] as int;
        return timeA.compareTo(timeB); // 升序排列（時間戳小的在前，即最久沒更新的優先）
      });

      // 按照排序後的順序同步
      int successCount = 0;
      int newCount = 0;
      
      for (final item in courseWithSyncTime) {
        final courseId = item['courseId'] as String;
        
        try {
          final announcements = await service.connector.getCourseAnnouncements(courseId);
          final announcementIds = announcements
              .where((a) => a.nid != null && a.nid!.isNotEmpty)
              .map((a) => a.nid!)
              .toList();
          
          final oldCount = await BadgeService().getUnreadCount(BadgeFeature.ischool);
          await BadgeService().syncCourseAnnouncements(courseId, announcementIds);
          final addedCount = await BadgeService().getUnreadCount(BadgeFeature.ischool) - oldCount;
          
          if (addedCount > 0) {
            newCount += addedCount;
          }
          successCount++;
        } catch (e) {
          // 靜默跳過錯誤
        }
      }

      if (newCount > 0) {
        print('[HomePage] i學院同步完成：$successCount/$newCount');
      }
    } catch (e) {
      // 靜默失敗
    }
  }

  /// 構建帶紅點的導航圖標
  Widget _buildNavIcon(IconData icon, String itemId, bool isSelected) {
    // 只有 ntut_learn 需要檢查紅點
    if (itemId == 'ntut_learn') {
      return FutureBuilder<bool>(
        future: BadgeService().hasAnyUnreadInISchool(),
        builder: (context, snapshot) {
          final hasUnread = snapshot.data ?? false;
          return Stack(
            clipBehavior: Clip.none,
            children: [
              Icon(icon),
              if (hasUnread)
                Positioned(
                  right: -4,
                  top: -4,
                  child: Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: Colors.red,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
            ],
          );
        },
      );
    }
    return Icon(icon);
  }

  /// 構建帶紅點的「其他」圖標
  Widget _buildOtherIcon() {
    return FutureBuilder<bool>(
      future: _checkIfOtherHasBadge(),
      builder: (context, snapshot) {
        final hasUnread = snapshot.data ?? false;
        return Stack(
          clipBehavior: Clip.none,
          children: [
            const Icon(Icons.more_horiz),
            if (hasUnread)
              Positioned(
                right: -4,
                top: -4,
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: Colors.red,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  /// 檢查「其他」頁面是否包含有紅點的功能
  Future<bool> _checkIfOtherHasBadge() async {
    final navConfig = context.read<NavigationConfigService>();
    final otherFeatures = navConfig.getOtherFeatures();
    
    // 檢查 ntut_learn 是否在「其他」頁面中
    final hasNtutLearnInOther = otherFeatures.any((item) => item.id == 'ntut_learn');
    if (hasNtutLearnInOther) {
      return await BadgeService().hasAnyUnreadInISchool();
    }
    
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final navConfig = context.watch<NavigationConfigService>();
    
    // 根據配置構建頁面列表（自訂項目 + 其他）
    final navItems = navConfig.currentNavOrder
        .map((id) => navConfig.getNavItemById(id))
        .whereType<NavItem>()
        .toList();
    
    // 使用懶加載的方式建立頁面，只有當前頁面和已訪問過的頁面才會被建立
    final pages = <Widget>[
      ...navItems.asMap().entries.map((entry) {
        final index = entry.key;
        final item = entry.value;
        return _LazyLoadWidget(
          isActive: _currentIndex == index,
          builder: () => item.pageBuilder(context),
        );
      }),
      const OtherFeaturesPage(), // 「其他」頁面固定在最後
    ];
    
    // 立即修正 currentIndex，避免超出範圍
    final safeCurrentIndex = _currentIndex >= pages.length ? 0 : _currentIndex;
    
    // 如果 currentIndex 已經超出範圍，在下一幀更新它
    if (_currentIndex >= pages.length) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          setState(() => _currentIndex = 0);
        }
      });
    }
    
    return Scaffold(
      body: IndexedStack(
        index: safeCurrentIndex,
        children: pages,
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: safeCurrentIndex,
        onDestinationSelected: (index) {
          setState(() => _currentIndex = index);
        },
        destinations: [
          ...navItems.map((item) => NavigationDestination(
            icon: _buildNavIcon(item.icon, item.id, false),
            selectedIcon: _buildNavIcon(item.icon, item.id, true),
            label: item.label,
          )),
          NavigationDestination(
            icon: _buildOtherIcon(),
            selectedIcon: _buildOtherIcon(),
            label: l10n.other,
          ),
        ],
      ),
    );
  }
}

/// 懶加載 Widget，只有在 isActive 為 true 時才建立內容
class _LazyLoadWidget extends StatefulWidget {
  final bool isActive;
  final Widget Function() builder;

  const _LazyLoadWidget({
    required this.isActive,
    required this.builder,
  });

  @override
  State<_LazyLoadWidget> createState() => _LazyLoadWidgetState();
}

class _LazyLoadWidgetState extends State<_LazyLoadWidget> with AutomaticKeepAliveClientMixin {
  Widget? _cachedWidget;

  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    
    // 只有在 active 時才建立 widget，並緩存它
    if (widget.isActive && _cachedWidget == null) {
      _cachedWidget = widget.builder();
    }
    
    // 如果還沒建立過，返回空容器
    return _cachedWidget ?? const SizedBox.shrink();
  }
}
