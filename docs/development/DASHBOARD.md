# Project Clover Development Dashboard

_Last updated: 2026-08-12_

## Executive Status

- Current version: V0.16 — Import Accuracy & Reconstruction
- Current state: CI_BUILD (blocked by CI analyze failure)
- Development branch: `agent/flutter-prototype-v0`
- Draft PR: #1 (Open, Draft, not merged)
- Current remote head: `528b0f178fefda6689504e1ccd196296b5f39ee6`
- V0.16 implementation: integrated into remote branch
- CI: failed at Flutter Analyze
- CI blocker: `Undefined name 'OfferCategory'` in `test/v016_reconstruction_test.dart:226`
- Tests/build in failed CI run: skipped after analyze failure
- Founder Acceptance: pending Build 16 Android APK

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

### Universal Import — ACTIVE
- Image import
- Multi-product import architecture
- PDF catalogue import
- Local OCR
- Product reconstruction
- Merchant / brand / product field separation
- READY / NEEDS REVIEW / REJECTED states
- Final Validation Gate
- V0.16 focus: prevent non-product candidates, prevent cross-cell contamination, reduce review burden

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
| G2 | Implementation | PASS |
| G3 | Local QA | PASS (Codex reported 102/102 locally before integration) |
| G4 | Commit / integration | PASS |
| G5 | Release authorization | PASS |
| G6 | GitHub CI + Android APK | BLOCKED — Analyze failure |
| G7 | Founder Android Acceptance | WAITING |
| G8 | Accepted / Release-ready | NOT STARTED |

## Current P0 Blocker

GitHub Actions run #87 fails at `flutter analyze` because test code references an undefined `OfferCategory` symbol in `test/v016_reconstruction_test.dart:226`.

Required next action:
1. Fix the test/import/reference.
2. Re-run Flutter Analyze.
3. Run all V0.16 tests.
4. Build Build 16 Android APK.
5. Founder re-tests the same supermarket screenshot and Costco PDF.

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
