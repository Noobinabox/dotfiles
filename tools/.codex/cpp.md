# C++ AI Development Instructions

Use these instructions with `AGENTS.md` for C++ application, library, and native build changes.

## Applies To

- C++ application code
- Native libraries and shared modules
- Public headers and ABI-sensitive interfaces
- CMake, Make, MSBuild, and compiler configuration
- Platform integration code
- Unit, integration, and native runtime tests

## Coding Standards

- Follow established project conventions before introducing new patterns.
- Prefer modern C++ language and standard library features that are already supported by the project toolchain.
- Use RAII for resource ownership and cleanup.
- Prefer smart pointers for owning references and raw pointers or references only for non-owning access.
- Make ownership, lifetime, move, and copy behavior explicit.
- Use `const` where it communicates intent and protects invariants.
- Avoid global mutable state, hidden initialization order dependencies, and broad preprocessor macros.
- Keep functions small, focused, and easy to reason about.
- Avoid undefined behavior, unchecked narrowing, unsafe casts, and unchecked buffer access.

## Architecture

- Separate public headers, implementation details, platform adapters, and build configuration.
- Keep API and ABI boundaries stable and documented when external callers depend on them.
- Isolate compiler-specific, operating-system-specific, and architecture-specific code.
- Avoid circular dependencies between libraries and modules.
- Keep thread ownership, synchronization strategy, and shutdown behavior explicit.
- Prefer clear dependency boundaries over broad shared utility modules.

## Error Handling and Logging

- Follow the project's exception or result-code convention consistently.
- Preserve diagnostic context when wrapping or translating failures.
- Design exception-safe resource handling, especially around constructors, destructors, moves, and callbacks.
- Log actionable context without logging secrets, tokens, credentials, or sensitive payloads.
- Include class, function, subsystem, or module context in log messages when practical.

## Security

- Validate external input before parsing, indexing, allocating, or using it in system calls.
- Check buffer sizes, integer ranges, path handling, encodings, and allocation limits.
- Avoid unsafe string and memory APIs when safer project-approved alternatives exist.
- Treat file paths, environment variables, command arguments, network data, and plugin inputs as untrusted.
- Review native dependency updates for supply-chain, licensing, and binary compatibility risk.
- Use least privilege for filesystem, process, network, and device access.

## Testing

- Cover success paths, invalid input, boundary values, ownership transfer, and failure cleanup.
- Add regression tests for fixed memory, parsing, threading, or platform bugs.
- Use sanitizers, static analysis, compiler warnings, or runtime diagnostics when the changed area has memory or concurrency risk.
- Include cross-platform or compiler validation when behavior differs by operating system, architecture, or toolchain.
- Keep tests deterministic and avoid timing-sensitive assertions unless timing is the behavior under test.

## Review Checklist

- Thranduil verifies C++ idioms, RAII, type safety, warning hygiene, static analysis concerns, resource cleanup, and maintainability.
- Magus verifies module boundaries, API clarity, naming, build consistency, documentation, and portability.
- Sauron challenges undefined behavior, invalid input, null and lifetime assumptions, races, overflow, partial failures, and missing regression tests.
