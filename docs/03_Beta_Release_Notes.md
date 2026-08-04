# Project Clover V0.12 Beta Release Notes

版本：`0.12.0（Build 12）`

## 本版目標

這一版不增加大型功能。目標是驗證 Project Clover 是否能讓使用者在 5 秒內知道今天最該使用哪張優惠，並透過提醒減少優惠浪費。

## 本版內容

- Beta Feedback 會開啟手機 Email App，附上 App 版本、Build、Android 版本與裝置型號。
- 回饋 Email 不包含優惠名稱、來源、備註或其他優惠內容。
- Founder 驗收清單已依六個核心區域整理。
- 新增 Beta Known Issues、FAQ 與 Google Play Release Checklist。
- 擴充通知排程／取消、V0.8～V0.11 備份相容、還原與清理測試。

## 安裝方式

1. 從最新成功的 GitHub Actions 下載 `project-clover-android-debug`。
2. 解壓縮並安裝 `app-debug.apk`。
3. Android 若阻擋未知來源安裝，僅對實際使用的檔案管理器暫時允許。
4. 開啟 App，從軟體資訊確認版本為 `0.12.0（Build 12）`。

這是可安裝的 Beta Debug APK，不是 Google Play 正式發布版本。

## 測試重點

- 新增至少 3 張不同到期日的真實或測試優惠。
- 在 5 秒內指出首頁推薦的優惠，記錄是否容易理解。
- 實際等待至少一次通知並點擊進入優惠。
- 使用優惠後標記完成，記錄是否因 App 避免了一次浪費。
- 透過 Beta Feedback 回報問題，寄出前可自行檢查內容。
