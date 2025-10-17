# 新增頁面到導航系統指南

本文檔說明如何在 QAQ Flutter 應用程式中新增一個可配置的頁面到導航系統。

## 概述

QAQ 應用程式採用可配置的導航系統，使用者可以自訂底部導航列的內容。新增頁面需要修改以下幾個檔案：

1. 建立頁面檔案
2. 更新本地化字串
3. 註冊到導航配置服務

## 步驟說明

### 步驟 1: 建立頁面檔案

在 `lib/src/pages/` 目錄下建立新的頁面檔案。

**範例：** `credits_page.dart` （學分計算頁面）

```dart
import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';

/// 學分計算頁面
/// 用於計算學分、規劃課程
class CreditsPage extends StatelessWidget {
  const CreditsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.credits),
      ),
      body: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.calculate, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text('學分計算功能開發中'),
            SizedBox(height: 8),
            Text(
              '規劃課程、計算學分',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }
}
```

**重點：**
- 頁面類別應繼承 `StatelessWidget` 或 `StatefulWidget`
- 使用 `AppLocalizations.of(context)` 取得本地化字串
- 為類別添加註解說明頁面用途

---

### 步驟 2: 更新本地化字串

編輯 `lib/src/l10n/app_localizations.dart` 檔案，新增頁面的本地化字串。

#### 2.1 新增 Getter

在導航區域新增對應的 getter：

```dart
// 導航
String get courseTable => _localizedValues[locale.languageCode]?['courseTable'] ?? '課表';
String get calendar => _localizedValues[locale.languageCode]?['calendar'] ?? '日曆';
String get courseSearch => _localizedValues[locale.languageCode]?['courseSearch'] ?? '課程查詢';
String get grades => _localizedValues[locale.languageCode]?['grades'] ?? '成績';
String get credits => _localizedValues[locale.languageCode]?['credits'] ?? '學分';  // 新增這行
// ... 其他項目
```

#### 2.2 新增中文翻譯

在 `_localizedValues` 的 `'zh'` 區塊中新增翻譯：

```dart
'zh': {
  // ... 其他翻譯
  // 導航
  'courseTable': '課表',
  'calendar': '日曆',
  'courseSearch': '課程查詢',
  'grades': '成績',
  'credits': '學分',  // 新增這行
  // ...
}
```

#### 2.3 新增英文翻譯

在 `_localizedValues` 的 `'en'` 區塊中新增翻譯：

```dart
'en': {
  // ... 其他翻譯
  // Navigation
  'courseTable': 'Course Table',
  'calendar': 'Calendar',
  'courseSearch': 'Course Search',
  'grades': 'Grades',
  'credits': 'Credits',  // 新增這行
  // ...
}
```

---

### 步驟 3: 註冊到導航配置服務

編輯 `lib/src/services/navigation_config_service.dart` 檔案。

#### 3.1 匯入頁面

在檔案頂部新增 import 語句：

```dart
import '../pages/course_table_page.dart';
import '../pages/calendar_page.dart';
import '../pages/course_search_page.dart';
import '../pages/grades_page.dart';
import '../pages/credits_page.dart';  // 新增這行
// ... 其他 imports
```

#### 3.2 新增導航項目

在 `availableNavItems` 列表中新增新的 `NavItem`：

```dart
final List<NavItem> availableNavItems = [
  NavItem(
    id: 'course_table',
    label: '課表',
    icon: Icons.calendar_view_week,
    pageBuilder: (context) => const CourseTablePage(),
  ),
  // ... 其他項目
  NavItem(
    id: 'credits',                          // 唯一識別碼
    label: '學分',                          // 顯示標籤
    icon: Icons.grade,                      // 圖示
    pageBuilder: (context) => const CreditsPage(),  // 頁面建構器
  ),
  // ... 其他項目
];
```

**重點：**
- `id`: 唯一識別碼，用於保存使用者設定
- `label`: 顯示在導航列和設定頁面的文字（可考慮改用本地化字串）
- `icon`: Material Icons 圖示
- `pageBuilder`: 返回頁面實例的函數

