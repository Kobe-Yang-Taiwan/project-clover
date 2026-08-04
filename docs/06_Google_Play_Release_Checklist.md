# Google Play Release Checklist

本文件只用於發布準備；本 Sprint 不執行 Google Play 發布。

## Privacy Policy

- [ ] 建立可公開存取的隱私政策網址。
- [ ] 說明 Local-first 儲存、備份檔、診斷資訊與 Email 回饋流程。
- [ ] 明確說明優惠內容不會由 Project Clover 上傳。
- [ ] 完成 Google Play Data safety 表單並與實際 App 行為逐項核對。

## Permissions

- [ ] 盤點最終 AndroidManifest 的所有權限。
- [ ] 通知權限只在需要時請求，拒絕後核心功能仍可使用。
- [ ] 確認沒有不必要的儲存、相機、位置、聯絡人或網路權限。
- [ ] 對 Play Console 的權限聲明與 App 實際行為保持一致。

## Target SDK

- [ ] 在發布當日核對 Google Play 最新 target API level 要求。
- [ ] 固定並記錄正式 Android `compileSdk`、`targetSdk` 與 `minSdk`。
- [ ] 以目標 Android 版本完成通知權限、備份、還原與 Email intent 實機測試。

## AAB

- [ ] 建立正式 Android 專案設定，不再只依賴 CI 臨時產生平台檔。
- [ ] 建立 release signing key，安全保存並記錄復原責任人。
- [ ] 建置 signed release AAB，而不是 Debug APK。
- [ ] 使用 Play Console internal testing 驗證安裝、升級與資料保留。
- [ ] 保存 versionCode、versionName、mapping 與建置來源提交。

## Icons

- [ ] 準備符合 Android Adaptive Icon 規格的前景、背景與單色圖示。
- [ ] 檢查 launcher、設定頁、通知列與不同形狀遮罩的顯示結果。
- [ ] 確認圖示沒有測試字樣、透明邊界錯誤或低解析度素材。

## Feature Graphic

- [ ] 準備 Google Play Feature Graphic。
- [ ] 使用發布當日 Play Console 規格核對尺寸、格式及安全區域。
- [ ] 圖面清楚表達「今天優先使用哪張優惠」與到期提醒價值。
- [ ] 避免放入未實作功能、裝置框誤導或不可證實的成效宣稱。

## Release gate

- [ ] Founder 實機驗收通過。
- [ ] 3～10 位 Beta 使用者完成 7～14 天測試。
- [ ] 無資料遺失、錯誤還原或阻擋核心流程的問題。
- [ ] 格式、靜態分析、自動測試及 release AAB 建置全部通過。
- [ ] Release Notes、Known Issues、FAQ、支援 Email 與版本資料已更新。
- [ ] PR 經人工確認後才決定是否脫離 Draft；不得由自動化流程直接發布。
