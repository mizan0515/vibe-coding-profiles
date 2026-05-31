---
name: overnight-all-tickets
description: >
  밤샘전체티켓 overnight-all-tickets: 남은 티켓을 밤새 최대한 밀기 위한
  parent-owned 실행 번들을 만들고, 관리자가 parent /goal 하나만 붙여넣으면
  되도록 worker 목표, preflight, 재시도, adoption, 최종 보고 흐름을 구성합니다.
  Use when the manager asks to run every remaining ticket overnight, push all
  runnable work as far as possible, generate parent/worker goal bundles, or asks
  whether worker goals must be run manually.
  Trigger: "밤샘전체티켓", "밤새", "자기 전에", "남은 티켓 전부",
  "남은 티켓 다", "all tickets", "overnight", "overnight all tickets",
  "parent /goal 하나", "worker /goal", "overnight 감사", "overnight 결과물 확인",
  "지난 overnight", "다음 overnight로 미뤘는지", "데이터수집 안했는지".
---

# Overnight All Tickets

Generate and run a repo-local overnight execution bundle. This skill is the
primary source of truth for the current all-tickets flow. Older giant prompt
files are compatibility/fallback specs only.

## Manager Contract

Normal path:

```text
Manager runs one parent /goal only.
Parent owns SmokeOnly, TuiVisible, ExecBackground, worker start, retry,
adoption, parent-direct serial fallback, next waves, validation,
PR/merge/issue/Project gates, and final report.
Worker /goals are fallback artifacts and recovery handles, not manager chores.
```

Do not ask the manager to run SmokeOnly, TuiVisible, ExecBackground, or
individual worker `/goal`s during normal overnight operation. Ask only true
manager decisions: product priority, paid billing, public release,
destructive/irreversible action, host-global change, credential entry/use, user
data transfer risk, or verified hard-external access.

## Audit Signal Mode

When the manager signals an overnight audit, act as the overnight skill audit
owner, not as a new planning worker. Inspect the latest completed or attempted
overnight result before generating any next overnight bundle.

Accepted audit signals include:

- "overnight 감사"
- "지난 overnight 확인"
- "overnight 결과물 확인"
- "다음 overnight로 미뤘는지 봐"
- "데이터수집 직접 할 수 있는데 안했는지 봐"
- typo variants such as "overnignt", "overnitgnt", "overningt"

Required audit inputs, discovered locally when the manager does not provide a
path:

```powershell
Get-ChildItem -Path .runtime\goal-runs -Directory -ErrorAction SilentlyContinue | Sort-Object LastWriteTime -Descending | Select-Object -First 5
Get-ChildItem -Path .runtime\goal-bundles -Filter "*overnight-all-tickets-parent.md" -ErrorAction SilentlyContinue | Sort-Object LastWriteTime -Descending | Select-Object -First 5
Get-ChildItem -Path docs\manager-reports -Filter "*overnight*report*.md" -ErrorAction SilentlyContinue | Sort-Object LastWriteTime -Descending | Select-Object -First 5
gh issue list --state open --json number,title,labels,updatedAt,url --limit 100
gh pr list --state open --json number,title,headRefName,mergeStateStatus,updatedAt,url --limit 100
```

If multiple runs exist, audit the newest run with a manager report first; then
cross-check its run id against `.runtime/goal-runs/<RUN_ID>/workflow-state.json`,
parent progress, worker reports, status JSON, issue/PR comments, and generated
artifacts. If no report exists, audit the newest parent bundle and run
artifacts, and mark the manager report `MISSING`.

The audit must answer these questions before allowing another overnight:

- Did the final report defer an agent-solvable task to "next overnight",
  "follow-up", "watch", "후속", "보류", "나중", "future ticket flow", or an
  open issue without same-run attempts?
- Did any lane need public data, transcripts, subtitles, examples, benchmark
  samples, candidates, browser evidence, dependency probing, latest docs, or
  open-source/tool adoption review that Codex could safely collect or inspect
  under repo rules, but did not attempt?
- Did the parent create or cite a tracker instead of running
  `ParentDirectSerial`, local commands, browser automation, public internet
  research, dependency probes, or safe artifact generation?
- Did upstream evidence expand after downstream scoring, matching, validation,
  proposal, training-readiness, or review ran, without rerunning that downstream
  executable path?
- Did the manager report claim exhaustion, Done, no manager action, or all safe
  lanes executed while any artifact still shows `NOT_RUN`, `SKIPPED_NOT_RUN`,
  `UNVERIFIED`, `PARENT_REVIEW_READY`, missing validation, proposed-only data,
  or stale inputs?

Audit result rules:

- If agent-solvable work was skipped, stale, or merely deferred, do not produce
  the next overnight bundle yet. Re-enter the same run when possible, or create
  a corrected parent continuation objective that first performs the skipped
  collection, rerun, validation, or adoption path.
- If direct data collection was possible but skipped, name the exact safe data
  route to run now, such as repo-local download tooling, public transcript or
  subtitle acquisition, browser DOM evidence, public search/latest docs, local
  sample generation, dependency probe, or existing artifacts to parse. Respect
  secrets, cookies, `.env`, host-global, and user-data boundaries.
- If a blocker is truly manager-only or hard-external, require command/tool
  evidence showing why Codex could not proceed. An old open issue or old comment
  is not enough.
- If the previous run can be continued, prefer a parent continuation over
  starting a fresh overnight. A fresh overnight is allowed only after the audit
  shows no skipped agent-solvable collection/rerun/adoption remains, or the
  continuation itself is blocked by verified hard-external state.

### Audit Stop Gates

