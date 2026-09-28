#!/usr/bin/env pwsh
<#
.SYNOPSIS
  一键验证：overlay 状态 + 四项 fixture + Plan 模板/只读模式回归 + Hook 存活度。
.EXAMPLE
  pwsh -NoProfile -File ~/.codex/harness/overlays/mac-adaptation/Verify-All.ps1
#>
param(
    [string]$CodexHome   = $(if ($env:CODEX_HOME) { $env:CODEX_HOME } else { Join-Path $HOME '.codex' }),
    [string]$ProjectRoot = (Join-Path $HOME 'Documents/Codex/Agent-Harness-V5.2.5')
)

$ErrorActionPreference = 'Continue'
$overlayRoot = $PSScriptRoot
$summary = [System.Collections.Specialized.OrderedDictionary]::new()

function Show([string]$Title) {
    Write-Host ''
    Write-Host ('═' * 68) -ForegroundColor DarkGray
    Write-Host "  $Title" -ForegroundColor Cyan
    Write-Host ('═' * 68) -ForegroundColor DarkGray
}
function Mark([bool]$Ok) { if ($Ok) { 'PASS' } else { 'FAIL' } }

# ─────────────────────────────── 1. 环境 ───────────────────────────────
Show '1. 环境'
Write-Host "  PowerShell   : $($PSVersionTable.PSVersion)"
Write-Host "  Platform     : $($PSVersionTable.Platform)"
Write-Host "  CodexHome    : $CodexHome"
Write-Host "  ProjectRoot  : $ProjectRoot"
$gitOk = $null -ne (Get-Command git -ErrorAction SilentlyContinue)
Write-Host "  git          : $(Mark $gitOk)"
$summary['env.git'] = $gitOk

# ────────────────────────────── 2. overlay ─────────────────────────────
Show '2. Overlay 状态（已备案的缺陷修复）'
$manifest = Get-Content -LiteralPath (Join-Path $overlayRoot 'overlay-manifest.json') -Raw -Encoding UTF8 | ConvertFrom-Json
$overlayOk = $true
foreach ($e in $manifest.entries) {
    $t = ($e.target -replace '<CODEX_HOME>', $CodexHome) -replace '<PROJECT_ROOT>', $ProjectRoot
    $artifact = Join-Path $overlayRoot ($e.artifact -replace '/', [System.IO.Path]::DirectorySeparatorChar)
    $backup = Join-Path $overlayRoot ($e.backupArtifact -replace '/', [System.IO.Path]::DirectorySeparatorChar)
    $cur = if (Test-Path -LiteralPath $t -PathType Leaf) {
        (Get-FileHash -LiteralPath $t -Algorithm SHA256).Hash.ToUpperInvariant()
    } else { $null }
    $artifactHash = if (Test-Path -LiteralPath $artifact -PathType Leaf) {
        (Get-FileHash -LiteralPath $artifact -Algorithm SHA256).Hash.ToUpperInvariant()
    } else { $null }
    $backupHash = if (Test-Path -LiteralPath $backup -PathType Leaf) {
        (Get-FileHash -LiteralPath $backup -Algorithm SHA256).Hash.ToUpperInvariant()
    } else { $null }
    $state = if ($null -eq $cur) { 'MISSING' }
             elseif ($cur -eq $e.sha256Patched)  { 'applied' }
             elseif ($cur -eq $e.sha256Pristine) { 'PRISTINE(未应用)' }
             else { 'DRIFT' }
    $assetsOk = ($artifactHash -eq $e.sha256Patched -and $backupHash -eq $e.sha256Pristine)
    if ($state -notin @('applied') -or -not $assetsOk) { $overlayOk = $false }
    $color = if ($state -eq 'applied' -and $assetsOk) { 'Green' } else { 'Yellow' }
    Write-Host ("  {0}  {1,-16} assets={2,-4}  {3}" -f $e.id, $state, (Mark $assetsOk), $e.target) -ForegroundColor $color
}
Write-Host "  => $(Mark $overlayOk)"
$summary['overlay'] = $overlayOk
if (-not $overlayOk) {
    Write-Host '  提示: 运行 Apply-Overlay.ps1 重新贴回补丁' -ForegroundColor Yellow
}

