# Parser Limits and Known Issues

## V0.16R known limitations

- Paid Gemini `gemini-3.6-flash` is approved, but the standard APK remains cloud-
  disabled. A provider-enabled Founder APK requires a deployed Clover HTTPS proxy,
  paid-project Gemini secret and protected short-lived proxy token.
- Paid Gemini is not ZDR. Google states paid prompts/images/responses are not used
  to improve its products, while limited abuse-monitoring retention still applies.
- The FamilyMart original selected image is not present; only Founder failure
  evidence/thumbnail remains. Product-count regression is labelled, but full
  identity/field accuracy cannot be scored until the original is supplied again.
- Native PDF product-cell reconstruction is deterministic and layout-aware, but
  unusual overlapping/vector text, encrypted PDFs or missing fonts may require the
  scanned-page path.
- Multi-variant cards (several sizes/models/prices in one visual cell) remain one
  product object and may require confirmation rather than being split or guessed.
- No production accuracy number is claimed before Founder Android Golden Dataset
  reruns. Automated schema/fixture tests are engineering evidence only.
- The public repository stores Golden Dataset manifests/hashes, not copyrighted
  retailer binary assets.
- This Linux runner cannot execute the real native-PDF path under `flutter test`
  because PDFium is not bundled into that test process, and it has no Android SDK.
  CI APK build and Founder Android execution are therefore the authoritative native
  PDF runtime evidence.

## V0.16 known limitations

- Device OCR still determines which characters are available; severely blurred or missing text cannot be recovered.
- Product cards without ITEM, explicit promotional price or visual separation may remain `NEEDS_CONFIRMATION` or `EXCLUDED` rather than being guessed.
- Irregular free-form layouts require Founder-labelled fixtures before safe direct-import coverage expands.
- Real Founder Costco PDF and supermarket screenshot metrics remain pending Android rerun; no production accuracy value is invented.
- The app intentionally prefers fewer correct candidates over a large uncertain list.

## V0.15 historical limitations

1. 通用 OCR 自動辨識不宣稱 100%。V0.15 的 100% 指寫入資料均通過系統驗證或使用者明確確認。
2. 嚴重模糊、反光、手寫、藝術字、文字與圖片大幅重疊仍可能造成 `NEEDS REVIEW` 或漏候選。
3. ITEM 與價格皆缺少、商品卡片沒有穩定空間間隔的版面，區域切割能力有限。
4. 商家只在文件有可靠品牌脈絡時自動下傳；未知來源維持空白並要求確認。
5. 組合價、平均價、單價與滿額門檻不會被當成原價，可能需要使用者確認優惠價。
6. 保守型碎片合併優先使用 ITEM 或品牌＋型號；文字不同且無識別碼的同商品可能仍分成兩筆。
7. PDF 上限 30 MB／30 頁，渲染寬度 3000 px；加密、損壞或 Android renderer 不支援的 PDF 會被拒絕。
8. 取消是頁面邊界的合作式取消；正在執行的原生 OCR 會先完成當頁。
9. Founder 真實截圖與 Costco PDF 的 Recall、Precision、One-to-One Rate、欄位正確率與時間改善，必須用同一份標註樣本實機量測，目前不得填入推估值。

目前不包含雲端 OCR、外部 AI/LLM、登入、同步、iOS、Wallet、分享、相機、QR、Barcode 或遊戲化。