The audit must fail when a run closes with `status: done`, "manager has nothing
to run", "manager run/paste: none", or "Codex can continue in follow-up
sessions" while any of these remain:

- open draft PRs whose normal PR gates, comments, checks, review threads,
  rebase, merge, issue close, or Project update are still agent-owned;
- `COMMENT_FOLLOWUP_NEEDED`, `ISSUE_COMMENT_FOLLOWUP_NEEDED`, or stop-marker
  comments that can be read/classified by Codex;
- `PARENT_REVIEW_READY`, `PR_READY` without mergeability/check evidence, or
  review-ready outputs not adopted by the parent;
- serialized waits based only on an active claim, unless the parent proves live
  owner liveness, non-stale threshold, and why safe stale-release or
  ParentDirectSerial is not allowed now;
- missing reconciliation/checker scripts that were only ticketed, when a small
  bounded implementation or checker repair could be attempted in the same
  session;
- public data, transcript/subtitle, browser evidence, latest-docs,
  dependency-probe, or open-source/tool adoption paths that failed in a worker
  under a transient environment such as proxy/temp-dir but were not retried by
  the parent after environment recovery or with an alternate safe route.

`workflow-state.json` must not use `status: done` when any lane count shows
remaining agent-owned work: `draft_prs`, `blocked`, `serialized_wait`,
`claim_released_ready`, `review_ready`, `not_started`, or `failed` above zero,
unless each remaining lane has same-run execution/adoption evidence and is
classified manager-only, hard-external, or explicitly out-of-scope. An empty
`blockers` array is not enough.

If a lane was serialized by claim and a later claim check becomes
`OWNERSHIP_CLEAR_TO_START`, the parent must reclassify it as runnable-now or
manager-only/hard-external. It cannot close the run under `done` without a
same-run attempt, adoption evidence, or a continuation objective.

A final report must fail if it moves current-run inventory, priority/core/top
issues, claim-released lanes, or data-acquisition lanes to "future ticket flow",
"normal ticket flow", "next overnight", "후속", "보류", or "나중" without a
parent continuation goal or hard-external/manager-only evidence.

For these failures, the audit output must not say `manager run/paste: none`.
It must produce exactly one parent continuation `/goal` that resumes the
previous run and orders the remaining work by unblock-first priority:

1. fix or run the reconciliation/checker gate;
2. classify stop-marker/comment gates and rerun mergeability;
3. finish draft PR gates, undraft only after evidence, then auto-merge routine
   PRs when repo policy allows;
4. retry safe data/transcript/browser/dependency routes that are agent-owned;
5. release/retry stale claims only with claim evidence;
6. update issues/Project and the manager report with final evidence.

Audit output format:

```text
built/inspected:
- latest overnight run/report audited: <path/run id>
- artifacts checked: <short list>

tested/evidence:
- <commands or artifact evidence used>

manager run/paste:
- <one parent continuation /goal if skipped agent-solvable work exists, or one
  next overnight /goal only if audit passed>

blocked/unverified:
- <true manager-only/hard-external blockers, or "none">

audit verdict:
- PASS_NEXT_OVERNIGHT_ALLOWED | FAIL_CONTINUE_PREVIOUS_RUN_FIRST
- skipped agent-solvable work: <yes/no and exact lanes>
- direct data collection skipped: <yes/no and exact routes>
- stale downstream rerun needed: <yes/no and exact command/path>
```

## Required Skills

Read and apply when present:

- `ticket-review`
- `ticket-issue`
- `parallel-ticket-planner`
- `finish-to-done`
- `easy-briefing`
- `repo-evidence-cli`
- `codex-safety-guard`
- PR/merge/close: `ticket-close`, `main-sync`
- experiments/adoption: `root-goal-check`

If a skill file is missing, record `UNVERIFIED_SKILL_MISSING`, use this skill's
embedded rule, and continue when safe.

## Evidence Preflight

Run from the target repo. Failed commands become `UNVERIFIED` or `BLOCKED`;
never invent clean state.

```powershell
git rev-parse --show-toplevel
git status --short --branch --untracked-files=all
git branch --show-current
git remote -v
git worktree list
gh auth status
gh repo view --json nameWithOwner,url,defaultBranchRef,projectsV2
gh issue list --state open --json number,title,labels,updatedAt,body,url,projectItems --limit 200
gh pr list --state open --json number,title,headRefName,baseRefName,isDraft,mergeStateStatus,updatedAt,url --limit 100
gh issue list --state closed --json number,title,closedAt,labels,url --limit 50
rg -n "TODO|FIXME|HACK|XXX|pending|deferred|보류|백로그|follow-up|후속" . --glob "!secrets/**" --glob "!.env" --glob "!.env.*" --glob "!.ssh/**" --glob "!**/.ssh/**" --glob "!node_modules/**" --glob "!.git/**" --glob "!dist/**" --glob "!build/**" --glob "!*.original.md"
```

Use repo-local session claim scripts when available. Preserve unrelated
dirty/untracked work. Never reset, stash, clean, delete, or revert user work.

## Bundle Files

Create under the target repo:

- `.runtime/goal-bundles/<RUN_ID>-overnight-all-tickets-parent.md`
- `.runtime/goal-bundles/<RUN_ID>-T001-<slug>.md` for all runnable/serialized
  worker lanes
