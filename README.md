# QAQ Flutter App


北科大校園資訊 App - 課表、成績、行事曆一站式查詢

## 🎯 核心特色

- 🎯 **直接抓取** - App 直接呼叫 NTUT API，避免後端被標記為爬蟲
- 🔄 **智慧重試** - Session 過期自動重新登入，無需手動操作
- 🏫 **可擴展架構** - Adapter 模式，未來可輕鬆支援其他學校
- 📦 **離線功能** - 本地快取，無網路也能查看資料
- 🎨 **現代 UI** - 參考 TAT 設計，Material Design 3

## 🏗️ 架構設計

```
Flutter App (直接呼叫 NTUT API)
    ↓
SchoolAdapter (抽象層)
    ↓
AuthManager + RetryPolicy (自動重登)
    ↓
Backend API (資料同步與分享)
```

## 🚀 快速開始

### 前置需求

- Flutter SDK 3.24+
- Dart 3.5+
- Android Studio / VS Code
- Android 設備或模擬器

### 安裝與執行

```powershell
# 安裝依賴
flutter pub get

# 運行 App
flutter run



## ✨ 核心功能

- ✅ **認證系統** - NTUT Portal 登入、自動重登、Session 管理
- ✅ **課表查詢** - 即時抓取、離線快取、週次顯示
- ✅ **成績查詢** - 學期成績、GPA 計算、學分統計
- ✅ **行事曆** - 學校行事曆 + 本地事件、重複事件支援
- ✅ **課程搜尋** - 全校課程資料、多條件篩選
- ✅ **空教室查詢** - 即時空教室資訊
- ✅ **管理員系統** - 獎懲、缺曠課查詢
- ✅ **深色模式** - 支援系統主題切換

## 📁 專案結構

```
lib/
├── src/
│   ├── core/                        # 核心抽象層（NEW）
│   │   ├── adapter/                 # 學校 API 抽象介面
│   │   ├── auth/                    # 統一認證管理
│   │   └── retry/                   # 自動重試策略
│   ├── adapters/                    # 學校實作（NEW）
│   │   ├── ntut_school_adapter.dart # 北科大實作
│   │   └── ischool_plus_adapter.dart # i學院+
│   ├── services/
│   │   ├── *_service_v2.dart        # V2 服務（使用 Adapter）
│   │   └── *_service.dart           # 舊版服務（向後相容）
│   ├── providers/                   # 狀態管理
│   ├── models/                      # 資料模型
│   └── ui/                          # 畫面與元件
└── main.dart





