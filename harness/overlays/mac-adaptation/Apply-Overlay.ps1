#!/usr/bin/env pwsh
<#
.SYNOPSIS
  重放 mac-adaptation overlay。任何一次 Install-Harness.ps1 -Repair 或包重装之后运行本脚本，
  即可把已备案的缺陷修复重新贴回去。
.DESCRIPTION
  对 overlay-manifest.json 里的每一条：
    - 目标文件 sha256 == sha256Pristine/sha256PriorPatched -> 应用当前补丁
    - 目标文件 sha256 == sha256Patched   -> 已是最新，跳过
    - 两者都不等                          -> 报告为 drift，不做任何修改
  永远不会覆盖第三方修改；不匹配就停手并报告。
.EXAMPLE
  pwsh -NoProfile -File Apply-Overlay.ps1 -WhatIf
  pwsh -NoProfile -File Apply-Overlay.ps1
#>
[CmdletBinding(SupportsShouldProcess = $true)]
param(
    [string]$CodexHome   = $(if ($env:CODEX_HOME) { $env:CODEX_HOME } else { Join-Path $HOME '.codex' }),
    [string]$ProjectRoot = (Join-Path $HOME 'Documents/Codex/Agent-Harness-V5.2.5')
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$overlayRoot  = $PSScriptRoot
$manifestPath = Join-Path $overlayRoot 'overlay-manifest.json'
if (-not (Test-Path -LiteralPath $manifestPath)) { throw "overlay manifest 缺失: $manifestPath" }
$manifest = Get-Content -LiteralPath $manifestPath -Raw -Encoding UTF8 | ConvertFrom-Json

function Get-Sha([string]$Path) {
    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) { return $null }
    (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToUpperInvariant()
}
function Resolve-Target([string]$Spec) {
    $p = $Spec -replace '<CODEX_HOME>',   $CodexHome
    $p = $p    -replace '<PROJECT_ROOT>', $ProjectRoot
    $p -replace '/', [System.IO.Path]::DirectorySeparatorChar
}

$applied = 0; $skipped = 0; $drift = @(); $missing = @()

foreach ($entry in $manifest.entries) {
    $target   = Resolve-Target $entry.target
    $artifact = Join-Path $overlayRoot ($entry.artifact -replace '/', [System.IO.Path]::DirectorySeparatorChar)
    $backup   = Join-Path $overlayRoot ($entry.backupArtifact -replace '/', [System.IO.Path]::DirectorySeparatorChar)
    $current  = Get-Sha $target

    if (-not (Test-Path -LiteralPath $artifact -PathType Leaf)) {
        $missing += "$($entry.id)  overlay 产物缺失: $artifact"
        continue
    }
    $artifactHash = Get-Sha $artifact
    if ($artifactHash -ne $entry.sha256Patched) {
        $drift += "$($entry.id)  overlay 产物 hash 不符: $artifactHash"
        continue
    }
    if (-not (Test-Path -LiteralPath $backup -PathType Leaf)) {
        $missing += "$($entry.id)  原始备份缺失: $backup"
        continue
    }
    $backupHash = Get-Sha $backup
    if ($backupHash -ne $entry.sha256Pristine) {
        $drift += "$($entry.id)  原始备份 hash 不符: $backupHash"
        continue
    }
    if ($null -eq $current) {
        $missing += "$($entry.id)  目标不存在: $target"
        continue
    }
    if ($current -eq $entry.sha256Patched) {
        Write-Host ("  [skip ] {0}  已应用  {1}" -f $entry.id, $entry.target)
        $skipped++
        continue
    }
    $acceptedBaseHashes = @([string]$entry.sha256Pristine)
    if ($entry.PSObject.Properties.Name -contains 'sha256PriorPatched') {
        $acceptedBaseHashes += @($entry.sha256PriorPatched | ForEach-Object { [string]$_ })
    }
    if ($current -notin $acceptedBaseHashes) {
        $drift += "$($entry.id)  内容既非原始也非补丁后（sha=$($current.Substring(0,8))）: $target"
        continue
    }
    if ($PSCmdlet.ShouldProcess($target, "应用 $($entry.id)")) {
        Copy-Item -LiteralPath $artifact -Destination $target -Force
        $after = Get-Sha $target
        if ($after -ne $entry.sha256Patched) { throw "$($entry.id) 应用后 hash 不符: $after" }
        Write-Host ("  [apply] {0}  {1} -> {2}  {3}" -f $entry.id,
            $current.Substring(0,8), $after.Substring(0,8), $entry.target)
        $applied++
    }
}

Write-Host ''
Write-Host ("applied={0} skipped={1} drift={2} missing={3}" -f $applied, $skipped, $drift.Count, $missing.Count)
foreach ($d in $drift)   { Write-Warning $d }
foreach ($m in $missing) { Write-Warning $m }

$passed = ($drift.Count -eq 0 -and $missing.Count -eq 0)
[ordered]@{
    passed  = $passed
    applied = $applied
    skipped = $skipped
    drift   = @($drift)
    missing = @($missing)
} | ConvertTo-Json -Depth 6 -Compress
if (-not $passed) { exit 1 }
