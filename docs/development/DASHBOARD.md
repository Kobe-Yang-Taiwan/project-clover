# Project Clover Development Dashboard

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

_Current status updated: 2026-09-05; historical snapshot below retained._

## Historical diagnostic status — 2026-09-05, superseded

- Build 19 engineering PASS (historical); Founder Test FAIL (Founder reported).
- REDUCE IMPORT AMBITION: full reconstruction is not an MVP Gate.
- Phase 0 context sync complete; Phase 1 preflight STOP-4: no actual device trace
  or runnable Flutter/Dart located. No diagnostic patch/fixture acceptance yet.
- No recognition fix, Phase 2, Build 20, main merge or new release authorized.
- [Current state](../context/CURRENT_STATE.md),
  [active contract](IMPORT_SCOPE_REDUCTION_SPEC.md),
  [evidence gap and next action](BUILD19_DIAGNOSTIC_REVIEW.md).
- Earlier acceptance-pending labels and launch ETAs below are historical, not
  current readiness, schedule or permission. Store requirements must be reverified
  at an eventual release gate.

## Historical snapshot — 2026-08-18

## Executive Status

- Current version: V0.16R / 0.16.1 — Import Architecture Remediation
- Current state: FOUNDER_TEST
- Development branch: `agent/flutter-prototype-v0`
- Draft PR: #1 (Open, Draft, not merged)
- V0.16R Local Image POC head: `306f835633884ffe73f2bdaea9bb76df1e68e655`
- V0.16 Founder Acceptance: FAILED — real images had severe false negatives and
  Costco fields remained polluted/mixed.
- V0.16R privacy architecture: Hybrid Local-first approved 2026-08-16.
- Founder Test provider: paid Google Gemini Developer API `gemini-3.6-flash`
  through the Clover proxy; provider-enabled Build 18 blocked on secure proxy
  deployment/configuration.
- Build 18 standard CI: run #93 PASS; cloud-disabled artifact `9260715239`.
- Build 19 Local Image POC CI: run #99 PASS; 131/131 Flutter tests; Android
  artifact `9336905618`.
- V0.16R CI/build: run #91 PASS; Android Build 17 artifact `9260093101`.
- Founder Acceptance: pending V0.16R Costco/PX Mart/FamilyMart rerun.

## Product Progress

### Core coupon management — DONE
- Create / view / edit / delete
- Local persistence
- Mark used / restore
- Expiration status
- Search / filter / sort
- Favorites / categories
- Batch operations
- Dashboard / My Day
- Reminder scheduling and notification deep-link
- JSON backup / restore and backward compatibility
- Diagnostics / feedback / cleanup / global reminder defaults

### Universal Import — REMEDIATION ACTIVE
- Image import
- Multi-product import architecture
- PDF catalogue import
- Native PDF text/layout first
- Explicit-consent multimodal vision for images/scanned pages
- Conservative local OCR fallback
- Product reconstruction
- Merchant / brand / product field separation
- READY / NEEDS REVIEW / REJECTED states
- Final Validation Gate
- V0.16R focus: balanced real-world recall/precision with evidence ownership

### Beta / Release Readiness — PARTIAL
- Founder real-device validation: ongoing
- External Beta: not yet started at scale
- AI persona validation (MatrAIx): intentionally deferred until core flow is stable
- Privacy policy: pending release phase
- Data Safety declaration: pending Play Console setup
- Signed AAB / Play App Signing: pending
- Store listing assets: pending
- Google Play closed test: pending
- Production submission: pending

## Development Gates

| Gate | Meaning | Status |
|---|---|---|
| G0 | Approved scope/spec | PASS |
| G1 | Repo/worktree inspection | PASS |
| G2 | Implementation | PASS — local product-region POC and tap recovery |
| G3 | QA | PASS — CI analyze, 131 Flutter + 4 local proxy tests |
| G4 | Commit / integration | PASS — remote fast-forward, force=false |
| G5 | Release authorization | PASS |
| G6 | GitHub CI + Android APK | Build 19 run #99 PASS; artifact 9336905618 |
| G7 | Founder Android Acceptance | PENDING HASH-MATCHED REAL-ASSET RUN |
| G8 | Accepted / Release-ready | NOT STARTED |

## Current Acceptance Work

V0.16 run #89 passed engineering checks but failed Founder Acceptance. The
remediation replaces raster-OCR PDF extraction and universal text-fragment grouping
with source routing, native PDF layout and consented product-region vision. Green
synthetic tests must not be represented as real-world performance.

## Google Play Launch Roadmap

### Milestone A — V0.16 Founder Acceptance
Target: verify image/PDF import correctness and review burden on real Android device.

### Milestone B — Beta Candidate
Target: 3–10 real coupon users complete end-to-end use for 7–14 days, with no data-loss or reminder-critical issue.

### Milestone C — Google Play Release Readiness
Required work:
- final privacy policy
- Data Safety form
- final app name/icon/screenshots/store description
- target SDK verification
- signed Android App Bundle (AAB)
- Play App Signing / package identity
- permissions and notification behavior review
- release notes / support contact

### Milestone D — Closed Test / Production Access
For a newly created personal Google Play developer account subject to Google's current testing requirement: at least 12 testers opted in continuously for 14 days before applying for production access.

### Milestone E — Production Release
Submit production release after testing, policy checks and production access approval.

## Founder-Level ETA

Best case (if V0.16 stabilizes quickly and the Play account is NOT subject to the 14-day closed-test requirement): approximately 2–4 weeks to a production-ready Google Play submission.

More realistic case for a new personal developer account subject to the mandatory closed test: approximately 4–7 weeks, including the required 14-day closed-testing period, release preparation, fixes and Google review/production-access timing.

This is not a guaranteed calendar date. The largest schedule risks are:
- Universal Import still failing Founder acceptance
- reminder/data reliability issues discovered in Beta
- Google Play account/testing requirements
- policy/store-listing rework
- target SDK/API changes near submission

## Release Principle

Do not optimize for version number. Production readiness requires:

`Stable core flow → Engineering QA → Founder Acceptance → Beta evidence → Play compliance → Closed test (if required) → Production`
