param(
  [string]$OutputRoot = ".runtime\profile-pack-test",
  [switch]$Json
)

$ErrorActionPreference = "Stop"

$repoRoot = (git rev-parse --show-toplevel).Trim()
if ($LASTEXITCODE -ne 0) { throw "git rev-parse failed" }

$generator = Join-Path $repoRoot "scripts\New-VibeCodingProfilePack.ps1"
$output = & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $generator -OutputRoot $OutputRoot -Json
if ($LASTEXITCODE -ne 0) { throw "Profile pack generator failed" }
$result = $output | ConvertFrom-Json

$manifest = Get-Content -LiteralPath $result.manifest_path -Raw -Encoding UTF8 | ConvertFrom-Json
$checks = [System.Collections.Generic.List[object]]::new()
$checks.Add([pscustomobject]@{ name = "generator-pass"; pass = ($result.status -eq "PASS") }) | Out-Null
$checks.Add([pscustomobject]@{ name = "always-on-rules-present"; pass = (@($manifest.always_on_rules).Count -ge 3) }) | Out-Null
$checks.Add([pscustomobject]@{ name = "codex-skills-present"; pass = (@($manifest.codex_skills).Count -ge 4) }) | Out-Null
$checks.Add([pscustomobject]@{ name = "claude-skill-present"; pass = (@($manifest.claude_skills).Count -ge 1) }) | Out-Null
$checks.Add([pscustomobject]@{ name = "on-demand-skills-present"; pass = (@($manifest.on_demand_skills).Count -ge 5) }) | Out-Null
$checks.Add([pscustomobject]@{ name = "manager-templates-present"; pass = (@($manifest.manager_templates).Count -ge 2) }) | Out-Null
$checks.Add([pscustomobject]@{ name = "validation-scripts-present"; pass = (@($manifest.validation_scripts).Count -ge 4) }) | Out-Null
$checks.Add([pscustomobject]@{ name = "dry-run-default"; pass = ([bool]$manifest.safety.dry_run_default) }) | Out-Null
$checks.Add([pscustomobject]@{ name = "host-global-not-written"; pass = ($manifest.safety.host_global_write -eq "not_performed") }) | Out-Null

$failed = @($checks | Where-Object { -not $_.pass })
$summary = [pscustomobject]@{
  status = if ($failed.Count -eq 0) { "PASS" } else { "FAIL" }
  manifest_path = $result.manifest_path
  checks = @($checks)
}

if ($Json) {
  $summary | ConvertTo-Json -Depth 8
} else {
  if ($summary.status -eq "PASS") {
    "VIBE_PROFILE_PACK_TEST_PASS"
    "manifest=$($result.manifest_path)"
  } else {
    "VIBE_PROFILE_PACK_TEST_FAIL"
  }
}

if ($failed.Count -gt 0) { exit 1 }