# ───────────────────────── 3. fixture + 回归测试 ────────────────────────
Show '3. Fixture 与回归测试'
$tests = [ordered]@{
    'query-routing-e2e'    = Join-Path $ProjectRoot '.codex/hooks/tests/query-routing-e2e.ps1'
    'memory-desktop-e2e'   = Join-Path $ProjectRoot '.codex/hooks/tests/memory-desktop-e2e.ps1'
    'plan-disclosure-e2e'  = Join-Path $ProjectRoot '.codex/hooks/tests/plan-disclosure-e2e.ps1'
    'runtime-performance'  = Join-Path $ProjectRoot 'tools/diagnostics/tests/runtime-performance-e2e.ps1'
}
foreach ($name in $tests.Keys) {
    $path = $tests[$name]
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
        Write-Host ("  {0,-22} SKIP  (不存在)" -f $name) -ForegroundColor DarkYellow
        $summary["test.$name"] = 'missing'; continue
    }
    $out = & pwsh -NoProfile -File $path 2>&1 | Out-String
    $ok  = $out -match '"passed"\s*:\s*true'
    Write-Host ("  {0,-22} {1}" -f $name, (Mark $ok)) -ForegroundColor $(if ($ok) {'Green'} else {'Red'})
    if (-not $ok) { Write-Host ('      ' + ($out.Trim() -split "`n" | Select-Object -First 4 | Out-String).Trim()) -ForegroundColor DarkRed }
    $summary["test.$name"] = $ok
}

# 新增：模板→Register 回归
$reg = Join-Path $overlayRoot 'Test-PlanTemplateRegression.ps1'
$out = & pwsh -NoProfile -File $reg -CodexHome $CodexHome -ProjectRoot $ProjectRoot 2>&1 | Out-String
$ok  = $out -match '"passed"\s*:\s*true'
Write-Host ("  {0,-22} {1}   <= 原包缺失的那个测试" -f 'plan-template-regression', (Mark $ok)) -ForegroundColor $(if ($ok) {'Green'} else {'Red'})
if (-not $ok) { Write-Host ('      ' + $out.Trim()) -ForegroundColor DarkRed }
$summary['test.plan-template-regression'] = $ok

$planModeRegression = Join-Path $overlayRoot 'Test-PlanModeReadonlyRegression.ps1'
$out = & pwsh -NoProfile -File $planModeRegression -ProjectRoot $ProjectRoot 2>&1 | Out-String
$ok = $out -match '"passed"\s*:\s*true'
Write-Host ("  {0,-22} {1}   <= Plan mode/Stop 只读协议" -f 'plan-mode-readonly', (Mark $ok)) -ForegroundColor $(if ($ok) {'Green'} else {'Red'})
if (-not $ok) { Write-Host ('      ' + ($out.Trim())) -ForegroundColor DarkRed }
$summary['test.plan-mode-readonly'] = $ok

