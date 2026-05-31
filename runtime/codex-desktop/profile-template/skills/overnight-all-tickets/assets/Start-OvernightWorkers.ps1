param(
  [ValidateSet("SmokeOnly", "TuiVisible", "ExecBackground")]
  [string]$Mode = "SmokeOnly",
  [Parameter(Mandatory = $true)][string]$TargetRepo,
  [Parameter(Mandatory = $true)][string]$RunId,
  [string]$ManifestPath = "",
  [int]$MaxParallelWorkers = 3,
  [int]$StartDelaySeconds = 30,
  [int]$SmokeMaxAttempts = 3,
  [int]$SmokeRetryDelaySeconds = 20,
  [switch]$PreflightOnly
)

$ErrorActionPreference = "Stop"

function Resolve-FullPath([string]$Path) {
  return [System.IO.Path]::GetFullPath($Path)
}

$TargetRepo = Resolve-FullPath $TargetRepo
if (-not (Test-Path -LiteralPath $TargetRepo -PathType Container)) {
  throw "Target repo does not exist: $TargetRepo"
}

if ([string]::IsNullOrWhiteSpace($ManifestPath)) {
  $ManifestPath = Join-Path $TargetRepo ".runtime\goal-bundles\$RunId-launcher-manifest.json"
}
$ManifestPath = Resolve-FullPath $ManifestPath

$RunRoot = Join-Path $TargetRepo ".runtime\goal-runs\$RunId"
$ReportRoot = Join-Path $RunRoot "reports"
$StatusRoot = Join-Path $RunRoot "status"
$LogRoot = Join-Path $RunRoot "logs"
$LauncherSummaryPath = Join-Path $ReportRoot "launcher-summary.md"
$LauncherArtifactsPath = Join-Path $StatusRoot "launcher-artifacts.json"
$MetricsScriptPath = Join-Path $TargetRepo "scripts\New-OvernightRunMetrics.ps1"
$MetricsRoot = Join-Path $RunRoot "metrics"
$MetricsJsonPath = Join-Path $MetricsRoot "overnight-metrics.json"
$MetricsCsvPath = Join-Path $MetricsRoot "overnight-metrics.csv"
$MetricsMarkdownPath = Join-Path $MetricsRoot "overnight-metrics.md"
$SandboxRecoveryPath = Join-Path $StatusRoot "launcher-sandbox-recovery.json"
$WorkflowStatePath = Join-Path $RunRoot "workflow-state.json"
$CodexCommand = Get-Command codex -ErrorAction Stop
$CodexPath = $CodexCommand.Source

New-Item -ItemType Directory -Force -Path $ReportRoot, $StatusRoot, $LogRoot | Out-Null

function Write-JsonFile {
  param(
    [Parameter(Mandatory = $true)][string]$Path,
    [Parameter(Mandatory = $true)]$Object
  )
  $Object | ConvertTo-Json -Depth 12 | Set-Content -LiteralPath $Path -Encoding UTF8
}

function Read-TextIfExists([string]$Path) {
  if (Test-Path -LiteralPath $Path) {
    return (Get-Content -LiteralPath $Path -Raw)
  }
  return ""
}

function Test-PathState([string]$Path) {
  if ([string]::IsNullOrWhiteSpace($Path)) { return "missing" }
  if (Test-Path -LiteralPath $Path) { return "present" }
  return "missing"
}

function Get-StatusTone([string]$Value) {
  $normalized = $Value.ToLowerInvariant()
  if ($normalized -match "merged|adopted|done|pass|ready") { return "done" }
  if ($normalized -match "blocked|hard_external|conflict|fail|error") { return "blocked" }
  if ($normalized -match "started|running|working|active") { return "working" }
  if ($normalized -match "not_started|pending|queued|waiting") { return "not_started" }
  return "not_started"
}

function New-EmptyLaneCounts {
  return [ordered]@{
    merged_adopted = 0
    review_ready = 0
    blocked = 0
    not_started = 0
    failed = 0
    skipped = 0
  }
}

function Get-CurrentLaneCounts {
  $counts = New-EmptyLaneCounts
  if (-not (Test-Path -LiteralPath $StatusRoot)) {
    return $counts
  }
  $statusFiles = @(Get-ChildItem -LiteralPath $StatusRoot -Filter "worker-*.json" -File -ErrorAction SilentlyContinue)
  foreach ($file in $statusFiles) {
    try {
      $status = Get-Content -LiteralPath $file.FullName -Raw | ConvertFrom-Json
      $combined = "$($status.final_signal) $($status.state) $($status.status)".Trim().ToUpperInvariant()
      if ($combined -match "PARENT_REVIEW_READY") { $counts.review_ready++ }
      elseif ($combined -match "MERGED_DONE|ADOPTED_DONE|DONE_ADOPTED|MERGED|ADOPTED") { $counts.merged_adopted++ }
      elseif ($combined -match "HARD_EXTERNAL_BLOCKED|BLOCKED_TRUE_MANAGER|BLOCKED") { $counts.blocked++ }
      elseif ($combined -match "FAILED|FAIL|ERROR") { $counts.failed++ }
      elseif ($combined -match "SKIPPED|SKIPPED_CAPABILITY_ARTIFACT") { $counts.skipped++ }
      else { $counts.not_started++ }
    } catch {
      $counts.failed++
    }
  }
  return $counts
}

