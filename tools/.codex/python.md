# Python AI Development Instructions

Use these instructions with `AGENTS.md` for Python codebases.

## Applies To

- Python application code
- Data engineering scripts
- Libraries and packages
- Automation scripts
- Unit and integration tests

## Coding Standards

- Follow the project's formatter, linter, and type-checking conventions.
- Prefer readable functions with explicit inputs and outputs.
- Use type hints for public functions and complex data structures.
- Keep side effects isolated from pure transformation logic.
- Prefer standard library functionality before adding dependencies.
- Avoid mutable default arguments.
- Avoid broad `except Exception` blocks unless the handler adds context and re-raises or safely recovers.
- Use context managers for files, connections, locks, and other managed resources.

## Architecture

- Separate orchestration, business logic, and I/O.
- Keep notebooks, scripts, and command-line entrypoints thin when reusable logic belongs in modules.
- Prefer dataclasses, typed dictionaries, or Pydantic models when structured data needs validation or clarity.
- Make configuration explicit and injectable.
- Avoid importing modules for their side effects.

## Error Handling and Logging

- Raise specific exceptions with actionable messages.
- Preserve traceback context unless intentionally converting an expected failure.
- Log useful identifiers and execution context.
- Never log secrets, tokens, raw credentials, or sensitive records.
- Include module, class, and function context in loggers or messages where practical.

## Security

- Validate and sanitize external input.
- Use parameterized APIs for SQL and command execution.
- Avoid shell execution unless necessary; when required, pass arguments safely.
- Read secrets from approved secret stores or environment-specific configuration, not committed files.
- Review dependencies for known vulnerabilities and unnecessary transitive risk.

## Testing

- Use focused unit tests for transformation logic.
- Use integration tests for file systems, databases, APIs, queues, and cloud services.
- Cover empty inputs, malformed inputs, missing fields, large data, and dependency failures.
- Mock external services at stable boundaries.
- Keep tests deterministic and avoid reliance on local machine state.

## Review Checklist

- Thranduil verifies Python idioms, type clarity, resource management, dependency choices, and maintainability.
- Magus verifies the implementation is easy to follow, modular, documented where needed, and consistent with existing project layout.
- Sauron challenges malformed input, empty collections, large input, dependency outages, retries, idempotency, and missing failure-path tests.
