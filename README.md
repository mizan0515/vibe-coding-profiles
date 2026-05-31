# Vibe-Coding Profile Pack Source

Public-safe source material for building Codex and Claude Code profile packs.
This repository is source guidance, not a live profile home. It references tracked
template files in this repository and keeps shared, Codex-specific, and
Claude-specific instructions separate so a packager can assemble each profile
without reading host-global profile folders or private manager rules.

## One-command pack check

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\Test-VibeCodingProfilePack.ps1
```

The check creates a local manifest, verifies that the selected prompts and skills exist, and confirms that the pack remains dry-run by default. It does not write to a live assistant profile.

## What is included

- `profiles/`: public source notes for shared, Codex, and Claude behavior.
- `runtime/codex-desktop/profile-template/prompts/`: reusable Codex prompt assets.
- `runtime/codex-desktop/profile-template/skills/`: selected Codex skills and assets.
- `runtime/claude-code/profile-template/prompts/`: reusable Claude Code prompt assets.
- `runtime/claude-code/profile-template/skills/`: selected Claude Code skills.
- `examples/skillopt-*`: SkillOpt rollout fixtures for selected profile changes.
- `templates/`: manager-facing closeout templates in Korean and English.

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

Run the profile-pack validator:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\Test-VibeCodingProfilePack.ps1
```

Run the template validator:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\Test-ProfileTemplates.ps1
```

The OpenAI Codex for Open Source form has not been submitted.
