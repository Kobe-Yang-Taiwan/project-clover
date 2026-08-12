# Project Clover — AI Development Control System

## Purpose
This repository is the single source of truth for Project Clover development. Founder discusses product direction in ChatGPT; approved version specifications are stored in this repository; Codex executes from those approved specifications. The Founder should not need to repeatedly copy long prompts between ChatGPT and Codex.

## Roles
- Founder / Product Owner: approves product direction, scope changes, high-risk actions, and final real-device acceptance.
- ChatGPT Product/System Layer: converts discovery and Founder feedback into approved specs, acceptance criteria, priorities, and repository documentation.
- Codex Engineering Layer: inspects, implements, tests, commits, builds, updates technical documentation, and reports evidence.
- AI User Validation Layer: reserved for later persona simulation (for example MatrAIx) once the core MVP flow is stable and before broader human Beta validation.

## Source of Truth
Before implementing a version, Codex must read the approved version specification under `docs/development/` plus this file. Do not rely on an old chat prompt when repository instructions are newer.

## State Machine
Every version uses these states:
SPEC -> IMPLEMENTING -> LOCAL_QA -> READY_TO_PUSH -> CI_BUILD -> FOUNDER_TEST -> ACCEPTED -> RELEASED

Failure may move a version to BLOCKED or FAILED, followed by a fix and return to the appropriate gate.

Never describe a version as complete merely because implementation or automated tests finished.

## Gates
G0 Scope: version mission, scope, priorities, acceptance criteria approved.
G1 Inspect: inspect repository, current branch/worktree, previous version, tests, migrations and known limitations.
G2 Implement: implement only approved scope; routine engineering decisions are autonomous.
G3 Local QA: format/analyze/tests/regression; P0 gates must pass.
G4 Commit: clean, reviewable commit; no unrelated changes.
G5 Release Authorization: obey platform safety requirements for external writes. If explicit Founder authorization is required, stop only at this gate and provide the exact authorization required.
G6 CI / Build: push only to the approved development branch, update Draft PR, run CI and produce Android APK when configured.
G7 Founder Acceptance: real Android device and real representative data/workflows. Automated tests do not replace this gate.
G8 Accepted / Released: only after Founder Acceptance. Main merge or production/store release requires explicit Founder approval.

## Default GitHub Development Destination
Repository: `Kobe-Yang-Taiwan/project-clover`
Development branch: `agent/flutter-prototype-v0`
Draft PR: `#1`

Normal development target is the development branch / Draft PR. Never merge `main` autonomously.

## Founder Approval Required
Always require Founder approval for:
- merging `main`;
- production or store release;
- destructive or irreversible data migration;
- data-loss-risk actions;
- material product scope change;
- architecture changes outside an approved specification when they materially alter product behavior, privacy, or data ownership;
- any external write when the execution platform itself requires explicit authorization.

Do not interrupt the Founder for routine implementation choices.

## MVP Rules
- MVP and core user value first; avoid feature inflation.
- Preserve Local-first behavior unless an approved spec explicitly changes it.
- Do not silently introduce login, cloud sync, AI, iOS, monetization, gamification, or unrelated redesign.
- Existing user data and supported backup compatibility must not be broken without explicit approval and a migration plan.
- A smaller correct solution is better than a broader unreliable one.

## Project Clover Core Product Principle
The product should reduce the work required to capture, understand, save, and use owned promotions before they expire.

For Universal Import, optimize for final imported information correctness, not raw OCR output volume. Unknown is better than fabricated data. Non-products must not become coupons. Product-specific fields from neighboring products must not be mixed.

## QA Layers
1. Engineering QA: static analysis, unit/integration/regression tests, build.
2. AI User QA: persona simulation when the system reaches the maturity gate defined below.
3. Real-world QA: Founder acceptance and human Beta users.

### MatrAIx maturity trigger
Do not add MatrAIx to the app or to an unfinished version merely because it exists. Recommend/introduce AI persona validation when all are true:
- Import -> Candidate -> Review -> Save -> Reminder core flow is stable end-to-end.
- Major foundational data reconstruction errors are no longer the dominant failure mode.
- UI/UX is close enough to Beta that behavior simulation will produce useful findings.
- The project is preparing for broader human Beta testing.

At that point, insert AI persona simulation after Engineering QA and before broader human Beta. Founder real-device acceptance remains required.

## Required Delivery Evidence
At every engineering handoff report:
- current state/gate;
- version/build;
- branch and commit SHA;
- actual files/areas changed;
- tests added and exact results;
- static analysis result;
- build/CI result;
- unresolved P0/P1 issues;
- known limitations;
- whether Founder action is required;
- exact next gate.

Avoid unsupported percentage-complete estimates. Gate/state evidence is preferred.

## Blocker Format
Only stop for a genuine blocker. Use:
BLOCKER -> IMPACT -> OPTIONS -> RECOMMENDATION -> REQUIRED FOUNDER ACTION

If no Founder decision is genuinely required, continue autonomously.

## Documentation Discipline
For each approved version, keep the repository documentation synchronized where those documents exist, including:
- Product Discovery;
- Product Bible;
- PRD;
- Development Progress;
- architecture notes;
- release notes;
- Known Limitations;
- Founder Acceptance Checklist;
- Draft PR description.

Do not invent missing historical facts. Add/update documents from approved product decisions and verified implementation evidence.

## Codex Start Contract
When asked to execute an approved version:
1. Read this `AGENTS.md`.
2. Read the approved version spec under `docs/development/`.
3. Inspect current repository/worktree and preserve valid existing work.
4. Report only genuine contradictions/blockers requiring Founder input.
5. Otherwise implement autonomously through Local QA and Commit.
6. Continue through Push/CI/Build when authorization and tooling permit.
7. Stop for Founder Acceptance with a concise real-device checklist.
8. Never merge `main` without explicit Founder approval.
