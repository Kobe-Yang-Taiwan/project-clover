# Execution Policy

## Purpose

Define how an agent chooses the minimum reliable execution path and how much autonomy it has inside an approved task.

## Standard loop

Task → Define goal → Select minimum capability → Define allowed scope → Execute → Observe result → Verify expected state → Recover or escalate if needed.

## Execution principles

- Prefer the simplest reliable modality.
- Keep planning and execution together unless risk requires separation.
- Prefer outcome-based contracts over step-by-step micromanagement.
- Do not pause after every small step.
- Do not broaden scope just because additional improvements are visible.
- Prefer Minimal Patch → Local Refactor → Architecture Change.

## Safe autonomous actions

Within approved scope, an agent may normally perform reversible repository-local actions such as editing files, formatting, linting, running tests, building, debugging, fixing known test failures, correcting obvious implementation defects, and rerunning validation.

## Human approval boundary

Approval is required before actions with material external or irreversible impact, including production deployment, destructive data changes, credential or secret changes, payment, auth/security-sensitive changes, external publish/send/submit, or major architecture expansion outside scope.

## Completion expectation

An implementation is not complete until the expected result has been executed or otherwise validated where feasible. If the task cannot be reliably executed or verified, do not claim completion.
