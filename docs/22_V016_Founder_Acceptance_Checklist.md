# V0.16 Founder Acceptance Checklist

Test version: `0.16.0 (Build 16)`

## Engineering gate evidence

- [x] GitHub Actions run #89 passed formatting and Flutter static analysis.
- [x] All 103 automated tests passed, including V0.15 failure regressions.
- [x] Android Build 16 debug APK was built and uploaded as `project-clover-android-debug`.
- [x] Automated fixtures cover non-product rejection, cross-cell isolation,
  multi-product reconstruction, no fabricated price/date, and final import validation.
- [ ] Real-device Founder dataset validation is complete.

## Costco PDF

- [ ] Package counts such as `36包入(CT)` do not appear as candidates.
- [ ] Disclaimer, legal, purchase restriction and payment text do not appear as candidates.
- [ ] Each real product appears exactly once.
- [ ] Neighboring product names, ITEMs, specifications and prices are not mixed.
- [ ] Merchant is `Costco 好市多`; product brand remains separate.
- [ ] Dates are inherited only from the applicable promotion period.
- [ ] Direct Import records contain reliable required information.
- [ ] Needs Confirmation shows only unresolved fields.
- [ ] Review candidate count is materially lower than V0.15's 123.

## Multi-product supermarket image

- [ ] One image produces multiple independent product candidates.
- [ ] Campaign banner and phone UI are ignored.
- [ ] Each product retains its own price and specification.
- [ ] No manual cropping is required.

## Regression and safety

- [ ] Manual entry, reminders, storage, backup/restore and existing imports still work.
- [ ] Cancelled or failed import leaves existing data unchanged.
- [ ] No reminder is scheduled before final confirmation.
- [ ] Excluded content can be inspected but cannot be imported normally.

Record actual labelled Candidate Precision, Recall, Field Accuracy, Duplicate Rate, Cross-cell Contamination and Review Burden after testing. Do not use OCR confidence as accuracy.
