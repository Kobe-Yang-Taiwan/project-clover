# Validation sheet

All POC measurements are NOT MEASURED. No attempts have been supplied for this POC.

| Metric | Planned target | Actual |
|---|---|---|
| Successful capture with reminder capability | >=90% | Unknown |
| Critical-field draft accuracy | >=90% | Unknown |
| Low-friction/no free-form typing | >=90%; experiment minimum 80% | Unknown |
| Median human actions per benefit | <=3 | Unknown |
| Median time per benefit | <=15 seconds | Unknown |
| Review burden | Only three critical fields | Not tested |
| Ease / blocking issues | Acceptably easy | Not tested |
| Repeat use / redemption / savings | Next-stage validation | Not tested |

Attempt record template (no fabricated rows): anonymous attempt ID, fixture hash,
source type/page/region, app commit, device/extractor version, ground-truth reference,
draft Name/Expiration/Value correctness and field confidence, final save result,
reminder capability, elapsed seconds, actions, typing count, frustration/blocker
notes, assisted/unassisted status. Keep user/source evidence local/private.

See [protocol](BUSINESS_VALIDATION.md). Low-friction and no-typing measure the same
interaction constraint here; do not count them as independent successes.

## Remote context preserved from e1775af (2026-08-23)

Historical KPI/authorization statements below are superseded by the current scope.
The real-user observations remain valid evidence and are not discarded.

# Project Clover — Business Validation Sheet

## Purpose
This is the concise Founder-facing business validation scorecard for Project Clover.

Use this sheet to prevent engineering progress from being mistaken for product validation. Update it only from real evidence such as user interviews, observed behavior, Founder tests, retention data, or willingness-to-pay tests.

Status labels:
- CONFIRMED: supported by repeated real evidence
- PARTIAL: some evidence exists, but not enough to generalize
- HYPOTHESIS: plausible but not yet proven
- UNKNOWN: no reliable evidence yet
- BLOCKED: cannot be validated until an upstream product issue is fixed

---

## Current Business Validation Sheet

| Dimension | Current hypothesis / answer | Evidence today | Status | Next evidence required |
| --- | --- | --- | --- | --- |
| **Target User** | People who already receive and use multiple coupons, retailer offers, membership benefits, screenshots, PDFs, or paper promotions and lose value because they are scattered or forgotten. Household purchase decision makers and heavy multi-retailer benefit users are leading candidate segments. | Project originated from a real household pain. A real tester rejected manual entry as too much work. | PARTIAL | Interview 5–10 target users and identify which segment has the strongest recurring pain and repeat usage. |
| **Economic Buyer** | The individual user or household purchase decision maker may pay if Clover reliably prevents enough wasted value and saves enough effort. User and payer may not always be the same person. | No direct willingness-to-pay evidence yet. | UNKNOWN | Ask target users whether they would pay if Clover reliably prevents a measurable amount of monthly lost value; test actual payment intent later. |
| **Core Pain** | Users own value but lose it because promotions are scattered, hard to capture, hard to remember, and expire unused. Manual capture is itself a major friction point. | Real household origin + real tester feedback that manual entry is unacceptable. Build 19 also confirms that poor import quality makes the product unusable regardless of feature count. | PARTIAL | Quantify how often users forget benefits, how much value is lost, and which pain is strongest: capture, finding, remembering, or deciding. |
| **Usage Frequency** | Import may be occasional, but reminders / My Day / “what should I use today?” may create weekly or daily return behavior. | No cohort or repeat-use data yet. | UNKNOWN | Observe 5–10 users for multiple weeks. Measure import frequency, reminder actions, voluntary reopens, and whether My Day becomes a habit. |
| **Current Alternative** | Retailer apps, screenshots, photo gallery, LINE, email, paper coupons, calendars, notes, memory, or simply accepting expiry. | Known alternatives are obvious from current behavior, but Clover has not yet proven lower total effort. | HYPOTHESIS | Ask users exactly what they do today and compare total steps/time against Clover once Import is usable. |
| **Willingness to Pay** | Users may pay if Clover reliably saves meaningful money or removes enough cross-platform management work. Free/core experience must still be genuinely good. | No direct payment evidence. | UNKNOWN | Test concrete value framing, e.g. “If Clover reliably prevents NT$300–500 of lost value per month, would you pay? How much?” Avoid leading questions and later validate with real payment behavior. |
| **Retention Trigger** | Import is the entry point; expiry reminders, My Day, upcoming-value view, and cross-merchant visibility are candidate retention engines. | Reminder/My Day capabilities exist conceptually/product-wise, but retention has not been proven with real users. | HYPOTHESIS | Track whether users return without Founder prompting and whether reminders cause real actions. |
| **Distribution** | First users may come from households and communities with heavy coupon / membership usage; family sharing by word of mouth may be a natural path later. | No repeatable acquisition channel yet. | UNKNOWN | Identify first 10 and first 100 user channels. Record source of every beta user and whether referrals happen naturally. |
| **Moat Hypothesis** | Clover’s long-term advantage is not OCR, Flutter, GPT, Gemini, or a parser. The strongest hypothesis is a cross-merchant personal value layer: normalization across retailers, trusted history, promotion semantics, adapters, and accumulated usage/negative-case knowledge. | Architecture and domain learning are accumulating, but no durable market moat is proven. | HYPOTHESIS | Validate whether users value cross-merchant aggregation enough to switch behavior and whether accumulated data/semantics improve outcomes over time. |
| **Unit Economics** | Free/core usage should have near-zero variable cloud inference cost. Any recurring Founder cost that scales linearly with free-user activity must not become mandatory without a sustainable revenue model. | Explicit Founder decision already made after reviewing Gemini/OpenAI cloud-vision economics. | CONFIRMED | Later quantify hosting, support, store, analytics, and any paid-service costs per active user before monetization launch. |
| **Activation Requirement** | A new user must be able to get useful promotions into Clover with almost no typing. | Manual entry was rejected by a real tester. Build 19 Founder evidence shows current image/PDF import still fails this requirement. | BLOCKED | Fix Import enough to run unbiased external-user activation tests. |
| **Primary UX KPI** | No-Typing Import Rate >= 95%. One-tap recovery is acceptable; repeated manual field entry is not. | Founder-approved product criterion. Current Build 19 does not satisfy it. | BLOCKED | Measure on real FamilyMart/PX Mart/PDF cases after remediation, then on external users. |

