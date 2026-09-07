# Business validation — planned, not implemented

Outcome: users capture useful benefits, receive reminders and actually use value.
North Star: Benefit Captured / Money Saved.

Hypothesis: three critical fields plus quick confirmation can support activation
without full Product Reconstruction. No user evidence yet establishes this.
Future POC: existing image/photo/PDF capture; dense PDF Tap-first; show only Name,
Expiration and Value. High prefilled; Medium candidate selection; Low quick recovery.
Preserve evidence ownership and unknown values. Sale price is not money saved;
user-selected reminder date is not a fabricated expiration date.

Experiment after separate approval: >=5 image and >=5 PDF/coupon examples,
including current failure families; >=20 attempts when practical. Predefine ground
truth, timing start/end, action counting (including selection/save), failure handling
and field-accuracy denominator. Score drafts BEFORE correction; report each field
as well as aggregate accuracy. Do not discard failed attempts. This is a small
directional POC, not statistical proof of market success.

PASS: capture >=90%, draft accuracy >=90%, median actions <=3, median time <=15s,
no typing >=80% (target >=90%), interaction judged acceptably easy.
Conditional: capture 80–89% OR median actions 4–5 OR time 16–30s, with no FAIL
criterion; allow only one targeted extraction or confirmation-UX improvement cycle.
FAIL overrides conditional: capture <80%, median actions >5, median time >30s,
or users consider it too much work. Escalate product/architecture, do not auto-tune.
Other unmet gates remain non-PASS pending explicit review.

Next only after POC: repeated use, reminder-to-redemption and actual savings.
Existing mark-used functionality should be inspected/reused, not built twice.
Future model planning only: Pending, Used, Expired, Missed; Original Benefit Value,
Actual Money Saved, Avoided Loss, Redemption Time, Currency. Unknown amounts null.
Expired means date passed/outcome unconfirmed; Missed means confirmed unused.
No new dashboard, schema migration, monetization or distribution implementation now.

## Remote context preserved from e1775af (2026-08-23)

Historical KPI/authorization statements below are superseded by the current scope.
The real-user observations remain valid evidence and are not discarded.

# Project Clover — Business Validation

## Purpose
This document tracks whether Project Clover is becoming a product that deserves continued investment, not merely a technically functioning app.

Engineering evidence and business evidence are separate. A passing build, CI run, or import benchmark does not prove product-market fit, retention, willingness to pay, or sustainable unit economics.

Use this file as the persistent business-reality context for Founder, ChatGPT, Codex, and future AI agents.

---

## Current Business Validation Status

Status: EARLY VALIDATION / NOT PROVEN

Current conclusion:
- The original pain is real: owned promotions/coupons are easy to forget and scattered across sources.
- A real tester already showed that manual coupon entry creates too much friction.
- The Import experience is still not reliable enough to support broader product validation.
- Early platform-demand evidence exists: during V0.16 friend testing, most invited testers used iPhone and multiple people proactively asked whether an iPhone version was available to try.
- Willingness to pay, retention frequency, economic buyer, distribution, and moat are not yet proven.

Do not interpret engineering progress as business validation.

---

## 1. Target User

### Primary hypothesis
People who already receive and use multiple promotions, coupons, membership benefits, or retailer offers and who experience friction from remembering, locating, and using them before expiry.

Potential high-fit segments to validate:
- Household purchase decision makers
- Heavy coupon / membership-benefit users
- Users of multiple retailers or loyalty programs
- Families that accumulate paper, screenshot, PDF, and app-based promotions
- Users who frequently lose value because benefits expire unused

### Evidence
Confirmed:
- The product originated from a real household problem: coupons/promotions are easily forgotten when scattered across different places.
- Real-user feedback identified manual entry as too much work.

Still unknown:
- Which segment has the strongest recurring pain.
- Which segment has the highest retention potential.
- Which segment is most willing to pay.

---

## 2. Economic Buyer

Status: UNPROVEN

Do not assume the user and payer are automatically the same person.

Current hypotheses:
1. Individual user pays directly for convenience and reduced wasted value.
2. Household/family decision maker pays because Clover helps manage benefits across family purchases.
3. Future B2B/B2B2C possibilities may exist, but they are not MVP assumptions.

Key validation question:
> Who receives enough measurable value from Clover that paying becomes economically rational?

Do not build pricing or premium feature walls until this has evidence.

---

## 3. Core Pain

