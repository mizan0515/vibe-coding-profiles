param(
  [string]$OutputRoot = ".runtime\profile-pack-install-test",
  [switch]$Json
)

$ErrorActionPreference = "Stop"

$repoRoot = (git rev-parse --show-toplevel).Trim()
if ($LASTEXITCODE -ne 0) { throw "git rev-parse failed" }

$installer = Join-Path $repoRoot "scripts\Install-VibeCodingProfilePack.ps1"
$dryRaw = & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $installer -TargetRoot $OutputRoot -Json
if ($LASTEXITCODE -ne 0) { throw "Profile pack install dry run failed" }
$dry = $dryRaw | ConvertFrom-Json

$executeRaw = & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $installer -TargetRoot $OutputRoot -Execute -Json
if ($LASTEXITCODE -ne 0) { throw "Profile pack install execution failed" }
$execute = $executeRaw | ConvertFrom-Json

$homeBlocked = Join-Path ([Environment]::GetFolderPath("UserProfile")) ("." + "codex")
$blockedRaw = & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $installer -TargetRoot $homeBlocked -Json 2>$null
$blockedExit = $LASTEXITCODE

$checks = [System.Collections.Generic.List[object]]::new()
$checks.Add([pscustomobject]@{ name = "dry-run-ready"; pass = ($dry.status -eq "DRY_RUN_READY" -and $dry.dry_run) }) | Out-Null
$checks.Add([pscustomobject]@{ name = "execute-installed"; pass = ($execute.status -eq "INSTALLED" -and -not $execute.dry_run) }) | Out-Null
$checks.Add([pscustomobject]@{ name = "template-copied"; pass = (Test-Path -LiteralPath (Join-Path $execute.target_root "templates\manager-report.ko.md") -PathType Leaf) }) | Out-Null
$checks.Add([pscustomobject]@{ name = "host-global-refused"; pass = ($blockedExit -eq 2 -and (($blockedRaw | ConvertFrom-Json).status -eq "REFUSED_HOST_GLOBAL_TARGET")) }) | Out-Null

$failed = @($checks | Where-Object { -not $_.pass })
$summary = [pscustomobject]@{
  status = if ($failed.Count -eq 0) { "PASS" } else { "FAIL" }
  target_root = $execute.target_root
  checks = @($checks)
}

if ($Json) {
  $summary | ConvertTo-Json -Depth 8
} elseif ($summary.status -eq "PASS") {
  "VIBE_PROFILE_PACK_INSTALL_TEST_PASS"
  "target=$($execute.target_root)"
} else {
  "VIBE_PROFILE_PACK_INSTALL_TEST_FAIL"
}

if ($failed.Count -gt 0) { exit 1 }
