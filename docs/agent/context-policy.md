# Context Policy

## Purpose

Load the minimum sufficient context needed for the next reliable decision or action.

## Pull, do not push

Default context should include only what is relevant to the current task:

- goal
- current state
- constraints
- relevant product or architecture rules
- required files/objects
- evidence already available
- open issues that affect the task

Do not preload the entire repository history, all documentation, all failed attempts, unrelated debug output, or every Skill.

## On-demand loading

Examples:

- product/UX behavior → read the Product Handbook
- database schema change → load database-specific instructions if they exist
- deployment → load deployment instructions if they exist
- architecture change → load architecture constraints
- tests → load the relevant test instructions
- a specialized repeated workflow → load its Skill

If context is insufficient, pull the next smallest relevant source rather than loading everything.

## Cross-task handoff

Prefer referencing work products and evidence over copying complete conversations. A handoff should carry goal, output, evidence reference, known risks, unresolved issues, acceptance status, and next task.

## Rule

Reference the work product, not the entire conversation.
