# Electron AI Development Instructions

Use these instructions with `AGENTS.md` for Electron desktop applications. Use `typescript.md` for TypeScript code and any renderer framework instructions that apply.

## Applies To

- Electron main-process code
- Preload scripts and context bridge APIs
- Renderer integration with Electron APIs
- IPC request and response contracts
- Native modules and desktop integration
- Packaging, installer, auto-update, and release configuration
- Electron unit, integration, runtime, and packaging tests

## Coding Standards

- Follow established project conventions before introducing new patterns.
- Keep main, preload, and renderer responsibilities separate.
- Keep privileged operating-system work in the main process.
- Expose the smallest practical preload API through the context bridge.
- Validate all IPC inputs and outputs at process boundaries.
- Treat renderer data, command arguments, file paths, drag-and-drop payloads, and deep links as untrusted.
- Avoid sharing broad service objects or privileged APIs directly with renderer code.
- Keep asynchronous startup, shutdown, and update flows explicit and observable.

## Architecture

- Define stable IPC contracts close to the boundary they describe.
- Separate desktop services, application state, UI state, packaging configuration, and platform adapters.
- Isolate Windows, Linux, and macOS behavior behind small modules.
- Avoid coupling renderer components to Electron internals when a preload boundary can provide a safer interface.
- Keep native-module loading, asset lookup, and filesystem paths compatible with packaged applications.
- Document public desktop APIs, deep links, command-line switches, or installer behaviors when they change.

## Error Handling and Logging

- Surface renderer-safe errors without exposing stack traces, secrets, local paths, or sensitive payloads.
- Preserve diagnostic context for main-process startup, IPC, native-module, packaging, and update failures.
- Handle rejected promises in main, preload, and renderer code intentionally.
- Log enough context to diagnose platform and packaging issues without logging credentials, tokens, or user data.
- Include process, module, class, or function context in log messages when practical.

## Security

- Keep `contextIsolation` enabled unless the project has a documented exception.
- Disable Node integration for untrusted renderer content.
- Use sandboxing where practical for renderer windows.
- Restrict navigation, `window.open`, external URL handling, permissions, and file access.
- Validate IPC authorization assumptions before performing privileged actions.
- Use a restrictive content security policy when the renderer serves web content.
- Avoid loading remote content with elevated privileges.
- Keep secrets out of renderer bundles, logs, crash reports, and packaged assets.

## Packaging and Runtime

- Validate behavior in the packaged application when changing assets, native modules, file paths, installers, or update logic.
- Account for `app.asar`, unpacked binaries, code signing, auto-update channels, and installer permissions.
- Keep development-only dependencies and diagnostics out of production packages.
- Verify platform-specific paths, file permissions, protocol handlers, tray behavior, and notifications on the platforms affected by the change.

## Testing

- Cover main-process services, preload bridges, IPC contracts, renderer states, and packaging behavior as appropriate.
- Include invalid IPC input, denied permissions, missing files, native-module load failures, offline startup, and update failure scenarios.
- Run type-check, lint, unit, integration, Electron runtime smoke, and packaging commands used by the consuming project.
- For packaging changes, verify the packaged app path, not only development mode.

## Review Checklist

- Thranduil verifies TypeScript or JavaScript quality, async handling, IPC validation, dependency choices, native-module handling, and maintainability.
- Magus verifies process boundaries, naming, desktop architecture, packaging clarity, documentation, and project consistency.
- Sauron challenges renderer trust assumptions, malformed IPC payloads, navigation escapes, missing assets, packaged runtime failures, platform differences, and untested installer or updater paths.