function Write-WorkflowState {
  param(
    [Parameter(Mandatory = $true)][string]$Phase,
    [string]$State = "",
    [string]$Classification = "",
    [object[]]$Workers = @()
  )

  $laneCounts = Get-CurrentLaneCounts
  $status = Get-StatusTone "$State $Classification"
  $lanes = @($Workers | ForEach-Object {
    [ordered]@{
      id = $_.id
      issue = $_.issue
      status = "started"
      title = "Issue #$($_.issue)"
      evidence = [ordered]@{
        report = $_.report_path
        status = $_.status_path
        log = $_.log_path
        capability_status = $_.capability_status_path
      }
    }
  })

  $summary = switch ($Phase) {
    "SmokeOnly" { "SmokeOnly launcher proof was recorded." }
    default { "Overnight parent launcher phase recorded: $Phase." }
  }

  Write-JsonFile -Path $WorkflowStatePath -Object ([ordered]@{
    schema_version = "workflow-state.v1"
    source = "canonical"
    run_id = $RunId
    status = $status
    phase = $Phase
    manager_summary = [ordered]@{
      current = $summary
      needs_manager = $false
    }
    next_action = if ($status -eq "blocked") { "Review the linked issue evidence and retry the named condition." } else { "Continue the parent-owned overnight workflow." }
    lane_counts = $laneCounts
    evidence = [ordered]@{
      run_root = $RunRoot
      launcher_summary = $LauncherSummaryPath
      launcher_artifacts = $LauncherArtifactsPath
      smoke_status = (Join-Path $StatusRoot "launcher-smoke.json")
      manager_report = ""
    }
    phases = @([ordered]@{
      id = ($Phase -replace '[^A-Za-z0-9_-]+', '-').Trim('-').ToLowerInvariant()
      title = $Phase
      status = $status
      summary = $summary
      laneCounts = $laneCounts
      lanes = $lanes
    })
    lanes = $lanes
    blockers = @()
    updated_at = (Get-Date).ToUniversalTime().ToString("o")
  })
}

function Write-LauncherEvidenceBundle {
  param(
    [Parameter(Mandatory = $true)][string]$Phase,
    [string]$State = "",
    [object]$ExitCode = $null,
    [string]$Classification = "",
    [object[]]$Workers = @()
  )

  $cliPreflightPath = Join-Path $StatusRoot "launcher-cli-preflight.json"
  $smokeStatusPath = Join-Path $StatusRoot "launcher-smoke.json"
  $smokeLastMessagePath = Join-Path $StatusRoot "launcher-smoke-last-message.txt"
  $smokeLogPath = Join-Path $LogRoot "launcher-smoke-jsonl.log"
  $tuiPreflightPath = Join-Path $StatusRoot "TuiVisible-preflight-status.json"
  $execPreflightPath = Join-Path $StatusRoot "ExecBackground-preflight-status.json"
  $reproductionCommand = "powershell.exe -NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`" -Mode $Mode -TargetRepo `"$TargetRepo`" -RunId `"$RunId`" -ManifestPath `"$ManifestPath`""
  $metricsStatus = "missing"
  if (Test-Path -LiteralPath $MetricsScriptPath) {
    try {
      $metricsRaw = & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $MetricsScriptPath -Root $TargetRepo -RunId $RunId -OutputRoot $MetricsRoot -Phase $Phase -Mode $Mode 2>&1
      $metricsText = (($metricsRaw | Out-String).Trim())
      $metricsParsed = if (-not [string]::IsNullOrWhiteSpace($metricsText)) { $metricsText | ConvertFrom-Json } else { $null }
      $metricsStatus = if ($metricsParsed -and $metricsParsed.status -eq "PASS") { "present" } else { "unverified" }
    } catch {
      $metricsStatus = "unverified"
    }
  }

  Write-WorkflowState -Phase $Phase -State $State -Classification $Classification -Workers $Workers

  $artifactIndex = [ordered]@{
    run_id = $RunId
    target_repo = $TargetRepo
    mode = $Mode
    phase = $Phase
    state = $State
    classification = $Classification
    exit_code = $ExitCode
    selected_windows_sandbox = Get-SmokeSelectedWindowsSandbox
    reproduction_command = $reproductionCommand
    summary = $LauncherSummaryPath
    manifest = $ManifestPath
    cli_preflight = $cliPreflightPath
    smoke_status = $smokeStatusPath
    smoke_output_last_message = $smokeLastMessagePath
    smoke_log = $smokeLogPath
    tui_visible_preflight = $tuiPreflightPath
    exec_background_preflight = $execPreflightPath
    metrics_summary = $MetricsMarkdownPath
    metrics_json = $MetricsJsonPath
    metrics_csv = $MetricsCsvPath
    workers = @($Workers | ForEach-Object {
      [ordered]@{
        id = $_.id
        issue = $_.issue
        worktree = $_.worktree
        report_path = $_.report_path
        status_path = $_.status_path
        log_path = $_.log_path
        capability_status_path = $_.capability_status_path
      }
    })
    artifacts = @(
      [ordered]@{ name = "launcher-summary.md"; path = $LauncherSummaryPath; state = "present" },
      [ordered]@{ name = "launcher-artifacts.json"; path = $LauncherArtifactsPath; state = "present" },
      [ordered]@{ name = "launcher-cli-preflight.json"; path = $cliPreflightPath; state = (Test-PathState $cliPreflightPath) },
      [ordered]@{ name = "launcher-smoke.json"; path = $smokeStatusPath; state = (Test-PathState $smokeStatusPath) },
      [ordered]@{ name = "launcher-sandbox-recovery.json"; path = $SandboxRecoveryPath; state = (Test-PathState $SandboxRecoveryPath) },
      [ordered]@{ name = "launcher-smoke-last-message.txt"; path = $smokeLastMessagePath; state = (Test-PathState $smokeLastMessagePath) },
      [ordered]@{ name = "launcher-smoke-jsonl.log"; path = $smokeLogPath; state = (Test-PathState $smokeLogPath) },
      [ordered]@{ name = "TuiVisible-preflight-status.json"; path = $tuiPreflightPath; state = (Test-PathState $tuiPreflightPath) },
      [ordered]@{ name = "ExecBackground-preflight-status.json"; path = $execPreflightPath; state = (Test-PathState $execPreflightPath) },
      [ordered]@{ name = "workflow-state.json"; path = $WorkflowStatePath; state = (Test-PathState $WorkflowStatePath) },
      [ordered]@{ name = "overnight-metrics.md"; path = $MetricsMarkdownPath; state = $metricsStatus },
      [ordered]@{ name = "overnight-metrics.json"; path = $MetricsJsonPath; state = $metricsStatus },
      [ordered]@{ name = "overnight-metrics.csv"; path = $MetricsCsvPath; state = $metricsStatus }
    )
    updated_at = (Get-Date).ToUniversalTime().ToString("o")
  }

  $workerLines = @($artifactIndex.workers | ForEach-Object {
    "- $($_.id) issue #$($_.issue): capability=$($_.capability_status_path); status=$($_.status_path); report=$($_.report_path); log=$($_.log_path)"
  })
  if ($workerLines.Count -eq 0) {
    $workerLines = @("- No workers selected in this launcher phase.")
  }

  $artifactLines = @($artifactIndex.artifacts | ForEach-Object {
    "- $($_.name): $($_.state) - $($_.path)"
  })

  $summaryLines = [System.Collections.Generic.List[string]]::new()
  foreach ($line in @(
    "# Launcher Evidence Summary: $RunId",
    "",
    "phase: $Phase",
    "mode: $Mode",
    "state: $State",
    "classification: $Classification",
    "exit_code: $ExitCode",
    "selected_windows_sandbox: $($artifactIndex.selected_windows_sandbox)",
    "",
    "reproduction_command:",
    '```powershell',
    $reproductionCommand,
    '```',
    "",
    "artifacts:"
  )) {
    $summaryLines.Add([string]$line) | Out-Null
  }
  foreach ($line in $artifactLines) {
    $summaryLines.Add([string]$line) | Out-Null
  }
  foreach ($line in @("", "workers:")) {
    $summaryLines.Add([string]$line) | Out-Null
  }
  foreach ($line in $workerLines) {
    $summaryLines.Add([string]$line) | Out-Null
  }
  foreach ($line in @(
    "",
    "metrics summary:",
    "- markdown: $MetricsMarkdownPath",
    "- json: $MetricsJsonPath",
    "- csv: $MetricsCsvPath",
    "",
    "manager note: process start is not success. Parent must inspect report/status/log/PR evidence before adoption."
  )) {
    $summaryLines.Add([string]$line) | Out-Null
  }
  $summary = $summaryLines -join [Environment]::NewLine
  Set-Content -LiteralPath $LauncherSummaryPath -Encoding UTF8 -Value $summary
  Write-JsonFile -Path $LauncherArtifactsPath -Object $artifactIndex
}

