# Claude Code Profile Source

Use this file to assemble a public-safe Claude Code profile pack from tracked
repository material.

## Source Files

| source | use in Claude Code pack |
|---|---|
| `runtime/claude-code/profile-template/CLAUDE.md` | Claude Code hot profile guidance. |
| `runtime/claude-code/profile-template/settings.json` | Claude Code settings template. |
| `runtime/claude-code/profile-template/hooks/` | Claude Code hook implementations. |
| `runtime/claude-code/profile-template/prompts/` | Claude Code prompt templates. |
| `runtime/claude-code/profile-template/commands/` | Claude Code slash-command aliases. |
| `runtime/claude-code/profile-template/skills/` | Claude Code skill source tree. |
| `runtime/claude-code/profile-template/PORTING_MANIFEST.md` | Codex-to-Claude source mapping and residual risks. |
| `runtime/claude-code/profile-template/README.md` | Claude profile install and validation notes. |

## Claude-Specific Rules

- Profile root is repo-local and materialized by the repository launcher; do
  not depend on a host-global Claude profile folder.
- `CLAUDE.md` is hot context. Keep it compact and route long workflows to
  skills, commands, hooks, prompts, scripts, or docs.
- Claude Code adversarial review uses the Codex plugin slash-command path
  documented in the template. Do not replace that path with a recursive native
  assistant call.
- Slash commands cannot be invoked inside an assistant turn. When needed, print
  the exact command for the manager and wait for the result.
- Preserve the porting manifest distinction between shared skills,
  Claude-owned divergent skills, and Codex-only skills.

## Pack Assembly Notes

1. Start from the tracked Claude Code profile template paths listed above.
2. Overlay `shared-instructions.md` only where it does not duplicate stronger
   Claude-specific rules.
3. Keep Codex Desktop/CLI launcher-only and overnight worker launcher behavior
   out of the Claude Code pack unless the profile template already contains a
   Claude-specific equivalent.
4. Run `scripts/Test-ClaudeCodeIsolatedProfile.ps1` when the local environment
   can materialize the profile; otherwise keep launch behavior `UNVERIFIED` and
   rely only on static source validation.
5. Run `scripts/Test-VibeCodingProfileSource.ps1` and
   `scripts/Test-CodexContainment.ps1` before using this material in a public
   snapshot or release packet.

## Public-Source Exclusions

Do not include generated live profile homes, host-global profile folders,
account state, local logs, private manager reports, backlog notes, environment
files, SSH material, browser state, or secret-like paths.