- `.runtime/goal-bundles/<RUN_ID>-Start-OvernightWorkers.ps1`
- `.runtime/goal-runs/<RUN_ID>/reports/parent-progress.md`
- `.runtime/goal-runs/<RUN_ID>/reports/worker-T001-report.md`
- `.runtime/goal-runs/<RUN_ID>/status/worker-T001-status.json`
- `.runtime/goal-runs/<RUN_ID>/logs/worker-T001-transcript.txt`
- `.runtime/goal-runs/<RUN_ID>/workflow-state.json`
- `docs/manager-reports/<RUN_ID>-overnight-all-tickets-report.md`, unless repo
  policy forbids docs changes; then use
  `.runtime/goal-runs/<RUN_ID>/manager-summary.md`.

Use the canonical launcher asset instead of hand-authoring launcher logic:

- source asset:
  `runtime/codex-desktop/profile-template/skills/overnight-all-tickets/assets/Start-OvernightWorkers.ps1`
- target copy:
  `.runtime/goal-bundles/<RUN_ID>-Start-OvernightWorkers.ps1`
- target manifest:
  `.runtime/goal-bundles/<RUN_ID>-launcher-manifest.json`

The parent may fill target repo, run id, and worker manifest values, but should
not rewrite the core SmokeOnly, classification, or worker launch gate logic.

Keep the final manager-facing parent `/goal` under 1200 characters. Long
instructions belong in bundle files, not in the chat objective.

## Ticket Inventory

Inventory all of these:

- open issues
- open PRs
- clear TODO/backlog/local pending work
- recent closed issues relevant to follow-up
- dirty/untracked files
- worktrees and branches
- validation docs and repo rules

Classify each item:

- runnable now
- runnable after current wave
- serialized dependency
- pending keep
- true manager decision
- hard-external/auth/network blocked
- duplicate/stale/project essence weak

Reuse existing issues whenever possible. Create new issues only for clear,
verifiable local work. Do not create speculative follow-up issues before
evidence proves them.

## Agent-Solvable Non-Completion

Treat any agent-solvable non-completion as runnable overnight work, not as a
final blocker. This is broader than data/evidence gaps. It includes missing or
weak implementation, latest technology research, open-source/tool adoption
review, dependency probe, feature implementation, integration gap, validation
failure, failing tests, missing real-use proof, browser automation, UI
discoverability, hidden manager entry point, cleanup, mergeability/comment
gates, stale claims, doc/prompt/skill gaps, sample/data shortages,
transcript/subtitle acquisition, public candidate discovery, and any inspectable
blocker the target repo rules allow Codex to attempt.

When a lane says "needs improvement", "needs latest research", "needs
integration", "needs validation", "needs cleanup", "data is insufficient",
"need more samples", "need public transcripts", "watch", "follow-up", "후속",
"보류", or similar, the parent must classify whether the remaining work is
agent-solvable before final reporting:

- Agent-solvable: run finish-to-done style Autonomous Blocker Resolution in the
  same overnight session. Try bounded approaches through local commands, tests,
  code changes, browser automation, public internet/latest docs,
  open-source/tool adoption review, dependency probe, public data/transcript
  routes, repo tooling, or safe local artifact generation as allowed. If workers
  did not do it, use `ParentDirectSerial`.
- Manager-only: ask only for product priority, credentials, billing, public
  release, destructive/irreversible action, host-global promotion, or user data
  transfer risk.
- Hard-external: record exact command/source evidence proving the dependency is
  unavailable or requires unavailable account/credential/paid access.

Open ticket, comment-only status, or wording like "Codex should do this later"
is not enough for `PARENT_REVIEW_READY`, Done, or exhaustion when the missing
work is agent-solvable. An existing open issue is a tracker, not proof of
same-run exhaustion. The parent must first attempt the bounded finish-to-done
route, record each method tried, outputs, limits, why remaining options are
unsafe/unavailable, and the next executable retry condition. If still
unresolved, keep or create the smallest open not-Done tracker and link it from
the manager report.

### Data Acquisition Before NOT_ENOUGH_DATA

Issue #928 tracks a regression where an overnight run could report
`NOT_ENOUGH_DATA`, insufficient candidates, missing transcript/source slices, or
"learning approval is not needed because material is insufficient" without
first running additional safe data collection that the target repo allowed. This
is not an acceptable stop state by itself.

Before final reporting, Done, exhaustion, `PARENT_REVIEW_READY`, or
manager-readable "no training/prompt approval needed" wording, parent must run
or attempt a bounded `DataAcquisition` lane whenever the remaining gap is
candidate/material volume or reviewable labels. The lane must use repo-approved
safe routes before stopping, such as:

- existing repo video-download, public media cache, transcript acquisition,
  source-slice, report/export, or manager-edit parsing commands;
- public metadata/search/crawl routes that do not require credentials, cookies,
  private browser state, owner analytics, or paid access;
- Webwright, Browser, Playwright-style scripts, or Chrome DevTools for public
  pages, rendered DOM/action-log evidence, diagnostics, or allowed reusable
  browser automation;
- local parsing of generated artifacts under repo-approved ignored runtime or
  generated directories.

The lane must record command lines or browser route, input source, output path,
new candidate/transcript/slice/label counts, stop condition, safety limits, and
whether raw media/private data stayed uncommitted. If collection remains
impossible, the final report must list each attempted collection route and why
no further safe route remains. Saying "data is insufficient" after only reading
old artifacts, old comments, active-claim text, or stale reports fails the final
artifact-to-claim audit.

### Same-Run Attempt Ledger Gate

Issue #925 tracks a regression where a parent report kept existing target-repo
issues open but did not force every current-run attempt and skipped/serialized
lane reason back into those issues. To prevent this, every final report,
exhaustion claim, `PARENT_REVIEW_READY`, `PR_READY`, or manager-readable
"nothing for manager to run" statement must prove a current-run attempt ledger
for each unresolved lane. The ledger can be a GitHub issue/PR comment or a
durable run artifact linked from the relevant issue/PR, but it must include:

