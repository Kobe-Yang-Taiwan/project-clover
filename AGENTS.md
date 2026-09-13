# AGENTS.md

## Purpose

This file is the routing layer for AI coding agents working in Project Clover. Keep it short. Load deeper instructions only when the task needs them.

Project product intent lives in `docs/01_Project_Clover_Handbook.md`. Read it when a change can affect product behavior, user value, prioritization, reminders, redemption, value tracking, or user-facing workflow.

## Core operating principles

- Minimum instructions. Maximum judgment.
- Pull only the context needed for the next reliable decision or action.
- Prefer the lowest-complexity execution path that can reliably complete the task.
- Do not preload unrelated architecture, database, deployment, testing, or product documents.
- One concern should have one canonical rule owner. Do not duplicate policy text across files.
- No PASS without verifiable evidence.
- Agent self-report, reasoning text, or statements such as “done”, “looks good”, or “should work” are not evidence.

## Default task loop

Understand → Implement → Execute → Verify → Fix → Re-verify.

A code edit is not complete by itself. Completion requires the expected state to be verified with appropriate evidence.

## Context routing

Load only what applies:

- Product behavior / UX / MVP scope → `docs/01_Project_Clover_Handbook.md`
- Execution modality, implementation scope, autonomy → `docs/agent/execution-policy.md`
- Tests, build results, screenshots, logs, diffs, completion proof → `docs/agent/evidence-policy.md`
- Permissions, destructive actions, production, auth, security, external side effects → `docs/agent/risk-permission-policy.md`
- What to read, what not to preload, cross-task context → `docs/agent/context-policy.md`
- Failure handling, recovery, stop conditions, escalation → `docs/agent/stop-escalation-policy.md`
- Skill creation / trigger design → `docs/agent/skill-guidelines.md`

Do not read every linked file for every task.

## Safe autonomy

Within the approved task scope, the agent may normally perform reversible local actions without pausing for confirmation, including:

- edit local repository files
- format
- lint
- run local tests
- build
- debug
- fix test failures with known causes
- correct obvious implementation defects
- rerun validation

Stop for approval when an action involves production deployment, destructive data operations, irreversible external effects, secrets or credentials, payment, authentication or authorization changes, security-sensitive changes, external send/publish/submit, or a major architecture change outside the approved scope.

## Change discipline

Prefer, in order:

1. Minimal patch
2. Local refactor
3. Architecture change

Do not expand scope merely because adjacent improvements are available.

If a task uncovers unrelated defects, record them separately unless they block the requested outcome.

## Validation

Use evidence proportional to risk. Relevant evidence may include tests, build/lint results, Git diff, logs, screenshots/UI state, API responses, generated artifacts, external system state, or independent review.

If verification is unavailable or inconclusive, report `NEEDS CONFIRMATION` rather than `PASS`.

## Failure handling

Every blocked step resolves to one of:

- CONTINUE
- RECOVER
- STOP
- ESCALATE

Recover only when the root cause is known and the fix stays within approved scope. Do not guess through unknown high-impact failures.

## Skills

Skills must be narrow and task-triggered. Do not create broad catch-all skills. A skill should define purpose, precise trigger, required input, critical constraints, next context to load, and expected output. Keep long examples and edge cases out of always-loaded instructions.

## Final report

For meaningful implementation work, summarize:

- changed files
- verification performed
- failures found and fixes applied
- known risks / unresolved issues
- final status: PASS / CONDITIONAL PASS / FAIL
