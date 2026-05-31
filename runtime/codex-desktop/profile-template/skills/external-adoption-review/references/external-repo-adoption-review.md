---
name: external-repo-adoption-review
version: 2026-05-28
status: skill-reference
required_inputs:
  - external repository URL or candidate list
  - current project path or context
  - adoption goal
---

# External Repository Adoption Review

Use this reference when a full external repository adoption review is needed.
The goal is not to rate whether a repository is impressive. The goal is to
decide whether it should reduce this project's time, cost, development burden,
or operating risk.

## Required Judgment

Final judgment for each target:

- `ADOPT`
- `PILOT_ONLY`
- `WATCH_LATER`
- `DO_NOT_ADOPT`
- `INSUFFICIENT_EVIDENCE`

Also classify each sub-item as:

- 채택
- 변형
- 실험
- 보류
- 제외

## Evidence Labels

Use these labels for important claims:

- `Observed`: directly checked source, command, file, issue, PR, release, or
  license evidence.
- `Inferred`: conclusion from observed facts.
- `Unverified`: not checked or not enough evidence.
- `Recommendation`: current-project action.
- `Blocked`: missing access, source unavailable, or tool/time limit.

## Step 1. Repository Trust Gate

Check before feature analysis:

- stars, forks, watchers, contributors, dependents/registry downloads when
  available;
- recent meaningful commit and release dates;
- changelog/release notes;
- issue/PR health and maintainer response;
- tests, CI, type checks, linting, formatting;
- license and product-fit risk;
- security signals: `SECURITY.md`, CVE/security issue history, dependency
  update posture, unsafe shell/eval/defaults;
- maintainer/bus factor: individual/company/foundation/community.

Star interpretation:

- 0-50: little validation; experiments only unless niche evidence is strong.
- 50-100: possible niche candidate; inspect code/issues/releases carefully.
- 100-500: viable for focused tools.
- 500-2,000: normal adoption candidate.
- 2,000-5,000: popularity signal.
- 5,000-10,000: likely well-known, still verify maintenance.
- 10,000+: famous signal, not proof of fit or safety.

## Step 2. Current Project Fit

Summarize:

- project goal;
- primary user;
- current stage;
- stack and operating constraints;
- current bottleneck;
- complexity that must not increase;
- relevance to the external repo.

For `codex-isolated-runtime`, default fit criteria:

- manager-safe Codex-only operation;
- repo-local state and evidence;
- isolated worktrees;
- GitHub issue/PR/merge automation owned by Codex;
- no host-global profile mutation;
- no credential/private data access;
- no retired MoA/peer revival without explicit issue approval.

## Step 3. Findings

Look for:

- code or scripts to adopt;
- architecture or protocol ideas to adapt;
- functions/features that help manager visibility, worker coordination,
  recovery, status, history, review, or automation;
- technical tools that reduce repeated work;
- lessons and failure patterns;
- what not to adopt.

For each finding, record:

- evidence path or URL;
- expected benefit;
- implementation cost;
- operating burden;
- risk;
- rollback path;
- recommendation.

## Step 4. Output

Use concise tables:

```markdown
## 리포지토리 신뢰도 요약
| 항목 | 판단 | 근거 |
|---|---|---|

## 현재 프로젝트 요약
- 목표:
- 핵심 사용자:
- 지금 필요한 것:
- 피해야 할 것:

## 후보별 판단
| 후보 | 신뢰도 | 적합성 | 최종 판단 | 이유 |
|---|---|---|---|---|

## 우선순위
| 우선순위 | 항목 | 구분 | 추천 판단 | 기대효과 | 난이도 | 리스크 | 근거 수준 | 추천 액션 |
|---|---|---|---|---|---|---|---|---|

## 도입하지 말 것
| 항목 | 제외 이유 | 대체 방법 | 다시 검토할 조건 |
|---|---|---|---|
```

Do not stop here if the user asked for action. Continue with the execution
transition reference.
