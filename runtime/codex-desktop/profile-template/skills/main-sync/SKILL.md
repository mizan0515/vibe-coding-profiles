---
name: main-sync
description: >
  메인동기화. 명시 요청 때만 현재 브랜치 안전 확인 후 PR/merge/local pull 처리.
  Trigger: "메인동기화", "main sync", "push merge pull", "PR 만들고 머지", "merge 후 pull".
---

# Main Sync

Codex용 `메인동기화` 이식본. 현재 작업 브랜치를 PR 경유로 원격 main에 반영하고 로컬 main까지 맞춘다. 이 스킬은 Git/GitHub 안전 게이트를 관리자가 판단하게 넘기지 않는다.

## 한글 호출 예시

- `메인동기화 해줘. 지금 브랜치를 PR로 main에 반영해줘.`
- `푸시하고 PR 만든 뒤, 가능하면 merge 후 local main도 pull해줘.`
- `main에 들어갔는지 관리자가 확인할 수 있게 증거를 보여줘.`

## Manager Outcome

관리자는 “병합됨 / 수동 검토 대기 / 검사 대기 / 막힘 / 중단” 중 하나와 확인 링크만 보면 된다. Codex는 dirty worktree, mergeability, PR 댓글, review thread, linked issue comment, manager-risk stop을 먼저 확인한다.

## Required Checks

```powershell
Get-Location
git rev-parse --show-toplevel
git rev-parse --abbrev-ref HEAD
git status --short --branch
git remote -v
```

## Stop Gates

STOP하고 보고한다:

1. 현재 브랜치가 `main`이나 `master`이다.
2. dirty worktree가 있다. 수정/생성/삭제 파일 목록을 먼저 보고한다.
3. 원격이 local보다 앞서 있거나 merge base가 불명확하다.
4. 브랜치명과 티켓 번호가 명백히 어긋난다.
5. GitHub 인증, remote, PR 조회, checks 조회, 또는 helper 실행이 불가능하다.
6. 제품 우선순위, paid billing, public release, destructive/irreversible action, host-global mutation, credential entry/use 같은 manager-risk stop이 있다.

## Procedure

1. 현재 브랜치, issue/PR 연결, validation evidence, dirty worktree 상태를 확인한다.
2. 현재 브랜치를 push한다.
3. PR 생성 또는 기존 PR 확인. 기존 PR이면 제목/body를 임의로 덮어쓰지 않는다.
4. portable resolver로 `Test-CurrentPrMergeability.ps1`를 찾아 현재 branch에 실행한다. 이 게이트는 mergeability, PR 댓글/review thread, linked issue comment, 브랜치번호 ticket issue 댓글까지 확인한다.
5. `COMMENT_FOLLOWUP_NEEDED`, `ISSUE_COMMENT_FOLLOWUP_NEEDED`, unresolved review thread, requested changes, failed checks, unknown mergeability, missing linked issue, 또는 stale validation이면 `PR_READY`, merge-ready, `MERGED_DONE`을 말하지 않는다. agent-solvable이면 먼저 follow-up을 해결하고 같은 gate를 재시도한다.
6. 검증 결과와 Host Evidence를 PR body 또는 PR comment에 남긴다.
7. routine auto-merge 조건이 맞고 manager-risk stop이 없으면 `Invoke-CurrentPrAutoMerge.ps1`를 사용한다. 수동 merge 버튼으로 관리자에게 넘기는 것을 기본값으로 삼지 않는다.
8. PR이 열린 채 남으면 portable resolver로 `Test-OpenPrManagerState.ps1`를 찾아 `-Repo mizan0515/codex-isolated-runtime`로 실행하고 상태를 번역한다.
9. 병합 성공 후에만 `main`으로 이동해 `git pull --ff-only origin main`을 실행한다.
10. `main`과 `origin/main` hash 일치 확인 후에만 `MERGED_DONE`을 보고한다.

## Commands

```powershell
git push -u origin <current-branch>
gh pr create --base main --head <current-branch> --title "<title>" --body "<body>"
$script = & $resolver -ScriptName Test-CurrentPrMergeability.ps1
& $script -Repo mizan0515/codex-isolated-runtime -Branch <current-branch>
$mergeScript = & $resolver -ScriptName Invoke-CurrentPrAutoMerge.ps1
& $mergeScript -Repo mizan0515/codex-isolated-runtime -Branch <current-branch>
$stateScript = & $resolver -ScriptName Test-OpenPrManagerState.ps1
& $stateScript -Repo mizan0515/codex-isolated-runtime
git switch main
git pull --ff-only origin main
git rev-parse main origin/main
```

명령은 상황에 맞게 실제 브랜치와 PR 번호로 바꿔 실행한다.

## Output

```markdown
## 메인동기화 결과
- PR:
- merge:
- local pull:
- main hash:
- origin/main hash:
- 관리자 확인:
- open PR manager state:
- blocked/unverified:

상태: MERGED_DONE / PR_READY / WAITING_CHECKS / MANAGER_DECISION_NEEDED / BLOCKED / STOP
```

## Rollback

Restore `examples\skillopt-core-rollout\main-sync\rollback\SKILL.md` over the live `main-sync` skill files, then rerun the `main-sync` SkillOpt harness spec. Do not claim merge readiness until `Test-CurrentPrMergeability.ps1` and comment gates pass again.

## Safety

- main 직접 push 금지.
- force push, reset, history rewrite, or destructive git action 금지.
- dirty worktree에서 진행 금지.
- 증거 없이 "반영됨", `PR_READY`, merge-ready, or `MERGED_DONE` 금지.
- "ready to merge"만 보고 금지. 병합/의도적 보류/관리자 결정 필요/검사 대기/막힘 중 하나로 보고.
- No external SkillOpt runtime dependency, peer/subagent/recursive AI call, host-global mutation, credential/secret access, paid billing/model loop, public release/share, or private browser state access.
