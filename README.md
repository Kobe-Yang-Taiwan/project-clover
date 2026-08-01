# Project Clover

Project Clover 是一款 Android 優先的優惠管理原型，協助使用者快速看見即將到期的優惠，避免已擁有的價值因遺忘而浪費。

## Prototype V0.1 已包含

- 今日首頁：依到期急迫程度排列待使用優惠
- 優惠清單：分開顯示待使用與已完成項目
- 新增優惠：名稱與到期日為必填，來源與備註為選填
- 優惠詳情：查看內容並標記完成
- 本機永久保存：新增內容與完成狀態在重新啟動 App 後仍會保留
- 儲存失敗保護與繁體中文錯誤提示
- 繁體中文介面與台灣日期格式
- 資料邏輯、永久保存與 Widget 測試
- GitHub Actions 自動分析、測試及建置 Android Debug APK

## 資料與隱私

- 優惠資料目前只儲存在使用者自己的 Android 手機
- 本版不會把資料上傳到網路或雲端
- 解除安裝 App 或清除 App 資料會刪除已保存的優惠
- 首次安裝會顯示三筆示範資料；之後會載入手機已保存的資料

## 本版限制

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
4. 在 Artifacts 點選 `project-clover-android-debug` 下載 ZIP
5. 解壓縮後安裝 `app-debug.apk`
6. 新增一筆優惠、關閉 App、再次開啟，確認資料仍存在
