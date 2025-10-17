import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:provider/provider.dart';
import 'ntut_api_service.dart';
import '../config/feature_config.dart';
import '../pages/course_table_page.dart';
import '../pages/calendar_page.dart';
import '../pages/course_search_page.dart';
import '../pages/grades_page.dart';
import '../pages/credits_page.dart';
import '../pages/campus_map_page.dart';
import '../pages/empty_classroom_page.dart';
import '../pages/club_announcements_page.dart';
import '../pages/admin_system_page.dart';
import '../pages/messages_page.dart';
import '../pages/ntut_learn_page.dart';
import '../pages/food_map_page.dart';

/// 導航項目配置
class NavItem {
  final String id;
  final String label;
  final IconData icon;
  final Widget Function(BuildContext) pageBuilder;

  const NavItem({
    required this.id,
    required this.label,
    required this.icon,
    required this.pageBuilder,
  });
}

/// 導航欄配置服務
/// 管理底部導航列的可變數量位置（最多 5 個）+ 固定的「其他」按鈕
class NavigationConfigService extends ChangeNotifier {
  static const String _boxName = 'navigation_config';
  static const String _configKey = 'nav_order';
  static const int maxNavItems = 5; // 最多 5 個導航項目（不含「其他」）
  Box? _box;
  
  // 預設導航順序：課表、日曆、課程查詢、成績
  static const List<String> defaultNavOrder = [
    'course_table',
    'calendar',
    'course_search',
    'grades',
  ];
  
  List<String> _navOrder = List.from(defaultNavOrder);
  
  /// 當前導航順序
  List<String> get currentNavOrder => _navOrder;
  
  /// 所有定義的導航項目（包含已啟用和已停用的）
  final List<NavItem> _allNavItems = [
    NavItem(
      id: 'course_table',
      label: '課表',
      icon: Icons.calendar_view_week,
      pageBuilder: (context) => const CourseTablePage(),
    ),
    NavItem(
      id: 'calendar',
      label: '日曆',
      icon: Icons.calendar_today,
      pageBuilder: (context) => const CalendarPage(),
    ),
    NavItem(
      id: 'course_search',
      label: '課程查詢',
      icon: Icons.search,
      pageBuilder: (context) => const CourseSearchPage(),
    ),
    NavItem(
      id: 'grades',
      label: '成績',
      icon: Icons.calculate,
      pageBuilder: (context) => const GradesPage(),
    ),
    NavItem(
      id: 'credits',
      label: '學分',
      icon: Icons.grade,
      pageBuilder: (context) => const CreditsPage(),
    ),
    NavItem(
      id: 'campus_map',
      label: '校園地圖',
      icon: Icons.map,
      pageBuilder: (context) => const CampusMapPage(),
    ),
    NavItem(
      id: 'empty_classroom',
      label: '空教室查詢',
      icon: Icons.meeting_room,
      pageBuilder: (context) => const EmptyClassroomPage(),
    ),
    NavItem(
      id: 'club_announcements',
      label: '社團公告',
      icon: Icons.campaign,
      pageBuilder: (context) => const ClubAnnouncementsPage(),
    ),
    NavItem(
      id: 'admin_system',
      label: '校務系統',
      icon: Icons.admin_panel_settings,
      pageBuilder: (context) {
        // 從 Provider 取得 NtutApiService
        final ntutApi = context.read<NtutApiService>();
        return AdminSystemPage(apiService: ntutApi);
      },
    ),
    NavItem(
      id: 'messages',
      label: '訊息',
      icon: Icons.message,
      pageBuilder: (context) => const MessagesPage(),
    ),
    NavItem(
      id: 'ntut_learn',
      label: '北科i學園',
      icon: Icons.school,
      pageBuilder: (context) => const NtutLearnPage(),
    ),
    NavItem(
      id: 'food_map',
      label: '美食地圖',
      icon: Icons.restaurant,
      pageBuilder: (context) => const FoodMapPage(),
    ),
  ];
  
  /// 取得所有可用的導航項目（只包含啟用的功能）
  List<NavItem> get availableNavItems {
    return _allNavItems
        .where((item) => FeatureConfig.isFeatureEnabled(item.id))
        .toList();
  }
  
  /// 根據 ID 取得導航項目（只返回已啟用的功能）
  NavItem? getNavItemById(String id) {
    // 先檢查功能是否啟用
    if (!FeatureConfig.isFeatureEnabled(id)) {
      return null;
    }
    
    try {
      return _allNavItems.firstWhere((item) => item.id == id);
    } catch (e) {
      return null;
    }
  }
  
  /// 初始化服務
  Future<void> init() async {
    _box = await Hive.openBox(_boxName);
    await _loadNavOrder();
  }
  
  /// 載入導航順序
  Future<void> _loadNavOrder() async {
    if (_box == null) return;
    
    final saved = _box!.get(_configKey);
    if (saved != null && saved is List && saved.isNotEmpty && saved.length <= maxNavItems) {
      // 過濾掉已停用的功能
      _navOrder = (List<String>.from(saved))
          .where((id) => FeatureConfig.isFeatureEnabled(id))
          .toList();
    } else {
      _navOrder = (List<String>.from(defaultNavOrder))
          .where((id) => FeatureConfig.isFeatureEnabled(id))
          .toList();
    }
    
    // 如果過濾後為空，使用預設的啟用功能
    if (_navOrder.isEmpty) {
      _navOrder = (List<String>.from(defaultNavOrder))
          .where((id) => FeatureConfig.isFeatureEnabled(id))
          .toList();
    }
    
    notifyListeners();
  }
  
  /// 儲存導航順序
  Future<void> saveNavOrder(List<String> order) async {
    // 過濾掉已停用的功能
    final enabledOrder = order
        .where((id) => FeatureConfig.isFeatureEnabled(id))
        .toList();
    
    if (enabledOrder.isEmpty || enabledOrder.length > maxNavItems) {
      throw ArgumentError('導航順序必須包含 1-$maxNavItems 個已啟用的項目');
    }
    
    _navOrder = List.from(enabledOrder);
    
    if (_box != null) {
      await _box!.put(_configKey, enabledOrder);
    }
    
    notifyListeners();
  }
  
  /// 取得不在導航列的功能項目（顯示在「其他」頁面）
  List<NavItem> getOtherFeatures() {
    return availableNavItems
        .where((item) => !_navOrder.contains(item.id))
        .toList();
  }
  
  /// 重設為預設值
  Future<void> resetToDefault() async {
    await saveNavOrder(List.from(defaultNavOrder));
  }
}
