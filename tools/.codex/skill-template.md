# Skill Template

Use this template when creating a new shared AI assistant skill. Replace bracketed placeholders before publishing.

```markdown
---
name: [skill-name]
description: [What this skill does and the exact contexts that should trigger it. Include when to use the skill here because this metadata drives activation.]
---

# [Skill Display Name]

Use this skill to [short purpose statement].

## Required Context

- [Input, file, system, or artifact the assistant must inspect first]
- [Required user-provided information]
- [Project or environment prerequisite]

## Workflow

1. [First inspection or discovery step]
2. [Main action step]
3. [Validation step]
4. [Review or completion step]

## Resource Usage

- Use `references/[file].md` when [condition].
- Use `scripts/[script-name]` when [condition].
- Use `assets/[asset-name]` when [condition].

Delete any unused resource guidance before publishing the skill.

## Validation

- [Command, check, or review required before completion]
- [Expected output or acceptance condition]
- [Failure handling expectation]

## Completion Criteria

- [Required artifact exists or change is complete]
- [Validation has passed or limitation is documented]
- [Review requirement is complete]
```

## Authoring Notes

- Use lowercase letters, digits, and hyphens for the skill name.
- Keep only `name` and `description` in frontmatter unless the target platform requires more.
- Keep `SKILL.md` concise and move detailed supporting material into resources.
- Do not include secrets, personal notes, machine-specific paths, or unrelated documentation.
- Add only resource folders that the skill actually uses.
