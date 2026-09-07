# Clover current state

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

Updated: 2026-09-07. Authority: Founder Simplified MVP Playable Build, EXECUTE MODE.

- Build target: 0.17.0+20; branch: `agent/flutter-prototype-v0`, Draft PR #1.
- Current implementation: local image OCR → critical-field draft → confirmation
  → existing Offer persistence → existing notification scheduling/state query.
- Historical Build 19: 131/131 engineering tests, Actions #99 PASS; Founder FAIL.
- PX 12 → 7 proposals / 0 direct / 4 review + 9 excluded and native PDF
  0 direct / 111 review / 229 excluded remain unresolved negative cases.
- New image flow bypasses full reconstruction; the legacy engine is preserved.
- Local-first; no cloud requests in new image flow; native PDF route preserved.
- Local proxy tests: 4/4 PASS; secret boundary PASS. Flutter/Android run in CI.
- CI validation in progress. No new product acceptance or APK claimed here.
- Device synthetic smoke test exercises real local OCR/persistence/pending
  notification. Real coupon accuracy and notification delivery need Founder test.
- Current approved [spec](../development/SIMPLIFIED_MVP_BUILD20.md),
  [evidence](../development/BUILD20_EVIDENCE.md), and
  [Founder test](../development/BUILD20_FOUNDER_TEST.md).

Next authorized task: finish engineering verification and APK, then Founder test.
Do not resume full reconstruction diagnostics as a prerequisite. No main merge.
Earlier preflight used a stale local checkout; remote context already existed and
has now been preserved below. Do not repeat the earlier missing-context claim.

## Remote context preserved from e1775af (2026-08-23)

Historical KPI/authorization statements below are superseded by the current scope.
The real-user observations remain valid evidence and are not discarded.

# Project Clover — Current State

Last updated: 2026-08-23

## Current Gate
**FOUNDER_TEST — real-world Import validation has failed for the currently tested PX Mart image and Native-text PDF cases. Remediation decision pending.**

Do not describe the current Import POC as accepted or release-ready.

## Current build under Founder evidence review
- Build: 19
- Development branch: `agent/flutter-prototype-v0`
- Main: not merged
- Automated engineering evidence reported before Founder test: 131/131 Flutter tests passed and Android Build 19 CI passed.
- Important: automated tests do not override the real-device failures recorded below.

## Current P0
**Import must become useful with almost no typing while keeping the free/core path Local-first and without mandatory per-use cloud inference cost.**

The product goal is not raw OCR volume and not maximum candidate count. The user experience goal is to import real promotional content with minimal correction and very little or no typing.

Target product KPI:
- No-Typing Import Rate: >= 95% as a product goal.

## Build 19 Founder evidence available so far
### PX Mart promotional image
Observed on Android real device:
- Ground truth discussed for this Golden Dataset: 12 products.
- App reported 7 proposed regions.
- Direct Import: 0.
- Needs Confirmation: 4.
- Excluded: 9.
- Visible failures include promotion/specification fragments becoming product names and apparent real-product text being excluded.

Current judgment: **FAIL evidence**.

### Native-text PDF
Observed on Android real device:
- App confirmed local native-text/layout processing and no PDF upload.
- Direct Import: 0.
- Needs Confirmation: 111.
- Excluded: 229.
- Visible failures include non-product/disclaimer text treated as candidate material, fragmented product identity, and poor ownership between product name/specification/price/item information.

Current judgment: **FAIL evidence**.

### FamilyMart promotional image
Real-device Build 19 result is not yet recorded in this context layer.

## Architecture that remains valuable
Do not discard these without evidence:
- Native-text PDF should remain local-first.
- PDF native text + coordinates/layout should remain preferred over OCR for native-text PDFs.
- Structured representation / Structured Markdown remains the common intermediate-information direction.
- Evidence ownership and cross-product isolation remain required.
- Local image processing remains the preferred free/core runtime direction while feasible.
- One-Tap Recovery remains a valuable UX concept because the product goal is almost-no-typing rather than perfect autonomy.
- Cloud provider abstraction may remain dormant for benchmark/future use, but is not approved as a mandatory free-core dependency.

## Do not start yet
Until Import remediation is decided and validated, do not start unrelated scope such as:
- V0.17 feature expansion
- login/account system
- cloud sync
- gamification
- recommendations
- iOS
- monetization implementation
- broad UI redesign

## Next decision required
After all intended Build 19 Founder evidence is collected, perform a single architecture/remediation review covering both:
1. image region detection/reconstruction failure;
2. native-PDF Product Cell/reconstruction failure.

Do not respond to individual screenshots by repeatedly tuning global thresholds. The next engineering cycle must be evidence-driven and narrowly scoped.
