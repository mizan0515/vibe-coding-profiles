param(
  [string]$Repo = '',
  [string]$OutputPath = '',
  [int]$IssueLimit = 50,
  [switch]$SkipEcosystem,
  [switch]$RefreshEcosystem,
  [string[]]$EcosystemCandidates = @('microsoft/playwright-mcp', 'mem0ai/mem0', 'openai/openai-agents-python'),
  [string]$EcosystemFollowUpIssue = '',
  [int]$DiscoveryLimitPerQuery = 3,
  [int]$TrendWindowDays = 120,
  [int]$MinStars = 100
)

$ErrorActionPreference = 'Stop'
if ($PSVersionTable.PSVersion.Major -lt 6) {
  [Console]::OutputEncoding = New-Object System.Text.UTF8Encoding($false)
  $script:OutputEncoding = [Console]::OutputEncoding
}

function ConvertTo-Array {
  param([object]$Value)
  if ($null -eq $Value) { return @() }
  return @($Value)
}

function Convert-ToSafeLine {
  param([object]$Value, [int]$MaxLength = 150)
  $text = [string]$Value
  if ([string]::IsNullOrWhiteSpace($text)) { return '' }
  $line = ($text -replace '[\r\n]+', ' ' -replace '\s+', ' ').Trim()
  if ($line.Length -le $MaxLength) { return $line }
  return "$($line.Substring(0, [Math]::Max(0, $MaxLength - 3)))..."
}

