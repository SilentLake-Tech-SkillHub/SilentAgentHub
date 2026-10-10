param([string]$SourceRoot = '')
$ErrorActionPreference = 'Stop'
if ([string]::IsNullOrWhiteSpace($SourceRoot)) { $SourceRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..\..')).Path }
$hooks = Join-Path $SourceRoot '.codex\hooks'
. (Join-Path $hooks 'common.ps1')

if ((Get-QueryRouteCandidate '批准 T-013') -ne 'plan_review') { throw 'Plan approval was not classified as review.' }
if ((Get-QueryRouteCandidate '为什么跑了那么多 Skills？') -ne 'status_or_readonly') { throw 'Read-only Skill question was misclassified as complex.' }
if ((Get-QueryRouteCandidate '为什么需要跑这么多 Skills？') -ne 'status_or_readonly') { throw 'Read-only question containing need was misclassified as a change.' }
if ((Get-QueryRouteCandidate '请修复 Hook 并部署生产版本') -ne 'complex_candidate') { throw 'Complex Hook deployment was not detected.' }

$readInput = [pscustomobject]@{ toolCall = [pscustomobject]@{ name = 'functions.exec_command' }; tool_input = [pscustomobject]@{ cmd = 'Get-Content README.md' }; turn_id = 'turn-performance' }
$writeInput = [pscustomobject]@{ toolCall = [pscustomobject]@{ name = 'functions.apply_patch' }; turn_id = 'turn-performance' }
if (Test-ToolMutation $readInput) { throw 'Read-only command was marked mutating.' }
if (-not (Test-ToolMutation $writeInput)) { throw 'apply_patch was not marked mutating.' }

$root = Join-Path ([System.IO.Path]::GetTempPath()) ('harness-performance-' + [guid]::NewGuid().ToString('N'))
$harness = Join-Path $root '.codex\harness'
$tempHooks = Join-Path $root '.codex\hooks'
New-Item -ItemType Directory -Path $harness,$tempHooks -Force | Out-Null
try {
    Copy-Item -LiteralPath (Join-Path $hooks 'common.ps1') -Destination $tempHooks -Force
    Copy-Item -LiteralPath (Join-Path $hooks 'runtime-performance.ps1') -Destination $tempHooks -Force
    Copy-Item -LiteralPath (Join-Path $SourceRoot '.codex\harness\performance-policy.json') -Destination $harness -Force
    Copy-Item -LiteralPath (Join-Path $SourceRoot '.codex\harness\performance-policy.schema.json') -Destination $harness -Force
    [System.IO.File]::WriteAllText((Join-Path $harness 'index.json'), '{"performancePolicy":".codex/harness/performance-policy.json","runtimeEventLog":".codex/harness/runtime-events.jsonl"}', (New-Object System.Text.UTF8Encoding($true)))
    $runtime = Join-Path $tempHooks 'runtime-performance.ps1'
    $null = & $runtime -Event Record -Root $root -HookEvent PreToolUse -Phase start -Category tool -Name Bash -SessionId s -ConversationId c -TurnId t -OperationId op -Mutating $false
    $null = & $runtime -Event Record -Root $root -HookEvent PostToolUse -Phase complete -Category tool -Name Bash -SessionId s -ConversationId c -TurnId t -OperationId op -Mutating $false
    $report = & $runtime -Event Report -Root $root -ConversationId c -TurnId t | ConvertFrom-Json
    if ([int]$report.matched_tool_count -ne 1 -or [int]$report.mutating_tool_count -ne 0) { throw 'Performance report did not pair tool events.' }
    if ([int]$report.automatic_retry_limit -ne 1 -or @($report.incomplete_tool_operations).Count -ne 0) { throw 'Performance retry/incomplete-operation policy was not reported.' }
    if ([string]$report.model_timing -notmatch 'unavailable') { throw 'Performance report overstated model timing visibility.' }
    $validation = & $runtime -Event Validate -Root $root | ConvertFrom-Json
    if (-not [bool]$validation.passed) { throw 'Performance policy validation failed.' }
    [pscustomobject]@{
        passed = $true
        approval = 'plan_review'
        readonly = 'status_or_readonly'
        complex = 'complex_candidate'
        matchedTools = [int]$report.matched_tool_count
        modelTiming = [string]$report.model_timing
    } | ConvertTo-Json -Depth 6
} finally {
    Remove-Item -LiteralPath $root -Recurse -Force -ErrorAction SilentlyContinue
}
