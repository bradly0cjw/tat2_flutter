/// 功能開關配置
/// 
/// 用於集中管理所有功能的啟用/禁用狀態
/// 當某個功能過時、不可用或需要暫時隱藏時，可以在這裡設定
class FeatureConfig {
  /// 功能啟用狀態映射表
  /// key: 功能 ID
  /// value: 是否啟用 (true: 啟用, false: 隱藏)
  static const Map<String, bool> _featureEnabled = {
    // 核心功能
    'course_table': true,       // 課表
    'calendar': true,            // 日曆
    'course_search': true,       // 課程查詢
    'grades': true,              // 成績
    
    // 其他功能
    'credits': false,            // 學分 - 已隱藏
    'campus_map': true,          // 校園地圖
    'empty_classroom': true,     // 空教室查詢
    'club_announcements': false, // 社團公告 - 已隱藏
    'admin_system': true,        // 校務系統
    'messages': false,           // 訊息 - 已隱藏
    'ntut_learn': true,          // 北科i學園
    'food_map': false,           // 美食地圖 - 已隱藏
  };

  /// 檢查功能是否啟用
  /// 
  /// [featureId] 功能 ID
  /// 
  /// 返回 true 表示功能啟用，false 表示功能隱藏
  /// 如果功能 ID 不在配置中，預設返回 true（向後兼容）
  static bool isFeatureEnabled(String featureId) {
    return _featureEnabled[featureId] ?? true;
  }

  /// 取得所有啟用的功能 ID 列表
  static List<String> getEnabledFeatures() {
    return _featureEnabled.entries
        .where((entry) => entry.value)
        .map((entry) => entry.key)
        .toList();
  }

  /// 取得所有已隱藏的功能 ID 列表
  static List<String> getDisabledFeatures() {
    return _featureEnabled.entries
        .where((entry) => !entry.value)
        .map((entry) => entry.key)
        .toList();
  }

  /// 取得功能的隱藏原因說明（可選，用於開發時說明）
  static String? getDisabledReason(String featureId) {
    if (isFeatureEnabled(featureId)) return null;

    // 這裡可以記錄每個功能被隱藏的原因，方便日後維護
    const disabledReasons = {
      'credits': '功能暫時不可用',
      'club_announcements': '功能暫時不可用',
      'messages': '功能暫時不可用',
      'food_map': '功能暫時不可用',
    };

    return disabledReasons[featureId];
  }

  /// 開發用：列印所有功能的狀態
  static void printFeatureStatus() {
    print('=== 功能啟用狀態 ===');
    _featureEnabled.forEach((featureId, enabled) {
      final status = enabled ? '✓ 啟用' : '✗ 隱藏';
      final reason = getDisabledReason(featureId);
      final reasonText = reason != null ? ' ($reason)' : '';
      print('$status - $featureId$reasonText');
    });
    print('==================');
  }
}
