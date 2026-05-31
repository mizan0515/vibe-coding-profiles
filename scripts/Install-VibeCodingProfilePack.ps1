param(
  [string]$TargetRoot = ".runtime\vibe-profile-pack",
  [switch]$Execute,
  [switch]$Json
)

$ErrorActionPreference = "Stop"

$repoRoot = (git rev-parse --show-toplevel).Trim()
if ($LASTEXITCODE -ne 0) { throw "git rev-parse failed" }

if ([System.IO.Path]::IsPathRooted($TargetRoot)) {
  $resolvedTarget = [System.IO.Path]::GetFullPath($TargetRoot)
} else {
  $resolvedTarget = [System.IO.Path]::GetFullPath((Join-Path $repoRoot $TargetRoot))
}
$homeRoot = [Environment]::GetFolderPath("UserProfile")
$blockedTargets = @(
  (Join-Path $homeRoot ("." + "codex")),
  (Join-Path $homeRoot ("." + "claude"))
) | ForEach-Object { [System.IO.Path]::GetFullPath($_) }

foreach ($blocked in $blockedTargets) {
  if ($resolvedTarget.Equals($blocked, [System.StringComparison]::OrdinalIgnoreCase) -or $resolvedTarget.StartsWith($blocked + [System.IO.Path]::DirectorySeparatorChar, [System.StringComparison]::OrdinalIgnoreCase)) {
    $result = [pscustomobject]@{
      status = "REFUSED_HOST_GLOBAL_TARGET"
      target_root = $resolvedTarget
      manager_next_step = "Choose a repo-local or temporary target folder."
    }
    if ($Json) { $result | ConvertTo-Json -Depth 6 } else { $result.status }
    exit 2
  }
}

$generator = Join-Path $repoRoot "scripts\New-VibeCodingProfilePack.ps1"
$manifestRaw = & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $generator -OutputRoot ".runtime\profile-pack-install-plan" -Json
if ($LASTEXITCODE -ne 0) { throw "Profile pack manifest generation failed" }
$manifestResult = $manifestRaw | ConvertFrom-Json

$copyList = @(
  "profiles\shared-instructions.md",
  "profiles\codex-profile-source.md",
  "profiles\claude-profile-source.md",
  "templates\manager-report.ko.md",
  "templates\manager-report.en.md",
  "source-manifest.json"
)

if ($Execute) {
  New-Item -ItemType Directory -Path $resolvedTarget -Force | Out-Null
  foreach ($relative in $copyList) {
    $source = Join-Path $repoRoot $relative
    $destination = Join-Path $resolvedTarget $relative
    New-Item -ItemType Directory -Path (Split-Path -Parent $destination) -Force | Out-Null
    Copy-Item -LiteralPath $source -Destination $destination -Force
  }
}

$result = [pscustomObject]@{
  status = if ($Execute) { "INSTALLED" } else { "DRY_RUN_READY" }
  dry_run = -not [bool]$Execute
  target_root = $resolvedTarget
  manifest_path = $manifestResult.manifest_path
  planned_files = $copyList
  manager_next_step = if ($Execute) { "Use the copied templates and manifest from the target folder." } else { "Re-run with -Execute and a repo-local target folder." }
}

if ($Json) {
  $result | ConvertTo-Json -Depth 8
} else {
  "VIBE_PROFILE_PACK_INSTALL_$($result.status)"
  "target=$resolvedTarget"
}