- run id and lane id;
- issue/PR number and current state;
- commands or actions attempted in this run, or an explicit `NOT_RUN` reason;
- outputs, limits, and validation results;
- stale/serialized claim evidence when a lane was not relaunched;
- why remaining work is manager-only, hard-external, serialized wait, unsafe,
  or still agent-solvable;
- exact next executable retry condition and owner surface;
- linked open not-Done tracker.

Old comments, old artifacts, or a pre-existing open issue may be cited as
context, but they do not satisfy this gate unless the parent appends or links a
current-run ledger that says why no further safe parent action was possible.
If the parent cannot write the ledger because GitHub is unavailable, it must
write the same ledger into the run artifact, mark GitHub ledger posting
`UNVERIFIED`, and keep the lane blocked from Done/exhaustion claims.

The final manager report must not say "manager has nothing to decide" while
leaving an agent-solvable non-completion unattempted. It must instead say what
Codex attempted, what was found, what remains open, and why no further safe
agent action is currently possible.

## Final Artifact-to-Claim Audit

Before any final manager report, Done, exhaustion, `MERGED_DONE`, or "all safe
lanes executed" claim, parent must run a final artifact-to-claim audit. This is
a required stop gate, not optional narrative review. The audit compares the
manager-facing report, parent-progress, worker reports, lane status JSON,
workflow-state, GitHub issue/PR comments, and key generated artifacts.

The audit must fail the final report and re-enter the wave loop or
`ParentDirectSerial` when it finds any agent-solvable contradiction:

- skipped-stage audit: artifacts contain `SKIPPED_NOT_RUN`, `NOT_RUN`,
  `UNVERIFIED`, `PARENT_REVIEW_READY`, `SKIPPED_MISSING_*`,
  `*_UNAVAILABLE`, `TODO`, `후속`, `보류`, `watch`, or "not run" while the
  final report claims exhaustion, Done, or no worker/action remains
- stale-input audit: an upstream lane expanded evidence after a downstream lane
  ran, such as more candidates, transcripts, source slices, browser evidence,
  dependency/tool availability, or test fixtures, but the downstream proposal,
  validation, matching, scoring, review, or training-readiness lane was not
  rerun on the newer artifact
- downstream-rerun audit: a report says "inputs increased", "coverage improved",
  or "new artifacts exist" while the dependent lane only posted a count
  correction instead of rerunning the executable command path
- contradiction audit: final report wording such as "safe lanes all executed",
  "manager has nothing to run", "학습 시작 불가", or "완료" conflicts with
  lane artifacts that show runnable missing stages, stale evidence, missing
  validation, or proposed-only data that still needs agent-owned batching
- review-ready audit: `PARENT_REVIEW_READY` is not Done and cannot be hidden in
  a final report as completed unless parent adopted the lane, reran required
  gates, and either merged/closed it or left an explicit not-Done tracker
- attempt-ledger audit: every unresolved, serialized, stale, skipped, or
  review-ready lane must have a current-run attempt ledger in the issue/PR or a
  linked run artifact. A pre-existing open issue or old comment alone fails the
  audit.

If the audit finds an agent-solvable issue, parent must not publish the final
report as exhaustion. It must run the smallest bounded retry before report:
rerun the downstream command with the latest artifact, execute skipped local
test/tool/browser/open-source/dependency/data paths, or create/repair the
missing checker when the checker itself is the blocker. Only after these
attempts may the parent report remaining manager-only or hard-external blockers.

The final report must include a compact audit summary:

- artifacts checked
- stale or skipped evidence found
- retries run before report
- remaining unsafe/unavailable options
- open not-Done trackers for unresolved agent-solvable leftovers

Absence of a reconciliation script is not enough to claim `UNVERIFIED` and stop.
If `scripts\Test-OvernightRunReconciliation.ps1` is missing, parent must run an
equivalent manual artifact-to-claim audit and create/reuse a follow-up issue for
the missing script only after the manual audit is complete.

## Parallel Planning

Apply `parallel-ticket-planner` for:

- dependency graph
- surface-by-ticket conflict matrix
- owner/read-only/forbidden surfaces
- phase guide
- separate parent cleanup/adoption prompts when needed
- self-contained worker bundles

In this overnight mode, do not present worker prompts as a manager paste queue.
Label them as fallback artifacts.

## Worker Worktree Provisioning

Before any TuiVisible or ExecBackground worker launch, the parent must create
and verify one explicit Git worktree per runnable worker lane.

Required lane setup:

- create each worker worktree under `.runtime/worktrees/` with a lane-specific
  branch such as `codex/<issue>-<slug>` or
  `codex/overnight-<issue>-<slug>-<run-id>`
- run `git worktree add` or verify an existing matching worktree before writing
  the launcher manifest
- run `git -C <worktree> rev-parse --show-toplevel`, `git -C <worktree> branch
  --show-current`, and `git -C <worktree> status --short --branch
  --untracked-files=all`; record the evidence in parent-progress and
  `workflow-state.json`
- acquire or check the session claim for that lane with the issue, branch,
  worktree, and owner surfaces before launch
- put the verified absolute `worktree` path in each launcher manifest worker
  record; do not omit it and do not use the root checkout as a parallel worker
  worktree

