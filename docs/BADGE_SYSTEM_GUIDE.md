# 紅點通知系統使用指南

## 📋 目錄

1. [系統概述](#系統概述)
2. [快速開始](#快速開始)
3. [核心概念](#核心概念)
4. [詳細使用教學](#詳細使用教學)
5. [完整範例](#完整範例)
6. [最佳實踐](#最佳實踐)
7. [常見問題](#常見問題)

---

## 系統概述

紅點通知系統是一個通用的未讀狀態管理服務，支援多種功能模組的紅點顯示。

### 特性

- ✅ **通用化設計**：支援多種功能類型（i學院、社團公告、訊息等）
- ✅ **持久化儲存**：使用 SharedPreferences 保存狀態
- ✅ **即時更新**：使用 ChangeNotifier 自動通知 UI 更新
- ✅ **智能同步**：保留已讀狀態，只標記新內容為未讀
- ✅ **級聯顯示**：支援多層級紅點（項目 → 類別 → 入口）
- ✅ **全局控制**：支援全局隱藏所有紅點
- ✅ **自動檢查限制**：防止頻繁抓取資料（15分鐘限制）

### 支援的功能類型

```dart
enum BadgeFeature {
  ischool('ischool'),           // i學院
  clubAnnouncement('club'),     // 社團公告
  message('message'),           //### API 參考

### 通用方法

| 方法 | 說明 |
|------|------|
| `markAsRead(feature, itemId)` | 標記項目為已讀 |
| `isRead(feature, itemId)` | 檢查項目是否已讀 |
| `hasUnread(feature)` | 檢查功能是否有未讀（自動檢查全局隱藏） |
| `getUnreadCount(feature)` | 取得未讀數量 |
| `clearFeatureBadges(feature)` | 清除功能的所有紅點 |
| `clearAllBadges()` | 清除所有功能的紅點 |
| `setFeatureEnabled(feature, enabled)` | 設定功能開關 |
| `isFeatureEnabled(feature)` | 檢查功能是否啟用 |

### 全局設定方法

| 方法 | 說明 |
|------|------|
| `setHideAllBadges(hide)` | 設定是否隱藏所有紅點 |
| `isHideAllBadges()` | 檢查是否隱藏所有紅點 |
| `setAutoCheckISchool(enabled)` | 設定是否啟用自動檢查 i學院 |
| `isAutoCheckISchoolEnabled()` | 檢查是否啟用自動檢查 |
| `canAutoCheckISchool()` | 檢查是否可以進行自動檢查（15分鐘限制） |
| `updateISchoolCheckTime()` | 更新最後檢查時間 |
| `getRemainingMinutesToCheck()` | 取得距離下次可檢查的剩餘分鐘數 |stem('admin');         // 校務系統
}
```

---

## 快速開始

### 1. 導入服務

```dart
import '../services/badge_service.dart';
```

### 2. 在頁面中監聽變化

```dart
class MyPage extends StatefulWidget {
  @override
  State<MyPage> createState() => _MyPageState();
}

class _MyPageState extends State<MyPage> {
  @override
  void initState() {
    super.initState();
    // 監聽 BadgeService 變化
    BadgeService().addListener(_onBadgeChanged);
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
  
  // ... 其他代碼
}
```

### 3. 顯示紅點

```dart
FutureBuilder<bool>(
  future: BadgeService().hasUnread(BadgeFeature.ischool),
  builder: (context, snapshot) {
    final hasUnread = snapshot.data ?? false;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Icon(Icons.school),
        if (hasUnread)
          Positioned(
            right: -4,
            top: -4,
            child: Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: Colors.red,
                shape: BoxShape.circle,
              ),
            ),
          ),
      ],
    );
  },
)
```

---

## 核心概念

### 1. 功能類型（BadgeFeature）

每個功能都有獨立的紅點系統，通過 `BadgeFeature` 枚舉區分。

### 2. 項目 ID（Item ID）

每個需要追蹤的項目都有唯一的 ID，格式通常為：`{主ID}_{子ID}`

例如 i學院：`{courseId}_{announcementId}`

### 3. 狀態值

- `false` = 未讀（顯示紅點）
- `true` = 已讀（不顯示紅點）

### 4. 儲存鍵格式

```
badge_read_items_{feature}_{itemId}
```

例如：`badge_read_items_ischool_CS101_12345`

---

## 詳細使用教學

### 步驟 1：註冊新內容

當從 API 獲取內容列表時，註冊所有項目：

```dart
// 範例：註冊社團公告
Future<void> _syncAnnouncements() async {
  // 1. 從 API 獲取公告列表
  final announcements = await api.getClubAnnouncements();
  
  // 2. 提取 ID 列表
  final announcementIds = announcements
      .map((a) => a.id)
      .where((id) => id != null && id.isNotEmpty)
      .toList();
  
  // 3. 註冊到 BadgeService（智能同步，保留已讀狀態）
  for (final id in announcementIds) {
    final key = 'club_$id'; // 建立唯一 ID
    await BadgeService().markAsRead(BadgeFeature.clubAnnouncement, key);
  }
}
```

### 步驟 2：標記為已讀

當用戶點擊項目時，標記為已讀：

```dart
void _onAnnouncementTap(String announcementId) async {
  // 標記為已讀
  await BadgeService().markAsRead(
    BadgeFeature.clubAnnouncement,
    'club_$announcementId',
  );
  
  // 顯示詳情
  _showAnnouncementDetail(announcementId);
}
```

### 步驟 3：檢查未讀狀態

#### 3.1 檢查單個項目

```dart
Future<bool> _isAnnouncementUnread(String id) async {
  return !(await BadgeService().isRead(
    BadgeFeature.clubAnnouncement,
    'club_$id',
  ));
}
```

#### 3.2 檢查整個功能

```dart
Future<bool> _hasAnyUnreadAnnouncements() async {
  return await BadgeService().hasUnread(BadgeFeature.clubAnnouncement);
}
```

### 步驟 4：顯示紅點

#### 4.1 單個項目的紅點

```dart
Widget _buildAnnouncementItem(Announcement announcement) {
  return FutureBuilder<bool>(
    future: _isAnnouncementUnread(announcement.id),
    builder: (context, snapshot) {
      final hasUnread = snapshot.data ?? false;
      return ListTile(
        leading: Stack(
          clipBehavior: Clip.none,
          children: [
            Icon(Icons.announcement),
            if (hasUnread)
              Positioned(
                right: -2,
                top: -2,
                child: Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: Colors.red,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
          ],
        ),
        title: Text(announcement.title),
        onTap: () => _onAnnouncementTap(announcement.id),
      );
    },
  );
}
```

#### 4.2 導航欄的紅點

```dart
Widget _buildNavIcon(IconData icon, BadgeFeature feature) {
  return FutureBuilder<bool>(
    future: BadgeService().hasUnread(feature),
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
                decoration: BoxDecoration(
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
```

### 步驟 5：管理功能

#### 5.1 清除所有紅點

```dart
Future<void> _clearAllBadges() async {
  await BadgeService().clearFeatureBadges(BadgeFeature.clubAnnouncement);
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text('已清除所有紅點')),
  );
}
```

#### 5.2 開關紅點功能

```dart
Future<void> _toggleBadgeFeature() async {
  final isEnabled = await BadgeService().isFeatureEnabled(
    BadgeFeature.clubAnnouncement,
  );
  await BadgeService().setFeatureEnabled(
    BadgeFeature.clubAnnouncement,
    !isEnabled,
  );
}
```

---

## 完整範例

以下是一個完整的社團公告頁面範例：

```dart
import 'package:flutter/material.dart';
import '../services/badge_service.dart';
import '../models/club_announcement.dart';

class ClubAnnouncementsPage extends StatefulWidget {
  const ClubAnnouncementsPage({super.key});

  @override
  State<ClubAnnouncementsPage> createState() => _ClubAnnouncementsPageState();
}

class _ClubAnnouncementsPageState extends State<ClubAnnouncementsPage> {
  List<ClubAnnouncement> _announcements = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    // 監聽 BadgeService 變化
    BadgeService().addListener(_onBadgeChanged);
    _loadAnnouncements();
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

  Future<void> _loadAnnouncements() async {
    setState(() => _isLoading = true);
    
    try {
      // 1. 從 API 獲取公告
      final announcements = await _api.getClubAnnouncements();
      
      // 2. 註冊所有公告（智能同步）
      for (final announcement in announcements) {
        if (announcement.id == null) continue;
        
        final key = 'club_${announcement.id}';
        // 檢查是否已存在
        final exists = await BadgeService().isRead(
          BadgeFeature.clubAnnouncement,
          key,
        );
        
        if (!exists) {
          // 新公告，標記為未讀
          await BadgeService().markAsRead(
            BadgeFeature.clubAnnouncement,
            key,
          );
        }
      }
      
      setState(() {
        _announcements = announcements;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      print('Failed to load announcements: $e');
    }
  }

  Future<void> _onAnnouncementTap(ClubAnnouncement announcement) async {
    // 標記為已讀
    await BadgeService().markAsRead(
      BadgeFeature.clubAnnouncement,
      'club_${announcement.id}',
    );
    
    // 顯示詳情
    _showAnnouncementDialog(announcement);
  }

  void _showAnnouncementDialog(ClubAnnouncement announcement) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(announcement.title),
        content: Text(announcement.content),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('關閉'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('社團公告'),
        actions: [
          // 清除所有紅點按鈕
          IconButton(
            icon: Icon(Icons.clear_all),
            onPressed: () async {
              await BadgeService().clearFeatureBadges(
                BadgeFeature.clubAnnouncement,
              );
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('已清除所有紅點')),
              );
            },
          ),
        ],
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : ListView.builder(
              itemCount: _announcements.length,
              itemBuilder: (context, index) {
                final announcement = _announcements[index];
                return _buildAnnouncementItem(announcement);
              },
            ),
    );
  }

  Widget _buildAnnouncementItem(ClubAnnouncement announcement) {
    return FutureBuilder<bool>(
      future: BadgeService().isRead(
        BadgeFeature.clubAnnouncement,
        'club_${announcement.id}',
      ),
      builder: (context, snapshot) {
        final isRead = snapshot.data ?? false;
        final hasUnread = !isRead;
        
        return ListTile(
          leading: Stack(
            clipBehavior: Clip.none,
            children: [
              CircleAvatar(
                backgroundColor: hasUnread ? Colors.red : Colors.grey,
                child: Icon(
                  hasUnread ? Icons.mail : Icons.mail_outline,
                  color: Colors.white,
                ),
              ),
              if (hasUnread)
                Positioned(
                  right: -2,
                  top: -2,
                  child: Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: Colors.red,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
            ],
          ),
          title: Text(
            announcement.title,
            style: TextStyle(
              fontWeight: hasUnread ? FontWeight.bold : FontWeight.normal,
            ),
          ),
          subtitle: Text(announcement.date),
          onTap: () => _onAnnouncementTap(announcement),
        );
      },
    );
  }
}
```

---

## 最佳實踐

### 1. 監聽器管理

✅ **正確做法**：在 StatefulWidget 中管理監聽器

```dart
@override
void initState() {
  super.initState();
  BadgeService().addListener(_onBadgeChanged);
}

@override
void dispose() {
  BadgeService().removeListener(_onBadgeChanged);
  super.dispose();
}
```

❌ **錯誤做法**：忘記移除監聽器會導致記憶體洩漏

### 2. ID 命名規範

使用清晰的命名規範：

```dart
// ✅ 好的命名
'ischool_CS101_12345'
'club_sports_announcement_001'
'message_system_notification_123'

// ❌ 不好的命名
'12345'
'a1'
'notification'
```

### 3. 智能同步

註冊內容時，使用智能同步保留已讀狀態：

```dart
// ✅ 智能同步（推薦）
for (final item in items) {
  final key = 'feature_${item.id}';
  final isRead = await BadgeService().isRead(feature, key);
  if (!isRead) {
    // 只註冊新項目
  }
}

// ❌ 簡單覆蓋（不推薦）
await BadgeService().clearFeatureBadges(feature);
for (final item in items) {
  // 所有項目都變成未讀
}
```

### 4. 錯誤處理

```dart
try {
  await BadgeService().markAsRead(feature, itemId);
} catch (e) {
  print('Failed to mark as read: $e');
  // 不影響用戶體驗，靜默處理
}
```

### 5. 性能優化

使用 `FutureBuilder` 避免不必要的重建：

```dart
// ✅ 使用 FutureBuilder
FutureBuilder<bool>(
  future: BadgeService().hasUnread(feature),
  builder: (context, snapshot) {
    // 只在數據變化時重建
  },
)

// ❌ 直接在 build 中調用 async
Widget build(BuildContext context) {
  final hasUnread = await BadgeService().hasUnread(feature); // 錯誤！
}
```

---

## 常見問題

### Q1: 紅點不即時更新？

**A**: 確保頁面已添加監聽器：

```dart
@override
void initState() {
  super.initState();
  BadgeService().addListener(_onBadgeChanged);
}
```

### Q2: 清除紅點後又出現？

**A**: 使用 `clearFeatureBadges` 而不是刪除記錄。新版本已修復，清除會標記為已讀而不是刪除。

### Q3: 重啟 App 後紅點恢復？

**A**: 確保同步邏輯使用智能同步，不要覆蓋已存在的記錄。參考 `registerISchoolAnnouncements` 的實現。

### Q4: 如何添加新的功能類型？

**A**: 在 `BadgeFeature` 枚舉中添加：

```dart
enum BadgeFeature {
  ischool('ischool'),
  clubAnnouncement('club'),
  message('message'),
  adminSystem('admin'),
  myNewFeature('mynew'),  // 添加這行
}
```

### Q5: 如何實現級聯紅點？

**A**: 使用多層檢查：

```dart
// 層級 1: 檢查單個項目
hasUnread('item_123')

// 層級 2: 檢查類別
hasUnreadInCategory('category_a')

// 層級 3: 檢查整個功能
hasUnread(BadgeFeature.myFeature)
```

---

## API 參考

### 通用方法

| 方法 | 說明 |
|------|------|
| `markAsRead(feature, itemId)` | 標記項目為已讀 |
| `isRead(feature, itemId)` | 檢查項目是否已讀 |
| `hasUnread(feature)` | 檢查功能是否有未讀 |
| `getUnreadCount(feature)` | 取得未讀數量 |
| `clearFeatureBadges(feature)` | 清除功能的所有紅點 |
| `clearAllBadges()` | 清除所有功能的紅點 |
| `setFeatureEnabled(feature, enabled)` | 設定功能開關 |
| `isFeatureEnabled(feature)` | 檢查功能是否啟用 |

### i學院專用方法

| 方法 | 說明 |
|------|------|
| `registerISchoolAnnouncement(courseId, announcementId)` | 註冊單個公告 |
| `registerISchoolAnnouncements(courseId, announcementIds)` | 批量註冊公告（智能同步） |
| `markISchoolAnnouncementAsRead(courseId, announcementId)` | 標記公告為已讀 |
| `isISchoolAnnouncementRead(courseId, announcementId)` | 檢查公告是否已讀 |
| `hasUnreadAnnouncements(courseId)` | 檢查課程是否有未讀公告 |
| `hasAnyUnreadInISchool()` | 檢查 i學院是否有任何未讀 |
| `clearAllISchoolBadges()` | 清除所有 i學院紅點 |
| `resetAllISchoolBadges()` | 復原所有紅點（測試用） |
| `setISchoolBadgeEnabled(enabled)` | 設定 i學院紅點開關 |
| `isISchoolBadgeEnabled()` | 檢查 i學院紅點是否啟用 |

---

## 更新日誌

### v1.2.0 (2025-10-06)
- ✅ 新增全局隱藏所有紅點功能
- ✅ 新增自動檢查 i學院公告開關
- ✅ 新增15分鐘檢查限制，避免頻繁抓取
- ✅ 在設定頁面新增通知設定區塊
- ✅ 移除 i學院頁面的紅點開關功能

### v1.1.0 (2025-10-05)
- ✅ 修復清除紅點後重啟又出現的問題
- ✅ 改為標記已讀而不是刪除記錄
- ✅ 新增智能同步邏輯

### v1.0.0 (2025-10-04)
- ✅ 初始版本
- ✅ 支援 i學院公告紅點
- ✅ 通用化架構設計

---

## 支援與聯繫

如有問題或建議，請聯繫開發團隊。

**Happy Coding! 🎉**
