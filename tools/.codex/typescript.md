# TypeScript AI Development Instructions

Use these instructions with `AGENTS.md` for TypeScript codebases.

## Applies To

- TypeScript application code
- Frontend and backend TypeScript services
- Shared packages
- Build and tooling scripts
- Unit and integration tests

## Coding Standards

- Prefer explicit types at public boundaries.
- Let local inference reduce noise when the inferred type is obvious.
- Avoid `any`; use `unknown` and narrow it safely when input is not trusted.
- Keep functions small and side effects explicit.
- Prefer discriminated unions for state that has distinct variants.
- Avoid non-null assertions unless the invariant is proven nearby.
- Use `readonly` or immutable patterns where they clarify ownership.
- Keep asynchronous code clear and handle rejected promises intentionally.

## Architecture

- Separate domain logic from framework, transport, and persistence code.
- Keep shared types close to the boundary they describe.
- Avoid circular imports.
- Prefer dependency injection or explicit parameters for services, clients, clocks, and configuration.
- Keep module exports intentional and stable.

## Error Handling and Logging

- Validate unknown external input before using it as a typed object.
- Return explicit result shapes or throw specific errors according to project convention.
- Preserve useful diagnostic context.
- Never log secrets, tokens, sensitive payloads, or raw credentials.
- Include class, function, component, or module context in log messages when practical.

## Security

- Treat browser, API, file, and message payloads as untrusted until validated.
- Encode output according to the rendering context.
- Avoid unsafe dynamic execution.
- Keep dependency additions minimal and review transitive risk.

## Testing

- Cover happy paths, validation failures, rejected promises, edge states, and regression cases.
- Include tests for type guards and parsing logic.
- Prefer deterministic tests that do not depend on timers, network, or shared global state unless controlled.

## Review Checklist

- Thranduil verifies type safety, async handling, maintainability, dependency choices, and dead code.
- Magus verifies module boundaries, naming, readability, and documentation for public interfaces.
- Sauron challenges invalid input, impossible states, race conditions, rejected promises, stale state, and untested edge cases.