The canonical launcher rejects missing, nonexistent, root-checkout, or non-Git
worker worktrees with `WORKTREE_MISSING_OR_INVALID`. Treat that as an
agent-solvable parent bundle defect: create or repair the lane worktree, update
the manifest, rerun SmokeOnly only when needed, then retry worker launch. Do not
ask the manager to paste fallback worker goals until worktree repair,
launcher/runtime recovery, and `ParentDirectSerial` have all failed with
evidence.

## Parent Bundle Requirements

The parent bundle must include:

- target repo path, remote, base branch, Project evidence
- project essence gate
- full ticket inventory and classifications
- start-now lanes, next-wave lanes, serialized lanes, blocked lanes
- issue/PR reuse/create decisions
- lane metadata: id, issue/local task, title, branch, worktree, owner write
  surface, read-only surface, forbidden surface, validations, done signal,
  report/status/log paths
- `MAX_PARALLEL_WORKERS`, default 3
- exhaustion condition
- root dirty/untracked protection
- session claim rule
- parent-owned launch method
- worker result adoption rule
- stuck worker diagnostic rule
- Windows sandbox spawn recovery rule
- ParentDirectSerial fallback rule when worker launch remains blocked
- agent-solvable non-completion finish-to-done rule, including direct attempts
  for missing implementation, latest technology research, validation failure,
  integration gap, UI discoverability, browser automation, public internet,
  open-source/tool adoption review, dependency probe, transcript/subtitle, and
  safe public artifact generation before final report
- final artifact-to-claim audit rule, including skipped-stage audit,
  stale-input audit, downstream-rerun audit, contradiction audit, review-ready
  audit, and retry-before-report behavior
- validation rerun, PR mergeability, auto-merge, issue close, Project update
  gates
- long-running/resumable rule
- finish-to-done blocker auto-followup
- no-ship/containment boundary
- manager-visible surface gate
- experiment-to-ticket/root-goal-check gate
- instruction stale scan gate
- retired MoA/ROI boundary
- final manager report format

## Parent-Owned Launch

Put this exact rule in the parent bundle:

```text
Manager does not manually run SmokeOnly, TuiVisible, ExecBackground, or individual worker /goals during normal overnight operation.

Parent owns launch preflight:
1. Run the bundled launcher in SmokeOnly mode and record report/status/log evidence, including the exact Codex command shape, exit code, state file, and output-last-message.
2. SmokeOnly retries transient `SANDBOX_SPAWN_FAIL` with bounded backoff, records every attempt, and stops retrying immediately for non-transient failures such as `CLI_SHAPE_FAIL`.
3. If default Windows SmokeOnly ends in `SANDBOX_SPAWN_FAIL`, the launcher retries the same SmokeOnly probe with per-command `-c windows.sandbox="unelevated"` and records `launcher-sandbox-recovery.json`; this does not mutate host-global Codex config and is not dangerous sandbox bypass.
4. SmokeOnly passes only when the launcher proves real shell spawn with a minimal command such as `Write-Output hi`, the state file says `SMOKE_PASS`, and the final output-last-message is `SMOKE_PASS`.
5. If SmokeOnly passes through unelevated recovery, every later TuiVisible/ExecBackground worker Codex invocation must inherit the same per-command `windows.sandbox="unelevated"` setting.
6. If SmokeOnly fails after bounded default retry and bounded unelevated recovery, do not run TuiVisible, ExecBackground, or any worker. Mark TuiVisible and ExecBackground `UNVERIFIED`, classify the blocker, and switch to `ParentDirectSerial` before reporting a manager-facing blocker.
7. If SmokeOnly passes, run TuiVisible preflight and verify visible PowerShell PID, sentinel/status/log, liveness, and non-hidden window behavior.
8. Before TuiVisible or ExecBackground worker launch, create or verify one explicit Git worktree per selected worker lane, acquire/check the session claim for that worktree and branch, and write the verified absolute worktree path into the launcher manifest. Missing or invalid worker worktree is `WORKTREE_MISSING_OR_INVALID` and must be repaired by the parent before launch retry.
9. If TuiVisible passes, start the first worker wave through TuiVisible.
10. If TuiVisible fails but ExecBackground conditions can be proven, run ExecBackground smoke and start workers only after report, PID, exit/output, state file, output-last-message, and worker worktree evidence all pass.
11. If parallel spawn contention appears after SmokeOnly passes, lower MAX_PARALLEL_WORKERS to 1, add stagger delay, and retry serially.
12. `ParentDirectSerial` means the parent executes safe runnable lanes itself, one at a time, with the same issue/worktree/session-claim/no-ship/validation/PR gates a worker would use. It must preserve the dependency order and conflict matrix, acquire or check the session claim per lane, stop only for true manager decisions, verified hard-external blockers, context exhaustion with a continuation artifact, or no runnable lanes.
13. If `ParentDirectSerial` cannot safely execute a lane, classify that lane and continue the next independent lane when possible; do not ask the manager to paste worker /goals as the normal path.
14. If a lane is blocked by an agent-solvable non-completion, `ParentDirectSerial` must try bounded finish-to-done work itself before any final blocker report. This includes missing implementation, latest technology research, validation failure, integration gap, UI discoverability, browser automation, public internet, open-source/tool adoption review, dependency probe, public transcript/subtitle routes, and safe local artifact generation allowed by repo rules.
15. If launcher/runtime recovery and `ParentDirectSerial` both cannot progress, record the exact blocker in parent-progress and then present Desktop/app worker /goals as fallback artifacts.

Worker /goals are fallback artifacts and recovery handles. They are not the normal manager execution path.
```

Launcher commands are parent-internal commands. They may appear in the parent
bundle for the parent to run, but not as manager chores.

## Launcher Requirements