### Problem hypothesis
Users already own promotions and benefits, but value is lost because they are:
- scattered across apps, screenshots, PDFs, paper, or messages;
- difficult to capture without manual typing;
- forgotten before expiry;
- hard to evaluate at the moment of purchase;
- difficult to compare across merchants.

### Current product promise
Clover should reduce the work required to capture, understand, save, and use owned promotions before they expire.

The product should help users answer within roughly five seconds:
> What value should I use today?

### P0 friction
Import must require almost no typing.

Current target KPI:
- No-Typing Import Rate >= 95%

---

## 4. Usage Frequency

Status: UNPROVEN

Important distinction:
- Import frequency may be low or irregular.
- Product retention depends on whether Clover creates a reason to reopen between imports.

Current hypothesis:
> Import is the entry mechanism; My Day / Today-to-use value may become the retention engine.

Questions to validate:
- How often do target users receive new promotions?
- How often do they need to check expiring value?
- Would they open Clover daily, weekly, only when shopping, or only when importing?
- Is expiry/reminder value enough to create a recurring habit?

A painful problem with low usage frequency may still produce weak retention.

---

## 5. Current Alternatives

Users may currently rely on:
- retailer apps;
- screenshots/photo gallery;
- LINE/messages;
- email;
- paper coupons;
- calendars/reminders;
- notes;
- memory;
- doing nothing and accepting expiry/waste.

Clover must beat these alternatives on total friction, not just feature count.

Key question:
> Why is Clover easier than simply leaving the coupon where it already is?

---

## 6. Willingness to Pay

Status: NOT VALIDATED

Do not assume users will pay merely because Clover is useful.

Future interview prompts may include:
- If Clover reliably prevents NT$300–500 of lost value per month, would you pay for it?
- What monthly price would feel obviously worth it?
- Which capability would make payment feel justified?

Important product rule:
The free/core experience must not intentionally be poor in order to force conversion.

A weak free import experience would damage activation before monetization can occur.

---

## 7. Retention Trigger

Current hypotheses:
- Expiry reminders
- Today / My Day recommendations
- Upcoming-value view
- Cross-merchant benefit visibility
- Family-level value management in the future

Current working insight:
> Import is a ticket to enter the product; recurring value must come from helping users decide what to use before it expires.

Retention has not yet been proven with real cohorts.

---

## 8. Distribution

Status: UNPROVEN, WITH EARLY iOS DEMAND SIGNAL

Questions:
- Where will the first 10 users come from?
- Where will the first 100 users come from?
- Which communities naturally contain heavy promotion/coupon users?
- Is the product easy enough to demonstrate through screenshots/video/social sharing?
- Can one user naturally introduce Clover to a spouse/family member?

### Early iOS Demand Evidence
During V0.16 friend testing:
- most of the friends invited to test were iPhone users;
- multiple people proactively asked whether an iPhone version was available for them to try;
- the Founder currently owns only an Android phone, so Android remains the primary development and real-device acceptance platform for now.

Interpretation:
- This is stronger than a generic compliment because the user is expressing intent to try the product if the platform barrier is removed.
- It is still early evidence, not proof of retention, willingness to pay, or product-market fit.
- Do not start iOS development merely because this signal exists. Preserve Flutter cross-platform compatibility and continue collecting iOS test interest while the Android core flow is stabilized.

Suggested metric:
- iOS Waitlist / Test Interest Intent = number of iPhone users who explicitly ask to be notified or included when an iOS beta becomes available.

Do not assume App Store / Google Play presence creates distribution.

---

## 9. Moat Hypothesis

Do not treat Flutter, OCR, GPT, Gemini, or a specific parser as a durable moat.

Current strongest long-term hypothesis:
> Clover becomes a cross-merchant personal value layer that helps users manage benefits across sources that individual retailers will not manage for one another.

Potential moat sources to validate over time:
- Cross-merchant normalization
- User trust
- Accumulated structured benefit history
- Better understanding of promotion semantics
- Personal usage/value history
- Habit / switching cost
- Retailer/source adapters
- Proprietary negative-case and reconstruction knowledge

Current moat status: NOT PROVEN

---

## 10. Unit Economics / Founder Cost

Active business architecture principle:
> Any feature whose recurring Founder infrastructure or inference cost grows linearly with free-user usage must not become a mandatory dependency of the free/core Clover journey without an approved sustainable revenue model.

