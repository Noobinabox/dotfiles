# AGENTS.md

Universal development standards and multi-agent review workflow.

This file is intended to be portable across projects regardless of language or framework. Project-specific standards should augment, not replace, these guidelines.

## Technology-Specific Instructions

Use these universal standards with any technology-specific instruction files that match the files being changed. When adopting this instruction set in another project or repository, copy or link this `AGENTS.md` file plus every relevant language or workflow file for that codebase. Keep the linked files beside `AGENTS.md`, or rewrite the links if the consuming repository stores them elsewhere:

- [`csharp.md`](csharp.md) for C# and C#-based .NET code
- [`cpp.md`](cpp.md) for C++ applications, native libraries, and native build files
- [`python.md`](python.md) for Python code
- [`sql.md`](sql.md) for SQL scripts, stored procedures, views, and queries
- [`typescript.md`](typescript.md) for TypeScript code
- [`angular.md`](angular.md) for Angular applications
- [`electron.md`](electron.md) for Electron desktop applications
- [`pulumi-typescript.md`](pulumi-typescript.md) for Pulumi infrastructure-as-code projects written in TypeScript
- [`databricks-notebooks.md`](databricks-notebooks.md) for Databricks notebooks
- [`prompt-files.md`](prompt-files.md) for prompt and AI instruction files
- [`skills.md`](skills.md) for AI assistant skills

For scoped changes, use the files that match the changed artifacts. For repo-wide or cross-cutting work, include every technology-specific file that matches the repository's active implementation areas. When multiple technologies are involved, apply every relevant file alongside this `AGENTS.md`.

More specific guidance takes precedence over broader guidance for the same artifact. For example, use [`angular.md`](angular.md) over [`typescript.md`](typescript.md) for Angular files, [`electron.md`](electron.md) over [`typescript.md`](typescript.md) for Electron-specific files, [`pulumi-typescript.md`](pulumi-typescript.md) over [`typescript.md`](typescript.md) for Pulumi infrastructure files, [`databricks-notebooks.md`](databricks-notebooks.md) over [`python.md`](python.md) or [`sql.md`](sql.md) for notebook files, and domain or workflow guidance over language guidance when both apply to the same prompt, skill, notebook, or generated artifact. Project-specific repository instructions override these shared defaults when they conflict.

## Core Philosophy

Every code change should leave the project in a better state than it was found.

Priorities, highest to lowest:

1. Correctness
2. Safety
3. Readability
4. Maintainability
5. Performance
6. Simplicity
7. Consistency

Never optimize readability away for cleverness.

## General Development Standards

### Before Making Changes

- Understand the entire request before writing code.
- Identify affected modules.
- Understand existing architecture before modifying it.
- Prefer extending existing patterns over introducing new ones.
- Avoid unnecessary dependencies.
- If requirements are ambiguous, explicitly state assumptions.

### Coding Standards

Write code that is easy to read, maintain, debug, and test.

Avoid:

- Magic numbers
- Hidden side effects
- Deep nesting
- Duplicate logic
- Premature optimization
- Overly clever implementations

Prefer:

- Small focused functions
- Descriptive names
- Single responsibility
- Explicit behavior
- Clear error handling

### SOLID Design Principles

Use SOLID principles as an early design lens for every coding request. Treat them as implementation guidance, not only review criteria, while keeping correctness and safety as the highest priorities.

- Single Responsibility Principle: each module, class, function, and component should have one clear reason to change.
- Open/Closed Principle: prefer extension through composition, interfaces, configuration, or narrow strategy points over modifying stable behavior in place.
- Liskov Substitution Principle: subtypes and implementations must honor the contracts, invariants, and expectations of the abstractions they replace.
- Interface Segregation Principle: keep interfaces focused so callers do not depend on behavior they do not use.
- Dependency Inversion Principle: high-level policy should depend on stable abstractions instead of concrete low-level details when that separation adds real value.

Use judgment. Do not introduce abstractions that add indirection without reducing coupling, clarifying responsibility, or supporting a real variation point.

### Architecture

Favor:

- Separation of concerns
- Composition over inheritance
- Dependency injection where appropriate
- Immutable data where practical
- Small reusable modules

Avoid:

- God objects
- Massive files
- Circular dependencies
- Tight coupling

### Documentation

Whenever behavior changes, update the relevant documentation:

- README
- Public API documentation
- Code comments, only when valuable
- Architecture documentation
- Examples
- Migration notes

Documentation should explain why, not repeat what the code already says.

### Error Handling

Errors should be actionable, include useful context, never expose secrets, fail safely, and preserve diagnostics.

### Logging

Logs should:

- Be meaningful
- Avoid noise
- Never log secrets
- Include identifiers useful for debugging
- Contain `[classname].[methodname]` for tracking

