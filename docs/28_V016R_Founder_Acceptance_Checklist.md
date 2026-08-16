# V0.16R / 0.16.1 Founder Android Acceptance Checklist

Test build: `0.16.1 (Build 18)`
State: STANDARD CI PASS — provider-enabled Founder APK configuration pending

## Privacy and routing

- [ ] Native Costco PDF reports local native-text route and zero cloud requests.
- [ ] Image/scanned-page upload occurs only after tapping `同意並開始辨識`.
- [ ] `取消` causes zero upload and keeps manual/local fallback available.
- [ ] Founder APK reports Google Gemini Developer API / `gemini-3.6-flash` Paid.
- [ ] Only selected image/required scanned pages are transmitted.
- [ ] Cloud failure does not change existing coupons or reminders.

## Costco (129 product cards)

- [ ] Page counts match 16／16／16／20／13／16／16／16.
- [ ] Page 1 legal content creates zero candidates.
- [ ] Package/spec/ITEM/price/disclaimer fragments never become product names.
- [ ] Each visual cell is one product object; multi-variant cells are not duplicated.
- [ ] No name/brand/model/spec/ITEM/price crosses to a neighboring cell.
- [ ] Original, discount and sale price roles match visible evidence or stay unknown.

## PX Mart (12 product cards)

- [ ] Detects 12 distinct products.
- [ ] Payment campaign banners and app/status/navigation UI are excluded.
- [ ] Bundle totals, quantities and average unit prices retain different roles.
- [ ] Merchant is 全聯福利中心; every price/spec remains with its own card.

## FamilyMart (8 product cards)

- [ ] Original source image is supplied again and its SHA-256 is recorded.
- [ ] Detects 8 distinct products rather than the V0.16 baseline of 1.
- [ ] Shared campaign text and phone UI create zero products.
- [ ] Eight visible prices remain associated with their own product regions.

## Record for every sample

- Ground Truth Product Count
- Detected Product Count
- Correct Product Count
- Product Recall
- Candidate Precision
- Field Accuracy
- False Candidate Count
- Duplicate Rate
- Cross-product Contamination
- Review Burden
- Cloud requests and estimated cost
- Cloud input/output/total token usage

## Engineering regression

- [x] Format, analyze and all Flutter tests pass (120 tests, 2026-08-16).
- [x] Android Build 17 debug APK builds in GitHub Actions run #91.
- [x] Build 18 local format/analyze and 123 Flutter tests pass.
- [x] Build 18 proxy privacy/schema suite passes (4 tests); secret-boundary scan passes.
- [x] Standard Build 18 Android APK builds in GitHub Actions run #93 (artifact `9260715239`).
- [ ] Provider-enabled Build 18 Founder APK builds with deployed HTTPS proxy config.
- [ ] Android APK installs and launches on Founder device.
- [ ] Manual entry, storage, backup/restore, reminder and earlier import flows pass.

Do not mark accepted if any P0 item fails. Do not merge `main`.
