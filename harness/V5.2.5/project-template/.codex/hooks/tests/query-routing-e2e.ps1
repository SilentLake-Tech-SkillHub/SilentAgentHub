param([string]$SourceRoot = '')
$ErrorActionPreference = 'Stop'
if ([string]::IsNullOrWhiteSpace($SourceRoot)) { $SourceRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..\..')).Path }
$hooks = Join-Path $SourceRoot '.codex\hooks'
. (Join-Path $hooks 'common.ps1')

if ((Get-QueryRouteCandidate '批准 T-014') -ne 'plan_review') { throw 'Plan approval was not classified as review.' }
if ((Get-QueryRouteCandidate '为什么跑了那么多 Skills？') -ne 'status_or_readonly') { throw 'Read-only Skill question was misclassified as complex.' }
if ((Get-QueryRouteCandidate '为什么需要跑这么多 Skills？') -ne 'status_or_readonly') { throw 'Read-only question containing need was misclassified as a change.' }
if ((Get-QueryRouteCandidate '请修复 Hook 并部署生产版本') -ne 'complex_candidate') { throw 'Complex Hook deployment was not detected.' }

$readInput = [pscustomobject]@{ toolCall = [pscustomobject]@{ name = 'functions.exec_command' }; tool_input = [pscustomobject]@{ cmd = 'Get-Content README.md' }; turn_id = 'turn-query' }
$writeInput = [pscustomobject]@{ toolCall = [pscustomobject]@{ name = 'functions.apply_patch' }; turn_id = 'turn-query' }
if (Test-ToolMutation $readInput) { throw 'Read-only command was marked mutating.' }
if (-not (Test-ToolMutation $writeInput)) { throw 'apply_patch was not marked mutating.' }

$index = Get-Content -LiteralPath (Join-Path $SourceRoot '.codex\harness\index.json') -Raw -Encoding UTF8 | ConvertFrom-Json
if ($index.PSObject.Properties.Name -contains 'performancePolicy' -or $index.PSObject.Properties.Name -contains 'performancePolicySchema') { throw 'Production index still references performance policy.' }
if (Test-Path -LiteralPath (Join-Path $hooks 'runtime-performance.ps1')) { throw 'Manual diagnostic remains in production Hook directory.' }
$hookConfig = Get-Content -LiteralPath (Join-Path $SourceRoot '.codex\hooks.json') -Raw -Encoding UTF8
if ($hookConfig -match 'runtime-performance') { throw 'Production hooks register the manual diagnostic.' }

[pscustomobject]@{
    passed = $true
    approval = 'plan_review'
    readonly = 'status_or_readonly'
    complex = 'complex_candidate'
    performancePolicyRemoved = $true
    diagnosticUnregistered = $true
} | ConvertTo-Json -Depth 5
