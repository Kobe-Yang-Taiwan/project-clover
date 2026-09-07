# Build 20 — Simplified playable MVP

Authority: Founder EXECUTE MODE instruction, 2026-09-07. This supersedes the
diagnostic-first / no-Build-20 authorization in older documents. Diagnostic WIP
is preserved in Git history, not included in this playable build.

Problem: owned benefits are forgotten, expire, and lose value.
Product outcome: **Benefit Captured / Money Saved**.
Decision: **REDUCE IMPORT AMBITION**. Full Product Reconstruction is not an MVP
requirement. No automatic multi-product reconstruction gate before Save.

## Authorized delta

- Existing image picker and local Chinese ML Kit OCR → one critical draft.
- Only name, expiration and value/discount. Evidence-backed alternatives,
  High/Medium/Low per field; missing evidence stays unknown.
- Save confirms displayed fields. Existing text controls and date picker recover
  unknown fields; no mandatory merchant, SKU, legal metadata or product object.
- Existing Offer mapping: name → name, expiration → expiresAt, discount → note.
  Existing optional fields/storage/backup schema remain compatible.
- Existing atomic addOffer and notification scheduler; zero-day reminder preset
  enables same-day expiry. Persist the chosen time so reopening cannot move it.
- Query Android pendingNotificationRequests after scheduling. Permission or
  scheduling failure never rolls back an already persisted benefit or claims a
  verified reminder. Retry does not save a duplicate.
- Bounded local capture records (latest 50), no analytics service. Capture time
  starts when the selected image enters the draft screen, ends at persisted save.
  Picker/system permission time excluded and separately observed by Founder.
  Actions count Save, candidate selection, each edited text field, date picker
  opening/selection/confirmation (minimum 3). Calendar navigation and permission
  taps need observer counts; do not present this counter as exact physical taps.
  Initial/final fields recorded; ground-truth accuracy remains null until human
  review. Retry after save is outside capture-to-save metrics.

## Deferred / preserved

Dense PDF selection is deferred. Legacy PDF route is explicitly labeled; for this
MVP screenshot the desired coupon. Legacy engine, native PDF coordinates,
evidence ownership, provider abstraction and consent rules remain. New image
flow calls only recognizeImage (local OCR); no cloud calls or new provider.
No iOS/login/sync/dashboard/reconstruction optimization/architecture rewrite.

PX Mart: GT 12, proposals 7, ready 0, review 4, excluded 9 (13 classifications).
Native PDF: ready 0, review 111, excluded 229. These are unresolved historical
Founder failures, not silently fixed or required to pass before this experiment.

## Validation gates

Engineering: relevant and full Flutter regressions, targeted critical-draft,
serialized persistence, permission failure/retry, same-day reminder tests;
format/analyze; Android APK. Unit scheduler doubles are not Android OS evidence.
Actual device pending state is queried in the UI; delivery/time/battery behavior
still needs device testing.

Founder: approximately 10 real screenshots/photos. Targets capture ≥90%, initial
critical-field accuracy ≥90%, median actions ≤3, median time ≤15 seconds,
no typing ≥80% minimum / ≥90% target. These are unmeasured targets, not engineering
acceptance claims. Score each initial field against the original input (missing
and wrong count as incorrect), report each field and combined score; include
failed/abandoned attempts in capture and friction denominators.

Build target: 0.17.0+20. Current implementation and CI evidence is tracked in
BUILD20_EVIDENCE.md. Product result always Founder Test Pending until tested.
