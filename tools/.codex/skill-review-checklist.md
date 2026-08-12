# Skill Review Checklist

Use this checklist before publishing or updating a shared AI assistant skill.

## General Review

- The skill has a clear purpose and bounded scope.
- The activation description is specific enough to avoid unrelated triggers.
- The skill explains required inputs, workflow steps, validation, and completion criteria.
- The skill avoids secrets, personal notes, local paths, and environment-specific assumptions.
- Optional resources directly support the workflow and are not duplicated in `SKILL.md`.
- Any scripts have been tested with representative input.

## Thranduil Review

Thranduil verifies engineering quality:

- Skill structure is maintainable.
- Naming is consistent and readable.
- Instructions are concise and actionable.
- Resource folders are justified.
- Scripts are deterministic and defensively coded.
- Validation catches likely implementation mistakes.
- Dead or placeholder content has been removed.

## Magus Review

Magus verifies future maintainability:

- The skill is understandable by future team members.
- The workflow matches existing team practices.
- Boundaries with related skills or prompt files are clear.
- Required documentation is present but not excessive.
- Examples clarify behavior without bloating the skill.
- Ownership and update expectations are clear.

## Sauron Review

Sauron tries to break the skill:

- What unrelated requests might accidentally trigger this skill?
- What required context might be missing?
- What unsafe tool permissions could be requested?
- What happens with ambiguous or incomplete user input?
- What happens if a script, reference file, API, or external system is unavailable?
- What validation gap would let a bad result appear successful?
- What stale resource or obsolete workflow could mislead the assistant?

## Release Decision

Publish or update the skill only when:

- Critical and High findings are resolved.
- Medium findings are resolved or explicitly deferred with a reason.
- Validation has been run or the limitation is documented.
- The owning team agrees the skill is ready for shared use.