function Invoke-Codex {
  param(
    [Parameter(Mandatory = $true)][string]$WorkingDirectory,
    [Parameter(Mandatory = $true)][string[]]$Arguments,
    [Parameter(Mandatory = $true)][string]$LogPath,
    [string]$StandardInput = ""
  )

  Push-Location -LiteralPath $WorkingDirectory
  $oldErrorActionPreference = $ErrorActionPreference
  $oldNativePreference = $null
  $hasNativePreference = Get-Variable -Name PSNativeCommandUseErrorActionPreference -Scope Global -ErrorAction SilentlyContinue
  try {
    $ErrorActionPreference = "Continue"
    if ($hasNativePreference) {
      $oldNativePreference = $global:PSNativeCommandUseErrorActionPreference
      $global:PSNativeCommandUseErrorActionPreference = $false
    }
    if ([string]::IsNullOrEmpty($StandardInput)) {
      $output = & $CodexPath @Arguments 2>&1
    } else {
      $output = $StandardInput | & $CodexPath @Arguments 2>&1
    }
    $exitCode = $LASTEXITCODE
  } finally {
    $ErrorActionPreference = $oldErrorActionPreference
    if ($hasNativePreference) {
      $global:PSNativeCommandUseErrorActionPreference = $oldNativePreference
    }
    Pop-Location
  }
  $combinedOutput = ($output | Out-String)

  $combined = @(
    ">>> codex $($Arguments -join ' ')",
    $combinedOutput,
    "<<< exit=$exitCode"
  ) -join [Environment]::NewLine
  Set-Content -LiteralPath $LogPath -Encoding UTF8 -Value $combined

  return [pscustomobject]@{
    exit_code = $exitCode
    stdout = $combinedOutput
    stderr = ""
    combined = $combined
  }
}

function Classify-CodexResult {
  param(
    [int]$ExitCode,
    [string]$Output,
    [string]$LastMessage
  )
  if ($LastMessage.Trim() -eq "SMOKE_PASS") {
    return "SMOKE_PASS"
  }
  if ($Output -match "unexpected argument") {
    return "CLI_SHAPE_FAIL"
  }
  if ($Output -match "windows sandbox: spawn setup refresh|spawn setup refresh|shell spawn") {
    return "SANDBOX_SPAWN_FAIL"
  }
  if ($ExitCode -ne 0) {
    return "CODEX_EXEC_FAIL"
  }
  return "SMOKE_FAIL"
}

function New-CodexExecArguments {
  param(
    [Parameter(Mandatory = $true)][string]$Repo,
    [Parameter(Mandatory = $true)][string]$OutputLastMessagePath,
    [string[]]$AdditionalWritableDirs = @(),
    [switch]$UseUnelevatedWindowsSandbox
  )

  $arguments = @("--ask-for-approval", "never")
  if ($UseUnelevatedWindowsSandbox) {
    $arguments += @("-c", 'windows.sandbox="unelevated"')
  }
  $arguments += @("--cd", $Repo)
  foreach ($dir in @($AdditionalWritableDirs)) {
    if (-not [string]::IsNullOrWhiteSpace($dir)) {
      $arguments += @("--add-dir", $dir)
    }
  }
  $arguments += @("--sandbox", "workspace-write", "exec", "--color", "never", "--output-last-message", $OutputLastMessagePath, "--json", "-")
  return $arguments
}

function Get-SmokeCommandShape([switch]$UseUnelevatedWindowsSandbox) {
  $config = if ($UseUnelevatedWindowsSandbox) { ' -c windows.sandbox="unelevated"' } else { "" }
  return "codex --ask-for-approval never$config --cd <repo> --sandbox workspace-write exec --output-last-message <file> --json -"
}

