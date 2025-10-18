import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 紅點功能類型
enum BadgeFeature {
  ischool('ischool'),           // i學院
  clubAnnouncement('club'),     // 社團公告
  message('message'),           // 訊息
  adminSystem('admin');         // 校務系統
  
  final String key;
  const BadgeFeature(this.key);
}

/// 紅點標記服務 - 通用的未讀狀態管理
/// 
/// 支援多種功能的紅點系統：
/// - i學院公告
/// - 社團公告
/// - 訊息
/// - 校務系統通知
/// 等等...
class BadgeService extends ChangeNotifier {
  static final BadgeService _instance = BadgeService._internal();
  factory BadgeService() => _instance;
  BadgeService._internal();

  static const String _keyPrefix = 'badge_';
  static const String _unreadItemsPrefix = 'unread_';
  static const String _featureEnabledPrefix = 'feature_enabled_';
  static const String _hideAllBadgesKey = 'badge_hide_all';
  static const String _autoCheckEnabledKey = 'badge_auto_check_ischool';
  static const String _lastCheckTimeKey = 'badge_last_check_time_ischool';
  static const String _courseLastSyncPrefix = 'badge_course_sync_'; // 每個課程的上次同步時間
  static const int _checkIntervalMinutes = 0; // 15分鐘檢查一次

  SharedPreferences? _prefs;

  /// 初始化
  Future<void> init() async {
    _prefs ??= await SharedPreferences.getInstance();
    await _migrateOldData();
  }

  /// 遷移舊的紅點數據（從 read_items_ 改為 unread_）
  Future<void> _migrateOldData() async {
    final keys = _prefs?.getKeys() ?? {};
    final oldPrefix = '${_keyPrefix}read_items_';
    
    // 刪除所有舊的 read_items_ 數據
    for (final key in keys) {
      if (key.startsWith(oldPrefix)) {
        await _prefs?.remove(key);
      }
    }
  }

  // ==================== 通用方法 ====================
  
  /// 標記項目為未讀（顯示紅點）
  /// [feature] 功能類型
  /// [itemId] 項目 ID（例如：courseId_announcementId）
  Future<void> markAsUnread(BadgeFeature feature, String itemId) async {
    await init();
    final key = '$_keyPrefix$_unreadItemsPrefix${feature.key}_$itemId';
    await _prefs?.setBool(key, true);
    notifyListeners();
  }

  /// 標記項目為已讀（移除紅點）
  Future<void> markAsRead(BadgeFeature feature, String itemId) async {
    await init();
    final key = '$_keyPrefix$_unreadItemsPrefix${feature.key}_$itemId';
    // 設置為 false = 已讀
    await _prefs?.setBool(key, false);
    notifyListeners();
  }

  /// 檢查項目是否有紅點
  Future<bool> hasItemBadge(BadgeFeature feature, String itemId) async {
    await init();
    final key = '$_keyPrefix$_unreadItemsPrefix${feature.key}_$itemId';
    return _prefs?.getBool(key) ?? false;
  }

  /// 取得功能的所有未讀項目數量
  Future<int> getUnreadCount(BadgeFeature feature) async {
    await init();
    int count = 0;
    final keys = _prefs?.getKeys() ?? {};
    final prefix = '$_keyPrefix$_unreadItemsPrefix${feature.key}_';
    
    for (final key in keys) {
      if (key.startsWith(prefix)) {
        final hasUnread = _prefs?.getBool(key) ?? false;
        if (hasUnread) {
          count++;
        }
      }
    }
    return count;
  }

  /// 檢查功能是否有未讀
  Future<bool> hasUnread(BadgeFeature feature) async {
    // 如果全局隱藏紅點，返回 false
    if (await isHideAllBadges()) {
      return false;
    }
    final count = await getUnreadCount(feature);
    return count > 0;
  }

  // ==================== 全局設定 ====================
  
  /// 設定是否隱藏所有紅點
  Future<void> setHideAllBadges(bool hide) async {
    await init();
    await _prefs?.setBool(_hideAllBadgesKey, hide);
    notifyListeners();
  }

  /// 檢查是否隱藏所有紅點
  Future<bool> isHideAllBadges() async {
    await init();
    return _prefs?.getBool(_hideAllBadgesKey) ?? false;
  }

  /// 設定是否啟用自動檢查 i學院公告
  Future<void> setAutoCheckISchool(bool enabled) async {
    await init();
    await _prefs?.setBool(_autoCheckEnabledKey, enabled);
    notifyListeners();
  }

  /// 檢查是否啟用自動檢查 i學院公告
  Future<bool> isAutoCheckISchoolEnabled() async {
    await init();
    return _prefs?.getBool(_autoCheckEnabledKey) ?? true; // 預設啟用
  }

