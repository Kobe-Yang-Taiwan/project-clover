# Skill Guidelines

## Purpose

Define when Project Clover should create or load a reusable Agent Skill.

## Create a Skill only when

A workflow is repeated, specialized, and benefits from consistent task-specific instructions, resources, or scripts.

Do not create a Skill merely to restate global project policy.

## Required Skill structure

Each Skill should make these elements explicit:

- **Purpose** — what the Skill is for
- **Trigger** — the precise situation that should activate it
- **Required Inputs** — what must be available before running it
- **Critical Constraints** — task-specific boundaries only
- **Next Context to Load** — only the docs/resources actually needed
- **Expected Output** — what successful execution produces
- **Validation** — how success is verified

## Trigger quality

Prefer specific situational triggers over broad keywords.

Good examples:

- “Use when changing a database schema or migration.”
- “Use when preparing a production deployment.”
- “Use when validating screenshot/PDF import behavior.”

Avoid triggers such as “use for backend work” or “use for testing,” which are too broad and likely to load unnecessary context.

## Progressive disclosure

Keep Skill metadata and root instructions short. Put long examples, scripts, troubleshooting, and edge cases in secondary files and load them only when the active task needs them.

## Policy reuse

Skills should reference the canonical Execution, Evidence, Risk & Permission, Context, and Stop & Escalation policies rather than duplicating them.

## Current repository status

At the time this baseline was created, Project Clover did not contain existing Skills. Do not invent placeholder Skills. Add the first Skill only when a real recurring workflow justifies it.
