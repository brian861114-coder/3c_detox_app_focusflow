# FocusFlow 專案目錄結構與用途說明

本文件旨在說明 FocusFlow 專案中各個資料夾與檔案的用途，方便開發者快速了解系統架構。

---

## 根目錄 (Root Directory)

| 檔案/資料夾 | 用途說明 |
| :--- | :--- |
| `CHANGELOG.md` | 紀錄專案的修改歷史與版本更新內容。 |
| `README.md` | 專案的基礎介紹與開發說明。 |
| `pubspec.yaml` | Flutter 專案的核心設定檔，定義專案名稱、依賴套件 (Dependencies) 及資產 (Assets)。 |
| `android/` | Android 原生平台的專案程式碼。 |
| `ios/` | iOS 原生平台的專案程式碼。 |
| `windows/` | Windows 桌面平台的專案程式碼。 |
| `lib/` | Flutter 專案的核心程式碼所在之處 (Dart)。 |
| `web/` | Web 平台的專案程式碼。 |
| `assets/` | 放置靜態資源，如圖片、字體、圖示及**背景音效 (retro_alarm.wav)**。 |
| `test/` | 單元測試或集成測試程式碼。 |
| `update_history.md` | 專案更新日誌，記錄每次功能開發與 Bug 修復細節。 |
| `project_structure.md` | 本文件，說明專案架構與目錄用途。 |
| `focus_flow_full_context.md` | 專案完整內容上下文 (Markdown)，彙整架構與關鍵程式碼。 |
| `focus_flow_full_context.txt` | 專案完整內容上下文 (TXT)，解決 AI Studio 上傳限制。 |

---

## 核心資料夾：lib/

`lib/` 是應用的靈魂所在，包含所有的 UI、邏輯與狀態管理。

### 📁 lib/models (資料模型)
定義系統中使用的資料結構。
- `block_list.dart`: 封鎖名單的模型類別，包含 ID、名稱及應用套件名列表。
- `schedule.dart`: 預約排程的模型類別，包含時間、重複天数、持續時間及關聯的封鎖名單。

### 📁 lib/providers (狀態管理)
使用 Provider 模式管理應用的全域狀態。
- `focus_provider.dart`: 管理專注模式的核心邏輯（計時、番茄鐘、嚴格模式開關、**音樂播放與鬧鐘功能**）。
- `language_provider.dart`: 管理多語言切換 (支援 中、英、日語)。
- `schedule_provider.dart`: 管理預約排程的儲存、刪除、切換與邏輯判斷。

### 📁 lib/screens (介面/視窗)
各個功能的展示視窗。
- `home_screen.dart`: 主介面，包含計時器、開始按鈕及快捷設定。
- `schedule_screen.dart`: 預約排程管理介面。
- `block_list_db_screen.dart`: 封鎖名單管理介面。
- `app_selector_screen.dart`: 應用程式選擇器，用於編輯封鎖名單。
- `stats_screen.dart`: 專注數據統計圖表介面。
- `music_list_screen.dart`: 音樂清單管理介面，可查看與移除匯入的曲目。

### 📁 lib/utils (工具類)
- `native_integration.dart`: Flutter 與 Android 原生程式碼溝通的橋樑 (MethodChannel)。

### 📄 lib/main.dart (進入點)
應用的起點，負責初始化 Provider 以及定時檢查背景排程是否有匹配的任務。

---

## 原生整合：android/

FocusFlow 具備「封鎖其他 App」的功能，這部分依賴於 Android 原生開發。

### 📁 android/app/src/main/kotlin/.../focus_flow/
- `MainActivity.kt`: 負責處理原生權限請求與 Flutter 的通訊通道。
- `FocusService.kt`: **核心背景服務**，負責在後台監聽當前開啟的 App 並決定是否顯示封鎖遮層。

### 📄 android/app/src/main/AndroidManifest.xml
定義 App 所需的 Android 權限（如：`PACKAGE_USAGE_STATS` 使用量存取、`SYSTEM_ALERT_WINDOW` 懸浮窗視窗）。

---

## 其他補充
- **build/**: 編譯後的檔案存放處，包含所有編譯後的產物。
    - `build/app/outputs/flutter-apk/app-release.apk`: 最新的發佈版 (Release) 安裝檔，可直接安裝至 Android 手機。
- **.dart_tool/** & **.idea/**: IDE 與 Dart 編譯器產生的快取資料，不需手動修改。

---
最後更新時間：2026-04-04 16:04 (由 AI 協助)
建立日期：2026-03-12