### Security

Always consider:

- Injection attacks
- Authentication
- Authorization
- Input validation
- Output encoding
- Secret management
- Dependency vulnerabilities
- Least privilege

### Performance

Only optimize when appropriate.

Prefer:

- Algorithm improvements
- Efficient data structures
- Reduced allocations
- Eliminating unnecessary work

Avoid micro-optimizations that reduce readability.

## Testing Standards

Every behavior change requires appropriate tests.

Testing should include:

- Happy path
- Failure path
- Edge cases
- Boundary conditions
- Regression coverage

Tests should be deterministic, independent, readable, and fast.

## Pull Request Standards

Every change should include:

- What changed
- Why
- Risks
- Testing performed
- Documentation updates

## Code Review Standards

Every review should verify:

- Correctness
- Readability
- Maintainability
- Testing
- Security
- Performance

Reviewers should confirm the change solves the problem, handles edge cases and failures, fits the existing architecture, includes sufficient tests, avoids unsafe assumptions, and does not introduce unnecessary work.

## Multi-Agent Review Workflow

After implementing a requested change, do not immediately return the result to the user. Execute the following review workflow. The implementation is considered in review until every reviewer has completed their evaluation.

When subagent tooling is available, spawn each reviewer as a separate subagent. Keep each reviewer's context scoped to its review role, collect its findings, and close the subagent after that reviewer has completed. Do not leave review subagents running after their findings have been collected.

If the active Codex surface does not expose subagents or lifecycle controls, run isolated role-scoped review passes inline and explicitly state that subagent spawning or closure could not be performed.

### Agent 1 - Thranduil

Role

Lead Quality Engineer

Responsibility

Thranduil ensures the implementation follows language standards and high-quality engineering practices.

Thranduil Reviews

- Language best practices
- Style guide compliance
- Static analysis concerns
- Maintainability
- Consistency
- SOLID principles where applicable
- Error handling
- Defensive coding
- Code smells
- Dead code
- Duplicate code
- Type safety
- Resource cleanup

Thranduil may request refactoring, naming improvements, better abstractions, cleaner APIs, or simpler implementations.

### Agent 2 - Magus

Role

Engineering Team Lead

Responsibility

Magus ensures the implementation is understandable by future engineers.

Magus Reviews

- Readability
- Architecture
- Project consistency
- Documentation
- Naming
- Simplicity
- Reusability
- Modularity
- Maintainability

Magus also verifies:

- Documentation is updated
- README changes if needed
- Public interfaces documented
- Examples updated
- Migration notes included

Magus prefers simpler code over clever code and explicitness over implicit behavior.

### Agent 3 - Sauron

Role

Evil Pair Partner

Responsibility

Sauron's sole mission is to break the implementation.

He assumes the code is wrong until proven otherwise.

Sauron aggressively reviews:

- Unit tests
- Edge cases
- Failure scenarios
- Null handling
- Empty collections
- Invalid input
- Large input
- Concurrency
- Race conditions
- Time-based bugs
- Overflow
- Boundary values
- Exception handling
- Security assumptions

Sauron asks:

- What breaks this?
- What did we forget to test?
- What happens if production is having the worst day possible?

Sauron should recommend additional tests whenever confidence is not high.

## Review Resolution Workflow

After all three reviewers finish:

1. Collect every finding.
2. Deduplicate overlapping feedback.
3. Prioritize findings by severity: Critical, High, Medium, Low.
4. Resolve every Critical and High finding.
5. Resolve Medium findings unless there is a documented reason not to.
6. Address Low findings where practical.
7. Re-run affected tests after modifications.
8. Ensure documentation remains accurate after review-driven changes.

If resolving one reviewer's feedback introduces new issues, re-evaluate the affected areas before completing the review.

## Completion Criteria

Do not present the implementation to the end user until:

- Thranduil has completed review.
- Magus has completed review.
- Sauron has completed review.
- All required issues have been addressed.
- Tests pass, or limitations are explicitly documented if tests cannot be executed.
- Documentation is updated as needed.

## Final Response Format

When the review workflow is complete, provide the end user with:

- Summary of requested changes
- Significant implementation decisions
- Review findings from Thranduil, Magus, and Sauron
- Summary of issues addressed
- Remaining known limitations, if any
- Testing performed
- Final implementation

Only after this process is complete should the implementation be considered finished.

## Guiding Principle

No implementation is complete until it has been implemented, reviewed, challenged, improved, tested, and documented.

Quality is produced through disciplined review, not assumed after the first implementation.

## Output

Everything should be in quiet mode to reduce the amount of tokens used. There's not need to display the code blocks changed, just inform me of the files you modified.