function Get-SmokeSelectedWindowsSandbox {
  $statusPath = Join-Path $StatusRoot "launcher-smoke.json"
  if (-not (Test-Path -LiteralPath $statusPath)) {
    return ""
  }
  try {
    $smoke = Get-Content -LiteralPath $statusPath -Raw | ConvertFrom-Json
    if ($smoke.PSObject.Properties.Name -contains "selected_windows_sandbox") {
      return [string]$smoke.selected_windows_sandbox
    }
  } catch {
    return ""
  }
  return ""
}

function New-WorkerCodexArgumentLiteral {
  param(
    [Parameter(Mandatory = $true)][string]$Worktree,
    [Parameter(Mandatory = $true)][string]$ReportPath,
    [string[]]$AdditionalWritableDirs = @(),
    [string]$SelectedWindowsSandbox = ""
  )

  $items = @("'--ask-for-approval'", "'never'")
  if ($SelectedWindowsSandbox -eq "unelevated") {
    $items += @("'-c'", "'windows.sandbox=`"unelevated`"'")
  }
  $items += @("'--cd'", "'$Worktree'")
  foreach ($dir in @($AdditionalWritableDirs)) {
    if (-not [string]::IsNullOrWhiteSpace($dir)) {
      $items += @("'--add-dir'", "'$dir'")
    }
  }
  $items += @("'--sandbox'", "'workspace-write'", "'exec'", "'--color'", "'never'", "'--output-last-message'", "'$ReportPath'", "'-'")
  return "@($($items -join ', '))"
}

function Test-CodexCli {
  $statusPath = Join-Path $StatusRoot "launcher-cli-preflight.json"
  $checks = @()
  foreach ($args in @(@("--help"), @("exec", "--help"))) {
    $name = "codex-" + (($args -join "-") -replace '[^A-Za-z0-9_-]+', "-")
    $log = Join-Path $LogRoot "$name.log"
    $result = Invoke-Codex -WorkingDirectory $TargetRepo -Arguments $args -LogPath $log
    $checks += [pscustomobject]@{
      command = "codex $($args -join ' ')"
      exit_code = $result.exit_code
      log = $log
    }
    if ($result.exit_code -ne 0) {
      Write-JsonFile -Path $statusPath -Object ([pscustomobject]@{
        state = "CLI_PREFLIGHT_FAIL"
        checks = $checks
        updated_at = (Get-Date).ToUniversalTime().ToString("o")
      })
      throw "Codex CLI preflight failed: codex $($args -join ' ')"
    }
  }
  Write-JsonFile -Path $statusPath -Object ([pscustomobject]@{
    state = "CLI_PREFLIGHT_PASS"
    checks = $checks
    updated_at = (Get-Date).ToUniversalTime().ToString("o")
  })
}

function Invoke-SmokeOnly {
  Test-CodexCli

  $statusPath = Join-Path $StatusRoot "launcher-smoke.json"
  $lastMessagePath = Join-Path $StatusRoot "launcher-smoke-last-message.txt"
  $logPath = Join-Path $LogRoot "launcher-smoke-jsonl.log"
  $maxAttempts = [Math]::Max(1, $SmokeMaxAttempts)
  $retryDelaySeconds = [Math]::Max(0, $SmokeRetryDelaySeconds)
  $prompt = @"
You are running an overnight launcher SmokeOnly probe.
Do not edit files.
Run exactly this PowerShell command with the shell: Write-Output SMOKE_PASS
If the command succeeds, reply exactly: SMOKE_PASS
If it fails, report the error and do not claim success.
"@

  $attempts = @()
  $state = "SMOKE_FAIL"
  $lastMessage = ""
  $result = $null

  $selectedWindowsSandbox = "default"
  $recoveryAttempted = $false
  $recoveryState = "NOT_NEEDED"
  $smokePlans = @(
    [pscustomobject]@{ name = "default"; use_unelevated = $false },
    [pscustomobject]@{ name = "unelevated"; use_unelevated = $true }
  )

  foreach ($plan in $smokePlans) {
    if ($plan.use_unelevated -and $state -ne "SANDBOX_SPAWN_FAIL") {
      break
    }
    if ($plan.use_unelevated) {
      $recoveryAttempted = $true
      $recoveryState = "WINDOWS_UNELEVATED_RETRYING"
    }

    for ($attempt = 1; $attempt -le $maxAttempts; $attempt++) {
      $attemptKey = if ($plan.use_unelevated) { "unelevated-attempt-{0}" -f $attempt } else { "attempt-{0}" -f $attempt }
      $attemptLastMessagePath = Join-Path $StatusRoot ("launcher-smoke-last-message-$attemptKey.txt")
      $attemptLogPath = Join-Path $LogRoot ("launcher-smoke-jsonl-$attemptKey.log")
      Remove-Item -LiteralPath $attemptLastMessagePath -Force -ErrorAction SilentlyContinue

      $args = New-CodexExecArguments -Repo $TargetRepo -OutputLastMessagePath $attemptLastMessagePath -UseUnelevatedWindowsSandbox:([bool]$plan.use_unelevated)
      $result = Invoke-Codex -WorkingDirectory $TargetRepo -Arguments $args -LogPath $attemptLogPath -StandardInput $prompt
      $lastMessage = Read-TextIfExists $attemptLastMessagePath
      $state = Classify-CodexResult -ExitCode $result.exit_code -Output $result.combined -LastMessage $lastMessage
      Set-Content -LiteralPath $lastMessagePath -Encoding UTF8 -Value $lastMessage
      Set-Content -LiteralPath $logPath -Encoding UTF8 -Value $result.combined

      if ($state -eq "SMOKE_PASS") {
        $selectedWindowsSandbox = [string]$plan.name
      }

      $willRetry = $state -eq "SANDBOX_SPAWN_FAIL" -and $attempt -lt $maxAttempts
      $attempts += [pscustomobject]@{
        attempt = $attempt
        sandbox_mode = [string]$plan.name
        state = $state
        exit_code = $result.exit_code
        command_shape = Get-SmokeCommandShape -UseUnelevatedWindowsSandbox:([bool]$plan.use_unelevated)
        output_last_message = $attemptLastMessagePath
        log = $attemptLogPath
        retry_after_seconds = if ($willRetry) { $retryDelaySeconds } else { $null }
      }

      if ($state -eq "SMOKE_PASS") {
        $recoveryState = if ($plan.use_unelevated) { "WINDOWS_UNELEVATED_RECOVERY_PASS" } else { "NOT_NEEDED" }
        break
      }
      if (-not $willRetry) {
        break
      }

      Write-JsonFile -Path $statusPath -Object ([pscustomobject]@{
        state = "SANDBOX_SPAWN_RETRYING"
        mode = "SmokeOnly"
        target_repo = $TargetRepo
        command_shape = Get-SmokeCommandShape -UseUnelevatedWindowsSandbox:([bool]$plan.use_unelevated)
        selected_windows_sandbox = $selectedWindowsSandbox
        sandbox_recovery = $recoveryState
        exit_code = $result.exit_code
        output_last_message = $lastMessagePath
        log = $logPath
        smoke_max_attempts = $maxAttempts
        smoke_retry_delay_seconds = $retryDelaySeconds
        attempts = $attempts
        tui_visible = "UNVERIFIED"
        exec_background = "UNVERIFIED"
        worker_launch = "FORBIDDEN"
        updated_at = (Get-Date).ToUniversalTime().ToString("o")
      })
      if ($retryDelaySeconds -gt 0) {
        Start-Sleep -Seconds $retryDelaySeconds
      }
    }

    if ($state -eq "SMOKE_PASS") {
      break
    }
  }

  if ($state -eq "SANDBOX_SPAWN_FAIL" -and $recoveryAttempted) {
    $recoveryState = "WINDOWS_UNELEVATED_RECOVERY_FAIL"
  }

  Write-JsonFile -Path $SandboxRecoveryPath -Object ([pscustomobject]@{
    state = $recoveryState
    selected_windows_sandbox = $selectedWindowsSandbox
    default_attempts = @($attempts | Where-Object { $_.sandbox_mode -eq "default" }).Count
    unelevated_attempts = @($attempts | Where-Object { $_.sandbox_mode -eq "unelevated" }).Count
    note = "Per-command windows.sandbox=`"unelevated`" is used only after default SmokeOnly returns SANDBOX_SPAWN_FAIL; host-global Codex config is not changed."
    updated_at = (Get-Date).ToUniversalTime().ToString("o")
  })

  Write-JsonFile -Path $statusPath -Object ([pscustomobject]@{
    state = $state
    mode = "SmokeOnly"
    target_repo = $TargetRepo
    command_shape = Get-SmokeCommandShape -UseUnelevatedWindowsSandbox:($selectedWindowsSandbox -eq "unelevated")
    selected_windows_sandbox = $selectedWindowsSandbox
    sandbox_recovery = $recoveryState
    sandbox_recovery_status = $SandboxRecoveryPath
    exit_code = $result.exit_code
    output_last_message = $lastMessagePath
    log = $logPath
    smoke_max_attempts = $maxAttempts
    smoke_retry_delay_seconds = $retryDelaySeconds
    attempts = $attempts
    tui_visible = "UNVERIFIED"
    exec_background = "UNVERIFIED"
    worker_launch = if ($state -eq "SMOKE_PASS") { "ALLOWED_AFTER_ADDITIONAL_PREFLIGHT" } else { "FORBIDDEN" }
    updated_at = (Get-Date).ToUniversalTime().ToString("o")
  })
  Write-LauncherEvidenceBundle -Phase "SmokeOnly" -State $state -ExitCode $result.exit_code -Classification $state

  if ($state -ne "SMOKE_PASS") {
    throw "SmokeOnly failed with $state; do not run TuiVisible, ExecBackground, or workers."
  }
}

