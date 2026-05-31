---
name: external-adoption-execution-transition
version: 2026-05-28
status: skill-reference
required_inputs:
  - reviewed candidates
  - evidence summary
  - current project constraints
---

# External Adoption Execution Transition

Use this reference after an external adoption review. The goal is to turn every
candidate into a concrete project action. Do not end at "review completed".

## Classify Every Candidate

Use exactly one:

- `A. 즉시 도입`: evidence is enough, scope is small, rollback is easy, cost and
  security risk are low.
- `B. 실사용 파일럿 후 도입 판단`: likely useful but must be tried in the real
  project flow.
- `C. 조건부 도입`: direction is proven, but one or two concrete conditions must
  be fixed before adoption.
- `D. 백로그`: too early now; has a measurable trigger for revisiting.
- `E. 제외`: risk, cost, complexity, license, or fit is worse than benefit.

## Anti-Over-Caution Rule

Do not send a candidate to `WATCH_LATER` or `INSUFFICIENT_EVIDENCE` when most
of these are true:

- small scope;
- easy rollback;
- low cost;
- low security/privacy/billing risk;
- reduces repeated work;
- improves tests, docs, operations, or manager visibility;
- maintainable by Codex/Claude;
- manager can see the result;
- failure impact is small;
- source evidence exists.

If still deferred, write:

- why now is wrong;
- opportunity cost of waiting;
- why this is not excessive caution;
- exact revisit condition.

## Be More Conservative When

- credentials, billing, privacy, permissions, or security are involved;
- license is unclear or restrictive;
- paid services or new infrastructure are required;
- current architecture must be replaced;
- maintainer bus factor is low and replacement is hard;
- failure can harm users;
- the manager cannot verify the result.

## Ticket Forms

### Immediate Adoption

Include:

- title;
- purpose;
- item to adopt;
- why no pilot is needed;
- expected benefit;
- implementation scope;
- excluded scope;
- done criteria;
- verification;
- manager-visible check;
- rollback;
- risks and mitigations.

### Real-Use Pilot

Include:

- title;
- why now;
- hypothesis;
- real project flow to attach to;
- minimum scope;
- real data or scenario;
- success criteria;
- failure criteria;
- evidence to measure;
- manager-visible result;
- cost and operations impact;
- security/license check;
- rollback;
- required final judgment:
  - `ADOPT_NOW`
  - `ADOPT_WITH_CHANGES`
  - `DO_NOT_ADOPT`
  - `WATCH_WITH_TRIGGER`

### Conditional Adoption

Include:

- what is already proven;
- what is still missing;
- what must be fixed;
- why fixing that means adoption can proceed;
- done criteria;
- verification;
- manager-visible check;
- remaining risk;
- cost of further delay.

### Backlog

Include:

- deferral reason;
- why not now;
- revisit trigger;
- evidence needed at revisit;
- expected value;
- risk if adopted now;
- cost of waiting too long;
- source evidence;
- priority.

### Exclusion

Include:

- excluded item;
- evidence;
- current-project risk;
- safer alternative;
- revisit condition;
- note to prevent repeated re-review.

## Final Tables

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
```

When the user asked for ticket creation and GitHub auth works, create/reuse the
issues instead of only drafting them.
