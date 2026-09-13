# Stop & Escalation Policy

## Purpose

Prevent both premature stopping and unsafe guessing.

## Allowed states

Each blocked or uncertain step resolves to one of:

- CONTINUE
- RECOVER
- STOP
- ESCALATE

## RECOVER

Recover when:

- the root cause is known
- the fix is within approved scope
- the fix is reversible or otherwise low-risk
- the expected state can be re-verified after the fix

Use the smallest reliable fix, then rerun validation.

## STOP

Stop when any of the following applies:

- unknown root cause with meaningful impact
- scope violation
- unresolved Critical risk
- insufficient evidence for a reliable conclusion
- required permission is missing
- expected state cannot be reliably verified

Do not guess through a STOP condition.

## ESCALATE

Escalate only when the current capability, tool, context, permission, evidence, or role separation is insufficient.

Choose the smallest necessary escalation, for example:

- load one additional document
- use a more appropriate tool
- add a specialized Skill
- request human approval
- request independent review

Do not escalate to multi-agent or complex orchestration merely for formality.
