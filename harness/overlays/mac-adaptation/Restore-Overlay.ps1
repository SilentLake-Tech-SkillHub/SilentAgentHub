#!/usr/bin/env pwsh
<#
.SYNOPSIS
  在 Hash 受控前提下恢复 mac-adaptation overlay 的原始文件。
.DESCRIPTION
  对 overlay-manifest.json 里的每一条：
    - 目标 sha256 == sha256Patched/sha256PriorPatched -> 从登记的 backupArtifact 恢复
    - 目标 sha256 == sha256Pristine -> 已恢复，跳过
    - 其他状态                  -> 拒绝覆盖并报告 drift
  备份必须存在，且其 Hash 必须等于 sha256Pristine。
.EXAMPLE
  pwsh -NoProfile -File Restore-Overlay.ps1 -WhatIf
  pwsh -NoProfile -File Restore-Overlay.ps1
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
if (-not (Test-Path -LiteralPath $manifestPath -PathType Leaf)) { throw "overlay manifest 缺失: $manifestPath" }
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

$restored = 0; $skipped = 0; $drift = @(); $missing = @()
foreach ($entry in $manifest.entries) {
    $target = Resolve-Target $entry.target
    $backup = Join-Path $overlayRoot ($entry.backupArtifact -replace '/', [System.IO.Path]::DirectorySeparatorChar)
    $current = Get-Sha $target

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
    if ($current -eq $entry.sha256Pristine) {
        Write-Host ("  [skip   ] {0}  已是原始版  {1}" -f $entry.id, $entry.target)
        $skipped++
        continue
    }
    $acceptedPatchedHashes = @([string]$entry.sha256Patched)
    if ($entry.PSObject.Properties.Name -contains 'sha256PriorPatched') {
        $acceptedPatchedHashes += @($entry.sha256PriorPatched | ForEach-Object { [string]$_ })
    }
    if ($current -notin $acceptedPatchedHashes) {
        $drift += "$($entry.id)  目标既非原始也非补丁后（sha=$($current.Substring(0,8))）: $target"
        continue
    }
    if ($PSCmdlet.ShouldProcess($target, "恢复 $($entry.id) 原始版")) {
        Copy-Item -LiteralPath $backup -Destination $target -Force
        $after = Get-Sha $target
        if ($after -ne $entry.sha256Pristine) { throw "$($entry.id) 恢复后 hash 不符: $after" }
        Write-Host ("  [restore] {0}  {1} -> {2}  {3}" -f $entry.id,
            $entry.sha256Patched.Substring(0,8), $after.Substring(0,8), $entry.target)
        $restored++
    }
}

Write-Host ''
Write-Host ("restored={0} skipped={1} drift={2} missing={3}" -f $restored, $skipped, $drift.Count, $missing.Count)
foreach ($d in $drift)   { Write-Warning $d }
foreach ($m in $missing) { Write-Warning $m }

$passed = ($drift.Count -eq 0 -and $missing.Count -eq 0)
[ordered]@{
    passed   = $passed
    restored = $restored
    skipped  = $skipped
    drift    = @($drift)
    missing  = @($missing)
} | ConvertTo-Json -Depth 6 -Compress
if (-not $passed) { exit 1 }
