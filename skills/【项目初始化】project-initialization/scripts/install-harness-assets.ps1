param(
    [Parameter(Mandatory = $true)][string]$Root,
    [string]$CodexHome = $env:CODEX_HOME,
    [string]$Version,
    [switch]$Repair
)

$ErrorActionPreference = 'Stop'
if ([string]::IsNullOrWhiteSpace($CodexHome)) { $CodexHome = Join-Path $HOME '.codex' }

$resolvedRoot = [System.IO.Path]::GetFullPath($Root).TrimEnd('\','/')
$resolvedCodexHome = [System.IO.Path]::GetFullPath($CodexHome).TrimEnd('\','/')
if (-not (Test-Path -LiteralPath $resolvedRoot -PathType Container)) { throw "Project root does not exist: $resolvedRoot" }

$currentPath = Join-Path $resolvedCodexHome 'harness/current.json'
if ([string]::IsNullOrWhiteSpace($Version)) {
    if (-not (Test-Path -LiteralPath $currentPath -PathType Leaf)) { throw "Harness production pointer is missing: $currentPath" }
    $current = Get-Content -LiteralPath $currentPath -Raw -Encoding UTF8 | ConvertFrom-Json
    $Version = [string]$current.version
}
if ($Version -notmatch '^V\d+\.\d+(\.\d+)?$') { throw "Invalid Harness version: $Version" }

$packageRoot = Join-Path $resolvedCodexHome "harness/$Version"
$templateRoot = Join-Path $packageRoot 'project-template'
$templateCodex = Join-Path $templateRoot '.codex'
if (-not (Test-Path -LiteralPath $templateCodex -PathType Container)) { throw "Project template is missing: $templateCodex" }
if (-not (Test-Path -LiteralPath (Join-Path $packageRoot 'manifest.json') -PathType Leaf)) { throw "Harness package manifest is missing: $packageRoot/manifest.json" }

$backupRoot = Join-Path $resolvedRoot ('.codex/harness/install-backups/' + (Get-Date -Format 'yyyyMMdd-HHmmss'))
$installed = [System.Collections.Generic.List[string]]::new()
$unchanged = [System.Collections.Generic.List[string]]::new()
$conflicts = [System.Collections.Generic.List[string]]::new()
$backups = [System.Collections.Generic.List[string]]::new()
$retired = [System.Collections.Generic.List[string]]::new()

$retiredManifestPath = Join-Path $packageRoot 'retired-project-assets.json'
if (Test-Path -LiteralPath $retiredManifestPath -PathType Leaf) {
    $retiredManifest = Get-Content -LiteralPath $retiredManifestPath -Raw -Encoding UTF8 | ConvertFrom-Json
    foreach ($relativeValue in @($retiredManifest.paths)) {
        $relative = [string]$relativeValue
        if ([string]::IsNullOrWhiteSpace($relative) -or [System.IO.Path]::IsPathRooted($relative) -or $relative -match '(^|[\\/])\.\.([\\/]|$)') { throw "Invalid retired project asset path: $relative" }
        $destination = [System.IO.Path]::GetFullPath((Join-Path $resolvedRoot $relative))
        $rootPrefix = $resolvedRoot + [System.IO.Path]::DirectorySeparatorChar
        if (-not $destination.StartsWith($rootPrefix, [System.StringComparison]::OrdinalIgnoreCase)) { throw "Retired project asset escapes root: $relative" }
        if (-not (Test-Path -LiteralPath $destination -PathType Leaf)) { continue }
        if (-not $Repair) { $conflicts.Add("retired:$relative"); continue }
        $backupPath = Join-Path $backupRoot $relative
        $backupDir = Split-Path -Parent $backupPath
        if (-not (Test-Path -LiteralPath $backupDir)) { New-Item -ItemType Directory -Path $backupDir -Force | Out-Null }
        Copy-Item -LiteralPath $destination -Destination $backupPath
        Remove-Item -LiteralPath $destination -Force
        $backups.Add($relative)
        $retired.Add($relative)
    }
}

foreach ($source in Get-ChildItem -LiteralPath $templateRoot -File -Recurse -Force) {
    $relative = $source.FullName.Substring($templateRoot.Length).TrimStart('\','/')
    $destination = Join-Path $resolvedRoot $relative
    $destinationDir = Split-Path -Parent $destination
    if (-not (Test-Path -LiteralPath $destinationDir)) { New-Item -ItemType Directory -Path $destinationDir -Force | Out-Null }

    if (-not (Test-Path -LiteralPath $destination -PathType Leaf)) {
        Copy-Item -LiteralPath $source.FullName -Destination $destination
        $installed.Add($relative)
        continue
    }

    $sourceHash = (Get-FileHash -LiteralPath $source.FullName -Algorithm SHA256).Hash
    $destinationHash = (Get-FileHash -LiteralPath $destination -Algorithm SHA256).Hash
    if ($sourceHash -eq $destinationHash) { $unchanged.Add($relative); continue }
    if (-not $Repair) { $conflicts.Add($relative); continue }

    $backupPath = Join-Path $backupRoot $relative
    $backupDir = Split-Path -Parent $backupPath
    if (-not (Test-Path -LiteralPath $backupDir)) { New-Item -ItemType Directory -Path $backupDir -Force | Out-Null }
    Copy-Item -LiteralPath $destination -Destination $backupPath
    Copy-Item -LiteralPath $source.FullName -Destination $destination -Force
    $backups.Add($relative)
    $installed.Add($relative)
}

$result = [ordered]@{
    passed = ($conflicts.Count -eq 0)
    root = $resolvedRoot
    version = $Version
    packageRoot = $packageRoot
    repair = [bool]$Repair
    installed = @($installed)
    unchanged = @($unchanged)
    conflicts = @($conflicts)
    backups = @($backups)
    retired = @($retired)
    backupRoot = if ($backups.Count -gt 0) { $backupRoot } else { $null }
}
$result | ConvertTo-Json -Depth 8
if ($conflicts.Count -gt 0) { exit 2 }