---

## 預設導航列設定（選擇性）

如果要將新頁面加入預設導航列，可以修改 `defaultNavOrder`：

```dart
static const List<String> defaultNavOrder = [
  'course_table',
  'calendar',
  'course_search',
  'grades',
  'credits',  // 新增到預設導航列
];
```

**注意：** 預設導航列最多 5 個項目。

---

## 圖示選擇建議

選擇合適的 Material Icons：

- **學分/計算**: `Icons.calculate`, `Icons.functions`, `Icons.account_balance`
- **成績**: `Icons.grade`, `Icons.star`, `Icons.assessment`
- **課程**: `Icons.book`, `Icons.menu_book`, `Icons.library_books`
- **地圖**: `Icons.map`, `Icons.location_on`, `Icons.explore`
- **查詢**: `Icons.search`, `Icons.find_in_page`, `Icons.query_stats`

可參考 [Material Icons 官方文檔](https://fonts.google.com/icons?selected=Material+Icons)。

---

## 導航系統特性

### 使用者可配置

- 使用者可自訂 1-5 個導航項目
- 未加入導航列的功能會顯示在「其他」頁面
- 支援拖曳排序

### 持久化儲存

- 使用 Hive 本地資料庫儲存設定
- 設定在應用程式重啟後仍然有效

### 「其他」功能

未加入導航列的頁面會自動顯示在「其他」頁面，使用者仍可存取。

---

## 完整範例：新增學分頁面

以學分計算頁面為例，完整的變更包括：

1. **新增檔案**
   - `lib/src/pages/credits_page.dart`

2. **修改檔案**
   - `lib/src/l10n/app_localizations.dart` - 新增 `credits` 本地化字串
   - `lib/src/services/navigation_config_service.dart` - 註冊頁面和圖示

3. **圖示調整**
   - 成績頁面：`Icons.grade` → `Icons.calculate`
   - 學分頁面：`Icons.grade`

---

## 注意事項

1. **唯一性**: 確保 `NavItem` 的 `id` 在所有項目中是唯一的
2. **圖示一致性**: 選擇與功能相符且風格一致的圖示
3. **本地化**: 確保所有文字都使用本地化字串，支援多語言
4. **測試**: 新增頁面後應測試：
   - 可以在設定中加入導航列
   - 可以從導航列移除
   - 在「其他」頁面正確顯示
   - 拖曳排序功能正常

---

## 常見問題

### Q: 如何更改頁面圖示？

修改 `navigation_config_service.dart` 中對應 `NavItem` 的 `icon` 屬性。

### Q: 新頁面沒有出現在「其他」功能中？

檢查是否已正確加入 `availableNavItems` 列表。

### Q: 如何限制頁面只在特定情況下顯示？

可以在 `getOtherFeatures()` 或頁面本身添加條件邏輯。

### Q: 可以動態新增頁面嗎？

目前系統使用靜態列表，如需動態新增，需要修改 `NavigationConfigService` 的架構。

---

## 相關檔案

- `lib/src/pages/` - 所有頁面檔案
- `lib/src/l10n/app_localizations.dart` - 本地化字串
- `lib/src/services/navigation_config_service.dart` - 導航配置服務
- `lib/src/pages/navigation_config_page.dart` - 導航設定頁面 UI

---

## 版本歷史

- **2025-10-05**: 初始版本，新增學分頁面範例

---

## 總結

透過以上步驟，您可以輕鬆地為 QAQ 應用程式新增新的可配置頁面。關鍵是確保：

1. ✅ 頁面檔案結構正確
2. ✅ 本地化字串完整（中英文）
3. ✅ 正確註冊到導航服務
4. ✅ 選擇合適的圖示
5. ✅ 測試所有導航功能

如有問題，請參考現有頁面（如 `grades_page.dart`, `calendar_page.dart`）作為範例。
