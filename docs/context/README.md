# Project Clover Persistent Context Layer

## Purpose
This directory is the durable context layer for Project Clover. It exists so ChatGPT, Codex, and future development agents can understand the current product state, prior decisions, real-world failures, and Founder acceptance evidence without relying on old chat history.

The repository remains the single source of truth. These files complement `AGENTS.md` and version specifications under `docs/development/`.

## Required reading order for AI development work
1. `/AGENTS.md`
2. `docs/context/CURRENT_STATE.md`
3. `docs/context/DECISIONS.md`
4. `docs/context/IMPORT_NEGATIVE_CASES.md` when work touches Import
5. `docs/context/FOUNDER_TEST_EVIDENCE.md` when work touches acceptance, QA, or regression
6. The currently approved version specification under `docs/development/`

## Files
- `CURRENT_STATE.md` — concise statement of where the project is now, the active gate, current P0, and what must not be started yet.
- `DECISIONS.md` — durable Founder/product/architecture decisions and the reasons behind them.
- `IMPORT_NEGATIVE_CASES.md` — real failures that future implementations must not repeat.
- `FOUNDER_TEST_EVIDENCE.md` — real-device evidence. Automated tests must never overwrite or substitute for this evidence.

## Context rules
- Prefer verified repository evidence and Founder real-device evidence over assumptions.
- Distinguish verified facts from hypotheses.
- Do not rewrite historical failures as successes because a later automated test passes.
- Do not remove a negative case merely because the implementation changed; mark it resolved only when a later real-world regression proves it.
- Keep these files short enough to be read at the start of every relevant engineering task.
- If two files conflict, the newer explicit Founder decision wins; record the conflict and resolution in `DECISIONS.md`.
