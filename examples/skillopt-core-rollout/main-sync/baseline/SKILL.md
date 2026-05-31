---
name: main-sync
description: >
  메인동기화. 명시 요청 때만 현재 브랜치 안전 확인 후 PR/merge/local pull 처리.
  Trigger: "메인동기화", "main sync", "push merge pull", "PR 만들고 머지", "merge 후 pull".
---

# Main Sync

Codex용 `메인동기화` 이식본. 현재 작업 브랜치를 안전하게 원격 main에 반영하고 로컬 main까지 맞춘다.

## 한글 호출 예시

- `메인동기화 해줘. 지금 브랜치를 PR로 main에 반영해줘.`
- `푸시하고 PR 만든 뒤, 가능하면 merge 후 local main도 pull해줘.`
- `main에 들어갔는지 관리자가 확인할 수 있게 증거를 보여줘.`

## Manager Purpose

관리자는 “이 작업이 진짜 메인에 들어갔는지”만 확인하면 된다. Codex는 그 전에 안전 가드를 통과해야 한다.

## Required Checks

```powershell
Get-Location
git rev-parse --show-toplevel
git rev-parse --abbrev-ref HEAD
git status --short --branch
git remote -v
```

가드:

1. 현재 브랜치가 `main`이나 `master`이면 STOP.
2. 작업 파일이 남아 있으면 STOP하고 파일 목록 보고.
3. 원격이 local보다 앞서 있으면 pull/rebase 필요로 STOP.
4. 브랜치명과 티켓 번호가 명백히 어긋나면 STOP.
5. GitHub 인증이나 remote가 없으면 `Blocked`로 보고.

## Procedure

1. 현재 브랜치 push.
2. PR 생성 또는 기존 PR 확인.
3. portable resolver로 `Test-CurrentPrMergeability.ps1`를 찾아 현재 branch에 실행한다. 이 게이트는 mergeability, PR 댓글/review thread, 연결/브랜치번호 ticket issue 댓글까지 확인한다.
4. 테스트/검증 결과를 PR body에 남긴다.
5. 사용자가 병합까지 요청했으면 PR merge.
6. PR이 열린 채 남으면 portable resolver로 `Test-OpenPrManagerState.ps1`를 찾아 `-Repo mizan0515/codex-isolated-runtime`로 실행.
7. `main`으로 이동 후 `git pull --ff-only origin main`.
8. `main`과 `origin/main` hash 일치 확인.

## Commands

```powershell
git push -u origin <current-branch>
gh pr create --base main --head <current-branch> --title "<title>" --body "<body>"
$script = & $resolver -ScriptName Test-CurrentPrMergeability.ps1
& $script -Repo mizan0515/codex-isolated-runtime -Branch <current-branch>
gh pr merge <pr-number> --merge --delete-branch
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

상태: MERGED_DONE 또는 PR_READY 또는 STOP
```

## Safety

- main 직접 push 금지.
- force push 금지.
- dirty worktree에서 진행 금지.
- 증거 없이 “반영됨” 금지.
- "ready to merge"만 보고 금지. 병합/의도적 보류/관리자 결정 필요/검사 대기/막힘 중 하나로 보고.