`<RUN_ID>-Start-OvernightWorkers.ps1` must support:

```powershell
[ValidateSet("TuiVisible","ExecBackground","SmokeOnly")]
[string]$Mode = "TuiVisible"
[string]$TargetRepo
[string]$RunId
[string]$ManifestPath
[int]$MaxParallelWorkers = 3
[int]$StartDelaySeconds = 30
[int]$SmokeMaxAttempts = 3
[int]$SmokeRetryDelaySeconds = 20
[switch]$PreflightOnly
```

Launcher duties:

- start from the canonical `assets/Start-OvernightWorkers.ps1` launcher asset
  and a manifest JSON; do not hand-generate divergent launcher control flow
- verify `codex --help`, `codex exec --help`, auth, sandbox, and Codex CLI
  option placement before any worker launch
- use global Codex options before `exec`: `codex --ask-for-approval never --cd
  <repo> --sandbox workspace-write exec ...`. Treat `codex exec
  --ask-for-approval never --cd <repo> --sandbox workspace-write ...` as
  `CLI_SHAPE_FAIL`, because those options are not valid after `exec` on the
  current CLI
- use prompt files/runner scripts, not long prompt bodies in argv
- run SmokeOnly to prove worker shell command spawn and report/status/log writes;
  help output alone is never enough
- SmokeOnly must run a real minimal shell spawn through Codex, such as
  `Write-Output hi`, then require `SMOKE_PASS` in the state file and
  output-last-message before TuiVisible, ExecBackground, or worker launch
- retry transient SmokeOnly `SANDBOX_SPAWN_FAIL` with bounded backoff, record
  `smoke_max_attempts`, `smoke_retry_delay_seconds`, and per-attempt
  state/log/output-last-message paths in `launcher-smoke.json`, and do not
  retry `CLI_SHAPE_FAIL` or other non-transient failures as if they were sandbox
  refresh flakes
- when default Windows SmokeOnly keeps returning `SANDBOX_SPAWN_FAIL`, retry
  SmokeOnly with per-command `-c windows.sandbox="unelevated"`, record
  `launcher-sandbox-recovery.json`, and if it passes, use the same per-command
  setting for TuiVisible and ExecBackground worker Codex invocations without
  changing host-global Codex config
- do not retry `CLI_SHAPE_FAIL`; command-shape errors need launcher/prompt fixes,
  not delay loops
- do not treat process `exit_code: 0` as success when the state file or final
  message says `SMOKE_FAIL`; logical smoke state outranks launcher process exit
- run TuiVisible preflight before worker wave; require visible PowerShell PID,
  sentinel/status/log, liveness, and non-hidden window behavior
- require every selected manifest worker to include an explicit `worktree` path
  that exists, is a Git top-level, and is not the root target repo; classify
  missing or invalid worktrees as `WORKTREE_MISSING_OR_INVALID` and do not fall
  back to the root checkout
- run ExecBackground only after smoke proves `--output-last-message`, PID,
  report, state file, and exit/output evidence
- treat wrong PID, immediate exit, placeholder report, missing transcript, or
  stale heartbeat as `WORKER_START_FAILED`
- classify option-order rejection as `CLI_SHAPE_FAIL`
- classify `windows sandbox: spawn setup refresh` and shell spawn failures as
  `SANDBOX_SPAWN_FAIL`: a worker launcher runtime blocker, not ticket code
  failure and not a manager decision
- when SmokeOnly fails even after default retry and unelevated recovery, forbid
  worker launch, keep TuiVisible/ExecBackground `UNVERIFIED`, and require the
  parent bundle to use `ParentDirectSerial` for safe runnable lanes before it
  reports a manager-facing blocker
- retry with `MAX_PARALLEL_WORKERS=1` and stagger delay before hard-external
- never use dangerous sandbox bypass/yolo/danger-full-access without explicit
  manager approval

## Wave Loop

Parent repeats until exhaustion:

1. Refresh target repo, issue, PR, worktree, report, status, process evidence.
2. Preserve unrelated dirty/untracked work.
3. Run session-claim preflight, then check session claims. If a claim blocks a
   lane, report `WAIT_FOR_OTHER_SESSION` for live owners and
   `STALE_CLAIM_REVIEW_NEEDED` for stale/missing-PID owners; parent owns safe
   release/retry with evidence, not the manager.
4. Create or verify per-lane Git worktrees and branches under
   `.runtime/worktrees`, then write only verified worktree paths into the
   launcher manifest.
5. Run parent-owned launcher preflight.
6. Start verified independent worker lanes up to current concurrency limit.
7. If launcher preflight remains blocked, run safe lanes through
   `ParentDirectSerial` one at a time instead of stopping for manager action.
8. If a worker or parent lane reports needs improvement, latest research needed,
   missing implementation, validation failure, integration gap, UI
   discoverability, missing data, missing transcript, insufficient candidates,
   missing references, sample-too-small, watch, 후속, or 보류, classify it as an
   agent-solvable non-completion by default. Before final reporting, try
   bounded finish-to-done routes through local commands, code changes, tests,
   public internet/latest docs, browser automation, open-source/tool adoption
   review, dependency probe, public transcript/subtitle routes, or existing repo
   tooling unless target repo safety rules forbid it.
9. If the lane reports `NOT_ENOUGH_DATA`, insufficient candidates, missing
   transcripts/source slices, sample-too-small, or "training/learning approval
   not needed because material is insufficient", run or attempt a bounded
   `DataAcquisition` lane before final reporting. Use repo-approved public
   media/transcript/download/search/crawl/browser/DevTools/local-artifact
   routes, then record counts, output paths, stop conditions, and safety limits.
