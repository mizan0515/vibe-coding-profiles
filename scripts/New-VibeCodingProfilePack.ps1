param(
  [string]$OutputRoot = ".runtime\profile-pack",
  [switch]$Json
)

$ErrorActionPreference = "Stop"

$repoRoot = (git rev-parse --show-toplevel).Trim()
if ($LASTEXITCODE -ne 0) { throw "git rev-parse failed" }

$resolvedOutput = [System.IO.Path]::GetFullPath((Join-Path $repoRoot $OutputRoot))
New-Item -ItemType Directory -Path $resolvedOutput -Force | Out-Null

$manifest = [ordered]@{
  schema_version = "1.0"
  generated_at = (Get-Date).ToUniversalTime().ToString("o")
  always_on_rules = @(
    "profiles/shared-instructions.md",
    "profiles/codex-profile-source.md",
    "profiles/claude-profile-source.md"
  )
  codex_prompts = @(
    "runtime/codex-desktop/profile-template/prompts/external-repo-adoption-review.md",
    "runtime/codex-desktop/profile-template/prompts/external-adoption-execution-transition.md"
  )
  codex_skills = @(
    "runtime/codex-desktop/profile-template/skills/external-adoption-review",
    "runtime/codex-desktop/profile-template/skills/main-sync",
    "runtime/codex-desktop/profile-template/skills/manager-next-work-radar",
    "runtime/codex-desktop/profile-template/skills/overnight-all-tickets"
  )
  claude_prompts = @(
    "runtime/claude-code/profile-template/prompts/external-repo-adoption.md",
    "runtime/claude-code/profile-template/prompts/external-repo-adoption-review.md",
    "runtime/claude-code/profile-template/prompts/external-adoption-execution-transition.md"
  )
  claude_skills = @(
    "runtime/claude-code/profile-template/skills/external-adoption-review"
  )
  on_demand_skills = @(
    "runtime/codex-desktop/profile-template/skills/external-adoption-review",
    "runtime/codex-desktop/profile-template/skills/main-sync",
    "runtime/codex-desktop/profile-template/skills/manager-next-work-radar",
    "runtime/codex-desktop/profile-template/skills/overnight-all-tickets",
    "runtime/claude-code/profile-template/skills/external-adoption-review"
  )
  manager_templates = @(
    "templates/manager-report.ko.md",
    "templates/manager-report.en.md"
  )
  templates = @(
    "templates/manager-report.ko.md",
    "templates/manager-report.en.md"
  )
  hooks = @()
  validation_scripts = @(
    "scripts/Test-VibeCodingProfilePack.ps1",
    "scripts/Test-ProfileTemplates.ps1",
    "scripts/Test-VibeCodingProfilePackInstall.ps1",
    "scripts/Test-ProfileContainmentFixtures.ps1"
  )
  safety = @{
    dry_run_default = $true
    host_global_write = "not_performed"
    install_requires_explicit_target = $true
  }
}

$missing = [System.Collections.Generic.List[string]]::new()
foreach ($path in @($manifest.always_on_rules + $manifest.codex_prompts + $manifest.codex_skills + $manifest.claude_prompts + $manifest.claude_skills + $manifest.manager_templates + $manifest.validation_scripts)) {
  if (-not (Test-Path -LiteralPath (Join-Path $repoRoot $path))) {
    $missing.Add($path) | Out-Null
  }
}

$manifestPath = Join-Path $resolvedOutput "profile-pack-manifest.json"
$manifest | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $manifestPath -Encoding UTF8

$result = [pscustomobject]@{
  status = if ($missing.Count -eq 0) { "PASS" } else { "FAIL" }
  manifest_path = $manifestPath
  missing = @($missing)
}

if ($Json) {
  $result | ConvertTo-Json -Depth 8
} else {
  if ($result.status -eq "PASS") {
    "VIBE_PROFILE_PACK_CREATED"
    "manifest=$manifestPath"
  } else {
    "VIBE_PROFILE_PACK_FAIL"
    "missing=$($missing -join ',')"
  }
}

if ($missing.Count -gt 0) { exit 1 }
