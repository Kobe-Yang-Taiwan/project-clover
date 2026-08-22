# Project Clover — Import Negative Cases

Last updated: 2026-08-23

Purpose: preserve real failures so future agents do not repeat them. Negative cases are permanent learning assets. Mark a case resolved only after a later real-device regression proves it.

## NC-001 — V0.15 false-positive explosion
**Status:** Historical, unresolved as a regression risk

Observed pattern:
- OCR/text fragments became product candidates.
- descriptions, legal/disclaimer text, prices, campaign copy, and UI/status text were promoted into products.
- neighboring products could merge; one product could split into multiple candidates.
- unsafe inference of price/original price occurred.

Do not solve future recall problems by globally lowering thresholds if that recreates this pattern.

## NC-002 — V0.16 false-negative collapse
**Status:** Historical, unresolved as a regression risk

Observed pattern:
- filtering became too strict.
- true products disappeared.
- FamilyMart example: approximately 8 visible products but only 1 usable candidate emerged.

Learning:
- precision-only optimization can destroy recall.
- Product Recall and Candidate Precision must be measured together.

## NC-003 — Build 19 PX Mart image region recall failure
**Status:** Active

Ground truth used by the project: 12 products.

Founder Android evidence:
- app reported 7 proposed regions.
- Direct Import: 0.
- Needs Confirmation: 4.
- Excluded: 9.

Failure modes visible in screenshots:
- promotion headline treated as product identity.
- specification fragments treated as product names, including examples such as `340gx3入/組`.
- malformed OCR/specification text treated as products.
- apparent true-product text such as the Green Giant corn content was visible in excluded material.

Current inference:
- Region Proposal recall is insufficient.
- Product Reconstruction / semantic role assignment is also failing.
- The counts suggest internal fragmentation may still exist between proposed regions and classified text objects; verify implementation rather than assuming one region equals one final object.

Do not solve by:
- globally lowering confidence;
- accepting every OCR block as a candidate;
- declaring success because cloud requests equal zero.

Required regression:
- representative PX Mart real image;
- correct region count/recall;
- product names must be product identities rather than specs/campaign copy;
- false candidates and cross-product contamination must remain low;
- meaningful direct-import/review burden improvement.

## NC-004 — Build 19 Native-text PDF reconstruction overload
**Status:** Active

Founder Android evidence:
- app reported local native-text/layout processing and no PDF upload.
- Direct Import: 0.
- Needs Confirmation: 111.
- Excluded: 229.

Visible candidate failures include text such as:
- `商品實際品號以賣場陳列或官網為準。`
- `此優惠期間還有更多優惠品項，續下頁`
- `MIVUE ITEM`
- generic/category-like fragments such as `SOUNDBAR COMBO`, `WATER OVEN`, `ORGANIC ITEM` appearing as product identity.

Visible ownership/reconstruction failures:
- product identity, ITEM/model/specification, and price values appear fragmented rather than reconstructed into one Product Cell.
- disclaimer/legal/shared text remains a major part of the classification workload.
- real product evidence may exist in the text layer but not be assembled into a complete product object.

Learning:
- successful native text extraction does not equal successful Product Reconstruction.
- Structured Markdown/representation must represent product ownership, not a formatted list of text fragments.

Do not solve by:
- reverting native-text PDFs to OCR-first;
- sending all native PDFs to cloud vision;
- treating every line on a product-heavy page as a candidate.

Required regression:
- product-cell grouping must improve;
- shared/legal/disclaimer content must be removed before product-object creation;
- product name/model/spec/price ownership must stay within the correct cell;
- review burden must fall dramatically from the Build 19 evidence.

## NC-005 — Direct Import = 0 despite large candidate volume
**Status:** Active

Seen in both current image/PDF Founder evidence.

This is a product-level failure even if extraction produces many objects. A user should not be asked to clean hundreds of uncertain fragments.

Learning:
- candidate quantity is not value.
- optimize for correct final import and low review burden.

## NC-006 — Automated QA can mask product failure
**Status:** Active process risk

Build 19 reported 131/131 Flutter tests and successful Android CI, yet real-world Import evidence failed.

Rule:
- automated QA proves engineering integrity;
- Golden Dataset / Founder real-device QA proves product behavior;
- neither substitutes for the other.