---

## Founder Six Questions — Current Scorecard

| Question | Current answer | Status |
| --- | --- | --- |
| 1. Who is the real user? | Likely multi-retailer coupon / benefit users, especially household purchase decision makers; exact highest-value segment not yet proven. | PARTIAL |
| 2. Who will pay? | Unknown. Individual user / household buyer is the leading hypothesis. | UNKNOWN |
| 3. How often will they need Clover? | Unknown. Import may be occasional; My Day / reminders may drive recurring use. | UNKNOWN |
| 4. Why not just use existing apps / screenshots? | Clover may win through cross-merchant aggregation and lower management friction, but this is not yet proven. | HYPOTHESIS |
| 5. Why can’t another retailer/platform replace it? | Individual retailers will not manage competitors’ benefits; cross-merchant value layer is the current moat hypothesis. | HYPOTHESIS |
| 6. Are real users voluntarily asking to continue using it? | Not yet proven with a sufficient external beta sample. | UNKNOWN |

---

## Current Validation Blocker

The immediate blocker is still **Import usability**.

Business validation must not wait for a feature-complete app, but it also should not ask users to judge a workflow that is already known to be broken.

Current Founder evidence shows Build 19 still fails the activation requirement:
- PX Mart image: 12-product ground truth, only 7 proposed regions; Direct Import = 0.
- Native-text PDF: Direct Import = 0; Needs Confirmation = 111; Excluded = 229.
- Product fragments, specifications, disclaimers, and true products are still misclassified/reconstructed.

Therefore the next engineering work must be framed as a validation hypothesis, not as generic “improve import.”

---

## Next Business Validation Actions

### Action B1 — 5–10 target-user interviews
Start once Import is minimally usable enough that users can understand the intended experience.

Ask:
1. Where do your coupons / promotions live today?
2. In the last month, how often did you forget one or let value expire?
3. Which part is most annoying: capturing, finding, remembering, or deciding what to use?
4. How often would you realistically open Clover?
5. If Clover reliably prevented meaningful monthly waste, would you pay? Why or why not?
6. What would make you stop using Clover after the first week?

Do not pitch or defend the product during these interviews.

### Action B2 — Behavioral evidence
Prefer behavior over compliments. Track whether users:
- import without assistance;
- return without Founder prompting;
- act on reminders;
- open My Day voluntarily;
- ask to keep using Clover;
- recommend it to a spouse/family member;
- report actual value saved or waste avoided.

### Action B3 — Monetization evidence
Do not implement a paywall yet. First identify the moment when the user perceives measurable value and test willingness to pay around that moment.

---

## No-New-Build Rule

Every meaningful new build must state before implementation:

1. **Unknown being tested**
2. **Why it matters to product/business value**
3. **Metric / evidence required**
4. **Pass condition**
5. **Conditional condition**
6. **Fail / stop condition**
7. **What decision the result will unlock**

Example:

> Hypothesis: improved Native PDF Product Cell Reconstruction can reduce the current 111-review / 229-excluded failure into a small exception-only review flow without reintroducing false candidates.

A build is not justified merely because Codex can implement it quickly.

---

## Business Validation Priority

1. Make Import usable enough to test the intended product experience.
2. Identify the highest-pain target segment.
3. Prove a recurring retention trigger.
4. Prove economic buyer and willingness to pay.
5. Find a repeatable first-user distribution path.
6. Validate whether the cross-merchant value layer can become a real moat.

The governing question is:

> What evidence would make us believe Project Clover deserves to keep being built?
