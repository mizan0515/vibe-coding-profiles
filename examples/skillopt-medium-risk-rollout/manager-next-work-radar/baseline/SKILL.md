---
name: manager-next-work-radar
description: >
  다음작업 radar manager-next-work-radar: 관리자가 지금 무엇을 하면 좋을지
  물을 때 현재 이슈, PR, 보류 작업, 외부 후보, 최신 GitHub 후보를 함께 보고
  쉬운 한국어로 다음 행동을 추천합니다. Use when the manager asks what to do
  next, wants a backlog recommendation, asks open work status, asks for trendy
  repo discovery, or needs a compact post-overnight/all-ticket status scan.
  Trigger: "다음 작업", "뭐 하지", "뭐부터 하지", "백로그 추천",
  "남은 작업", "남은 티켓", "next work", "next ticket", "trendy repo",
  "최신 레포", "최신 저장소".
---

# Manager Next-Work Radar

Use this skill to answer: "what should we do next?"

## Root Intent

A non-developer manager wants one thing: "I opened a project; tell me what to
do next in this project, with evidence, without making me understand scripts."
The radar must therefore work in any GitHub checkout opened by the current Codex
isolated environment. A repo-local helper is an enhancement, not a requirement.

## What It Does

First chooses the selected GitHub repository from explicit `-Repo <owner/repo>`
or the current checkout remote. Then:
- if the selected checkout has a repo-local manager report helper, run it;
- otherwise run the skill-owned portable fallback:

```powershell
$portable = Join-Path $env:CODEX_HOME 'skills\manager-next-work-radar\assets\New-PortableManagerNextWorkReport.ps1'
& $portable -Repo <owner/repo>
```

The report checks:
- current open GitHub issues and PRs;
- pending/backlog-looking issues;
- dynamic GitHub repository discovery using stars, recent pushed/created windows,
  and search terms for agent runtime, memory, eval, observability, MCP/tooling,
  and newly created agent repositories;
- an explicit bounded ecosystem refresh only when `-RefreshEcosystem` is passed,
  starting from `caramaschiHG/awesome-ai-agents-2026` and checking selected
  candidates against primary GitHub repository metadata;
- whether positive experiments have an open follow-up or adoption/watch/reject
  decision path.

The script reports candidate next work. Codex owns the follow-through: if the
report identifies a concrete agent-solvable next action or a valuable pilot with
no next path, create/reuse a GitHub issue through `ticket-issue` or
`backlog-register` before edits. Do not leave it as prose only.

## Workflow

1. Resolve the selected repo. If the user named a repo, use that. Otherwise
   infer it from the current GitHub checkout:

   ```powershell
   $repoRoot = git rev-parse --show-toplevel 2>$null
   $selectedRepo = gh repo view --json nameWithOwner --jq '.nameWithOwner'
   ```

   In a generated/projectless Codex folder, require an explicit
   `-Repo <owner/repo>` instead of guessing another checkout.

2. Prefer the selected repo's helper only when it exists in that checkout:

   ```powershell
   $helper = if ($repoRoot) { Join-Path $repoRoot 'scripts\New-ManagerNextWorkReport.ps1' } else { '' }
   if ($helper -and (Test-Path -LiteralPath $helper)) {
     & $helper -Repo $selectedRepo
   } else {
     $portable = Join-Path $env:CODEX_HOME 'skills\manager-next-work-radar\assets\New-PortableManagerNextWorkReport.ps1'
     & $portable -Repo $selectedRepo
   }
   ```

3. For this repository, the enhanced helper path is:

   ```powershell
   .\scripts\New-ManagerNextWorkReport.ps1 -Repo mizan0515/codex-isolated-runtime
   ```

   For another project without this helper, use the portable fallback:

   ```powershell
   $portable = Join-Path $env:CODEX_HOME 'skills\manager-next-work-radar\assets\New-PortableManagerNextWorkReport.ps1'
   & $portable -Repo mizan0515/auto-caption-generator
   ```

4. If the user wants a durable artifact:

   ```powershell
   & $portable -Repo <owner/repo> -OutputPath .runtime\manager-next-work-radar\latest.md
   ```

5. If the user asks for latest/trendy external recommendations, run without
   `-SkipEcosystem`. Treat GitHub trend signals as discovery only. Verify
   official/source docs at execution time before recommending adoption.

   If the user asks to refresh the awesome-list seed, run an ecosystem radar,
   or run an adoption scan, make the list scan explicit and bounded:

   ```powershell
   .\scripts\New-ManagerNextWorkReport.ps1 -Repo <owner/repo> -SkipEcosystem -RefreshEcosystem
   ```

   `-RefreshEcosystem` may process a short candidate list from
   `caramaschiHG/awesome-ai-agents-2026`, but list-only claims remain
   `UNVERIFIED`. Create/reuse a visible evidence ticket before adopting any
   external tool, library, MCP server, or SDK.

   This is the manager-safe trigger path. Do not install a recurring schedule
   from this skill unless a current issue proves the cadence, ownership, output
   location, and follow-up handling. When no schedule is proven, report that the
   ecosystem radar is on-demand and trigger-based.

6. Separate:
   - `Observed locally`
   - `External observed`
   - `Dynamic trendy repo discovery`
   - `Bounded ecosystem decisions`
   - `Backlog / follow-up gates`
   - `Inferred`
   - `UNVERIFIED`
   - `Blocked`
   - `Next action`

7. Ask the manager only true manager decisions: product priority, paid billing,
   public release, destructive/irreversible action, host-global change,
   credential entry/use, or user-data transfer risk.

## Output

Use easy Korean. Keep it compact:

```markdown
## Manager Next-Work Radar

### 지금 상태
- 열린 이슈:
- 열린 PR:
- 보류:

### 새로 찾은 후보
- <trendy repo 후보와 왜 볼 만한지>

### 다음에 할 일
1. <추천 작업>

### 왜 이 순서인가
- <근거>

### 보류/주의
- <UNVERIFIED/BLOCKED>
```

## Boundaries

- Follow the repo `AGENTS.md` Runtime Boundary for forbidden secret-bearing,
  credential, browser-profile, and host-global profile paths.
- Keep the selected `-Repo <owner/repo>` as the current backlog and schedule
  source. Other repos are allowed only when clearly marked as downstream,
  historical, archive, fixture, or reference context.
- Do not fallback to `codex-isolated-runtime` just because a target checkout
  lacks `scripts\New-ManagerNextWorkReport.ps1`; use the skill-owned portable
  fallback for that selected repo.
- Do not claim external tools are adopted from the radar report alone.
- Do not close a valuable pilot as "not adopted" without a next issue,
  watch/reject decision, or verified true manager/hard-external blocker.
- Do not leave a new manager-facing script as a hidden command. If you add or
  change one, add a skill, automation/hook trigger, manager guide entry, or an
  explicit internal-only reason.
