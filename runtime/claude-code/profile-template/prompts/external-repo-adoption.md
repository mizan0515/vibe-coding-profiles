# External Repo Adoption Prompt

English:

```text
Review this GitHub repository for adoption into Codex Isolated Runtime.

GitHub URL:
Target goal:
Risk tolerance:
Time budget:

Rules:
- Do not install or run external repository code by default.
- Do not read or mutate credentials, host-global profiles, browser state, environment files, SSH material, private keys, or secret folders.
- Collect repository metadata, license, recent activity, security posture, install path, fit with the root goal, and validation route.
- Include paste-ready Codex and Claude Code prompts, safety gates, dry-run fixture command, and rollback plan.
- Ask the manager only for semantic approval: credentials, billing, public release, destructive action, host-global promotion, user-data transfer, or product priority.
- The agent owns technical mechanics: source inspection, validation command choice, issue drafting, PR mechanics, and repo-local rollback.
- End with exactly one decision: adopt now, pilot, follow-up issue, watch, or reject.
- If work is agent-solvable, attempt the bounded dry-run or create the smallest follow-up issue with success criteria and verification.
- Report in built/inspected, tested/evidence, manager run/paste, blocked/unverified format.
```

Claude Code:

```text
Use external-adoption-review. Review this GitHub repository for the codex-isolated-runtime Claude Code profile or plugin.

GitHub URL:
Target goal:
Risk tolerance:
Time budget:

Rules:
- Stay inside the repo-local Claude profile/plugin surface. Do not mutate host-global Claude or Codex profile folders.
- Do not install or run external repository code by default.
- Do not read or mutate credentials, browser state, environment files, SSH material, private keys, or secret folders.
- Include trust evidence, fit, safety gates, dry-run fixture command, rollback plan, and exactly one manager decision: adopt now, pilot, follow-up issue, watch, or reject.
- Ask the manager only for semantic approval: credentials, billing, public release, destructive action, host-global promotion, user-data transfer, or product priority.
- The agent owns technical mechanics: source inspection, validation command choice, issue drafting, PR mechanics, and repo-local rollback.
```

Korean:

```text
이 GitHub 저장소를 Codex Isolated Runtime에 도입할지 검토해 주세요.

GitHub URL:
목표:
허용 가능한 위험:
시간 예산:

규칙:
- 기본값은 외부 저장소 코드를 설치하거나 실행하지 않습니다.
- 자격증명, host-global profile, browser state, environment file, SSH material, private key, secret folder를 읽거나 바꾸지 않습니다.
- repo metadata, license, 최근 활동, security posture, install path, root goal 적합성, validation route를 증거로 확인합니다.
- Codex와 Claude Code에 붙여넣을 수 있는 prompt, safety gate, dry-run fixture command, rollback plan을 포함합니다.
- 관리자는 credentials, billing, public release, destructive action, host-global promotion, user-data transfer, product priority 같은 의미 결정만 합니다.
- source inspection, validation command choice, issue drafting, PR mechanics, repo-local rollback 같은 기술 절차는 agent가 맡습니다.
- 결론은 adopt now, pilot, follow-up issue, watch, reject 중 하나만 선택합니다.
- agent가 해결할 수 있는 일이면 bounded dry-run을 시도하거나 success criteria와 verification이 있는 가장 작은 follow-up issue를 만듭니다.
- built/inspected, tested/evidence, manager run/paste, blocked/unverified 형식으로 보고합니다.
```
