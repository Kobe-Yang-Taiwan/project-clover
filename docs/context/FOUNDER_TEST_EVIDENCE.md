# Project Clover — Founder Test Evidence

Last updated: 2026-08-23

Purpose: record real-device evidence separately from automated engineering QA. This is the product acceptance ledger.

## Evidence rules
- Record observed facts first; hypotheses belong in analysis/negative cases.
- Do not replace real-device evidence with synthetic fixtures.
- Do not mark a failed case resolved until a later real-device test demonstrates resolution.
- Preserve source screenshots/fixture hashes where available outside this Markdown file.

## Build 19 — PX Mart promotional image
**Date observed:** 2026-08-22
**Platform:** Android real device
**Founder judgment:** FAIL evidence

### Ground truth
- Project Golden Dataset target: 12 products.

### App output visible in Founder screenshots
- Proposed regions: 7
- Direct Import: 0
- Needs Confirmation: 4
- Excluded: 9

### Visible failure examples
- promotion/campaign text appears as product identity;
- specification-only strings appear as candidate names;
- malformed OCR fragments appear as candidate names;
- apparent true-product text appears among excluded content;
- review burden remains high relative to the intended user experience.

### Product-level result
The test does not meet the previously discussed POC target of >=11/12 automatic correct detection for PX Mart and does not demonstrate the target almost-no-typing experience.

### Status
**OPEN — requires remediation and retest.**

---

## Build 19 — Native-text PDF import
**Date observed:** 2026-08-22
**Platform:** Android real device
**Founder judgment:** FAIL evidence

### App path visible in Founder screenshots
The UI states that Native-text PDF used local text/layout analysis and that the PDF was not uploaded.

### App output
- Direct Import: 0
- Needs Confirmation: 111
- Excluded: 229

### Visible failure examples
Candidate/review content includes apparent non-product or incomplete product fragments such as:
- `商品實際品號以賣場陳列或官網為準。`
- `此優惠期間還有更多優惠品項，續下頁`
- `MIVUE ITEM`
- `SOUNDBAR COMBO`
- `WATER OVEN`
- `ORGANIC ITEM`

Other screenshots show product/model/price-like evidence existing on the same pages but not reliably reconstructed into a complete product object.

### Product-level result
The native-text/local path is active, but the Product Reconstruction result is not acceptable. A user would face 111 items requiring confirmation plus 229 excluded fragments, with zero direct imports.

### Status
**OPEN — requires remediation and retest.**

---

## Build 19 — FamilyMart promotional image
**Status:** PENDING

No final real-device Build 19 FamilyMart result has been entered in this ledger yet.

When tested, record at minimum:
- ground truth count (current project reference: 8 visible products);
- proposed regions;
- correct products;
- false candidates;
- direct import / needs confirmation / excluded counts;
- One-Tap Recovery result;
- manual typing required;
- processing time;
- Founder judgment.

---

## Acceptance interpretation
Current Build 19 Import status must not be represented as PASS while the active PX Mart and Native-text PDF failure evidence above remains unresolved.

Engineering QA previously reported for Build 19:
- 131/131 Flutter tests passed;
- Android CI/Build 19 passed.

Those results remain useful engineering evidence, but they do not constitute Founder Acceptance.
