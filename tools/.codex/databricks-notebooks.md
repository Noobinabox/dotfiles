# Databricks Notebook AI Development Instructions

Use these instructions with `AGENTS.md` for Databricks notebooks and notebook-backed data workflows.

## Applies To

- Databricks notebooks
- PySpark and Spark SQL transformations
- Delta Lake data processing
- Databricks job notebooks
- Notebook prototypes intended to become production workflows

## Coding Standards

- Keep notebooks organized into clear sections for parameters, setup, reads, transformations, writes, validation, and cleanup.
- Move reusable logic into shared modules or libraries when it is used by more than one notebook.
- Prefer explicit schemas for production ingestion and transformation logic.
- Avoid hidden state across cells; notebooks should run top-to-bottom successfully.
- Use descriptive DataFrame names that reflect the data stage or business concept.
- Avoid collecting large datasets to the driver.
- Avoid hard-coded environment paths, catalog names, schemas, or storage locations unless they are project-approved constants.

## Architecture

- Keep orchestration separate from transformation logic when workflows grow beyond simple notebooks.
- Treat medallion-stage transitions as explicit contracts.
- Use Delta Lake features intentionally for reliability, auditability, and performance.
- Prefer parameterized notebooks or jobs for environment-specific values.
- Keep production notebooks deterministic and idempotent where practical.

## Error Handling and Logging

- Fail early when required parameters, tables, files, or secrets are missing.
- Log job context, input locations, output targets, row counts, and validation summaries.
- Never log secrets, tokens, connection strings, or protected record-level data.
- Include enough context to identify the failing notebook section and dataset.

## Security and Governance

- Use approved secret scopes or cloud secret providers.
- Respect catalog, schema, table, and volume permissions.
- Avoid bypassing Unity Catalog or platform governance controls.
- Do not write sensitive data to temporary unmanaged locations unless explicitly approved.

## Testing and Validation

- Validate schema expectations, row counts, duplicate keys, required fields, and rejected records.
- Test empty inputs, malformed files, schema changes, late-arriving data, and reruns.
- Include reconciliation checks for transformations that feed reporting or downstream contracts.
- For production changes, verify behavior against representative sample data before full-scale execution.

## Review Checklist

- Thranduil verifies Spark and Databricks idioms, reusable module boundaries, resource usage, and maintainability.
- Magus verifies notebook flow is understandable, production intent is clear, and documentation explains operational behavior.
- Sauron challenges reruns, partial writes, schema drift, empty inputs, large data, permissions, missing secrets, and downstream data quality failures.
