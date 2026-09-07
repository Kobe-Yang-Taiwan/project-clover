# Product Discovery — V0.16

## Observed problem

V0.15 could turn a Costco catalog into 123 `NEEDS REVIEW` entries. The system extracted text but did not reconstruct real products. Package counts, disclaimers, legal text and purchase restrictions became review work.

## Product judgment

- High candidate count is not success.
- One real promotional product must become exactly one useful candidate.
- Non-product content must create zero visible candidates.
- Manual correction burden is a product failure, even when uncertainty is disclosed.
- A smaller correct result is better than 123 questionable fragments.

## Success definition

“100% final imported information correctness” does not mean “pretend OCR is 100% accurate.” Correctness comes from reliable reconstruction, explicit uncertainty, targeted human confirmation and exclusion of invalid blocks.

The value chain remains: Universal Import → Correct Coupon Data → Reminder → My Day → Reduced Coupon Waste → Daily Habit → Future Gamification. Gamification is not V0.16 scope.
