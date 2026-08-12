# Parser Limits and Known Issues

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
