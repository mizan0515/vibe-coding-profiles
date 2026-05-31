param(
  [switch]$Json
)

$ErrorActionPreference = "Stop"

$repoRoot = (git rev-parse --show-toplevel).Trim()
if ($LASTEXITCODE -ne 0) { throw "git rev-parse failed" }

$templates = @(
  "templates\manager-report.ko.md",
  "templates\manager-report.en.md"
)
$requiredSections = @(
  "built/inspected",
  "tested/evidence",
  "manager run/paste",
  "blocked/unverified"
)
$invalidReport = Join-Path $repoRoot "examples\reports\invalid-hidden-done.md"

$checks = [System.Collections.Generic.List[object]]::new()
foreach ($template in $templates) {
  $path = Join-Path $repoRoot $template
  $exists = Test-Path -LiteralPath $path -PathType Leaf
  $checks.Add([pscustomobject]@{ name = "exists:$template"; pass = $exists }) | Out-Null
  if ($exists) {
    $text = Get-Content -LiteralPath $path -Raw -Encoding UTF8
    foreach ($section in $requiredSections) {
      $checks.Add([pscustomobject]@{ name = "section:$($template):$section"; pass = ($text -match [regex]::Escape($section)) }) | Out-Null
    }
  }
}
$invalidText = Get-Content -LiteralPath $invalidReport -Raw -Encoding UTF8
$rejectHiddenDone = ($invalidText -match "Done") -and ($invalidText -match "no manager-visible surface")
$checks.Add([pscustomobject]@{ name = "reject-hidden-done-fixture"; pass = $rejectHiddenDone }) | Out-Null

$failed = @($checks | Where-Object { -not $_.pass })
$summary = [pscustomobject]@{
  status = if ($failed.Count -eq 0) { "PASS" } else { "FAIL" }
  templates = $templates
  invalid_report = $invalidReport
  checks = @($checks)
}

if ($Json) {
  $summary | ConvertTo-Json -Depth 8
} elseif ($summary.status -eq "PASS") {
  "VIBE_PROFILE_TEMPLATES_TEST_PASS"
} else {
  "VIBE_PROFILE_TEMPLATES_TEST_FAIL"
}

if ($failed.Count -gt 0) { exit 1 }
