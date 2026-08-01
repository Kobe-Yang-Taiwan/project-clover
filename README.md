# Project Clover

Project Clover 是一款 Android 優先的優惠管理原型，協助使用者快速看見即將到期的優惠，避免已擁有的價值因遺忘而浪費。

## Prototype V0.4 已包含

- 今日首頁：依到期急迫程度排列待使用優惠
- 優惠清單：分開顯示待使用與已完成項目
- 新增優惠：名稱與到期日為必填，來源與備註為選填
- 優惠詳情：查看內容並標記完成
- 本機永久保存：重新啟動 App 後，新增內容與完成狀態仍會保留
- Android 到期提醒：每張優惠可自行開關，並設定提醒日期與時間
- 預設建議到期前一天上午 9:00，若該時間已過則建議五分鐘後
- 完成優惠後自動取消該筆提醒
- 依 Android 手機時區安排通知
- 儲存與通知失敗保護
- 繁體中文介面與台灣日期格式
- 軟體資訊：首頁右上角可查看實際安裝版本與 Build 編號
- GitHub Actions 自動分析、測試及建置 Android Debug APK

## 通知行為

- 第一次新增優惠時，Android 會詢問是否允許通知
- 使用者拒絕通知時，優惠仍會正常儲存
- 儲存前會檢查提醒時間必須晚於現在，且不能晚於到期日
- 最多安排近期 100 筆待使用優惠，避免手機排程數量過多
- 某些 Android 品牌的省電設定可能延遲背景通知

## 資料與隱私

- 優惠資料只儲存在使用者自己的 Android 手機
- 本版不會把資料上傳到網路或雲端
- 解除安裝 App 或清除 App 資料會刪除已保存的優惠
- 首次安裝會顯示三筆示範資料；之後會載入手機已保存的資料

## 本版限制

- 不包含登入、雲端同步、OCR、AI、家庭共享與商業功能
- Repository 採 source-only 管理；Android 平台檔在建置時由 Flutter CLI 產生

## 自動驗證

每次 Pull Request 都會執行：

1. 產生並設定 Android 平台檔
2. Dart 格式處理
3. Flutter 靜態分析
4. Flutter 測試
5. Android Debug APK 建置
6. 上傳 `project-clover-android-debug` artifact

## Founder 取得 Android 試玩版

1. 開啟 GitHub Pull Request
2. 確認最新 `Flutter checks` 顯示綠色勾勾
3. 下載最新 `project-clover-android-debug`
4. 解壓縮後安裝 `app-debug.apk`
5. 新增一張測試優惠，自行設定未來的提醒日期與時間，並允許通知
6. 確認優惠在重開 App 後仍存在
