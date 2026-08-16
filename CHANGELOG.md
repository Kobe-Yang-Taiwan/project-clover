# Changelog

## 0.16.1+17 — Source-Adaptive Import Remediation

- Native-text PDF 改以本機文字、座標與 product-cell ownership 重建，不再優先整頁 OCR。
- 圖片與掃描頁新增逐次同意、可關閉且 provider-neutral 的多模態視覺路徑。
- 每個 canonical 欄位保留 evidence/provenance；跨 region 欄位直接排除並計數。
- Costco 四欄版面、價格堆疊與不等列數分區避免漏件及跨 cell 污染。
- 新增真實 Costco／全聯／全家 Golden Dataset ground truth、hash 與必要品質指標。
- Cloud output 仍須通過 deterministic validation、confidence 與 review，不能直接寫入資料庫。

## 0.16.0+16 — Import Accuracy & Reconstruction

- 圖片與 PDF 共用 Extract → Segment → Classify → Associate → Reconstruct → Validate 管線。
- 包裝規格、免責、法規、付款活動、頁首頁尾與 UI 內容不得獨立建立候選。
- 商品名稱、品牌、ITEM、規格與價格只能取自自己的商品 cell。
- 共享日期只在明確屬於活動有效期間時繼承，不套用任意頁面日期。
- 新增已排除內容檢視與 Direct Import 專用批次選取。
- 新增 Precision、Recall、Field Accuracy、Duplicate Rate、Cross-cell Contamination 與 Review Burden 指標模型。

## 0.15.0+15 — Smart Universal Import

- 圖片與 PDF 皆以空間商品區域產生多候選；一個真實商品以一筆候選為目標。
- 新增商家／品牌分離、型號、規格、ITEM、原價、優惠價、節省與優惠條件語意。
- 新增 `READY / NEEDS REVIEW / REJECTED`、非商品拒絕與保守碎片合併。
- 問題候選置頂、紅字、不預選；所選問題項目可連續逐筆修正。
- 新增 Final Validation Gate，未解決關鍵欄位不得寫入或建立提醒。
- 新增 16 項受控分類，保留舊分類識別碼以維持備份相容。

## 0.13.0+13 — Universal Import Phase 1

- 新增手動輸入、圖片與多頁 PDF 的統一匯入入口。
- 使用 Android 裝置端 ML Kit OCR；來源檔與辨識文字不會上傳。
- 新增規則式優惠解析器，支援西元、民國日期、日期區間與不確定欄位標記。
- 新增圖片確認與 PDF 批次審查流程；任何資料均須確認後才寫入。
- 新增保守型重複警告、PDF 進度／取消、單頁失敗隔離及批次寫入回滾。
- 保留 V0.8～V0.12 備份相容性；不將圖片、PDF 或 OCR 暫存檔加入備份。

## 0.12.0+12 — Beta Validation Sprint

- 將設定中的回饋入口明確命名為 Beta Feedback。
- 回饋 Email 自動附上 App 版本、Build 編號、Android 版本與裝置型號。
- 回饋內容與診斷資訊均不包含優惠資料。
- 新增 Founder 驗收清單、Beta Release Notes、Known Issues、FAQ 與 Google Play Release Checklist。
- 擴充通知排程、提醒取消、V0.8～V0.11 備份相容、還原及過期清理測試。
- 不變更提醒、搜尋、篩選、排序、Dashboard、My Day、收藏、分類、批次操作或備份／還原行為。

## 0.11.0+11 — Beta Readiness Sprint

- 新增診斷資訊匯出與 Email 回饋。
- 新增過期優惠清理與全域提醒預設。
- 改善介面間距、圖示、空白狀態與文字層級。
