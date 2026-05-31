---
name: external-adoption-execution-transition
version: 2026-05-28
status: reusable-prompt
required_inputs:
  - reviewed candidates
  - evidence summary
  - current project constraints
---

# External Adoption Execution Transition Prompt

This prompt converts external repository review results into project actions.
The final success condition is not a report. The final success condition is a
clear adoption, pilot, conditional adoption, backlog, or exclusion outcome.

## Rules

- Do not stop at "review completed".
- Do not leave "needs more review" as the final result.
- Do not make the manager decide internal libraries, code structure, or tests.
- If the user asked for tickets and GitHub access works, create/reuse issues.
- If evidence is enough and the scope is small, do not over-defer.
- If risk is high, reduce it with a real-use pilot, backlog trigger, or
  exclusion.
- Every action must include safety gates, rollback, and a manager-visible
  decision state.
- The manager should only decide semantic questions: credentials, billing,
  public release, destructive action, host-global promotion, user-data transfer,
  or product priority. Agents own technical mechanics.

## Candidate Classes

- `A. 즉시 도입`: small, useful, low risk, easy rollback.
- `B. 실사용 파일럿 후 도입 판단`: promising but needs proof in the real project
  flow.
- `C. 조건부 도입`: already promising, but one or two specific blockers must be
  resolved.
- `D. 백로그`: not now, with numeric/event revisit trigger.
- `E. 제외`: current fit, cost, complexity, license, or risk is not acceptable.

## Output

```markdown
## 실행 전환 요약
| 후보 | 분류 | 이유 | 필요한 다음 행동 | 너무 미루면 손해 | 무리하게 도입하면 위험 |
|---|---|---|---|---|---|

## 즉시 도입 티켓
| 우선순위 | 티켓 제목 | 왜 바로 해도 되는가 | 기대효과 | 난이도 | 위험 | 완료 기준 | 관리자 확인 방법 |
|---|---|---|---|---|---|---|---|

## 실사용 파일럿 티켓
| 우선순위 | 티켓 제목 | 검증 가설 | 실제 사용 테스트 | 성공 기준 | 실패 기준 | 파일럿 후 필수 액션 |
|---|---|---|---|---|---|---|

## 조건부 도입 티켓
| 우선순위 | 티켓 제목 | 이미 증명된 것 | 남은 조건 | 조건 해결 후 액션 | 미루면 손해 |
|---|---|---|---|---|---|

## 백로그 티켓
| 우선순위 | 티켓 제목 | 보류 이유 | 다시 볼 조건 | 다시 볼 때 필요한 증거 |
|---|---|---|---|---|

## 제외 항목
| 항목 | 제외 이유 | 대체 방법 | 다시 검토할 조건 |
|---|---|---|---|

## Paste-Ready Prompts
| 대상 | 붙여넣을 프롬프트 | 언제 쓰나 |
|---|---|---|
| Codex | Use `$external-adoption-review`... | Codex isolated runtime에서 검토/티켓화 |
| Claude Code | Use external-adoption-review... | Claude Code profile/plugin에서 같은 검토/티켓화 |

## Safety / Rollback
| 액션 | safety gates | rollback | manager-only semantic decision |
|---|---|---|---|
| packet-only review | no external code execution, no secrets, no host-global mutation | delete packet or revert doc/prompt change | none unless public sharing is requested |
| bounded pilot | no credentials/billing/public release/destructive action without approval | revert pilot commit/PR and remove named fixtures | approve only product/safety risk |
| runtime prompt/skill change | repo-local only | restore tracked file from git and rerun validator | host-global promotion requires approval |

## GitHub Issue 본문
For each top-priority action, provide or create a GitHub issue with:
- title;
- classification;
- background;
- evidence;
- goal;
- scope;
- done criteria;
- verification;
- risks;
- rollback;
- final state.
```

End with a manager summary:

- 바로 티켓 발행하면 좋은 것;
- 파일럿이 필요한 것;
- 조건만 해결하면 도입할 것;
- 나중에 다시 볼 것;
- 하지 말아야 할 것;
- manager-only decisions;
- Codex/Claude actions.
