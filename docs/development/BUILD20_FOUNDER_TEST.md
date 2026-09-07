# Build 20 — Founder test, approximately 10 real attempts

Status: NOT RUN. Do not treat the synthetic Android smoke test as these attempts.
Use private screenshots/photos of actual owned coupons. Include image samples
from the PX Mart failure family; for dense PDFs, screenshot the wanted benefit.
This tests the reduced flow, not legacy 12-product / 111-record reconstruction.

1. Install the APK from BUILD20_EVIDENCE.md (extract the downloaded ZIP).
2. Clover → add → 匯入圖片 → choose one coupon screenshot/photo.
3. Check name, expiration, discount against the original. Choose or correct only
   uncertain fields, then 確認並儲存. Allow Android notifications if prompted.
4. Check the saved confirmation and pending reminder status. Tap 完成; verify
   the benefit in the existing list, close/reopen and verify again.
5. For one coupon expiring today, save with sufficient time before midnight;
   the reminder is scheduled about two minutes later. Lock the phone and check
   actual delivery (Android inexact/battery policy may delay it). Also test one
   notification tap opens the right benefit.

The add sheet's 本機匯入測試紀錄 contains initial/final critical fields, saved
status, local elapsed time, typing flag, semantic action counter and reminder
state. Records stay local (latest 50), no user image/OCR dump or upload. A missing
record, abrupt process kill, or failed persistence must be manually recorded as
an attempted capture; do not omit failures from denominators.

Score each initial draft field against the original BEFORE correction: 1 correct,
0 wrong or missing. App confidence is not measured accuracy. Candidate-only/missing
initial values count 0 for draft accuracy, even when selection later succeeds.
For action/time gates, separately observe picker time, repeated text-edit sessions,
calendar navigation and permission taps; app counters are not exact physical taps.
Record frustration or blocking issues even when Save eventually succeeds.

| Attempt | Saved + reminder usable? | Initial Name/Date/Value (0/1 each) | Actions observed | Seconds | Typed? | Reopen / notification / blocker notes |
|---|---|---|---|---|---|---|
| 1 | | | | | | |
| 2 | | | | | | |
| 3 | | | | | | |
| 4 | | | | | | |
| 5 | | | | | | |
| 6 | | | | | | |
| 7 | | | | | | |
| 8 | | | | | | |
| 9 | | | | | | |
| 10 | | | | | | |

Targets: capture ≥90%; name/date/value accuracy each and combined ≥90%; median
actions ≤3; median selected-image-to-save ≤15s; no free-form typing ≥80% minimum,
≥90% target. Also report completion-only medians alongside total failed attempts;
never remove failed attempts from capture/accuracy/no-typing denominators.
No Product PASS until Founder reports results. Next product scope is decided from
these results; do not automatically resume full reconstruction development.
