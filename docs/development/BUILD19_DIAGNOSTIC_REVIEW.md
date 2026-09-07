# Build 19 diagnostic preflight — 2026-09-05

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

CURRENT GATE: BUILD 19 DIAGNOSTIC REVIEW — STOP-4.
This is a partial preflight evidence pack, NOT completed Phase 1.

Baseline: `133ef0ec1eb7979bcad4e215554439d070135623`, clean before this work.
Phase 0 synchronized. Phase 1 source/fixture availability inspected; no production
instrumentation or failing replay committed. Existing 131/131 result is historical.

## PX Mart

GT 12; reported 7 regions/0 direct/13 classification records. Exact original hash
verified (see context evidence). Current `local_image_region_proposal.dart`
`propose` consumes `page.positionedLines`, so an image or screenshot transcript
alone cannot reproduce anchor proximity, deduplication and row decisions.
Existing `test/local_image_region_proposal_test.dart` PX 12-region case constructs
its coordinates by hand; its 7-region case is not the Founder PX failure.
No actual per-line device OCR/region export located in supplied workspace material.
First observed count divergence: Region Formation. Rule-level cause UNKNOWN.
No exact line IDs/bounds, stage counts or 7-to-13 mapping asserted.

## Native PDF

GT Page 2 =16 per Founder instruction; approximately 14 ITEM-based regions is a
prior finding, NOT a measured run here. Original PDF hash verified.
Source inspection confirms page-local `_looksLikeCostcoPage` routing in
`DocumentUnderstandingPipeline.understand`; `_selectAnchors` returns ITEM anchors
when any exist. `analyzePdf` result construction omits `merchantHint`, whose
default in `coupon_import_models.dart` is empty; parser uses `source.merchantHint`.
High confidence in these code paths; actual per-cell output and SEALY/MICHELIN
ownership require a native-extraction replay before claiming Phase 1 acceptance.
Independent routing/context defects do not establish the cause of every record.

## Excluded

229 is Founder-reported total. Header/Footer/Disclaimer/Legal/Campaign/Decoration/
Duplicate/Other counts are ALL UNKNOWN: no exact record export available.
Parser code includes shared-block exclusion paths, supporting an artifact-burden
mechanism, not a verified 229-record breakdown. Users should not clean fragments.

## Engineering / validation

- Runtime discovery: no flutter/dart in PATH or found under searched workspace,
  /opt, /tmp, /usr/local. No fresh test/analyze/build executed.
- Assets: both original SHA-256 values rechecked; no raw source copied to git.
- Scope: docs/context files plus active spec, dashboard and this evidence report.
- Recognition, storage, reminders, consent and build/version configuration unchanged.
- No APK, cloud request, remote push, CI trigger, main merge or Phase 2.
- Tests added: none. Failing fixtures: not yet reproducible. Independent review pending.
- Blast radius: documentation only; main risk is confusing supplied/prior findings
  with fresh runtime evidence, hence explicit provenance and unknowns above.

## Recommendation D — Evidence Still Insufficient

Need a Flutter/Android-capable execution environment and a private diagnostic
capture/replay of the hash-matched originals. Minimum capture: device/app/OCR version,
full/crop OCR IDs/text/bounds, proposals/anchors and reasons, ownership and complete
candidate/excluded records. PDF capture must retain native extractor provenance.
Existing raw images cannot substitute for actual Android OCR output.

Founder decision required: approve, if necessary, a diagnostic-only APK with an
explicit version/build exception and local-only export workflow (not a product fix
or Phase 2), or supply an existing private trace and runnable environment. Do not
ask Founder to manually manufacture line coordinates. No instrumentation is claimed
complete; implementation/validation remains under the same Phase 1 scope.
