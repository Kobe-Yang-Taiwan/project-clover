# Evidence Policy

## Purpose

Define what counts as proof that work is complete and correct enough to pass.

## Core rule

No PASS without verifiable evidence.

AI reasoning, self-report, summaries, or statements such as “done”, “tested”, “looks good”, or “should work” do not count as execution evidence by themselves.

## Standard validation

Expected State → External Evidence → Validation → PASS / NEEDS CONFIRMATION / FAIL.

## Acceptable evidence

Use evidence appropriate to the task, including:

- test results
- build results
- lint/static-analysis results
- Git diff
- logs
- screenshots or UI state
- API responses
- database or external-system state
- generated files/artifacts
- simulation or analysis results
- independent reviewer result

## Evidence strength

Match evidence strength to risk. A documentation edit may only need diff/content verification. A high-impact implementation may require tests, build, runtime evidence, and independent review.

## Progress

Progress should be based on verified completed outcomes, not the agent’s estimate of percentage complete.

## Inconclusive verification

When the expected state cannot be reliably observed, use `NEEDS CONFIRMATION`. Do not convert missing evidence into a PASS.
