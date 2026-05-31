# Vibe-Coding Profile Pack Source

Public-safe source material for building Codex and Claude Code profile packs.
This folder is source guidance, not a live profile home. It references tracked
template files in this repository and keeps shared, Codex-specific, and
Claude-specific instructions separate so a packager can assemble each profile
without reading host-global profile folders or private manager rules.

## Files

| file | purpose |
|---|---|
| `shared-instructions.md` | Rules that belong in both profile packs. |
| `codex-profile-source.md` | Codex Desktop/CLI profile-pack source material. |
| `claude-profile-source.md` | Claude Code profile-pack source material. |
| `source-manifest.json` | Machine-readable source inventory and validation expectations. |

## Source Boundary

Use only tracked repository templates and docs listed in `source-manifest.json`.
Do not copy or inspect host-global Codex or Claude folders, environment files,
SSH material, browser state, account state, private keys, secret folders,
runtime logs, or private manager notes.

## Build Intent

The pack target is a manager-friendly "vibe-coding" setup where the assistant
owns routine git, GitHub, validation, security checks, and evidence collection.
The manager decides only product meaning, credentials, billing, public release,
destructive actions, host-global promotion, or user-data transfer risk.

## Validation

Run the source-pack validator:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\Test-VibeCodingProfileSource.ps1
```

Then run the containment scan before using the material in a public packet:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\Test-CodexContainment.ps1
```
