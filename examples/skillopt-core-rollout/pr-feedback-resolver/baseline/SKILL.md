---
name: pr-feedback-resolver
description: >
  PR피드백처리. 열린 PR의 리뷰 댓글, 실패 체크, mergeability 문제를 확인해
  수정-검증-보고까지 진행. Trigger: "PR 피드백", "리뷰 댓글 반영",
  "PR 코멘트 처리", "체크 실패 해결", "resolve PR feedback",
  "fix PR comments".
---

# PR Feedback Resolver

Use when the manager asks Codex to handle PR comments, review feedback, failed
checks, or merge blockers. This is a native rewrite of the useful
`ce-resolve-pr-feedback` idea; do not use CE agents or peer reviewers.

Manager purpose:
- The manager should not inspect raw GitHub review threads or CI logs.
- Codex should identify actionable feedback, patch the branch, rerun validation,
  and report whether the PR is ready, merged, or blocked.

Required evidence:

```powershell
gh pr view <number-or-branch> --json number,state,title,url,headRefName,baseRefName,mergeStateStatus,reviewDecision,statusCheckRollup,comments,reviews
git status --short --branch
```

Procedure:
1. Identify the PR and branch.
2. Separate actionable feedback from discussion-only comments.
3. Patch only the PR-owned surface.
4. Run the smallest relevant validation, then the repo PR gate when appropriate.
5. Update PR evidence or final report with what was fixed, what was tested, and
   what remains blocked.
6. If the PR is clean and merge was requested or routine auto-merge rules allow
   it, use the repo mergeability and auto-merge helpers.

Rules:
- No peer/subagent/recursive AI review path.
- No force push, direct main push, or destructive history action.
- No credential, `.env`, `.ssh`, browser profile, cloud credential, or
  `secrets/**` access.
- If feedback asks for product priority, paid billing, public release,
  destructive action, host-global mutation, or credential use, stop for manager
  approval.

Manager report shape:

```markdown
built/inspected: checked PR feedback and changed <files>.
tested/evidence: <commands and results>.
manager run/paste: no manual GitHub/git command needed unless blocked.
blocked/unverified: <manager-only decision or unavailable evidence>
```
