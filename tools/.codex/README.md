# AI Development Instruction Library

This library provides reusable instruction files for AI coding assistants. The files are designed for shared use in GitHub, Confluence, or similar team documentation systems.

## Purpose

Use these files to guide AI-generated code toward the team's architecture, coding standards, testing expectations, and review practices.

The universal standards live in `AGENTS.md`. Technology-specific files extend those standards and should not replace them.

## Instruction Files

- [AGENTS.md](AGENTS.md) - Universal development standards and multi-agent review workflow
- [csharp.md](csharp.md) - C# and .NET development instructions
- [cpp.md](cpp.md) - C++ application and native library development instructions
- [python.md](python.md) - Python development instructions
- [sql.md](sql.md) - SQL development instructions
- [typescript.md](typescript.md) - TypeScript development instructions
- [angular.md](angular.md) - Angular development instructions
- [electron.md](electron.md) - Electron desktop application development instructions
- [pulumi-typescript.md](pulumi-typescript.md) - Pulumi TypeScript infrastructure development instructions
- [databricks-notebooks.md](databricks-notebooks.md) - Databricks notebook development instructions
- [prompt-files.md](prompt-files.md) - Prompt and AI instruction file development instructions
- [skills.md](skills.md) - AI skill development instructions
- [skill-template.md](skill-template.md) - Copy-ready template for new AI assistant skills
- [skill-review-checklist.md](skill-review-checklist.md) - Review checklist for publishing or updating skills

## Packaged Scope

This dotfiles package manages the Markdown instruction files listed above. It does not manage Codex runtime state, sessions, auth databases, generated caches, plugin installs, or skill directories.

Keep skill implementations and other generated Codex state outside this package unless they are intentionally added as versioned source artifacts.

## How to Use

1. Start with `AGENTS.md` for universal engineering expectations.
2. Add the technology-specific instruction file that matches the implementation area.
3. Keep project-specific conventions in the consuming repository and use these files as shared defaults.
4. Update these files when team standards change or new recurring review feedback appears.

## Publishing Notes

GitHub can use the relative Markdown links as-is. When publishing to Confluence, preserve each file as a separate page or attachment and convert relative links to Confluence page links where needed.

## Maintenance

Keep these instructions concise, actionable, and portable. Avoid project secrets, personal notes, environment-specific paths, and tool-specific assumptions unless they are required for team-wide usage.
