# V0.15 Development Progress

## Implemented

- [x] 候選欄位擴充：商家、品牌、型號、規格、ITEM、原價、優惠價、節省、條件。
- [x] `READY / NEEDS REVIEW / REJECTED` 與預設選取政策。
- [x] 圖片與 PDF 共用多候選解析入口。
- [x] ITEM／價格空間錨點商品區域切割。
- [x] 非商品拒絕、價格語意與文件層商家辨識。
- [x] 問題候選置頂、紅字原因、只看需要確認、逐筆修正。
- [x] Final Validation Gate 與匯入前暫存。
- [x] 16 項受控分類並保留舊分類識別碼相容性。

## Validation pending Founder device

- [ ] 同一張 Founder 超市截圖 Before/After 實機核對。
- [ ] 同一份 Founder Costco PDF Before/After 實機核對。
- [ ] 依標註結果計算 Recall、Precision、One-to-One Rate 與 Field correctness。
- [ ] 實機記錄匯入時間、修正率及點擊數。

上述數值在 Founder 完成標註與實機測試前維持「尚無可驗證數值」，不得猜測。

## Automated validation

- [x] Dart format：21 個檔案，0 個需修改。
- [x] Flutter Analyze：No issues found。
- [x] 自動測試：80／80 通過，0 失敗。
- [x] Android Debug APK：建置成功。
- [x] GitHub Actions：Run #82 成功。
- [x] APK artifact：`project-clover-android-debug`，Artifact ID `9111299788`，95,040,951 bytes。
- [x] Artifact SHA-256：`1ee1ac9b39dc95ca93c27c1242d9bda652ab9fb4d77f71ae19175a6244b4bb41`。
- [x] Artifact 到期日：2026-08-25。
