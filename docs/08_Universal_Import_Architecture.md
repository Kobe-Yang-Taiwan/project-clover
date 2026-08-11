# Universal Import Architecture — V0.15

## Pipeline

Input → Pre-processing → Local OCR + spatial metadata → Layout segmentation → Product-region detection → Text grouping → Semantic extraction → Non-product rejection → Duplicate/fragment merging → Candidate validation → Fast review → Final import → Reminder / My Day / Dashboard

## Spatial data

`OcrPageResult` 保存 OCR 行文字及正規化 bounding box。解析器優先以 ITEM 錨點切割型錄；沒有 ITEM 時，使用商品價格錨點推導列、欄與區域。狀態列、導覽與共用活動日期在分組前分別過濾或安全下傳，不會過早壓成純文字。

## Semantic model

候選暫存商家、品牌、標題、型號、規格、ITEM、起訖日、原價、優惠價、節省、優惠條件、分類、來源頁、信心與待確認原因。這些欄位只存在預覽階段；最終仍轉為既有 `Offer` 格式，因此舊資料庫與備份不需破壞性 migration。

## Candidate validation

- `READY`：必要欄位完整且無重大歧義，可預選。
- `NEEDS REVIEW`：有效商品可能性高，但欄位缺漏、日期／價格衝突、分組信心低或疑似重複；不預選。
- `REJECTED`：缺乏商品證據或只含價格、免責、標題、頁碼、導覽等內容；不顯示。

## Final Validation Gate

問題候選可由使用者主動選取。匯入時依序開啟所選問題項目，只修正未解欄位。所有選取候選均需具備名稱、商家與確認後的到期日，且不得保留關鍵 attention reason。通過後才呼叫單次批次寫入；成功後才申請／同步提醒。

## Local-first and cleanup

圖片、PDF、OCR 原文與產品資料不離開裝置。PDF 頁面暫存圖在完成、取消或失敗後清除。診斷報告只能包含區域數、狀態數、缺漏數與時間，不得包含標題、備註、OCR 原文或來源內容。
