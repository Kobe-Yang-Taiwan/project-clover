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
