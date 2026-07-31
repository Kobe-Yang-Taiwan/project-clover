# Project Clover

Project Clover 是一款 Android 優先的優惠管理原型，協助使用者快速看見即將到期的優惠，避免已擁有的價值因遺忘而浪費。

## Prototype V0 已包含

- 今日首頁：依到期急迫程度排列待使用優惠
- 優惠清單：分開顯示待使用與已完成項目
- 新增優惠：名稱與到期日為必填，來源與備註為選填
- 優惠詳情：查看內容並標記完成
- 繁體中文介面與台灣日期格式
- 基本資料邏輯與 Widget 測試
- GitHub Actions 自動分析、測試及建置 Android Debug APK

## 本版限制

- 資料目前只保留在 App 執行期間，重新啟動後會恢復示範資料
- 尚未加入 Android 系統通知
- 不包含登入、雲端同步、OCR、AI、家庭共享與商業功能
- Repository 採 source-only 管理；Android 平台檔在建置時由 Flutter CLI 產生

## 自動驗證

每次 Pull Request 都會執行：

1. 產生 Android 平台檔
2. Dart 格式檢查
3. Flutter 靜態分析
4. Flutter 測試
5. Android Debug APK 建置
6. 上傳 `project-clover-android-debug` artifact

## Founder 取得 Android 試玩版

1. 開啟 GitHub Pull Request
2. 確認 `Flutter checks` 顯示綠色勾勾
3. 進入該次 GitHub Actions 執行紀錄
4. 在 Artifacts 下載 `project-clover-android-debug`
5. 解壓縮後，將 APK 傳到 Android 手機並允許安裝測試版 App
