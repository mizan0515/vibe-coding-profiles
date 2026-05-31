# vibe-coding-profiles

Public-safe profile source pack for Codex-oriented maintainer workflows.

This companion repository contains reusable prompts, skills, report templates,
manifest contracts, and containment fixtures for the main
`vibe-coding-runtime` project.

Main repository:

```text
https://github.com/mizan0515/vibe-coding-runtime
```

## 60-second proof

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\Test-VibeCodingProfilePack.ps1
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\Test-VibeCodingProfilePackInstall.ps1
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\Test-ProfileTemplates.ps1
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\Test-ProfileContainmentFixtures.ps1
```

## What this proves

- selected Codex and Claude profile source files are tracked in the public repo;
- install behavior is dry-run by default and refuses host-global targets;
- Korean and English manager report templates have required closeout sections;
- containment fixtures document blocked categories without exposing private
  path contents.

## What is included

- `profiles/`: public source notes for shared, Codex, and Claude behavior.
- `runtime/codex-desktop/profile-template/prompts/`: reusable Codex prompt assets.
- `runtime/codex-desktop/profile-template/skills/`: selected Codex skills and assets.
- `runtime/claude-code/profile-template/prompts/`: reusable Claude Code prompt assets.
- `runtime/claude-code/profile-template/skills/`: selected Claude Code skills.
- `templates/`: Korean and English manager closeout templates.
- `schemas/profile-pack-manifest.schema.json`: machine-readable pack contract.
- `examples/containment/blocked-paths.fixture.json`: public-safe containment fixture categories.
- `examples/profile-pack-manifest.example.json`: committed sample manifest.

## Source boundary

Use only tracked repository templates and docs listed in `source-manifest.json`.
Do not copy or inspect host-global Codex or Claude folders, shell configuration
files, SSH material, browser state, account state, private keys, private
material folders, runtime logs, or private manager notes.

## Project status

`v0.1.0` is the first public companion release for
`vibe-coding-runtime`. This repository supports the application package; the
runtime repository is the primary submission URL.
