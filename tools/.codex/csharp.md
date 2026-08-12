# C# AI Development Instructions

Use these instructions with `AGENTS.md` for C# and .NET codebases.

## Applies To

- C# application code
- ASP.NET APIs
- Worker services
- Shared libraries
- Unit and integration tests

## Coding Standards

- Follow established project conventions before introducing new patterns.
- Prefer clear domain names over abbreviations.
- Use nullable reference types intentionally and handle possible `null` values explicitly.
- Prefer immutable models and records where they improve clarity.
- Keep methods small and focused on one behavior.
- Use asynchronous APIs for I/O-bound work and propagate `CancellationToken` where appropriate.
- Avoid blocking on async code with `.Result`, `.Wait()`, or similar patterns.
- Prefer dependency injection for external services, configuration, logging, and time providers.
- Keep LINQ readable; use named intermediate values when query logic becomes hard to scan.

## Architecture

- Keep controllers and endpoints thin.
- Put business rules in services or domain components.
- Separate transport models, domain models, and persistence models when their responsibilities differ.
- Avoid static global state except for pure helpers or framework-required constants.
- Prefer interfaces at boundaries that need substitution in tests or alternate implementations.

## Error Handling and Logging

- Throw specific exceptions or return explicit result types when failures are expected.
- Preserve inner exceptions when wrapping errors.
- Log meaningful context without logging secrets, tokens, raw connection strings, or sensitive payloads.
- Include `[ClassName].[MethodName]` in log messages or structured logging fields when practical.
- Use structured logging properties instead of string interpolation for values that should be queryable.

## Security

- Validate request input at service boundaries.
- Use parameterized queries or ORM parameter binding for data access.
- Enforce authentication and authorization at the correct boundary.
- Avoid exposing stack traces or internal exception details to callers.
- Store secrets in approved secret stores or configuration providers, never in source files.

## Testing

- Use unit tests for business rules and edge cases.
- Use integration tests for framework wiring, persistence, serialization, and authorization behavior.
- Cover success paths, validation failures, exception paths, boundary values, and regression cases.
- Prefer deterministic tests that do not depend on wall-clock time, shared mutable state, or test order.

## Review Checklist

- Thranduil verifies C# idioms, type safety, async correctness, static analysis concerns, resource cleanup, and maintainability.
- Magus verifies the code is readable, consistent with the project architecture, and documented where behavior changed.
- Sauron challenges null handling, invalid input, cancellation, race conditions, dependency failures, and missing regression tests.
