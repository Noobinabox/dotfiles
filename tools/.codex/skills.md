# Skills AI Development Instructions

Use these instructions with `AGENTS.md` for AI assistant skills, reusable task workflows, and skill documentation.

## Applies To

- Skill instruction files
- Skill packages
- Reusable AI workflows
- Tool-routing guidance
- Skill examples and templates

## What Skills Provide

Skills package specialized workflow knowledge so an AI assistant can perform a recurring task consistently without rediscovering domain rules each time.

Use a skill when the team needs reusable guidance for:

- Multi-step workflows
- Domain-specific procedures
- Tool or file-format handling
- Company or product standards
- Reusable scripts, references, templates, or assets

Do not create a skill for one-off instructions, generic coding advice, or information that belongs in project documentation.

## Design Standards

- Define exactly when the skill should be used.
- Keep trigger rules specific enough to avoid accidental activation.
- State required inputs, expected outputs, and completion criteria.
- Prefer small composable skills over broad catch-all skills.
- Include examples only when they clarify behavior or prevent misuse.
- Keep instructions portable and free of personal notes, secrets, or machine-specific paths.
- Keep the main skill instructions concise; move detailed reference material into linked resource files.
- Match the amount of detail to the risk of the workflow. Fragile workflows need stronger guardrails.

## Recommended Structure

A skill should include a required `SKILL.md` file and only the optional resources that directly support the skill.

Recommended layout:

```text
skill-name/
├── SKILL.md
├── platform/
├── scripts/
├── references/
└── assets/
```

Use:

- `SKILL.md` for essential trigger metadata and workflow instructions.
- `platform/` for assistant-specific metadata when the platform supports it.
- `scripts/` for deterministic or repeatedly generated automation.
- `references/` for detailed documentation loaded only when needed.
- `assets/` for templates, sample files, images, or other output resources.

Avoid extra files such as `README.md`, changelogs, installation guides, or duplicate quick references unless the target platform specifically requires them.

## SKILL.md Requirements

For the default shared format, every `SKILL.md` should contain YAML frontmatter with at least:

- `name`: lowercase skill name using letters, digits, and hyphens.
- `description`: what the skill does and the exact contexts that should trigger it.

Platform-specific metadata may be added when required by the target assistant platform.

Activation behavior varies by assistant platform. Put the most important "when to use" guidance in the most visible metadata or summary field, not only in the body.

The body should include:

- Required inspection or discovery steps.
- Workflow steps.
- Rules for using bundled resources.
- Validation requirements.
- Failure handling.
- Completion criteria.

Use imperative language and avoid long background explanations.

## Trigger Design

Good triggers are specific, action-oriented, and bounded.

Prefer descriptions that include:

- The task type
- The target artifact or system
- The contexts where the skill should activate
- Important exclusions when overlap is likely

Avoid descriptions that are:

- So broad they activate for unrelated work
- Dependent on body text that is not loaded until after activation
- Duplicative with another skill
- Framed around internal implementation details instead of user intent

When two skills could apply, make the boundary explicit in at least one description.

## Progressive Disclosure

Keep the default loaded instructions small. Put only essential workflow guidance in `SKILL.md`.

Some assistant platforms load only metadata before deciding whether to use a skill, while others load the full file. Design for the stricter case by keeping activation intent visible before detailed workflow guidance.

Move detailed material into:

- `references/` when the assistant may need documentation, schemas, policies, examples, or domain rules.
- `scripts/` when a repeated operation should be deterministic.
- `assets/` when final output requires reusable files or templates.

If a reference file becomes long, add a short table of contents so the assistant can quickly decide which section is relevant.

Keep references one level deep from `SKILL.md` where practical.

## Workflow Guidance

- Tell the assistant what to inspect before acting.
- Distinguish read-only planning steps from mutating implementation steps.
- Specify when to ask the user for clarification and when to proceed with defaults.
- Define how to validate the work before completion.
- Document review expectations, especially when a domain expert or secondary reviewer is required.
- State what artifacts the assistant should produce.
- State what artifacts the assistant must not change.
- Include cleanup expectations for temporary outputs or generated files.

## Tool and Dependency Guidance

- Use existing project tools and conventions before introducing new ones.
- Document required tools, permissions, and external systems.
- Keep tool usage scoped to the skill's purpose.
- Avoid instructions that require broad or unnecessary privileges.
- Prefer scripts for fragile repeated operations.
- Test any included script with representative input before relying on it.

## Testing and Evaluation

- Test the skill with representative user requests.
- Include ambiguous, underspecified, and failure-path examples.
- Verify the skill does not trigger for unrelated work.
- Confirm generated output follows required formats.
- Include expected activation and expected non-activation examples.
- Forward-test complex skills with fresh context when practical.
- Evaluate whether the skill works from raw artifacts, not hidden assumptions.
- Add regression examples when a skill is updated to correct a recurring failure.

## Ownership and Maintenance

- Assign an owner or owning team for every shared skill.
- Record behavior changes in the consuming repository or team documentation.
- Update the skill when review feedback reveals repeated ambiguity or missing validation.
- Deprecate skills that are replaced, obsolete, or too broad to trigger safely.
- Revalidate skills after major platform, tool, or workflow changes.

## Review Checklist

- Thranduil verifies the skill is maintainable, scoped, consistent, and free of unnecessary complexity.
- Magus verifies the skill is understandable, reusable, and documented for future maintainers.
- Sauron challenges trigger ambiguity, missing prerequisites, unsafe tool usage, unclear completion criteria, and failure handling.