function Invoke-GhJson {
  param([string[]]$Arguments)
  $output = & gh @Arguments 2>&1
  $exitCode = if ($null -eq $LASTEXITCODE) { 0 } else { $LASTEXITCODE }
  if ($exitCode -ne 0) {
    throw "gh $($Arguments -join ' ') failed with exit $exitCode`: $((@($output) | ForEach-Object { [string]$_ }) -join "`n")"
  }
  $raw = ((@($output) | ForEach-Object { [string]$_ }) -join "`n").Trim()
  if ([string]::IsNullOrWhiteSpace($raw)) { return @() }
  return $raw | ConvertFrom-Json
}

function Resolve-GitHubRepoFromRemote {
  param([string]$Remote)
  if ([string]::IsNullOrWhiteSpace($Remote)) { return '' }
  $value = $Remote.Trim()
  foreach ($pattern in @(
      'github\.com[:/](?<owner>[^/\s]+)/(?<repo>[^/\s]+?)(?:\.git)?$',
      '^https?://github\.com/(?<owner>[^/\s]+)/(?<repo>[^/\s]+?)(?:\.git)?$',
      '^ssh://git@github\.com/(?<owner>[^/\s]+)/(?<repo>[^/\s]+?)(?:\.git)?$'
    )) {
    if ($value -match $pattern) {
      return "$($matches.owner)/$($matches.repo)"
    }
  }
  return ''
}

function Resolve-SelectedRepo {
  if (-not [string]::IsNullOrWhiteSpace($Repo)) {
    return $Repo.Trim()
  }

  try {
    $nameWithOwner = (& gh repo view --json nameWithOwner --jq '.nameWithOwner' 2>$null | Select-Object -First 1)
    if (-not [string]::IsNullOrWhiteSpace($nameWithOwner)) {
      return ([string]$nameWithOwner).Trim()
    }
  } catch {
    # Fall back to parsing git remote below.
  }

  try {
    $remote = (& git config --get remote.origin.url 2>$null | Select-Object -First 1)
    $parsed = Resolve-GitHubRepoFromRemote -Remote ([string]$remote)
    if (-not [string]::IsNullOrWhiteSpace($parsed)) {
      return $parsed
    }
  } catch {
    # A projectless folder or non-git directory can still pass -Repo explicitly.
  }

  throw 'Could not infer a GitHub repository. Pass -Repo owner/name, or run from a checkout with a GitHub origin remote.'
}

function Format-IssueLine {
  param($Issue)
  $labels = @($Issue.labels | ForEach-Object { [string]$_.name } | Where-Object { $_ })
  $labelText = if ($labels.Count -gt 0) { " labels=$($labels -join ',')" } else { '' }
  return "#$($Issue.number) $(Convert-ToSafeLine $Issue.title 95)$labelText"
}

function Format-PrLine {
  param($Pr)
  $draft = if ($Pr.isDraft) { ' draft' } else { '' }
  return "#$($Pr.number) $(Convert-ToSafeLine $Pr.title 95)$draft"
}

function Get-DiscoveryQueries {
  $recentDate = (Get-Date).ToUniversalTime().AddDays(-1 * $TrendWindowDays).ToString('yyyy-MM-dd')
  return @(
    [pscustomobject]@{ name = 'agent frameworks'; query = "AI agent framework stars:>$MinStars pushed:>$recentDate archived:false fork:false"; reason = 'agent workflow ideas' },
    [pscustomobject]@{ name = 'agent memory'; query = "AI agent memory stars:>$MinStars pushed:>$recentDate archived:false fork:false"; reason = 'memory and recall ideas' },
    [pscustomobject]@{ name = 'prompt eval'; query = "LLM prompt evaluation stars:>$MinStars pushed:>$recentDate archived:false fork:false"; reason = 'instruction test ideas' },
    [pscustomobject]@{ name = 'observability'; query = "LLM observability tracing stars:>$MinStars pushed:>$recentDate archived:false fork:false"; reason = 'evidence and trace ideas' },
    [pscustomobject]@{ name = 'recent agent repos'; query = "AI agent created:>$recentDate stars:>$MinStars archived:false fork:false"; reason = 'new high-signal repositories' }
  )
}

function Get-TrendyRepositoryCandidates {
  if ($SkipEcosystem) {
    return @([pscustomobject]@{
        query = 'dynamic discovery'
        fullName = 'UNVERIFIED'
        description = 'skipped by -SkipEcosystem'
        url = ''
        stars = 0
        language = ''
        pushedAt = ''
        decision = 'UNVERIFIED'
        reason = 'Run without -SkipEcosystem to discover current/trendy repositories.'
      })
  }

  $seen = @{}
  $results = [System.Collections.Generic.List[object]]::new()
  foreach ($query in Get-DiscoveryQueries) {
    try {
      $items = @(ConvertTo-Array (Invoke-GhJson -Arguments @(
            'search', 'repos', $query.query,
            '--limit', [string]$DiscoveryLimitPerQuery,
            '--json', 'fullName,description,stargazersCount,pushedAt,url,language'
          )))
      foreach ($item in $items) {
        $fullName = [string]$item.fullName
        if ([string]::IsNullOrWhiteSpace($fullName) -or $seen.ContainsKey($fullName)) { continue }
        $seen[$fullName] = $true
        $results.Add([pscustomobject]@{
            query = $query.name
            fullName = $fullName
            description = Convert-ToSafeLine $item.description 95
            url = [string]$item.url
            stars = [int]$item.stargazersCount
            language = [string]$item.language
            pushedAt = [string]$item.pushedAt
            decision = 'evaluate'
            reason = "$($query.reason); discovery signal only, not adoption evidence"
          }) | Out-Null
      }
    } catch {
      $results.Add([pscustomobject]@{
          query = $query.name
          fullName = 'BLOCKED'
          description = Convert-ToSafeLine $_.Exception.Message 110
          url = ''
          stars = 0
          language = ''
          pushedAt = ''
          decision = 'BLOCKED'
          reason = 'GitHub search failed; do not infer trend state'
        }) | Out-Null
    }
  }
  return @($results | Sort-Object @{ Expression = 'stars'; Descending = $true } | Select-Object -First 10)
}

function Test-SeedReadmeMentionsRepo {
  param(
    [string]$ReadmeText,
    [string]$RepoFullName
  )

  if ([string]::IsNullOrWhiteSpace($ReadmeText) -or [string]::IsNullOrWhiteSpace($RepoFullName)) {
    return $false
  }
  $compact = $ReadmeText -replace '\s+', ''
  return $compact -match [regex]::Escape("github.com/$RepoFullName")
}

function Get-BoundedCandidateDecision {
  param([string]$RepoFullName)

  switch -Regex ($RepoFullName.ToLowerInvariant()) {
    '^microsoft/playwright-mcp$' {
      return [pscustomobject]@{
        decision = 'create-follow-up'
        reason = 'best fit for browser-proof gaps; adoption still needs a local no-secret browser evidence test'
        next = 'create/reuse a pending evidence ticket before enabling any MCP bridge'
      }
    }
    '^mem0ai/mem0$' {
      return [pscustomobject]@{
        decision = 'watch-later'
        reason = 'memory layer is relevant, but current repo already has memory lifecycle pending work and this adds dependency/data-boundary surface'
        next = 'keep behind the existing memory lifecycle backlog until local memory evidence is missing'
      }
    }
    '^openai/openai-agents-python$' {
      return [pscustomobject]@{
        decision = 'reject-current-runtime'
        reason = 'framework is active and reputable, but the current product path is Codex-only runtime automation, not a Python multi-agent SDK migration'
        next = 'track concepts only; do not add SDK work without a manager-approved runtime architecture issue'
      }
    }
    default {
      return [pscustomobject]@{
        decision = 'evaluate'
        reason = 'seed candidate needs a repo-local fit test before any adoption recommendation'
        next = 'create a bounded evidence ticket only if it solves a current visible manager problem'
      }
    }
  }
}

function Get-BoundedEcosystemSeedScan {
  param([string[]]$Candidates)

  $seedRepo = 'caramaschiHG/awesome-ai-agents-2026'
  $blocked = [System.Collections.Generic.List[string]]::new()
  $seedInfo = $null
  $readmeText = ''

  try {
    $seedInfo = Invoke-GhJson -Arguments @('repo', 'view', $seedRepo, '--json', 'nameWithOwner,description,licenseInfo,pushedAt,updatedAt,stargazerCount,forkCount,isArchived,url')
  } catch {
    $blocked.Add("seed repo metadata: $(Convert-ToSafeLine $_.Exception.Message 140)") | Out-Null
  }

  try {
    $encodedReadme = (& gh api "repos/$seedRepo/readme" --jq '.content' 2>&1)
    $exitCode = if ($null -eq $LASTEXITCODE) { 0 } else { $LASTEXITCODE }
    if ($exitCode -ne 0) {
      throw "gh api repos/$seedRepo/readme failed with exit $exitCode`: $((@($encodedReadme) | ForEach-Object { [string]$_ }) -join "`n")"
    }
    $readmeText = ((@($encodedReadme) | ForEach-Object { [string]$_ }) -join '') -replace '\s+', ''
    $readmeText = [System.Text.Encoding]::UTF8.GetString([Convert]::FromBase64String($readmeText))
  } catch {
    $blocked.Add("seed README scan: $(Convert-ToSafeLine $_.Exception.Message 140)") | Out-Null
  }

  $candidateRows = [System.Collections.Generic.List[object]]::new()
  foreach ($candidate in $Candidates) {
    $repoFullName = ([string]$candidate).Trim()
    if ([string]::IsNullOrWhiteSpace($repoFullName)) { continue }

    $seedMention = Test-SeedReadmeMentionsRepo -ReadmeText $readmeText -RepoFullName $repoFullName
    $decision = Get-BoundedCandidateDecision -RepoFullName $repoFullName
    try {
      $repoInfo = Invoke-GhJson -Arguments @('repo', 'view', $repoFullName, '--json', 'nameWithOwner,description,licenseInfo,latestRelease,pushedAt,updatedAt,stargazerCount,forkCount,isArchived,isSecurityPolicyEnabled,url,primaryLanguage')
      $releaseTag = if ($repoInfo.latestRelease -and $repoInfo.latestRelease.tagName) { [string]$repoInfo.latestRelease.tagName } else { 'none observed' }
      $license = if ($repoInfo.licenseInfo -and $repoInfo.licenseInfo.key) { [string]$repoInfo.licenseInfo.key } else { 'none observed' }
      $language = if ($repoInfo.primaryLanguage -and $repoInfo.primaryLanguage.name) { [string]$repoInfo.primaryLanguage.name } else { 'unknown' }
      $candidateRows.Add([pscustomobject]@{
          repo = [string]$repoInfo.nameWithOwner
          seedMention = $seedMention
          status = 'PASS'
          stars = [int]$repoInfo.stargazerCount
          forks = [int]$repoInfo.forkCount
          pushedAt = [string]$repoInfo.pushedAt
          updatedAt = [string]$repoInfo.updatedAt
          latestRelease = $releaseTag
          license = $license
          language = $language
          securityPolicy = [bool]$repoInfo.isSecurityPolicyEnabled
          archived = [bool]$repoInfo.isArchived
          url = [string]$repoInfo.url
          description = Convert-ToSafeLine $repoInfo.description 110
          decision = $decision.decision
          reason = $decision.reason
          next = $decision.next
        }) | Out-Null
    } catch {
      $candidateRows.Add([pscustomobject]@{
          repo = $repoFullName
          seedMention = $seedMention
          status = 'BLOCKED'
          stars = 0
          forks = 0
          pushedAt = ''
          updatedAt = ''
          latestRelease = ''
          license = ''
          language = ''
          securityPolicy = $false
          archived = $false
          url = ''
          description = Convert-ToSafeLine $_.Exception.Message 110
          decision = 'UNVERIFIED'
          reason = 'primary source metadata failed, so no adoption recommendation is allowed'
          next = 'retry primary-source verification before any follow-up decision'
        }) | Out-Null
    }
  }

  return [pscustomobject]@{
    seedRepo = $seedRepo
    seedInfo = $seedInfo
    candidates = @($candidateRows)
    blocked = @($blocked)
  }
}

$targetRepo = Resolve-SelectedRepo
$generatedAt = (Get-Date).ToUniversalTime().ToString('o')
$issues = @()
$prs = @()
$blocked = [System.Collections.Generic.List[string]]::new()
$issueListBlocked = $false
$prListBlocked = $false

try {
  $issues = @(ConvertTo-Array (Invoke-GhJson -Arguments @(
        'issue', 'list', '--repo', $targetRepo, '--state', 'open',
        '--limit', [string]$IssueLimit,
        '--json', 'number,title,labels,updatedAt,url'
      )))
} catch {
  $issueListBlocked = $true
  $blocked.Add("issue list: $(Convert-ToSafeLine $_.Exception.Message 120)") | Out-Null
}

try {
  $prs = @(ConvertTo-Array (Invoke-GhJson -Arguments @(
        'pr', 'list', '--repo', $targetRepo, '--state', 'open',
        '--limit', '30',
        '--json', 'number,title,isDraft,updatedAt,url,headRefName'
      )))
} catch {
  $prListBlocked = $true
  $blocked.Add("PR list: $(Convert-ToSafeLine $_.Exception.Message 120)") | Out-Null
}

$pendingIssues = @($issues | Where-Object {
    $title = [string]$_.title
    $labels = @($_.labels | ForEach-Object { [string]$_.name })
    $title -match '(?i)pending|backlog|follow-?up|adoption|watch|defer|보류|백로그|후속' -or
    $labels -contains 'pending' -or
    $labels -contains 'backlog' -or
    $labels -contains 'adoption'
  })
$trendy = @(Get-TrendyRepositoryCandidates)
$boundedScan = if ($RefreshEcosystem) { Get-BoundedEcosystemSeedScan -Candidates $EcosystemCandidates } else { $null }

$lines = [System.Collections.Generic.List[string]]::new()
$lines.Add('# Portable Manager Next-Work Radar') | Out-Null
$lines.Add("generated: $generatedAt; repo: $targetRepo") | Out-Null
$lines.Add('mode: skill-owned portable fallback; repo-local helper not required') | Out-Null
if ($RefreshEcosystem) {
  $lines.Add('trigger: on-demand ecosystem refresh requested by manager/radar workflow; no recurring schedule is installed by this script') | Out-Null
} else {
  $lines.Add('trigger: normal next-work radar; ecosystem seed refresh runs only when -RefreshEcosystem is explicit') | Out-Null
}
$lines.Add('') | Out-Null
$lines.Add('## Observed locally') | Out-Null
$lines.Add("- selected target repo: $targetRepo") | Out-Null
$lines.Add("- open issues: $(if ($issueListBlocked) { 'UNVERIFIED; issue list blocked' } else { [string]$issues.Count })") | Out-Null
foreach ($issue in @($issues | Select-Object -First 5)) {
  $lines.Add("- issue: $(Format-IssueLine $issue)") | Out-Null
}
if ($issueListBlocked) { $lines.Add('- issue: unavailable; see Blocked') | Out-Null }
elseif ($issues.Count -eq 0) { $lines.Add('- issue: none observed') | Out-Null }
$lines.Add("- open PRs: $(if ($prListBlocked) { 'UNVERIFIED; PR list blocked' } else { [string]$prs.Count })") | Out-Null
foreach ($pr in @($prs | Select-Object -First 5)) {
  $lines.Add("- PR: $(Format-PrLine $pr)") | Out-Null
}
if ($prListBlocked) { $lines.Add('- PR: unavailable; see Blocked') | Out-Null }
elseif ($prs.Count -eq 0) { $lines.Add('- PR: none observed') | Out-Null }
$lines.Add("- pending/backlog-looking issues: $(if ($issueListBlocked) { 'UNVERIFIED; issue list blocked' } else { [string]$pendingIssues.Count })") | Out-Null
foreach ($issue in @($pendingIssues | Select-Object -First 5)) {
  $lines.Add("- pending candidate: $(Format-IssueLine $issue)") | Out-Null
}
$lines.Add('') | Out-Null
$lines.Add('## Dynamic trendy repo discovery') | Out-Null
$lines.Add('- Source method: GitHub search by stars and recent pushed/created windows. This is discovery only, not adoption evidence.') | Out-Null
foreach ($candidate in $trendy) {
  $urlText = if ([string]::IsNullOrWhiteSpace([string]$candidate.url)) { '' } else { "; $($candidate.url)" }
  $lines.Add("- [$($candidate.query)] $($candidate.fullName): stars=$($candidate.stars); pushed=$($candidate.pushedAt); decision=$($candidate.decision); $(Convert-ToSafeLine $candidate.reason 120)$urlText") | Out-Null
}
$lines.Add('') | Out-Null
if ($RefreshEcosystem) {
  $lines.Add('## External observed') | Out-Null
  $seed = $boundedScan.seedInfo
  if ($null -ne $seed) {
    $seedLicense = if ($seed.licenseInfo -and $seed.licenseInfo.key) { [string]$seed.licenseInfo.key } else { 'none observed' }
    $lines.Add("- awesome-list seed: $($seed.nameWithOwner); stars=$($seed.stargazerCount); forks=$($seed.forkCount); pushed=$($seed.pushedAt); updated=$($seed.updatedAt); license=$seedLicense; source=$($seed.url)") | Out-Null
  } else {
    $lines.Add("- awesome-list seed: $($boundedScan.seedRepo); metadata unavailable") | Out-Null
  }
  foreach ($item in $boundedScan.candidates) {
    $seedStatus = if ($item.seedMention) { 'seed-link-observed' } else { 'seed-link-not-observed' }
    $lines.Add("- candidate primary source: $($item.repo); $seedStatus; status=$($item.status); stars=$($item.stars); forks=$($item.forks); pushed=$($item.pushedAt); release=$($item.latestRelease); license=$($item.license); security_policy=$($item.securityPolicy); $($item.url)") | Out-Null
  }
  $lines.Add('') | Out-Null
  $lines.Add('## Bounded ecosystem decisions') | Out-Null
  $lines.Add('- Rule: list-only claims remain UNVERIFIED. Adoption requires primary-source evidence plus a repo-local validation issue.') | Out-Null
  foreach ($item in $boundedScan.candidates) {
    $lines.Add("- $($item.repo): decision=$($item.decision); reason=$(Convert-ToSafeLine $item.reason 130); next=$(Convert-ToSafeLine $item.next 130)") | Out-Null
  }
  if (-not [string]::IsNullOrWhiteSpace($EcosystemFollowUpIssue)) {
    $lines.Add("- visible follow-up created/reused: $EcosystemFollowUpIssue") | Out-Null
  } else {
    $lines.Add('- visible follow-up needed: create/reuse a pending evidence ticket for any create-follow-up candidate before adoption.') | Out-Null
  }
  $lines.Add('') | Out-Null
}
$lines.Add('## Backlog / follow-up gates') | Out-Null
if ($pendingIssues.Count -gt 0) {
  $lines.Add("- Visible follow-up/backlog path exists: $((@($pendingIssues | Select-Object -First 3 | ForEach-Object { '#{0} {1}' -f $_.number, (Convert-ToSafeLine $_.title 70) })) -join '; ')") | Out-Null
} else {
  $lines.Add('- No obvious pending/backlog/adoption issue was found in the open issue list.') | Out-Null
}
$lines.Add('- Rule: useful pilots need adopt / follow-up / reject. Do not bury them as prose only.') | Out-Null
$lines.Add('') | Out-Null
$lines.Add('## Inferred') | Out-Null
$lines.Add('- A non-developer manager needs the next visible action in the selected repo, not a hidden repo-specific script failure.') | Out-Null
$lines.Add('- Use this fallback to decide the next issue/report path; use repo-local helpers only when the selected repo provides them.') | Out-Null
$lines.Add('') | Out-Null
$lines.Add('## UNVERIFIED') | Out-Null
$lines.Add('- Project board columns are not audited by this portable fallback.') | Out-Null
$lines.Add('- Trend search is a freshness signal. Verify official docs before adoption.') | Out-Null
$lines.Add('') | Out-Null
$lines.Add('## Blocked') | Out-Null
$boundedBlocked = if ($RefreshEcosystem -and $null -ne $boundedScan) {
  @($boundedScan.candidates | Where-Object { $_.status -eq 'BLOCKED' } | ForEach-Object { "bounded candidate $($_.repo): $($_.description)" }) +
  @($boundedScan.blocked | ForEach-Object { [string]$_ })
} else { @() }
foreach ($item in $boundedBlocked) {
  $blocked.Add($item) | Out-Null
}
if ($blocked.Count -gt 0) {
  foreach ($item in $blocked) { $lines.Add("- $item") | Out-Null }
} else {
  $lines.Add('- none') | Out-Null
}
$lines.Add('') | Out-Null
$lines.Add('## Next action') | Out-Null
if ($prs.Count -gt 0) {
  $lines.Add('1. Inspect the open PRs first; mergeable reviewed work usually beats starting new work.') | Out-Null
} elseif ($pendingIssues.Count -gt 0) {
  $lines.Add('1. Pick the highest-value pending/backlog issue and turn it into a visible validation or adoption decision.') | Out-Null
} elseif ($issues.Count -gt 0) {
  $lines.Add('1. Pick the clearest open issue with concrete verification and run it to done.') | Out-Null
} else {
  $lines.Add('1. Create a small next-work issue before editing so the manager has a visible path.') | Out-Null
}
$lines.Add("2. Keep $targetRepo as the schedule source unless the manager explicitly switches projects.") | Out-Null
$lines.Add('3. If a useful discovery candidate appears, create/reuse a validation issue before adoption.') | Out-Null

$reportText = $lines -join [Environment]::NewLine
if (-not [string]::IsNullOrWhiteSpace($OutputPath)) {
  $outputFull = [System.IO.Path]::GetFullPath($OutputPath)
  $outputDir = Split-Path -Parent $outputFull
  if (-not [string]::IsNullOrWhiteSpace($outputDir) -and -not (Test-Path -LiteralPath $outputDir)) {
    New-Item -ItemType Directory -Force -Path $outputDir | Out-Null
  }
  [System.IO.File]::WriteAllText($outputFull, $reportText, (New-Object System.Text.UTF8Encoding($false)))
}

$global:LASTEXITCODE = 0
Write-Output $reportText
