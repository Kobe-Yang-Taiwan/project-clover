# Agent Architecture

## Goal

Project Clover uses a small routing layer plus on-demand policy documents. `AGENTS.md` is the table of contents, not the encyclopedia.

## Current architecture

```text
Task
  ↓
AGENTS.md
  ↓
Load only relevant product/policy context
  ↓
Execute within approved scope
  ↓
Collect external evidence
  ↓
PASS / CONDITIONAL PASS / FAIL
```

## Canonical owners

| Concern | Canonical owner |
| --- | --- |
| Product mission, MVP value, product principles | `docs/01_Project_Clover_Handbook.md` |
| Execution and implementation autonomy | `docs/agent/execution-policy.md` |
| Evidence and completion validation | `docs/agent/evidence-policy.md` |
| Risk and permission boundaries | `docs/agent/risk-permission-policy.md` |
| Context loading and handoff boundaries | `docs/agent/context-policy.md` |
| Recovery, stop, and escalation | `docs/agent/stop-escalation-policy.md` |
| Skill structure and trigger quality | `docs/agent/skill-guidelines.md` |

## Before / After audit

### Before

The repository contained only a minimal README and product handbook. There was no `AGENTS.md`, no Agent policy map, and no Skills governance to refactor. Therefore this cleanup does **not** delete or rewrite legacy Agent rules; it establishes a minimal canonical baseline for future Codex work.

### After

- Root `AGENTS.md` stays concise and routes context on demand.
- Shared policies live in one canonical place each.
- Low-risk, reversible local work is autonomous.
- High-impact external or irreversible actions require approval.
- Completion is evidence-based.
- Skills are added only when a recurring task justifies them.

## Rule ownership discipline

When adding a new rule:

1. Identify its concern.
2. Put it in the existing canonical owner when one exists.
3. Reference the rule elsewhere instead of copying it.
4. Create a new policy file only if the concern cannot reasonably belong to an existing owner.

## Architecture guardrail

Do not add layers, agents, skills, or workflow documents merely because they are available. Add them only when they improve decision quality, execution reliability, or repeated task efficiency.
