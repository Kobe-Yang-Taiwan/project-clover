# Project Clover Development Dashboard

_Last updated: 2026-08-16_

## Executive Status

- Current version: V0.16R / 0.16.1 — Import Architecture Remediation
- Current state: FOUNDER_TEST
- Development branch: `agent/flutter-prototype-v0`
- Draft PR: #1 (Open, Draft, not merged)
- V0.16R CI evidence head: `7d5f296e93f212b7a6ebd1e3beff97d4bec8a5bc`
- V0.16 Founder Acceptance: FAILED — real images had severe false negatives and
  Costco fields remained polluted/mixed.
- V0.16R privacy architecture: Hybrid Local-first approved 2026-08-16.
- Founder Test provider: paid Google Gemini Developer API `gemini-3.6-flash`
  through the Clover proxy; provider-enabled Build 18 blocked on secure proxy
  deployment/configuration.
- Build 18 standard CI: run #93 PASS; cloud-disabled artifact `9260715239`.
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
| G2 | Implementation | PASS — Gemini Founder integration |
| G3 | Local QA | PASS — analyze, 123 Flutter + 4 proxy tests |
| G4 | Commit / integration | PASS — remote fast-forward, force=false |
| G5 | Release authorization | PASS |
| G6 | GitHub CI + Android APK | Standard Build 18 PASS; Founder APK BLOCKED ON PROXY CONFIG |
| G7 | Founder Android Acceptance | BLOCKED UNTIL PROVIDER APK EXISTS |
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
