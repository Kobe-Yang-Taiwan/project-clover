# Risk & Permission Policy

## Purpose

Classify actions by impact and reversibility, then decide whether the agent may proceed autonomously.

## Default rule

Low-risk, reversible, repository-local actions inside approved scope may proceed without repeated confirmation.

## Major / critical actions

Require explicit approval before:

- production deployment
- destructive data changes
- deleting or overwriting important external data
- payment or purchase
- authentication or authorization changes
- secrets, credentials, or key rotation
- security-sensitive configuration changes
- external publish, send, submit, or irreversible integration actions
- major architecture changes outside approved scope

## Decision path

Action → Classify impact/reversibility → Risk level → Permission check → Execute / Request approval / Block.

## Risk levels

- **Low**: reversible and local; normally autonomous.
- **Major**: meaningful blast radius but recoverable; proceed only when clearly within approved scope and permission.
- **Critical**: destructive, security-sensitive, financial, production, private-data, or otherwise high-impact; human approval required.

## Release guardrail

Unresolved Critical risk means `NO-GO` for release or deployment.
