# Angular AI Development Instructions

Use these instructions with `AGENTS.md` for Angular applications.

## Applies To

- Angular components
- Services
- Routes and guards
- Forms
- State management
- Unit and integration tests

## Coding Standards

- Follow the project's Angular version, style guide, and existing component patterns.
- Keep components focused on presentation and interaction.
- Put reusable business logic, API access, and shared state in services or dedicated modules.
- Use strong typing for inputs, outputs, services, route data, and API models.
- Prefer reactive patterns consistently when the project uses RxJS.
- Manage subscriptions safely with async pipes, framework lifecycle helpers, or explicit teardown.
- Avoid large templates with complex inline expressions.
- Keep accessibility and keyboard behavior in mind for interactive UI.

## Architecture

- Keep feature boundaries clear.
- Prefer reusable presentational components for repeated UI patterns.
- Keep routing, authorization, and data-loading behavior explicit.
- Avoid coupling components directly to unrelated feature services.
- Use dependency injection for services, clients, configuration, and adapters.

## Error Handling and Logging

- Handle API loading, empty, error, and success states.
- Surface user-facing errors that are actionable and safe.
- Preserve diagnostic details in logs or telemetry without exposing secrets.
- Include component, service, and method context in logs where practical.

## Security

- Treat route parameters, query parameters, form input, and API responses as untrusted.
- Avoid bypassing Angular sanitization unless the source is controlled and the risk is documented.
- Enforce authorization in backend services; frontend guards improve UX but are not security boundaries.
- Never store secrets in frontend code.

## Testing

- Test component rendering, input and output behavior, service interactions, route behavior, and error states.
- Cover form validation, empty data, loading states, permission states, and API failures.
- Prefer stable selectors and avoid brittle DOM assertions.
- Include accessibility checks where the component introduces meaningful UI behavior.

## Review Checklist

- Thranduil verifies Angular idioms, subscription safety, type safety, maintainability, and resource cleanup.
- Magus verifies component boundaries, readability, UX state clarity, and documentation for public behavior.
- Sauron challenges failed API calls, empty data, rapid user interaction, stale state, permission gaps, sanitization, and missing UI state tests.