  /// 檢查是否可以進行自動檢查（15分鐘限制，測試用）
  Future<bool> canAutoCheckISchool() async {
    await init();
    
    // 如果未啟用自動檢查，返回 false
    if (!await isAutoCheckISchoolEnabled()) {
      return false;
    }
    
    // 檢查上次檢查時間
    final lastCheckTime = _prefs?.getInt(_lastCheckTimeKey);
    if (lastCheckTime == null) {
      return true; // 首次檢查
    }
    
    final now = DateTime.now().millisecondsSinceEpoch;
    final elapsed = now - lastCheckTime;
    final elapsedMinutes = elapsed ~/ (1000 * 60);
    
    return elapsedMinutes >= _checkIntervalMinutes;
  }

  /// 更新 i學院最後檢查時間
  Future<void> updateISchoolCheckTime() async {
    await init();
    final now = DateTime.now().millisecondsSinceEpoch;
    await _prefs?.setInt(_lastCheckTimeKey, now);
  }

  /// 取得距離下次可檢查的剩餘分鐘數
  Future<int> getRemainingMinutesToCheck() async {
    await init();
    final lastCheckTime = _prefs?.getInt(_lastCheckTimeKey);
    if (lastCheckTime == null) {
      return 0; // 可以立即檢查
    }
    
    final now = DateTime.now().millisecondsSinceEpoch;
    final elapsed = now - lastCheckTime;
    final elapsedMinutes = elapsed ~/ (1000 * 60);
    final remaining = _checkIntervalMinutes - elapsedMinutes;
    
    return remaining > 0 ? remaining : 0;
  }

  /// 取得課程的上次同步時間（毫秒時間戳）
  Future<int?> getCourseLastSyncTime(String courseId) async {
    await init();
    final key = '$_courseLastSyncPrefix$courseId';
    return _prefs?.getInt(key);
  }

  /// 更新課程的同步時間
  Future<void> updateCourseSyncTime(String courseId) async {
    await init();
    final key = '$_courseLastSyncPrefix$courseId';
    final now = DateTime.now().millisecondsSinceEpoch;
    await _prefs?.setInt(key, now);
  }

  /// 清除功能的所有紅點標記（標記為已讀）
  Future<void> clearFeatureBadges(BadgeFeature feature) async {
    await init();
    final keys = _prefs?.getKeys() ?? {};
    final prefix = '$_keyPrefix$_unreadItemsPrefix${feature.key}_';
    
    for (final key in keys) {
      if (key.startsWith(prefix)) {
        await _prefs?.setBool(key, false);
      }
    }
    notifyListeners();
  }

  /// 清除所有功能的紅點標記（標記為已讀）
  Future<void> clearAllBadges() async {
    await init();
    final keys = _prefs?.getKeys() ?? {};
    
    for (final key in keys) {
      if (key.startsWith('$_keyPrefix$_unreadItemsPrefix')) {
        await _prefs?.setBool(key, false);
      }
    }
    notifyListeners();
  }

  /// 設定功能的紅點是否啟用
  Future<void> setFeatureEnabled(BadgeFeature feature, bool enabled) async {
    await init();
    final key = '$_keyPrefix$_featureEnabledPrefix${feature.key}';
    await _prefs?.setBool(key, enabled);
    notifyListeners();
  }

  /// 檢查功能的紅點是否啟用
  Future<bool> isFeatureEnabled(BadgeFeature feature) async {
    await init();
    final key = '$_keyPrefix$_featureEnabledPrefix${feature.key}';
    return _prefs?.getBool(key) ?? true; // 預設啟用
  }

  // ==================== i學院專用方法 ====================
  
  /// 同步課程公告紅點
  /// 邏輯：
  /// 1. 如果本地沒有、系統有 -> 創建未讀記錄
  /// 2. 如果本地有、雲端沒有 -> 刪除記錄
  /// 3. 如果都有 -> 保持原狀態不變
  Future<void> syncCourseAnnouncements(
    String courseId, 
    List<String> currentAnnouncementIds,
  ) async {
    await init();
    
    final keys = _prefs?.getKeys() ?? {};
    final prefix = '$_keyPrefix$_unreadItemsPrefix${BadgeFeature.ischool.key}_${courseId}_';
    final currentIdSet = currentAnnouncementIds.toSet();
    final existingIds = <String>{};
    
    // 1. 找出已存在的記錄，刪除雲端不存在的
    for (final key in keys) {
      if (key.startsWith(prefix)) {
        final announcementId = key.substring(prefix.length);
        if (currentIdSet.contains(announcementId)) {
          existingIds.add(announcementId);
        } else {
          // 本地有、雲端沒有 -> 刪除
          await _prefs?.remove(key);
        }
      }
    }
    
    // 2. 為新公告創建未讀記錄
    int newCount = 0;
    for (final announcementId in currentAnnouncementIds) {
      if (!existingIds.contains(announcementId)) {
        // 本地沒有、系統有 -> 創建未讀記錄
        await markAsUnread(BadgeFeature.ischool, '${courseId}_$announcementId');
        newCount++;
      }
    }
    
    if (newCount > 0) {
      print('[Badge] 課程 $courseId +$newCount 則新公告');
    }
    
    // 更新課程的同步時間
    await updateCourseSyncTime(courseId);
    
    notifyListeners();
  }
  
