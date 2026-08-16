# Product Discovery — V0.16R Import Remediation

## Evidence

- V0.15 treated OCR fragments as opportunities and produced many false products.
- V0.16 filtered harder but missed most products in real multi-product images.
- FamilyMart evidence contains 8 visible product cards; V0.16 returned 1.
- Costco has a usable native PDF text layer, but V0.16 discarded it by rasterizing
  every page before OCR.
- Existing tests used authored OCR strings, so green tests did not prove real image
  segmentation or PDF field ownership.

## Product decision

The import engine must answer “how many independent product regions exist?” before
extracting coupon fields. Source type changes the extraction method; validation and
review remain common.

The key outcome is less correction per useful promotion, not more candidates.
Unknown is better than plausible-looking wrong data.

## Privacy decision

Founder approved Hybrid Local-first on 2026-08-16. Cloud vision is opt-in for the
current selected image or required scanned pages only. Native PDFs stay local.
