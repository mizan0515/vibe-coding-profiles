# Codex Profile Source

Use this file to assemble a public-safe Codex Desktop/CLI profile pack from
tracked repository material.

## Source Files

| source | use in Codex pack |
|---|---|
| `runtime/codex-desktop/profile-template/AGENTS.md` | Codex hot profile guidance. |
| `runtime/codex-desktop/profile-template/config.toml` | Codex profile configuration template. |
| `runtime/codex-desktop/profile-template/hooks.json` | Codex hook registration template. |
| `runtime/codex-desktop/profile-template/hooks/` | Repo-local hook implementations. |
| `runtime/codex-desktop/profile-template/prompts/` | Codex prompt templates. |
| `runtime/codex-desktop/profile-template/skills/` | Codex skill source tree. |
| `runtime/codex-desktop/profile-template/hot-context/` | Compact context cards. |
| `docs/public-snapshot-export.md` | Public packet export rule. |
| `docs/oss-public-runtime.md` | Public runtime overview. |

## Codex-Specific Rules

- Profile root is repo-local `CODEX_HOME`; do not depend on a host-global
  profile folder.
- Codex Desktop/CLI is the default active route for this repository.
- Use Codex plugin and app capabilities only through the active isolated
  runtime and current tool list.
- Do not claim retired peer-lane, ROI, or multi-agent readiness from archive
  files, compatibility shims, labels, or fixtures.
- PowerShell syntax is the default for manager-run commands in this project.

## Pack Assembly Notes

1. Start from the tracked Codex profile template paths listed above.
2. Overlay `shared-instructions.md` only where it does not duplicate stronger
   Codex-specific rules.
3. Keep Codex-only launcher and overnight orchestration material out of the
   Claude Code pack unless a separate Claude-specific implementation exists.
4. Run `scripts/Test-VibeCodingProfileSource.ps1` and
   `scripts/Test-CodexContainment.ps1` before using this material in a public
   snapshot or release packet.

## Public-Source Exclusions

Do not include runtime accounts, generated homes, local logs, private manager
reports, backlog notes, environment files, SSH material, browser state, or
secret-like paths. The source pack points to templates only; it is not a
snapshot of a live user profile.
