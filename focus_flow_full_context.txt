# FocusFlow 專案完整內容上下文 (AI Studio 專用)

本文件彙整了 FocusFlow 專案的所有核心資訊、架構說明與關鍵源代碼，旨在為 Google AI Studio 提供完整的開發背景，方便進行後續的功能開發、除錯或架構調整。

---

## 1. 專案基本資訊
- **專案名稱**: FocusFlow
- **專案類型**: Flutter 跨平台應用程式 (支援 Android, iOS, Windows, Web)
- **核心定位**: 3C Detox / 專注力管理工具（Zen 風格）。
- **主要使命**: 幫助使用者擺脫手機干擾，透過「App 封鎖」、「番茄鐘」與「背景音樂」創造深度專注環境。

---

## 2. 核心功能說明

### A. 專注計時與番茄鐘 (Pomodoro)
- 支援「普通倒數」與「番茄鐘模式」。
- 番茄鐘模式遵循 25 分鐘專注 + 5 分鐘休息的循環。
- 專注結束後可選擇發出「復古機械鬧鐘」音效。

### B. 嚴格模式與 App 封鎖 (Android 專屬)
- **封鎖機制**: 透過 Android 原生 `UsageStatsManager` 監聽當前前景 App，若使用者嘗試打開「封鎖名單」中的 App，系統會強制將其拉回 FocusFlow 介面。
- **懸浮窗權限**: 依賴 `SYSTEM_ALERT_WINDOW` 以實現覆蓋封鎖。
- **封鎖名單管理**: 使用者可自定義多組封鎖名單，並在不同的專注排程中切換。

### C. 預約排程 (Schedules)
- 使用者可設定每週重複的自動專注時段（例如：每週一至週五 09:00 - 10:00）。
- 到了指定時間，App 會自動啟動專注模式（需權限支援）。

### D. 沉浸式音樂播放
- 支援從手機本地匯入音樂檔案或資料夾。
- 支援隨機播放、單曲點選播放、防護機制（自動跳過失效遺失的檔案）。
- 專注開始後仍可靈活切換音樂。

### E. 多語言支援 (i18n)
- 支援「繁體中文」、「英文」與「日文」。
- 介面文字會根據系統語言或使用者設定自動切換。

---

## 3. 技術棧 (Tech Stack)
- **Framework**: Flutter 3.10.8+
- **語言**: Dart (Flutter), Kotlin (Android Native Integration)
- **狀態管理**: `Provider`
- **數據存儲**: `shared_preferences`
- **多媒體**: `audioplayers`
- **檔案處理**: `file_picker`
- **UI 元件**: Google Fonts (Inter), Material Design 3

---

## 4. 專案目錄結構 (Project Structure)

| 檔案/資料夾 | 用途說明 |
| :--- | :--- |
| `lib/main.dart` | 應用進入點，包含 Provider 初始化與背景排程檢查邏輯。 |
| `lib/models/` | 包含 `BlockList` (封鎖名單) 與 `FocusSchedule` (排程) 資料模型。 |
| `lib/providers/` | 核心邏輯：`FocusProvider` (計時與音樂)、`LanguageProvider` (多語言)、`ScheduleProvider` (排程管理)。 |
| `lib/screens/` | 各大介面：`HomeScreen` (主頁計時)、`MusicListScreen` (音樂管理)、`AppSelectorScreen` (App 選擇) 等。 |
| `lib/utils/` | `native_integration.dart` 負責與 Android 原生通訊。 |
| `android/.../FocusService.kt` | Android 原生背景服務，負責執行監控與封鎖邏輯。 |
| `assets/` | 存放背景鬧鐘音效 `retro_alarm.wav`。 |

---

## 5. 核心代碼彙整 (Key Source Code)

### A. pubspec.yaml (環境與依賴)
```yaml
name: focus_flow
version: 1.0.0+1
environment:
  sdk: ^3.10.8
dependencies:
  flutter:
    sdk: flutter
  cupertino_icons: ^1.0.8
  provider: ^6.1.5+1
  google_fonts: ^8.0.2
  shared_preferences: ^2.5.4
  file_picker: ^8.1.7
  audioplayers: ^6.1.1
flutter:
  uses-material-design: true
  assets:
    - assets/retro_alarm.wav
```

### B. lib/main.dart (系統啟動與排程輪詢)
```dart
void main() {
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => FocusProvider()),
        ChangeNotifierProvider(create: (_) => LanguageProvider()),
        ChangeNotifierProvider(create: (_) => ScheduleProvider()),
      ],
      child: const FocusFlowApp(),
    ),
  );
}

// ... 內部輪詢檢查排程邏輯 ...
_scheduleChecker = Timer.periodic(const Duration(seconds: 10), (timer) {
  // 檢查當前時間是否匹配任何已啟動的排程，若匹配則自動開啟專注模式
});
```

### C. lib/providers/focus_provider.dart (核心邏輯)
此檔案管理了計時器狀態、音樂播放狀態、鬧鐘邏輯以及與原生層的通訊。
重點功能：
- `startFocus()`: 啟動計時並開啟原生封鎖服務。
- `_playMusic()`: 處理本地音樂播放，包含隨機播放與錯誤跳轉機制。
- `stopAlarm()`: 手動關閉響鈴。

### D. android/app/src/main/kotlin/com/example/focus_flow/FocusService.kt (原生監控)
這是實現「App 封鎖」的最關鍵部分：
```kotlin
private fun checkForegroundApp() {
    val usm = getSystemService(Context.USAGE_STATS_SERVICE) as UsageStatsManager
    // ... 查詢過去 10 秒的事件 ...
    if (event.eventType == UsageEvents.Event.MOVE_TO_FOREGROUND) {
        currentApp = event.packageName
    }
    // 若當前 App 在封鎖名單中，則啟動 MainActivity 將使用者拉回
    if (currentApp != null && blockedApps.contains(currentApp)) {
        startActivity(launchIntent)
    }
}
```

---

## 6. 最近更新重點 (2026-04-02)
- **音樂選歌優化**: 在專注期間可自由點選音樂並立即播放，解決了先前播放不同步的問題。
- **鬧鐘功能**: 新增倒數結束後的專屬音效提醒。
- **佈局修復**: 修復了主畫面底部溢出問題，並加入滾動支援。
- **跨平台預覽**: 新增 Windows 桌面端支援。

---

## 7. 如何在 AI Studio 中使用
1. 直接將本文件的內容貼入 AI Studio 的 Prompt 中。
2. 或將整個資料夾上傳。由於本文件已提取關鍵邏輯，AI 能夠快速理解跨平台與原生層的通訊機制。
3. 可針對「封鎖邏輯調整」、「音樂播放機制」或「新增圖表分析」向 AI 提問。
