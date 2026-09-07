# Product Bible — V0.16

## Promise

Project Clover saves coupon-management work. It must not move OCR cleanup work to the user.

## Non-negotiable rules

1. One product equals one candidate.
2. Non-products never become visible candidates.
3. Product-specific fields never cross cell boundaries.
4. Unknown is better than wrong.
5. Only final validated information is persisted.

## Review behavior

- `DIRECT_IMPORT`: reliable and selected by default.
- `NEEDS_CONFIRMATION`: likely product; only uncertain fields require correction and it is not preselected.
- `EXCLUDED`: hidden from the primary list, never selected, but inspectable.

## Privacy

OCR, source images, PDFs and reconstructed data remain on device. V0.16 adds no cloud OCR, LLM, analytics or content upload.