10. Watch report/status/log/transcript/PID/PR/check evidence.
11. Adopt verified outputs only.
12. Rerun validation and mergeability gates.
13. Merge/close/update Project when routine and safe.
14. Create/reuse smallest follow-up only when evidence proves it, and never as
    a substitute for same-session attempts on agent-solvable non-completions.
15. Post or write the same-run attempt ledger for every unresolved, serialized,
    stale, skipped, review-ready, or blocked lane. Existing open issues are
    not enough without this run's attempted methods, skipped reason, limits,
    next command, and retry condition.
16. Run the final artifact-to-claim audit before any final report or exhaustion
    claim. If it finds skipped runnable stages, stale inputs, downstream rerun
    gaps, report/artifact contradictions, or hidden `PARENT_REVIEW_READY`, treat
    that as an agent-solvable non-completion and run the smallest bounded retry.
17. Recalculate remaining runnable tickets.
18. Start next wave or next parent-direct serial lane.

Exhaustion condition: no runnable tickets remain, or every remaining item is a
true manager decision, verified hard-external/auth/network blocker, or serialized
dependency wait after agent-solvable non-completions have been attempted and
recorded with methods, outputs, limits, unsafe/unavailable remaining options,
exact retry conditions, and a passing final artifact-to-claim audit.

## Parent Run Reconciliation

Before any Done, merge-ready, or manager-facing final report claim, reconcile the
actual run artifacts with `scripts/Test-OvernightRunReconciliation.ps1` or an
equivalent repo-local check.

Required reconciliation:

- Read launcher status, worker/lane status JSON, worker reports, PR/issue state,
  canonical `workflow-state.json`, and the manager report path for the current
  run.
- Prefer `workflow-state.json` as the GUI/source-of-truth state contract when
  present; scattered status/report/metrics artifacts remain compatibility
  fallback only.
- Final manager report must be generated from actual status evidence, not from a
  stale template or earlier placeholder.
- Fail stale reports when they say the parent has not run, workers have not
  started, or launch is still pending while status files show execution.
- Fail reports that mention open follow-up tickets without a current-run
  attempt ledger for the issue/PR that records what this parent tried, why it
  stopped, and the exact retry condition. Old issue comments can be supporting
  evidence, not the current run's stop proof.
- Include lane counts in the manager report: merged/adopted, review-ready, blocked, not started, failed, skipped.
- Count `ParentDirectSerial` lanes and explain them as worker-launch recovery or
  fallback, not hidden success.
- `PARENT_REVIEW_READY` is not Done. It must stay visible as review-ready until
  the parent adopts, validates, and closes or merges the lane.
- If reconciliation fails, update parent-progress with the exact mismatch and fix
  the report/adoption state before closing issues or claiming exhaustion.
- Missing reconciliation script means use the manual final artifact-to-claim audit
  above; do not downgrade to `UNVERIFIED_RECONCILIATION_SCRIPT_MISSING`
  as a substitute for checking artifacts and retrying agent-solvable leftovers.

## Worker Bundle Requirements

Each worker bundle must be one independent ticket/local task only and include:

- repo/worktree/branch/issue
- owner, read-only, forbidden surfaces
- no recursive AI/Codex/Claude/Gemini/Qwen/MCP bridge/TeamCreate/Agent/subagent
- evidence to collect first
- implementation scope
- validation commands
- pre-implementation and pre-final no-ship review
- finish-to-done requirement
- session claim requirement
- long-running/resumable rule
- blocker autofollowup loop
- agent-solvable non-completion rule: missing implementation, latest technology
  research, validation failure, integration gap, UI discoverability, browser
  evidence, data, transcript, sample, public candidate, reference,
  open-source/tool adoption review, or dependency probe must be attempted
  directly when safe instead of reported as next overnight
- PR/mergeability gate
- manager-visible surface gate
- experiment-to-ticket/root-goal-check gate
- report/status/log paths
- final signal rule

Worker final signals:

- `PARENT_REVIEW_READY` when parent adoption is needed
- `PR_READY` only with current mergeability/check evidence
- `MERGED_DONE` only when repo policy allows worker merge and evidence proves
  merge/close
- `BLOCKED_TRUE_MANAGER` only for true manager decision with finish-to-done proof
- `HARD_EXTERNAL_BLOCKED` only with command/tool evidence and recovery proof
- `STOP` is invalid unless evidence proves non-agent-solvable stop reason

## Final Output

Generator response must include:

1. generated file paths
2. one manager-facing parent `/goal`
3. parent-internal launcher status and evidence paths
4. fallback worker `/goal` artifacts, clearly labeled fallback
5. remaining `UNVERIFIED`/`BLOCKED` evidence
6. final artifact-to-claim audit summary
7. self-check

Parent `/goal` template:

```text
/goal Read and execute the parent coordinator bundle at "<TARGET_REPO>\.runtime\goal-bundles\<RUN_ID>-overnight-all-tickets-parent.md". You own all worker launch preflight and orchestration: prove SmokeOnly with real shell spawn plus SMOKE_PASS state/final message before TuiVisible, ExecBackground, or worker launch; classify CLI_SHAPE_FAIL vs SANDBOX_SPAWN_FAIL; start verified worker waves, retry with lower concurrency or serial/staggered launch when allowed; if worker launch remains blocked after recovery, use ParentDirectSerial to execute safe lanes yourself one at a time before reporting a blocker; adopt reports/status/log/PR evidence and continue until exhaustion. Worker /goals are fallback artifacts, not manager chores. Routine git/GitHub/validation/merge/issue/Project work is agent-owned; ask only true manager decisions. Write the manager-readable overnight report.
```