# ───────────────────────── 4. Hook 实际存活度 ───────────────────────────
Show '4. Hook 分类运行证据（runtime-events 只代表 PostToolUse）'
$log = Join-Path $ProjectRoot '.codex/harness/runtime-events.jsonl'
if (Test-Path -LiteralPath $log -PathType Leaf) {
    $lines = @(Get-Content -LiteralPath $log -Encoding UTF8 | Where-Object { $_.Trim() })
    Write-Host "  PostToolUse 变更捕获记录 : $($lines.Count)"
    if ($lines.Count) {
        $last = $lines[-1] | ConvertFrom-Json
        $age  = (Get-Date) - [datetime]::Parse($last.timestamp)
        Write-Host "  最后 PostToolUse         : $($last.timestamp)  ($([int]$age.TotalHours) 小时前)  tool=$($last.tool)"
        $events = $lines | ForEach-Object { ($_ | ConvertFrom-Json).event } | Group-Object | Sort-Object Name
        Write-Host "  文件内 event 分布    : $(($events | ForEach-Object { "$($_.Name)=$($_.Count)" }) -join '  ')"
        if ($age.TotalHours -gt 2) {
            Write-Host '  !! 超过 2 小时无新 PostToolUse 记录；需结合期间是否在本项目执行工具判断。' -ForegroundColor Yellow
        }
    }
} else {
    Write-Host '  runtime-events.jsonl 不存在：仅表示暂无 PostToolUse 变更捕获证据。' -ForegroundColor Yellow
}
$memoryIndexPath = Join-Path $ProjectRoot '.codex/harness/memory-index.json'
if (Test-Path -LiteralPath $memoryIndexPath -PathType Leaf) {
    $mi = Get-Content -LiteralPath $memoryIndexPath -Raw -Encoding UTF8 | ConvertFrom-Json
    $conversations = @($mi.conversations)
    $latestMemory = @($conversations | Sort-Object { [datetime]$_.updatedAt } -Descending | Select-Object -First 1)
    Write-Host "  Memory conversation 数     : $($conversations.Count)  (index updatedAt=$($mi.updatedAt))"
    if ($latestMemory.Count) {
        Write-Host "  最新 Memory 状态        : $($latestMemory[0].updatedAt)  conversation=$($latestMemory[0].conversationId)  state=$($latestMemory[0].state)  location=$($latestMemory[0].location)"
    }
    $transactionsDir = Join-Path $ProjectRoot '.codex/harness/memory-transactions'
    $transactions = if (Test-Path -LiteralPath $transactionsDir) { @(Get-ChildItem -LiteralPath $transactionsDir -Filter '*.json' -File -Force) } else { @() }
    $latestTransaction = @($transactions | Sort-Object LastWriteTimeUtc -Descending | Select-Object -First 1)
    Write-Host "  终态 Memory transaction : $($transactions.Count)"
    if ($latestTransaction.Count) { Write-Host "  最新 transaction         : $($latestTransaction[0].LastWriteTimeUtc.ToString('o'))  file=$($latestTransaction[0].Name)" }
} else {
    Write-Host '  memory-index.json 不存在：无法判定 Memory capture/closeout。' -ForegroundColor Red
}
$pds = Join-Path $ProjectRoot '.codex/harness/plan-disclosure-state.json'
if (Test-Path -LiteralPath $pds -PathType Leaf) {
    $s = Get-Content -LiteralPath $pds -Raw -Encoding UTF8 | ConvertFrom-Json
    Write-Host "  Plan 注册记录 : $(@($s.records).Count)  (updatedAt=$($s.updatedAt))"
    $latestPlan = @($s.records | Sort-Object { [datetime]$_.registeredAt } -Descending | Select-Object -First 1)
    if ($latestPlan.Count) { Write-Host "  最新 Plan 记录 : $($latestPlan[0].registeredAt)  state=$($latestPlan[0].state)  plan=$($latestPlan[0].planPath)" }
    else { Write-Host '  尚无 Plan disclosure 记录。' -ForegroundColor Yellow }
}

# ─────────────────────────────── 汇总 ──────────────────────────────────
Show '汇总'
$fail = @($summary.Keys | Where-Object { $summary[$_] -eq $false })
foreach ($k in $summary.Keys) {
    $v = $summary[$k]
    $c = if ($v -eq $true) {'Green'} elseif ($v -eq $false) {'Red'} else {'DarkYellow'}
    Write-Host ("  {0,-34} {1}" -f $k, $v) -ForegroundColor $c
}
Write-Host ''
if ($fail.Count -eq 0) { Write-Host '  全部通过' -ForegroundColor Green }
else { Write-Host "  失败项: $($fail -join ', ')" -ForegroundColor Red }
Write-Host ''
exit $fail.Count
