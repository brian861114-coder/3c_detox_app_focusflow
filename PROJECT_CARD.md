---
id: 3c-detox
name: FocusFlow（3c_detox）
summary: Flutter 專注 App：專注時段封鎖干擾應用，主戰場在 Android
state: archived
locations:
  - host: nitro
    path: C:\Users\brian\Downloads\10_projects\19_archive\3c_detox
    role: source
status_source: README.md
snapshot: summary
related: []
card_reviewed: 2026-09-24
---

## 用途
數位排毒原型：專注／番茄鐘期間把黑名單 App 拉回 FocusFlow。無帳號、資料在本機。目錄在 `19_archive`，文件未寫仍為日常主開發。

## 功能
- 封鎖名單、專注模式、番茄鐘、使用量／懸浮權限攔截、統計、本機偏好、音效（README）
- 自動排程選封鎖清單（git 歷史）[未驗收]
- iOS／Windows／Web 目錄在，封鎖僅 Android 有效（架構文件）

## 結構與入口
- `lib/` Flutter UI；`android/` 原生攔截；`assets/` 音效圖示；`test/`
- 依賴：`pubspec.yaml`。安裝檔：`flutter build apk --release`（架構文件）

## 外部依賴
- 無後端。可選網路字型；離線退系統字型
- 發布簽章設定檔不在 repo；若出現勿讀

## 禁區
- `build/`、`.dart_tool/`：編譯產物
- 任何簽章設定檔（目前根目錄未見）：只列路徑不開

## 給 AI 的注意事項
- 先讀 `README.md`、`ARCHITECTURE_for_VibeCoder.md`
- 不要把 Web／iOS 寫成已能封鎖；改原生攔截前確認權限契約
