# SQL AI Development Instructions

Use these instructions with `AGENTS.md` for SQL scripts, queries, stored procedures, views, and data transformations.

## Applies To

- SQL queries
- Stored procedures and functions
- Views
- Data migration scripts
- Analytical transformations
- Validation and reconciliation queries

## Coding Standards

- Prefer clear, explicit query structure over compact cleverness.
- Use descriptive aliases that explain role or source.
- Qualify columns when joining multiple tables.
- Avoid `SELECT *` in production queries unless the contract explicitly requires all columns.
- Keep join predicates explicit and review join cardinality.
- Use common table expressions to clarify multi-step transformations.
- Keep filtering logic close to the data it filters.
- Make assumptions about duplicates, nulls, and date boundaries explicit.

## Architecture

- Separate extraction, transformation, validation, and presentation concerns where practical.
- Prefer idempotent migration and data maintenance scripts.
- Make schema changes backward-compatible when callers may still depend on old shapes.
- Avoid embedding environment-specific database names unless the project standard requires them.
- Keep reusable business rules centralized instead of copying predicates across many queries.

## Error Handling and Data Quality

- Validate row counts, duplicate keys, required fields, referential integrity, and expected value domains.
- Include reconciliation queries for meaningful data movement.
- Use transactions for multi-step changes that must succeed or fail together.
- Document rollback steps for risky migrations.

## Security

- Use parameterized queries from application code.
- Avoid dynamic SQL unless necessary; when required, validate identifiers and parameters carefully.
- Apply least privilege to database roles and service accounts.
- Do not expose protected data in logs, examples, comments, or test fixtures.

## Performance

- Check predicates, joins, grouping, and window functions for unnecessary scans.
- Use indexes, clustering, partitioning, or statistics according to the database platform.
- Avoid premature tuning that makes the query harder to understand.
- Validate performance against realistic data size when query cost matters.

## Testing

- Test happy path data, empty result sets, duplicate records, null values, boundary dates, and invalid values.
- Include regression fixtures for known production defects.
- Verify both row-level correctness and aggregate totals when transformations affect reporting.

## Review Checklist

- Thranduil verifies SQL readability, deterministic behavior, platform idioms, maintainability, and safe transaction usage.
- Magus verifies business rules are understandable, centralized where practical, and documented for future maintainers.
- Sauron challenges null behavior, duplicate handling, join explosion, boundary dates, permissions, injection risk, and rollback gaps.