Fallback worker label:

```text
Fallback worker /goal artifacts. Parent uses these only if launcher automation is blocked, or a manager explicitly chooses manual recovery after parent reports why automatic launch cannot run in this environment.
```

`manager run/paste` wording:

```text
manager run/paste:
- 정상 경로: parent /goal 하나만 붙여넣습니다.
- SmokeOnly, TuiVisible, ExecBackground, worker 실행은 parent coordinator가 맡습니다.
- worker를 띄울 수 없으면 parent가 먼저 안전한 작업을 순서대로 직접 처리합니다.
- parent가 자동 실행과 직접 처리 모두 불가능하다고 증거와 함께 보고할 때만 fallback worker /goal을 수동으로 사용합니다.
```

## Self-Check

- [ ] This is an execution bundle, not a plan-only response.
- [ ] Manager normal path is one parent `/goal` only.
- [ ] SmokeOnly/TuiVisible/ExecBackground and worker start/retry/adoption are parent-owned.
- [ ] SmokeOnly requires real shell spawn plus `SMOKE_PASS` state and final message before any worker launch.
- [ ] `CLI_SHAPE_FAIL` and `SANDBOX_SPAWN_FAIL` are classified separately.
- [ ] `exit_code: 0` with `SMOKE_FAIL` is treated as failure.
- [ ] SmokeOnly failure forbids TuiVisible, ExecBackground, and worker launch; direct parent execution is only for exactly one runnable lane with claim/worktree evidence.
- [ ] Worker `/goal`s are labeled fallback artifacts, not manager paste chores.
- [ ] Parent bundle has launcher preflight, retry, serial/stagger fallback.
- [ ] Parent creates or verifies one explicit Git worktree per worker lane
  before launcher manifest handoff.
- [ ] Launcher rejects missing, invalid, root-checkout, or non-Git worker
  worktrees with `WORKTREE_MISSING_OR_INVALID` instead of falling back to the
  target repo.
- [ ] Windows `SANDBOX_SPAWN_FAIL` triggers per-command unelevated sandbox
  recovery before hard-external, without host-global config mutation or
  dangerous bypass.
- [ ] If worker launch stays blocked, ParentDirectSerial runs safe lanes before
  manager-facing fallback worker Goals.
- [ ] Parent copies the canonical launcher asset and fills a manifest instead of hand-authoring launcher logic.
- [ ] Parent continues waves until exhaustion.
- [ ] Agent-solvable non-completions are not deferred as "next overnight"
  without finish-to-done attempts via local commands, code changes, tests,
  latest technology research, public internet, browser automation,
  open-source/tool adoption review, dependency probe, public transcript/subtitle
  routes, or repo tooling.
- [ ] Final artifact-to-claim audit compares manager report, parent-progress,
  worker reports, status JSON, workflow-state, GitHub comments, and key
  generated artifacts before Done, exhaustion, or "all safe lanes executed".
- [ ] Skipped-stage audit catches `SKIPPED_NOT_RUN`, `NOT_RUN`, `UNVERIFIED`,
  `PARENT_REVIEW_READY`, unavailable stages, `후속`, `보류`, `watch`, and "not
  run" before final report.
- [ ] Stale-input audit catches downstream lanes that were not rerun after
  upstream evidence expansion.
- [ ] Downstream-rerun audit catches count-only corrections that do not rerun
  the executable command path.
- [ ] Contradiction audit catches final report wording that conflicts with
  lane artifacts or proposed-only evidence.
- [ ] Review-ready audit keeps `PARENT_REVIEW_READY` separate from Done until
  parent adoption and gates are complete.
- [ ] Missing reconciliation script triggers manual artifact-to-claim audit, not
  a stop-at-UNVERIFIED shortcut.
- [ ] Final reports list attempted methods, outputs, limits,
  unsafe/unavailable remaining options, and open not-Done trackers for
  unresolved agent-solvable non-completions.
- [ ] Every unresolved, serialized, stale, skipped, blocked, or review-ready
  lane has a same-run attempt ledger in the issue/PR or a linked durable run
  artifact; old open issues/comments alone are not counted as sufficient.
- [ ] Parent run reconciliation detects stale manager reports, includes lane
  counts, and keeps `PARENT_REVIEW_READY` separate from Done.
- [ ] Ticket inventory covers open issues, open PRs, TODO/local pending, recent
  closed, dirty/untracked, worktrees.
- [ ] Target repo and runtime repo are separated.
- [ ] `parallel-ticket-planner` dependency graph/conflict matrix/surfaces are
  included.
- [ ] `ticket-issue` create/reuse and duplicate prevention are included.
- [ ] `finish-to-done` blocker auto-resolution and no-ship gates are included.
- [ ] Routine git/GitHub/validation/PR/merge/issue/Project work is agent-owned.
- [ ] Only true manager decisions are escalated.
- [ ] Worker cannot call another AI/agent/bridge.
- [ ] Dirty/untracked user work is preserved.
- [ ] PID/report/status/log/transcript evidence gates exist.
- [ ] Windows sandbox spawn failures trigger launcher recovery before
  hard-external.
- [ ] Long-running jobs are resumable/polled, not treated as blockers.
- [ ] Manager-visible surface gate exists.
- [ ] Experiment-to-ticket/root-goal-check gate exists.
- [ ] Instruction stale scan gate exists.
- [ ] Retired MoA/ROI boundary exists.
- [ ] Final report uses easy Korean with built/tested/manager-run/blocked
  sections.