Implications:
- Paid cloud AI must not be required for the free/core import path unless economics are explicitly approved.
- User growth must not automatically create an uncontrolled API bill.
- Optional paid AI, premium capability, benchmark infrastructure, or future B2B usage may still be evaluated separately.

Current desired free-core inference cost:
- Approximately zero variable cloud inference cost per normal import.

---

## 11. Founder Six Questions

Every major product milestone should answer these questions with evidence, not assumptions.

1. Who is the real user?
2. Who is the economic buyer?
3. How often does this person need Clover?
4. Why is Clover better than the current alternative?
5. Why can another app / retailer / platform not easily replace Clover?
6. Are real users voluntarily asking to continue using it?

Current status:

| Question | Status |
| --- | --- |
| Who is the user? | PARTIALLY KNOWN |
| Who will pay? | UNKNOWN |
| Usage frequency? | UNKNOWN |
| Why not existing alternatives? | HYPOTHESIS ONLY |
| Moat? | HYPOTHESIS ONLY |
| Voluntary continued usage? | EARLY SIGNAL — iPhone users proactively asked for an iOS version to try; continued usage not yet proven |

---

## 12. Validation Evidence

### Confirmed evidence
- Real household problem motivated the project.
- Manual entry was explicitly rejected by a real tester as too much work.
- Import accuracy is currently a blocking product issue, not merely a technical polish issue.
- During V0.16 friend testing, multiple iPhone users proactively asked whether an iPhone version was available to try. Record this as Early iOS Demand Evidence, not as retention or willingness-to-pay proof.

### Evidence still required
- 5–10 target-user interviews outside close-support bias where possible.
- Repeated use across multiple weeks.
- Evidence that users return without Founder prompting.
- Evidence that users ask to keep using Clover after actual hands-on use.
- Quantified value saved / waste avoided.
- Willingness-to-pay evidence.
- Activation and retention measurements after Import becomes usable.
- Count of explicit iOS waitlist / beta-test requests, rather than relying only on anecdotal recall.

---

## 13. Near-term Business Validation Plan

Do not wait for a feature-complete product.

After Import reaches a minimally usable Founder gate:

### Interview 5–10 target users
Ask at minimum:
1. Where do your coupons/promotions live today?
2. How often do you forget or lose value?
3. What is more painful: capturing, finding, remembering, or deciding what to use?
4. How often would you realistically open Clover?
5. If Clover reliably saved you meaningful value each month, would you pay? Why or why not?

Do not sell or defend the product during discovery interviews.

### Observe behavior
Prefer evidence such as:
- user imports without assistance;
- user returns later;
- user acts on a reminder;
- user asks to keep the app;
- user recommends it to another household member;
- iPhone users explicitly opt in to be notified for an iOS beta.

Compliments such as "很酷" are weak evidence unless paired with behavior.

---

## 14. Build Discipline

New rule:
> No new Build without a clear hypothesis.

Every meaningful build should state:
- Unknown being tested
- Metric / evidence required
- Pass condition
- Conditional condition
- Fail / stop condition

Example:
Bad:
> Improve Import.

Better:
> Test whether Native PDF Product Cell Reconstruction can reduce review burden from the current Founder-test failure level to the approved threshold without increasing false candidates.

AI coding speed must not become a reason to build unvalidated features faster.

---

## 15. Kill / Pivot Criteria

These are provisional and require Founder approval before becoming hard project shutdown rules.

Potential warning signals:
- Target users consistently say the problem is annoying but not important enough to change behavior.
- Users do not return after first import even when import quality is acceptable.
- No clear retention trigger emerges.
- Willingness to pay remains near zero and no sustainable alternative monetization model exists.
- Core value requires recurring infrastructure cost that exceeds realistic revenue.
- The product cannot outperform current alternatives on total user effort.

Do not interpret one negative interview as a kill signal. Look for repeated patterns.

---

## 16. Current Priority Order

1. Make Import usable enough for real product validation.
2. Validate target user and recurring pain.
3. Validate retention trigger / usage frequency.
4. Validate willingness to pay and economic buyer.
5. Validate distribution, including quantified iOS test interest.
6. Only then expand monetization and moat-building investment.

Do not reverse this order merely because AI makes feature development cheap.

---

## 17. Decision Principle

The central Founder question is no longer only:
> Can we build it?

It must also be:
> What evidence would make us believe this product deserves to keep being built?

Project Clover should evolve through:

Hypothesis -> Build/POC -> Real User -> Evidence -> Continue / Remediate / Pivot / Kill

not:

Build -> Add Features -> Build Again.
