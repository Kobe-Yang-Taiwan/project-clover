# Project Clover — GitHub-Driven Development

This directory contains approved version specifications that Codex should execute together with the repository-level `AGENTS.md`.

## Founder workflow
1. Discuss product problems, evidence and direction with ChatGPT.
2. ChatGPT proposes a version/sprint and acceptance criteria.
3. Founder approves the product decision.
4. The approved specification is written to this directory as `Vx.xx_SPEC.md`.
5. Codex reads `AGENTS.md` + the approved spec and executes it.
6. Codex performs Engineering QA and provides evidence.
7. GitHub CI builds the Android artifact when configured.
8. Founder performs real-device acceptance.
9. Only an accepted version may advance toward release/main merge.

The Founder should not need to manually copy multi-part implementation prompts once an approved spec is stored here.

## Specification status
A spec should clearly state one of:
- DRAFT
- APPROVED
- IMPLEMENTING
- READY_TO_PUSH
- CI_BUILD
- FOUNDER_TEST
- ACCEPTED
- RELEASED

Codex must not implement a DRAFT spec unless explicitly instructed by the Founder.

## Recommended spec sections
- Mission / measurable goal
- Evidence / observed failures
- Scope and non-goals
- P0 / P1 / P2 priorities
- Product behavior
- Architecture constraints
- Data and compatibility constraints
- Acceptance criteria
- Regression cases
- QA/build requirements
- Founder real-device checklist
- Documentation updates
- Git/GitHub delivery rules

## Short execution command
Once a spec is APPROVED, the normal Codex instruction should be conceptually equivalent to:

`Read AGENTS.md and docs/development/Vx.xx_SPEC.md, then execute the approved version through the allowed gates. Do not merge main.`

The long product specification belongs in GitHub, not in repeated chat copy/paste.
