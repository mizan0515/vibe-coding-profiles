param(
  [string]$FixturePath = "examples\containment\blocked-paths.fixture.json",
  [switch]$Json
)

$ErrorActionPreference = "Stop"

$repoRoot = (git rev-parse --show-toplevel).Trim()
if ($LASTEXITCODE -ne 0) { throw "git rev-parse failed" }

$fixtureFull = Join-Path $repoRoot $FixturePath
$fixture = Get-Content -LiteralPath $fixtureFull -Raw -Encoding UTF8 | ConvertFrom-Json
$expected = @(
  "local shell configuration files",
  "SSH material",
  "browser state folders",
  "account state",
  "private keys",
  "private material directories"
)

$checks = [System.Collections.Generic.List[object]]::new()
foreach ($category in $expected) {
  $checks.Add([pscustomobject]@{ name = "blocked-category:$category"; pass = (@($fixture.blocked_categories) -contains $category) }) | Out-Null
}
$checks.Add([pscustomobject]@{ name = "dry-run-only"; pass = ($fixture.allowed_result -match "dry-run") }) | Out-Null

$failed = @($checks | Where-Object { -not $_.pass })
$summary = [pscustomobject]@{
  status = if ($failed.Count -eq 0) { "PASS" } else { "FAIL" }
  fixture_path = $fixtureFull
  checks = @($checks)
}

if ($Json) {
  $summary | ConvertTo-Json -Depth 8
} elseif ($summary.status -eq "PASS") {
  "VIBE_PROFILE_CONTAINMENT_FIXTURE_TEST_PASS"
} else {
  "VIBE_PROFILE_CONTAINMENT_FIXTURE_TEST_FAIL"
}

if ($failed.Count -gt 0) { exit 1 }
