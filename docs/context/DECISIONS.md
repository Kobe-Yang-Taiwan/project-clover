# Decisions

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

## Reduce import ambition — Founder approved; context sync authorized 2026-09-05

- Situation: Build 19 engineering passed; real image and native PDF imports failed.
- Options: keep requiring complete reconstruction; reduce to useful critical drafts.
- Decision: REDUCE IMPORT AMBITION. Full Product Reconstruction is not an MVP Gate.
- Reason: users need low-effort capture and reminders, not catalogue cleanup.
- Assumption to test: Name / Expiration / Value with quick confirmation is enough
  for activation. This is not yet demonstrated by users.
- Preserve: Local-first, native PDF text/layout, Structured Representation,
  Evidence Ownership, Golden Dataset, storage/reminders, provider neutrality,
  explicit consent before each cloud request, Unknown > fabricated value.
- Future dense PDF interaction: Tap-first Capture; not implemented now.
- Current authorization: Phase 0 documents and Phase 1 diagnostics only.
- Explicitly withheld: accuracy fixes, Phase 2, Build 20, main merge.

95% no-typing remains a long-term aspiration, not the sole MVP gate.
North Star: Benefit Captured / Money Saved. See business validation for gates.

## Remote context preserved from e1775af (2026-08-23)

Historical KPI/authorization statements below are superseded by the current scope.
The real-user observations remain valid evidence and are not discarded.

# Project Clover — Durable Decisions

Last updated: 2026-08-23

This file records decisions that future agents must not casually reopen without new evidence.

## D-001 — Repository is the single source of truth
**Status:** Active

Project direction is discussed with the Founder, but approved specifications, current state, durable decisions, and acceptance evidence must live in the repository so Codex does not depend on old chat prompts.

## D-002 — Founder real-device acceptance is mandatory
**Status:** Active

Automated tests, static analysis, CI, and APK generation are Engineering QA only. They do not equal product acceptance. Real-device tests with representative real promotional material are required before an Import version can be accepted.

## D-003 — Local-first remains the default product architecture
**Status:** Active

Core coupon data, reminders, favorites, and normal product operation should remain local-first unless the Founder explicitly approves a material architecture/privacy change.

## D-004 — Native-text PDF must not be OCR-first
**Status:** Active

For PDFs with a usable text layer:
`Native PDF text + coordinates/layout -> Structured representation / Structured Markdown -> Product reconstruction`.

Do not route all PDFs through OCR or cloud vision merely because a vision provider exists.

## D-005 — Structured representation is the common Import intermediate layer
**Status:** Active

PDF and image import paths should converge into a structured intermediate representation that preserves product-region/cell ownership, evidence, coordinates where available, and unknown/null fields.

The representation exists to support reliable Product Reconstruction, not simply to serialize OCR fragments.

## D-006 — Unknown is better than fabricated
**Status:** Active

Never invent product name, merchant, brand, price, original price, discount, expiry date, specification, or other fields merely to make a candidate complete.

## D-007 — One real product should reconstruct to one Product Object
**Status:** Active

Known non-product text must not independently create coupon candidates. Neighboring products must not exchange product-specific evidence.

## D-008 — Free/core Clover must not require recurring paid AI inference per use
**Status:** Active

Any feature whose Founder infrastructure/inference cost grows linearly with free-user usage must not become a mandatory dependency of the free/core Clover journey without an approved sustainable revenue model.

Reason: Clover is intended to become a low-maintenance side-income product; user growth must not automatically create an unbounded Founder AI bill before revenue exists.

Cloud AI may still be used for:
- internal benchmark;
- optional future paid capability;
- enterprise/future experiments;
- explicitly approved fallback research.

## D-009 — GPT/Gemini account must not be required for normal users
**Status:** Active

A normal Clover user should not need a ChatGPT, OpenAI, Gemini, or other AI-provider account to use the core app.

## D-010 — Product KPI is almost-no-typing, not perfect autonomous AI
**Status:** Active

Primary user-experience principle:
`Import -> most content reconstructed automatically -> missing item recoverable with minimal action -> user reviews exceptions only`.

Target product KPI: No-Typing Import Rate >= 95%.

A system that automatically finds 7/8 items and lets the user recover the eighth with one tap and no typing may be more valuable than an expensive cloud-only 8/8 solution.

## D-011 — Do not endlessly tune a universal OCR threshold
**Status:** Active

V0.15 and V0.16 demonstrated opposite failure modes: false-positive explosion versus false-negative collapse. Future remediation must identify the failing architecture layer rather than repeatedly lower/raise global confidence thresholds.

## D-012 — Real-world Golden Dataset is a release gate
**Status:** Active

Synthetic/unit tests are necessary but insufficient. Representative real material must be measured for recall, precision, field accuracy, duplicates, cross-product contamination, false candidates, and review burden.

Known Golden cases include Costco PDF, PX Mart multi-product promotional image, and FamilyMart multi-product promotional image.

## D-013 — Architecture uncertainty should be resolved with a POC before broad implementation
**Status:** Active

When the team is unsure whether an approach can meet the product goal, first run a narrow POC with explicit pass/conditional/fail gates. Do not convert every hypothesis immediately into a full feature release.

## D-014 — Build 19 real-world evidence overrides green automated tests for Import acceptance
**Status:** Active

Build 19 has real-device failure evidence for PX Mart image import and Native-text PDF reconstruction. Those failures remain active until a later real-device regression demonstrates resolution. Passing 131 automated tests cannot mark these cases resolved.
