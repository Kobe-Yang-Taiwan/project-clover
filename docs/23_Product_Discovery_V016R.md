# Product Discovery — V0.16R Import Remediation

> CURRENT AUTHORITY — 2026-09-07: Founder authorized EXECUTE MODE for
> **0.17.0+20 Simplified Playable MVP**. **REDUCE IMPORT AMBITION**.
> Problem: benefits are forgotten, expire, and lose value. Outcome:
> **Benefit Captured / Money Saved**. Current MVP: image Capture → Name /
> Expiration / Value Draft → Confirm → local Save → Reminder.
> Full Product Reconstruction and diagnostic root-cause completion are not
> blocking requirements. Older no-Build-20 / diagnostic-first gates below are
> historical and superseded. Existing negative cases remain unresolved.
> Status: IMPLEMENTING; new QA/APK pending; Founder Test PENDING.
> Next authorized task: finish targeted implementation, tests and Android build.
> Current specification: docs/development/SIMPLIFIED_MVP_BUILD20.md.
> Results: docs/development/BUILD20_EVIDENCE.md. No main merge authorized.

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

## Local POC decision — 2026-08-18

Cloud vision must not be a required free/core dependency. Standard promotional
images use local multi-signal region proposal and independent region OCR. A missed
product is recovered by tapping it once, replacing multi-field manual entry.

Primary KPI: No-Typing Import Rate >= 95%. Real-device POC thresholds are 7/8
automatic FamilyMart regions and 11/12 PX Mart regions, with zero normal-path
cloud requests and approximately zero recurring Founder inference cost.

## Historical privacy/provider decision

Founder approved Hybrid Local-first on 2026-08-16. Cloud vision is opt-in for the
current selected image or required scanned pages only. Native PDFs stay local.

Founder selected paid Google Gemini Developer API `gemini-3.6-flash` for the first
real-device benchmark. The decision tests whether product-region vision materially
improves FamilyMart/PX Mart recall without recreating V0.15 false positives. This
infrastructure is now preserved only for optional research/future paid use and is
not invoked by the core image flow.