function Read-LauncherManifest {
  if (-not (Test-Path -LiteralPath $ManifestPath)) {
    return [pscustomobject]@{ workers = @() }
  }
  return Get-Content -LiteralPath $ManifestPath -Raw | ConvertFrom-Json
}

function Get-GitTopLevel([string]$Path) {
  $oldErrorActionPreference = $ErrorActionPreference
  $oldNativePreference = $null
  $hasNativePreference = Get-Variable -Name PSNativeCommandUseErrorActionPreference -Scope Global -ErrorAction SilentlyContinue
  try {
    $ErrorActionPreference = "Continue"
    if ($hasNativePreference) {
      $oldNativePreference = $global:PSNativeCommandUseErrorActionPreference
      $global:PSNativeCommandUseErrorActionPreference = $false
    }
    $output = & git -C $Path rev-parse --show-toplevel 2>$null
    if ($LASTEXITCODE -ne 0) {
      return ""
    }
    return (Resolve-FullPath (($output | Select-Object -First 1).ToString().Trim()))
  } finally {
    $ErrorActionPreference = $oldErrorActionPreference
    if ($hasNativePreference) {
      $global:PSNativeCommandUseErrorActionPreference = $oldNativePreference
    }
  }
}

function Assert-WorkerWorktree {
  param(
    [Parameter(Mandatory = $true)][string]$WorkerId,
    [object]$Issue,
    [object]$Worker,
    [Parameter(Mandatory = $true)][string]$StatusPath
  )

  $reason = ""
  $rawWorktree = ""
  $resolvedWorktree = ""
  $gitTopLevel = ""

  if ($Worker.PSObject.Properties.Name -contains "worktree") {
    $rawWorktree = [string]$Worker.worktree
  }
  if ([string]::IsNullOrWhiteSpace($rawWorktree)) {
    $reason = "worker.worktree is required; refusing to fall back to TargetRepo for parallel work."
  } else {
    $resolvedWorktree = Resolve-FullPath $rawWorktree
    if (-not (Test-Path -LiteralPath $resolvedWorktree -PathType Container)) {
      $reason = "worker.worktree does not exist."
    } elseif ($resolvedWorktree.TrimEnd('\', '/') -ieq $TargetRepo.TrimEnd('\', '/')) {
      $reason = "worker.worktree resolves to TargetRepo; each parallel worker needs its own worktree."
    } else {
      $gitTopLevel = Get-GitTopLevel $resolvedWorktree
      if ([string]::IsNullOrWhiteSpace($gitTopLevel)) {
        $reason = "worker.worktree is not a Git worktree."
      } elseif ($gitTopLevel.TrimEnd('\', '/') -ine $resolvedWorktree.TrimEnd('\', '/')) {
        $reason = "worker.worktree is not the Git top-level for this lane."
      }
    }
  }

  if (-not [string]::IsNullOrWhiteSpace($reason)) {
    Write-JsonFile -Path $StatusPath -Object ([pscustomobject]@{
      state = "WORKTREE_MISSING_OR_INVALID"
      worker_id = $WorkerId
      issue = $Issue
      worktree = $rawWorktree
      resolved_worktree = $resolvedWorktree
      target_repo = $TargetRepo
      git_top_level = $gitTopLevel
      reason = $reason
      note = "Launcher refuses root-checkout fallback so independent overnight lanes cannot write concurrently in TargetRepo."
      updated_at = (Get-Date).ToUniversalTime().ToString("o")
    })
    throw "Worker $WorkerId worktree invalid: $reason See $StatusPath"
  }

  return $resolvedWorktree
}

function Assert-SmokePass {
  $statusPath = Join-Path $StatusRoot "launcher-smoke.json"
  if (-not (Test-Path -LiteralPath $statusPath)) {
    throw "Worker launch blocked: SmokeOnly status missing. Run -Mode SmokeOnly first."
  }
  $smoke = Get-Content -LiteralPath $statusPath -Raw | ConvertFrom-Json
  if ($smoke.state -ne "SMOKE_PASS") {
    throw "Worker launch blocked: SmokeOnly state is $($smoke.state)."
  }
  return $smoke
}

function Invoke-ProcessPreflight {
  param([bool]$Visible)
  $statusPath = Join-Path $StatusRoot ("{0}-preflight-status.json" -f $Mode)
  $sentinelPath = Join-Path $StatusRoot ("{0}-preflight-sentinel.txt" -f $Mode)
  $runnerPath = Join-Path $LogRoot ("{0}-preflight-runner.ps1" -f $Mode)
  @"
`$ErrorActionPreference = 'Stop'
'started=' + (Get-Date).ToUniversalTime().ToString('o') | Set-Content -LiteralPath '$sentinelPath' -Encoding UTF8
Start-Sleep -Seconds 10
"@ | Set-Content -LiteralPath $runnerPath -Encoding UTF8

  $windowStyle = if ($Visible) { "Normal" } else { "Hidden" }
  $proc = Start-Process -FilePath "powershell.exe" -ArgumentList @("-NoProfile", "-ExecutionPolicy", "Bypass", "-File", "`"$runnerPath`"") -WindowStyle $windowStyle -PassThru
  Start-Sleep -Seconds 2
  $live = Get-Process -Id $proc.Id -ErrorAction SilentlyContinue
  $state = if ($live -and (Test-Path -LiteralPath $sentinelPath)) { "PREFLIGHT_PASS" } else { "WORKER_START_FAILED" }
  Write-JsonFile -Path $statusPath -Object ([pscustomobject]@{
    state = $state
    pid = $proc.Id
    visible_window_expected = $Visible
    sentinel = $sentinelPath
    runner = $runnerPath
    updated_at = (Get-Date).ToUniversalTime().ToString("o")
  })
  Write-LauncherEvidenceBundle -Phase "$Mode preflight" -State $state -Classification $state
  if ($state -ne "PREFLIGHT_PASS") {
    throw "$Mode preflight failed; no workers launched."
  }
}

function Invoke-WorkerCapabilityPreflight {
  param(
    [Parameter(Mandatory = $true)][string]$WorkerId,
    [object]$Issue,
    [Parameter(Mandatory = $true)][string]$WorkerWorktree,
    [Parameter(Mandatory = $true)][string]$SelectedWindowsSandbox
  )

  $capabilityStatusPath = Join-Path $StatusRoot ("worker-{0}-capability.json" -f $WorkerId)
  $capabilityReportPath = Join-Path $ReportRoot ("worker-{0}-capability-report.md" -f $WorkerId)
  $capabilityLogPath = Join-Path $LogRoot ("worker-{0}-capability-jsonl.log" -f $WorkerId)
  $probeRoot = Join-Path $WorkerWorktree ("logs\codex-worker-capability\{0}\{1}" -f $RunId, $WorkerId)
  $probeStatusPath = Join-Path $probeRoot "capability-probe-status.txt"
  $probeLogPath = Join-Path $probeRoot "capability-probe-log.txt"
  $probeReportPath = Join-Path $probeRoot "capability-probe-report.md"

  New-Item -ItemType Directory -Force -Path (Split-Path -Parent $capabilityStatusPath), (Split-Path -Parent $capabilityReportPath), (Split-Path -Parent $capabilityLogPath), $probeRoot | Out-Null
  Remove-Item -LiteralPath $capabilityReportPath, $capabilityLogPath, $probeStatusPath, $probeLogPath, $probeReportPath -Force -ErrorAction SilentlyContinue

  $useUnelevated = $SelectedWindowsSandbox -eq "unelevated"
  $args = New-CodexExecArguments -Repo $WorkerWorktree -OutputLastMessagePath $capabilityReportPath -AdditionalWritableDirs @($RunRoot) -UseUnelevatedWindowsSandbox:$useUnelevated
  $commandShape = if ($useUnelevated) {
    'codex --ask-for-approval never -c windows.sandbox="unelevated" --cd <worktree> --add-dir <run-root> --sandbox workspace-write exec --output-last-message <capability-report> --json -'
  } else {
    'codex --ask-for-approval never --cd <worktree> --add-dir <run-root> --sandbox workspace-write exec --output-last-message <capability-report> --json -'
  }
  $probeCommand = @"
`$ErrorActionPreference = 'Stop'
'WORKER_CAPABILITY_PASS' | Set-Content -LiteralPath '$probeStatusPath' -Encoding UTF8
'WORKER_CAPABILITY_PASS' | Set-Content -LiteralPath '$probeLogPath' -Encoding UTF8
'WORKER_CAPABILITY_PASS' | Set-Content -LiteralPath '$probeReportPath' -Encoding UTF8
Get-Content -LiteralPath '$probeStatusPath'
Get-Content -LiteralPath '$probeLogPath'
Get-Content -LiteralPath '$probeReportPath'
"@
  $prompt = @"
You are running an overnight worker capability preflight for worker $WorkerId.
Use the shell to run exactly this PowerShell command:
$probeCommand
If every command succeeds and the three reads print WORKER_CAPABILITY_PASS, reply exactly: WORKER_CAPABILITY_PASS
If anything fails, report the exact error and do not claim success.
"@

  $result = Invoke-Codex -WorkingDirectory $WorkerWorktree -Arguments $args -LogPath $capabilityLogPath -StandardInput $prompt
  $lastMessage = Read-TextIfExists $capabilityReportPath
  $probeStatus = Read-TextIfExists $probeStatusPath
  $probeLog = Read-TextIfExists $probeLogPath
  $probeReport = Read-TextIfExists $probeReportPath
  $state = if (
    $result.exit_code -eq 0 -and
    $lastMessage.Trim() -eq "WORKER_CAPABILITY_PASS" -and
    $probeStatus.Trim() -eq "WORKER_CAPABILITY_PASS" -and
    $probeLog.Trim() -eq "WORKER_CAPABILITY_PASS" -and
    $probeReport.Trim() -eq "WORKER_CAPABILITY_PASS"
  ) { "WORKER_CAPABILITY_PASS" } else { "WORKER_CAPABILITY_FAIL" }

  Write-JsonFile -Path $capabilityStatusPath -Object ([pscustomobject]@{
    state = $state
    worker_id = $WorkerId
    issue = $Issue
    worktree = $WorkerWorktree
    selected_windows_sandbox = $SelectedWindowsSandbox
    exit_code = $result.exit_code
    command_shape = $commandShape
    report_path = $capabilityReportPath
    status_path = $capabilityStatusPath
    log_path = $capabilityLogPath
    probe_root = $probeRoot
    probe_status_path = $probeStatusPath
    probe_log_path = $probeLogPath
    probe_report_path = $probeReportPath
    note = "WORKER_CAPABILITY_PASS proves the same Codex worker command path can run shell and write/read repo-local runtime evidence before assignment; launcher-owned report/status/log evidence remains under .runtime. PROCESS_STARTED is not treated as success."
    updated_at = (Get-Date).ToUniversalTime().ToString("o")
  })

  if ($state -ne "WORKER_CAPABILITY_PASS") {
    throw "Worker $WorkerId capability preflight failed; no workers launched. See $capabilityStatusPath"
  }

  return [pscustomobject]@{
    id = $WorkerId
    issue = $Issue
    worktree = $WorkerWorktree
    report_path = $capabilityReportPath
    status_path = $capabilityStatusPath
    log_path = $capabilityLogPath
    capability_status_path = $capabilityStatusPath
  }
}

function Start-Workers {
  param([bool]$Visible)
  $null = Assert-SmokePass
  $selectedWindowsSandbox = Get-SmokeSelectedWindowsSandbox

  $manifest = Read-LauncherManifest
  $workers = @($manifest.workers)
  if ($workers.Count -eq 0) {
    throw "No workers found in launcher manifest: $ManifestPath"
  }
  $selected = @($workers | Select-Object -First ([Math]::Min($MaxParallelWorkers, $workers.Count)))
  $selectedRecords = @()
  foreach ($worker in $selected) {
    $workerId = if ($worker.id) { [string]$worker.id } else { "worker" }
    $statusPath = if ($worker.status_path) { Resolve-FullPath ([string]$worker.status_path) } else { Join-Path $StatusRoot "worker-$workerId-status.json" }
    New-Item -ItemType Directory -Force -Path (Split-Path -Parent $statusPath) | Out-Null
    $workerWorktree = Assert-WorkerWorktree -WorkerId $workerId -Issue $worker.issue -Worker $worker -StatusPath $statusPath
    $selectedRecords += [pscustomobject]@{
      worker = $worker
      id = $workerId
      worktree = $workerWorktree
      status_path = $statusPath
    }
  }

  Invoke-ProcessPreflight -Visible:$Visible

  $selectedWithCapability = @()
  foreach ($record in $selectedRecords) {
    $worker = $record.worker
    $workerId = $record.id
    $workerWorktree = $record.worktree
    $statusPath = $record.status_path
    $reportPath = if ($worker.report_path) { Resolve-FullPath ([string]$worker.report_path) } else { Join-Path $ReportRoot "worker-$workerId-report.md" }
    $logPath = if ($worker.log_path) { Resolve-FullPath ([string]$worker.log_path) } else { Join-Path $LogRoot "worker-$workerId-transcript.txt" }
    $promptPath = if ($worker.prompt_path) { Resolve-FullPath ([string]$worker.prompt_path) } else { "" }
    $prompt = if (-not [string]::IsNullOrWhiteSpace($worker.goal)) {
      [string]$worker.goal
    } elseif (-not [string]::IsNullOrWhiteSpace($promptPath) -and (Test-Path -LiteralPath $promptPath)) {
      Get-Content -LiteralPath $promptPath -Raw
    } else {
      throw "Worker $workerId missing goal or prompt_path."
    }

    New-Item -ItemType Directory -Force -Path (Split-Path -Parent $statusPath), (Split-Path -Parent $reportPath), (Split-Path -Parent $logPath) | Out-Null
    $capability = Invoke-WorkerCapabilityPreflight -WorkerId $workerId -Issue $worker.issue -WorkerWorktree $workerWorktree -SelectedWindowsSandbox $selectedWindowsSandbox
    $selectedWithCapability += [pscustomobject]@{
      id = $workerId
      issue = $worker.issue
      worktree = $workerWorktree
      report_path = $reportPath
      status_path = $statusPath
      log_path = $logPath
      capability_status_path = $capability.status_path
    }
    if ($PreflightOnly) {
      continue
    }
    $workerCodexArgsLiteral = New-WorkerCodexArgumentLiteral -Worktree $workerWorktree -ReportPath $reportPath -AdditionalWritableDirs @($RunRoot) -SelectedWindowsSandbox $selectedWindowsSandbox
    $workerCommandShape = if ($selectedWindowsSandbox -eq "unelevated") {
      'codex --ask-for-approval never -c windows.sandbox="unelevated" --cd <worktree> --add-dir <run-root> --sandbox workspace-write exec --output-last-message <report> -'
    } else {
      "codex --ask-for-approval never --cd <worktree> --add-dir <run-root> --sandbox workspace-write exec --output-last-message <report> -"
    }

    if ($Visible) {
      $runnerPath = Join-Path $LogRoot "worker-$workerId-visible-runner.ps1"
      $promptPathForRunner = Join-Path $LogRoot "worker-$workerId-visible-prompt.txt"
      Set-Content -LiteralPath $promptPathForRunner -Encoding UTF8 -Value $prompt
      @"
`$ErrorActionPreference = 'Continue'
`$prompt = Get-Content -LiteralPath '$promptPathForRunner' -Raw
Set-Location -LiteralPath '$workerWorktree'
`$codex = (Get-Command codex -ErrorAction Stop).Source
`$args = $workerCodexArgsLiteral
`$prompt | & `$codex @args *> '$logPath'
`$exitCode = `$LASTEXITCODE
@{
  state = if (`$exitCode -eq 0) { 'EXITED_ZERO_UNVERIFIED' } else { 'EXITED_NONZERO' }
  worker_id = '$workerId'
  issue = '$($worker.issue)'
  mode = 'TuiVisible'
  selected_windows_sandbox = '$selectedWindowsSandbox'
  exit_code = `$exitCode
  report_path = '$reportPath'
  log_path = '$logPath'
  updated_at = (Get-Date).ToUniversalTime().ToString('o')
} | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath '$statusPath' -Encoding UTF8
Read-Host 'Worker $workerId ended. Press Enter to close this window'
"@ | Set-Content -LiteralPath $runnerPath -Encoding UTF8
      $proc = Start-Process -FilePath "powershell.exe" -ArgumentList @("-NoProfile", "-ExecutionPolicy", "Bypass", "-File", "`"$runnerPath`"") -PassThru
      Write-JsonFile -Path $statusPath -Object ([pscustomobject]@{
        state = "TUI_VISIBLE_STARTED_UNVERIFIED"
        worker_id = $workerId
        issue = $worker.issue
        pid = $proc.Id
        runner = $runnerPath
        selected_windows_sandbox = $selectedWindowsSandbox
        command_shape = $workerCommandShape
        capability_status_path = $capability.status_path
        report_path = $reportPath
        log_path = $logPath
        note = "Process start is not success. Parent must inspect report/status/log/PR evidence before adoption."
        updated_at = (Get-Date).ToUniversalTime().ToString("o")
      })
    } else {
      $runnerPath = Join-Path $LogRoot "worker-$workerId-exec-runner.ps1"
      $promptPathForRunner = Join-Path $LogRoot "worker-$workerId-exec-prompt.txt"
      Set-Content -LiteralPath $promptPathForRunner -Encoding UTF8 -Value $prompt
      @"
`$ErrorActionPreference = 'Continue'
`$prompt = Get-Content -LiteralPath '$promptPathForRunner' -Raw
Set-Location -LiteralPath '$workerWorktree'
`$codex = (Get-Command codex -ErrorAction Stop).Source
`$args = $workerCodexArgsLiteral
`$prompt | & `$codex @args *> '$logPath'
`$exitCode = `$LASTEXITCODE
@{
  state = if (`$exitCode -eq 0) { 'EXITED_ZERO_UNVERIFIED' } else { 'EXITED_NONZERO' }
  worker_id = '$workerId'
  issue = '$($worker.issue)'
  mode = 'ExecBackground'
  selected_windows_sandbox = '$selectedWindowsSandbox'
  exit_code = `$exitCode
  report_path = '$reportPath'
  log_path = '$logPath'
  updated_at = (Get-Date).ToUniversalTime().ToString('o')
} | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath '$statusPath' -Encoding UTF8
exit `$exitCode
"@ | Set-Content -LiteralPath $runnerPath -Encoding UTF8
      $proc = Start-Process -FilePath "powershell.exe" -ArgumentList @("-NoProfile", "-ExecutionPolicy", "Bypass", "-File", "`"$runnerPath`"") -WindowStyle Hidden -PassThru
      Write-JsonFile -Path $statusPath -Object ([pscustomobject]@{
        state = "EXEC_BACKGROUND_STARTED_UNVERIFIED"
        worker_id = $workerId
        issue = $worker.issue
        pid = $proc.Id
        runner = $runnerPath
        selected_windows_sandbox = $selectedWindowsSandbox
        command_shape = $workerCommandShape
        capability_status_path = $capability.status_path
        report_path = $reportPath
        log_path = $logPath
        note = "Process start is not success. Parent must inspect exit/output/report/status/log/PR evidence before adoption."
        updated_at = (Get-Date).ToUniversalTime().ToString("o")
      })
    }
    Start-Sleep -Seconds $StartDelaySeconds
  }
  if ($PreflightOnly) {
    Write-LauncherEvidenceBundle -Phase "$Mode worker capability preflight" -State "WORKER_CAPABILITY_PASS" -Classification "WORKER_CAPABILITY_PASS" -Workers $selectedWithCapability
    return
  }
  Write-LauncherEvidenceBundle -Phase "$Mode worker launch" -State "WORKERS_STARTED_UNVERIFIED" -Classification "PENDING_PARENT_ADOPTION" -Workers $selectedWithCapability
}

switch ($Mode) {
  "SmokeOnly" { Invoke-SmokeOnly }
  "TuiVisible" { Start-Workers -Visible:$true }
  "ExecBackground" { Start-Workers -Visible:$false }
}