  /// 清除特定課程的所有公告紅點（標記為已讀）
  Future<void> clearCourseAnnouncements(String courseId) async {
    await init();
    final keys = _prefs?.getKeys() ?? {};
    final prefix = '$_keyPrefix$_unreadItemsPrefix${BadgeFeature.ischool.key}_${courseId}_';
    
    for (final key in keys.where((key) => key.startsWith(prefix))) {
      await _prefs?.setBool(key, false);
    }
    notifyListeners();
  }
  
  /// 標記 i學院公告為已讀
  Future<void> markISchoolAnnouncementAsRead(String courseId, String announcementId) async {
    await markAsRead(BadgeFeature.ischool, '${courseId}_$announcementId');
  }

  /// 檢查 i學院公告是否有紅點
  Future<bool> hasISchoolAnnouncementBadge(String courseId, String announcementId) async {
    return await hasItemBadge(BadgeFeature.ischool, '${courseId}_$announcementId');
  }

  /// 檢查課程是否有未讀公告
  Future<bool> hasCourseUnreadAnnouncements(String courseId) async {
    if (await isHideAllBadges()) return false;
    
    await init();
    final keys = _prefs?.getKeys() ?? {};
    final prefix = '$_keyPrefix$_unreadItemsPrefix${BadgeFeature.ischool.key}_${courseId}_';
    
    return keys.any((key) => key.startsWith(prefix) && (_prefs?.getBool(key) ?? false));
  }

  /// 檢查 i學院是否有任何未讀
  Future<bool> hasAnyUnreadInISchool() async {
    if (await isHideAllBadges()) return false;
    if (!await isFeatureEnabled(BadgeFeature.ischool)) return false;
    return await hasUnread(BadgeFeature.ischool);
  }

  /// 清除所有 i學院紅點（標記全部已讀）
  Future<void> clearAllISchoolBadges() async {
    await init();
    final keys = _prefs?.getKeys() ?? {};
    final prefix = '$_keyPrefix$_unreadItemsPrefix${BadgeFeature.ischool.key}_';
    
    int count = 0;
    for (final key in keys) {
      if (key.startsWith(prefix)) {
        await _prefs?.setBool(key, false);
        count++;
      }
    }
    
    if (count > 0) {
      print('[Badge] 已標記 $count 個公告為已讀');
    }
    notifyListeners();
  }

  /// 恢復所有 i學院紅點（標記全部未讀）
  Future<void> resetAllISchoolBadges() async {
    await init();
    final keys = _prefs?.getKeys() ?? {};
    final prefix = '$_keyPrefix$_unreadItemsPrefix${BadgeFeature.ischool.key}_';
    
    int count = 0;
    for (final key in keys) {
      if (key.startsWith(prefix)) {
        await _prefs?.setBool(key, true);
        count++;
      }
    }
    
    if (count > 0) {
      print('[Badge] 已標記 $count 個公告為未讀');
    }
    notifyListeners();
  }
  
  /// 清除所有 i學院紅點記錄（用於重置）
  /// 這會刪除所有記錄，下次同步時會重新標記所有公告為新的
  Future<void> clearAllISchoolRecords() async {
    await init();
    final keys = _prefs?.getKeys() ?? {};
    final prefix = '$_keyPrefix$_unreadItemsPrefix${BadgeFeature.ischool.key}_';
    
    int count = 0;
    for (final key in keys) {
      if (key.startsWith(prefix)) {
        await _prefs?.remove(key);
        count++;
      }
    }
    
    if (count > 0) {
      print('[Badge] 已清除 $count 個記錄');
    }
    notifyListeners();
  }

  /// 設定 i學院紅點功能開關
  Future<void> setISchoolBadgeEnabled(bool enabled) async {
    await setFeatureEnabled(BadgeFeature.ischool, enabled);
  }

  /// 檢查 i學院紅點功能是否啟用
  Future<bool> isISchoolBadgeEnabled() async {
    return await isFeatureEnabled(BadgeFeature.ischool);
  }

  // ==================== 其他功能專用方法（預留） ====================
  
  /// 社團公告相關方法可以在這裡添加
  /// 訊息相關方法可以在這裡添加
  /// 校務系統相關方法可以在這裡添加
}
