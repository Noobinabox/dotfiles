# Pulumi TypeScript AI Development Instructions

Use these instructions with `AGENTS.md` and `typescript.md` for Pulumi infrastructure-as-code projects written in TypeScript.

## Applies To

- Pulumi TypeScript programs
- `Pulumi.yaml` and stack configuration files
- Provider setup and resource modules
- Component resources and shared infrastructure libraries
- Stack outputs, imports, aliases, and state-sensitive changes
- CI/CD preview, update, and deployment workflows
- Infrastructure tests and operator documentation

## Coding Standards

- Follow established project conventions before introducing new patterns.
- Use explicit types at module and component boundaries.
- Keep Pulumi `Input` and `Output` values in Pulumi-aware flows; avoid converting them to plain values outside supported callbacks.
- Prefer small component resources or modules when they clarify ownership and reuse.
- Keep program evaluation deterministic and free of unrelated network, filesystem, or time-dependent side effects.
- Avoid hidden dependencies between resources; express dependencies through resource relationships, inputs, parents, or explicit `dependsOn` when needed.
- Keep configuration names, defaults, and required values clear.

## Architecture

- Separate stack configuration, provider configuration, resource definitions, components, and deployment pipeline logic.
- Keep stack and environment boundaries explicit.
- Define ownership, parent-child relationships, providers, aliases, imports, and protect flags intentionally.
- Export only outputs that operators or downstream stacks need.
- Avoid coupling unrelated cloud services through shared mutable config or broad helper modules.
- Document public modules, stack outputs, migration steps, and operational runbooks when behavior changes.

## Config, Secrets, and Deployment Safety

- Use Pulumi secret configuration or `pulumi.secret(...)` for sensitive values.
- Never place secrets in source files, plaintext stack config, logs, command output, documentation examples, or non-secret stack outputs.
- Separate "defined in code" from "deployed in cloud" unless cloud state was verified.
- Run `pulumi preview` before `pulumi up` for deployment-impacting changes.
- Treat `pulumi up`, imports, deletes, provider changes, and resource recreation as explicit deployment actions.
- Review lifecycle risk for deletes, replacements, renames, aliases, provider changes, `protect`, and drift-sensitive resources.

## Error Handling and Logging

- Fail with actionable messages when required config, credentials, providers, or stack assumptions are missing.
- Preserve useful context for provider, deployment, and serialization failures.
- Avoid logging secrets, credentials, raw connection strings, tokens, or sensitive resource properties.
- Include module, component, stack, or resource context in diagnostics when practical.

## Security

- Use least-privilege provider credentials and cloud permissions.
- Review identity, role assignment, network, firewall, storage, key vault, and secret-access changes closely.
- Validate externally supplied config values before using them in names, paths, policies, or access rules.
- Keep dependency additions minimal and review transitive risk.
- Do not claim cloud permissions, secrets, or resources are present unless verified by Pulumi output, cloud query, or deployment evidence.

## Testing and Validation

- Run the consuming project's install, type-check, lint, tests, and Pulumi validation commands when available.
- Select or confirm the intended stack before previewing.
- Prefer `pulumi preview` for infrastructure changes and reserve `pulumi up` for approved deployments in the right environment.
- If TypeScript validation fails because of Node heap limits, retry with an explicit `NODE_OPTIONS=--max-old-space-size=<size>` and document the command used.
- If cloud validation cannot run locally, document the exact stack, credentials, command, or environment validation still needed.

## Review Checklist

- Thranduil verifies TypeScript quality, Pulumi `Input` and `Output` handling, provider usage, deterministic evaluation, dependency choices, and maintainability.
- Magus verifies stack structure, naming, module boundaries, operator documentation, deployment workflow clarity, and consistency with existing infrastructure patterns.
- Sauron challenges secret exposure, accidental deletes, resource recreation, drift, missing aliases or imports, wrong-stack deployment, provider credential assumptions, and untested failure paths.
