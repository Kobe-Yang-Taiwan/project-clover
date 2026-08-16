# Development Progress — V0.16R / 0.16.1

State: BLOCKED — provider-enabled Founder APK configuration required

## Root causes verified

- PDF service rasterized every page and never inspected the native text layer.
- ITEM/promo-price anchors controlled segmentation; missing anchors collapsed a
  multi-product image into one page region.
- Candidate fields lacked field-level evidence ownership.
- Cross-cell contamination metric was hard-coded to zero.
- “Golden” tests were authored OCR text/coordinates, not real assets.

## Implemented architecture work

- [x] Source router and mixed-PDF page planning.
- [x] Native PDF structured text and bounding boxes via PDFium.
- [x] Render only pages without reliable native text.
- [x] Provider-neutral HTTPS cloud vision interface, disabled by default.
- [x] Explicit per-import consent and local fallback notice.
- [x] Request size, duplicate/no-retry and usage/cost controls.
- [x] Canonical products with per-field evidence and region ownership.
- [x] Deterministic cross-region rejection and contamination counting.
- [x] Costco/PX Mart/FamilyMart/generic retailer adapters.
- [x] Native Costco price-stack semantics.
- [x] Decimal price support while retaining unit/average-price semantics.
- [x] Real-world Golden Dataset manifests and checksums.
- [x] Native and cloud-derived candidate fields retain field-level provenance.
- [x] Costco native layout uses four independent column grids so unequal row
  counts cannot move fields into an adjacent column.
- [x] Founder-approved `GeminiCloudVisionProvider` remains behind the neutral
  `CloudVisionProvider` interface and requires exact paid provider/model metadata.
- [x] Minimal stateless proxy keeps the Gemini key server-side and enforces auth,
  payload, rate, duplicate, schema and cost controls.
- [x] Dedicated Founder APK workflow requires an HTTPS proxy and protected
  short-lived proxy token before enabling cloud processing.
- [x] Input/output/total token usage and token-derived cost flow into the import
  quality report and Golden Dataset measurement schema.

## QA evidence — 2026-08-16

- `dart format --output=none --set-exit-if-changed lib test`: pass.
- `flutter analyze`: pass, no issues.
- `flutter test`: pass, 120 tests.
- Android configuration script executed twice: one INTERNET permission, one boot
  permission and one notification receiver remained (idempotence pass).
- Local `flutter build apk --debug`: not executed to completion because this runner
  has no Android SDK (`[!] No Android SDK found`). GitHub Actions is the configured
  Android build environment and remains required at G6.
- A local Flutter-test attempt against the real Costco PDF could not load Linux
  PDFium because Flutter test did not bundle the native asset. No real-world metric
  is inferred from that failed probe; Android Golden Dataset execution remains G7.
- GitHub Actions run #91 (second attempt): PASS. Format, analyze, 120 tests,
  Android Build 17 debug APK and artifact upload all succeeded. The first attempt
  failed only because Maven Central returned HTTP 429 while Gradle downloaded
  dependencies; no code change was used to conceal that external failure.
- APK artifact ID: `9260093101`; archive size: `111,633,047 bytes`; SHA-256:
  `b1777009e7666389406c64ec01ee2e35aaa7039ad82803f50dc77f96e46f4073`;
  expires `2026-08-30T07:28:01Z`.

## Gate

G0–G6 PASS. State is FOUNDER_TEST. Founder Android Golden Dataset acceptance
remains G7; no real-world metric is marked pass yet.

Build 18 local QA/CI evidence is recorded only after the corresponding commands and
workflow execute; previous Build 17 evidence remains historical and is not relabelled.

## Build 18 local QA — 2026-08-16

- Format check: PASS, 28 files, 0 changed.
- `flutter analyze`: PASS, no issues.
- Full `flutter test`: PASS, 123 tests.
- Proxy privacy/schema tests: PASS, 4 tests.
- Provider secret-boundary scan: PASS.
- Android notification/network configuration idempotence: PASS.
- Local APK build: blocked by the runner's missing Android SDK (`[!] No Android
  SDK found`); GitHub Actions remains the authoritative Android build environment.
- GitHub Actions run #93: PASS. Proxy tests, secret scan, format, analyze, 123
  Flutter tests, Android Build 18 debug APK and artifact upload all succeeded.
- Standard cloud-disabled APK artifact: `9260715239`, SHA-256
  `1e8f51f31fc578c9f933dbd7f4a3951c90bcd21af783d09af6864d5e3842e7f2`.
- Provider-enabled Founder APK remains blocked until the paid Gemini project key is
  installed only on a deployed Clover proxy and its HTTPS endpoint/short-lived
  proxy token are supplied to the protected Founder workflow.
