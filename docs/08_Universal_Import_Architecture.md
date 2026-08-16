# Universal Import Architecture — V0.16R

## Source-adaptive router

```text
Source Router
├ Native-text PDF → local PDF text/fragments/bounds → layout cells
├ Image-only PDF  → render only required pages → consented vision
├ Promo image     → consented product-region vision
└ Local fallback  → OCR evidence → conservative legacy reconstruction

All routes → Canonical Product + field evidence → deterministic validation
           → DIRECT_IMPORT / NEEDS_CONFIRMATION / EXCLUDED → review → import
```

Native text reliability requires a meaningful text/fragment count and usable
identity-character ratio. Reliable pages are never sent to cloud vision. Mixed
PDFs may use native extraction for some pages and vision for only the remaining
pages.

## Canonical evidence model

Every multimodal field contains value, page, product-region ID, raw visible
evidence, confidence and optional normalized bounds. Product-specific evidence
must equal and remain inside the reconstructed product region. Merchant, validity
period and campaign condition may use an explicitly labelled page/shared/banner
region on the same source page. Any other mismatch rejects the object and records
cross-product contamination.

Cloud output cannot write `Offer` records. It is parsed through a strict schema,
then processed by the same price/date/product validation and review workflow.

## Retailer adapters

- Costco: merchant, repeated catalogue grid and ITEM／賣場售價／現省 semantics.
- PX Mart: merchant, repeated product cards, bundle/average-unit-price semantics,
  and shared payment campaign banners.
- FamilyMart: merchant, repeated grid/card hints and shared campaign/UI rejection.
- Generic: no assumed merchant or fixed grid.

Adapters supply hints; they do not contain product identities.

## Consent, provider and cost boundary

The cloud provider is abstracted behind a canonical HTTPS contract. Production is
disabled unless endpoint, provider identity and privacy disclosure are configured.
Every import asks consent before sending the selected image or necessary scanned
pages. Refusal causes no upload and retains manual/local fallback.

Limits: 8 MB per cloud asset, one request per image/page/operation, duplicate-key
blocking, no automatic retry, usage/cost reporting, no provider key in the APK.

## Structured representation

Native PDF fragments retain page and normalized bounds. Layout analysis emits a
representation with `# Page`, `## Product Cell`, typed fields and shared metadata.
Product-specific fields remain in their cell; applicable merchant/date information
is the only shared inheritance path.

## V0.16 architecture history

## V0.16 common document-understanding pipeline

`Source Adapter → Extraction → Spatial/Layout Analysis → Semantic Block Classification → Product Reconstruction → Field Extraction → Validation → Confidence → Candidate Review → Import`

- Extraction preserves bounding boxes, normalized coordinates, page number and reading order.
- Layout analysis creates mutually exclusive product cells from reliable ITEM or promotional-price anchors.
- Every OCR line is classified before it can influence a coupon field.
- Product-specific fields can only come from the candidate's own `sourceRegionId`.
- Merchant and explicit catalog validity periods may be shared metadata; arbitrary dates and product-specific fields may not be inherited.
- Disclaimer, legal, header, footer, payment campaign and page decoration blocks never independently create visible candidates.
- Final Validation Gate remains the only path to persistence and reminder scheduling.

The invariant is: one real promotional product becomes one candidate; zero real promotional products becomes zero visible candidates.

## V0.15 pipeline history

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

## V0.15 Local-first and cleanup history

V0.15/V0.16 were fully local. V0.16R remains Local-first but permits the
Founder-approved, explicit-consent vision path documented above. PDF page temporary
images are deleted after success, cancellation or failure. Coupon data, reminders,
database and history are never part of a vision request.
