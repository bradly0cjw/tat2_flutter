# QAQ Flutter - 隱私條款與用戶協議實作總結

## 完成項目

### 1. 創建隱私權條款和使用者條款文件
- ✅ `assets/docs/privacy_policy.md` - 隱私權條款（參考 TAT，簡化版本）
- ✅ `assets/docs/terms_of_service.md` - 使用者條款

重點內容：
- 明確說明本服務為非官方性質
- **所有資訊僅供參考，不得作為重要決策依據**
- **請以學校官方系統為準**
- 本服務保留隨時暫停或終止服務的權利
- 服務中斷或資訊錯誤不負任何責任

### 2. 創建條款展示頁面
- ✅ `lib/src/pages/privacy_policy_page.dart` - 隱私權條款頁面
- ✅ `lib/src/pages/terms_of_service_page.dart` - 使用者條款頁面

功能：
- 使用 flutter_markdown 套件顯示 Markdown 格式的條款
- 支援超連結點擊
- 支援外部瀏覽器開啟連結

### 3. 更新依賴套件
在 `pubspec.yaml` 中新增：
- ✅ `package_info_plus: ^8.0.0` - 取得應用程式版本資訊
- ✅ `flutter_markdown: ^0.7.3+1` - 顯示 Markdown 格式
- ✅ 新增 `assets/docs/` 到 assets 列表

### 4. 更新關於頁面
修改 `lib/src/pages/about_page.dart`：
- ✅ 使用 `package_info_plus` 動態顯示版本號（從 pubspec.yaml 讀取）
- ✅ 移除硬編碼的版本號
- ✅ 新增「法律資訊」區塊
- ✅ 加入「隱私權條款」和「使用者條款」的連結卡片
- ✅ 點擊卡片可導航到對應的條款頁面

### 5. 更新登入頁面
修改 `lib/ui/screens/login_screen.dart`：
- ✅ 新增同意條款的 Checkbox
- ✅ 條款文字可點擊查看完整內容
- ✅ 登入前必須勾選同意條款
- ✅ 未勾選會顯示提示訊息
- ✅ 更新說明文字，提醒使用者「本服務為非官方應用，所有資訊僅供參考，請以學校官方系統為準」

## 技術實作細節

### 版本資訊
```dart
final packageInfo = await PackageInfo.fromPlatform();
String version = packageInfo.version;  // 從 pubspec.yaml 讀取
String buildNumber = packageInfo.buildNumber;
```

### 條款同意檢查
```dart
bool _agreedToTerms = false;

// 登入前檢查
if (!_agreedToTerms) {
  // 顯示錯誤訊息
  return;
}
```

### Markdown 顯示
```dart
await rootBundle.loadString('assets/docs/privacy_policy.md');
// 使用 flutter_markdown 套件的 Markdown widget 顯示
```

## 使用者體驗流程

1. **首次登入**
   - 使用者必須勾選「我已閱讀並同意隱私權條款和使用者條款」
   - 可以點擊條款文字查看完整內容
   - 未勾選無法登入

2. **查看條款**
   - 關於頁面中的「法律資訊」區塊
   - 點擊可查看完整的隱私權條款或使用者條款
   - 條款以 Markdown 格式顯示，易於閱讀

3. **版本資訊**
   - 關於頁面自動顯示當前版本（從 pubspec.yaml）
   - 不需要手動更新版本字串

## 法律保護重點

根據使用者條款，已明確說明：

1. **免責聲明**
   - 本服務為非官方性質
   - 所有資訊僅供參考
   - 不得作為重要決策依據
   - 以學校官方系統為準

2. **服務變更權利**
   - 保留隨時修改、暫停或終止服務的權利
   - 恕不另行通知

3. **責任限制**
   - 因使用本服務而產生的任何損失，不負任何責任
   - 對因服務中斷造成的任何損失不負責任

## 檔案清單

新增檔案：
- `assets/docs/privacy_policy.md`
- `assets/docs/terms_of_service.md`
- `lib/src/pages/privacy_policy_page.dart`
- `lib/src/pages/terms_of_service_page.dart`

修改檔案：
- `pubspec.yaml`
- `lib/src/pages/about_page.dart`
- `lib/ui/screens/login_screen.dart`

## 後續建議

1. 定期檢視並更新條款內容
2. 如有重大變更，應通知使用者
3. 保留條款修改歷史記錄
4. 考慮加入條款版本號

---

實作日期：2025年10月15日
