---
name: external-adoption-review
description: >
  외부도입검토 external-adoption-review: GitHub repo, awesome list, 오픈소스
  도구, agent orchestrator, 라이브러리, 프롬프트/스킬 자산을 현재 프로젝트에
  도입할지 증거 기반으로 판단하고 즉시도입/파일럿/조건부도입/백로그/제외
  티켓으로 닫습니다. Use when the user asks to adopt, evaluate for adoption,
  compare, pilot, or ticket external repositories or open-source projects for
  this project. Trigger: "외부 repo 도입", "오픈소스 도입", "도입 후보",
  "awesome list", "GitHub repo 검토", "스타 높은 프로젝트", "adoption
  review", "external repo adoption", "도입할거 도입", "시스템에 맞게 도입".
---

# External Adoption Review

Use this skill only when the user wants to decide whether an external
repository, open-source project, paper-with-code, prompt asset, skill, or
orchestrator idea should be adopted into the current project.

Do not use it for ordinary link summaries, generic web research, routine code
review, error resolution, or implementation work unless the prompt asks for an
adoption decision, pilot, ticket, or "bring this into our system" action.

## Placement Decision

1. Intended scope: external repository or open-source adoption decisions that
   must end in a project action.
2. Chosen location: on-demand skill `external-adoption-review`, plus reusable
   prompt assets in `runtime/codex-desktop/profile-template/prompts/` and the
   Claude Code profile/plugin prompt surface.
3. Why this scope is correct: broad adoption prompts are too long for hot
   instructions, but relying on pasted prompts causes missed execution
   follow-through. This skill triggers only on adoption language plus external
   repo/tool context.
4. Hot vs on-demand: on-demand. Never add this full process to `AGENTS.md`.
5. Rejected alternatives: global rule would over-trigger on ordinary links;
   hook-only routing cannot perform the evidence review; storing prompts only
   would not make the workflow automatic enough.

## Root Intent

The manager wants fewer bad adoptions, fewer missed useful improvements, and
less repeated manual evaluation. Success is not "many cool repos found";
success is fewer time, cost, maintenance, and operations risks while improving
the current product.

## Required Inputs

- External repo URL, awesome list, paper/tool name, or candidate set.
- Current project path or enough context to inspect its README/docs/issues.
- If the user asks for tickets, use `ticket-issue` before implementation.

If the target source is current or could have changed, browse or use GitHub/API
evidence. Record source URLs and dates.

## Workflow

1. Restate the manager goal in one sentence: what burden or risk should go
   down, and what quality should go up.
2. Inspect the current project first: `README.md`, `docs/PRODUCT_VISION.md`,
   `docs/MANAGER_OPERATING_MODEL.md`, active issue, and nearby skills/prompts.
3. For each external candidate, run the trust gate before feature enthusiasm:
   stars/forks, recent meaningful activity, release/changelog, issue/PR health,
   license, tests/CI, security/maintenance signals, and bus factor.
4. Separate facts:
   - `Observed`: directly checked source or command evidence.
   - `Inferred`: reasonable conclusion from observed facts.
   - `Unverified`: not checked or not enough evidence.
   - `Recommendation`: current-project action.
   - `Blocked`: missing access, source unavailable, or time/tool limit.
5. Fit the candidate to this project:
   - direct help to Codex isolated runtime or Claude Code isolated
     profile/plugin, manager-safe operation, evidence-first completion,
     ticket/PR/merge automation, or runtime safety;
   - operations burden, cost, security, host-global risk, and manager visibility.
6. Classify every candidate:
   - `A. 즉시 도입`
   - `B. 실사용 파일럿 후 도입 판단`
   - `C. 조건부 도입`
   - `D. 백로그`
   - `E. 제외`
7. Convert every non-excluded useful candidate into an action:
   - immediate adoption issue;
   - real-use pilot issue;
   - conditional adoption issue;
   - backlog issue with numeric/event trigger;
   - exclusion note with retry condition.
8. If the user asked for tickets, create/reuse GitHub issues and Project items
   when auth permits. Do not stop at a report.
9. Do not adopt whole external systems by default. Prefer the smallest useful
   idea, protocol, test, prompt, or script shape unless evidence proves a full
   integration is worth the added burden.
10. Product packets must include paste-ready Codex and Claude Code prompts,
    safety gates, dry-run fixture command, rollback plan, and only semantic
    manager decisions. Agents own technical mechanics.

## Prompt Assets

Use these assets when a full structured review is needed:

- `runtime/codex-desktop/profile-template/prompts/external-repo-adoption-review.md`
  for trust and fit review.
- `runtime/codex-desktop/profile-template/prompts/external-adoption-execution-transition.md`
  for forcing every candidate into an action.
- `prompts/external-repo-adoption.md` for a manager-facing Codex and Claude
  Code paste prompt.

In active isolated profiles, the same text may also be available under the
skill references:

- `references/external-repo-adoption-review.md`
- `references/external-adoption-execution-transition.md`

Read only the relevant reference. For small candidate sets, this SKILL.md
workflow is enough.

## Over-Trigger Guard

Use this skill when at least one adoption verb and one external-source signal
are present.

Adoption verbs:

- 도입, 적용, 가져오, 반영, 파일럿, 후보, 채택, 제외, 검토해서 티켓
- adopt, adoption, pilot, evaluate for our project, integrate, bring into our
  system

External-source signals:

- GitHub repo, awesome list, open-source project, external repository, paper
  with code, library/tool/framework name, star count, forks, license, release

Do not trigger for:

- "이 링크 요약해줘" without adoption language;
- bug/error/stack trace resolution;
- ordinary code review;
- current repo implementation without external candidate;
- product priority discussion without external repo/tool evidence.

## Output Contract

Use concise Korean for the manager. Include:

```markdown
## 외부도입검토 결과

### 현재 프로젝트 기준
- 목표:
- 지금 필요한 것:
- 피해야 할 것:

### 후보 요약
| 후보 | 신뢰도 | 현재 적합성 | 판단 | 이유 |
|---|---|---|---|---|

### 실행 전환
| 후보 | 분류 | 다음 행동 | 너무 미루면 손해 | 무리하게 도입하면 위험 |
|---|---|---|---|---|

### 티켓 상태
- 즉시 도입:
- 실사용 파일럿:
- 조건부 도입:
- 백로그:
- 제외:

### 증거 상태
- Observed:
- Inferred:
- Unverified:
- Blocked:

### manager run/paste
- Codex prompt:
- Claude Code prompt:
- Dry-run fixture command:

### safety/rollback
- Safety gates:
- Rollback plan:
- Manager-only semantic decisions:
```

If issues were created, list issue numbers and Project registration evidence.
If no issue was created, state exactly why.

## Never

- Do not recommend based on star count alone.
- Do not copy code from external repos without license/security review.
- Do not introduce paid services, credentials, host-global config, daemons, or
  public releases without manager approval.
- Do not end with "needs more review" only. Choose action, pilot, backlog with
  trigger, or exclusion.
- Do not ask the manager which library/internal architecture to use; the agent
  should create evidence and recommend.
