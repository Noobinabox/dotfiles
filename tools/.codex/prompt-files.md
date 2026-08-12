# Prompt File AI Development Instructions

Use these instructions with `AGENTS.md` for prompt files, system instructions, agent instructions, and reusable AI task guidance.

## Applies To

- System prompts
- Developer prompts
- Agent behavior instructions
- Reusable prompt templates
- Evaluation prompts
- Prompt fragments stored in source control

## Writing Standards

- State the goal, audience, and expected output clearly.
- Use imperative, testable instructions.
- Prefer concrete examples when ambiguity would otherwise remain.
- Separate durable rules from task-specific context.
- Avoid vague quality terms unless paired with observable criteria.
- Avoid conflicting instructions; when precedence matters, state it explicitly.
- Keep prompts concise enough to maintain, but complete enough to prevent repeated misuse.

## Structure

- Put high-priority behavioral rules near the top.
- Group related instructions under clear headings.
- Define input assumptions and expected output format.
- Include refusal, escalation, or uncertainty-handling rules when relevant.
- Keep reusable prompt files free of personal notes, environment-specific paths, and secrets.

## Safety and Security

- Do not include credentials, tokens, internal secrets, or sensitive examples.
- Instruct agents not to expose secrets in logs, output, or generated artifacts.
- Avoid prompt content that asks agents to bypass authorization, policy, or review workflows.
- Document any data sensitivity assumptions.

## Testing and Evaluation

- Test prompts against representative happy path, ambiguous, adversarial, and failure scenarios.
- Add regression examples when prompt behavior is corrected.
- Verify output format compliance when downstream automation depends on structure.
- Review whether the prompt causes overreach, hallucination, or unsupported assumptions.

## Review Checklist

- Thranduil verifies instruction clarity, consistency, maintainability, and absence of contradictory rules.
- Magus verifies future maintainers can understand the prompt's purpose, scope, and expected output.
- Sauron challenges ambiguous phrasing, jailbreak surface area, unsafe defaults, missing refusal paths, and brittle output formatting.
