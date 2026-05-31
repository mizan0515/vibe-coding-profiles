param(
  [string]$RemoteUrl = "",
  [string]$OutputRoot = "",
  [switch]$Json
)

$ErrorActionPreference = "Stop"

$repoRoot = (git rev-parse --show-toplevel).Trim()
if ($LASTEXITCODE -ne 0) { throw "git rev-parse failed" }

if ([string]::IsNullOrWhiteSpace($RemoteUrl)) { $RemoteUrl = $repoRoot }
if ([string]::IsNullOrWhiteSpace($OutputRoot)) {
  $OutputRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("vibe-profiles-fresh-clone-" + [guid]::NewGuid().ToString("N"))
}

$clonePath = Join-Path $OutputRoot "repo"
New-Item -ItemType Directory -Path $OutputRoot -Force | Out-Null
git clone --depth 1 $RemoteUrl $clonePath | Out-Null
if ($LASTEXITCODE -ne 0) { throw "git clone failed for $RemoteUrl" }

$commands = @(
  ".\scripts\Test-VibeCodingProfilePack.ps1",
  ".\scripts\Test-VibeCodingProfilePackInstall.ps1",
  ".\scripts\Test-ProfileTemplates.ps1",
  ".\scripts\Test-ProfileContainmentFixtures.ps1"
)

$results = [System.Collections.Generic.List[object]]::new()
foreach ($command in $commands) {
  $raw = & powershell.exe -NoProfile -ExecutionPolicy Bypass -File (Join-Path $clonePath $command) 2>&1
  $exitCode = if ($null -eq $LASTEXITCODE) { 0 } else { $LASTEXITCODE }
  $results.Add([pscustomobject]@{
    command = $command
    exit_code = $exitCode
    output = (($raw | ForEach-Object { [string]$_ }) -join "`n")
  }) | Out-Null
}

$failed = @($results | Where-Object { $_.exit_code -ne 0 })
$summary = [pscustomobject]@{
  status = if ($failed.Count -eq 0) { "PASS" } else { "FAIL" }
  remote_url = $RemoteUrl
  clone_path = $clonePath
  results = @($results)
}

if ($Json) {
  $summary | ConvertTo-Json -Depth 8
} elseif ($summary.status -eq "PASS") {
  "VIBE_PROFILES_FRESH_CLONE_TEST_PASS"
  "clone=$clonePath"
} else {
  "VIBE_PROFILES_FRESH_CLONE_TEST_FAIL"
}

if ($failed.Count -gt 0) { exit 1 }
