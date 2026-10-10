param([string]$SourceRoot = '')
$ErrorActionPreference = 'Stop'
if ([string]::IsNullOrWhiteSpace($SourceRoot)) { $SourceRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..\..')).Path }
$tool = Join-Path $SourceRoot 'tools\diagnostics\runtime-performance.ps1'
$root = Join-Path ([System.IO.Path]::GetTempPath()) ('harness-diagnostic-' + [guid]::NewGuid().ToString('N'))
$harness = Join-Path $root '.codex\harness'
New-Item -ItemType Directory -Path $harness -Force | Out-Null
try {
    $lines = @(
        '{"timestamp":"2026-07-16T00:00:00Z","event":"PreToolUse","phase":"start","category":"tool","tool":"Bash","turn_id":"t","conversation_id":"c","operation_id":"op","mutating":false}',
        '{"timestamp":"2026-07-16T00:00:02Z","event":"PostToolUse","phase":"complete","category":"tool","tool":"Bash","turn_id":"t","conversation_id":"c","operation_id":"op","mutating":false}',
        '{"timestamp":"2026-07-16T00:00:03Z","event":"PostToolUse","tool":"apply_patch","turn_id":"t","conversation_id":"c","mutating":true}'
    )
    [System.IO.File]::WriteAllLines((Join-Path $harness 'runtime-events.jsonl'), $lines, (New-Object System.Text.UTF8Encoding($false)))
    $report = & $tool -Root $root -ConversationId c -TurnId t | ConvertFrom-Json
    if ([int]$report.event_count -ne 3) { throw 'Manual diagnostic did not read the fixture.' }
    if (@($report.legacy_paired_tool_durations).Count -ne 1 -or [int]$report.legacy_paired_tool_durations[0].duration_ms -ne 2000) { throw 'Legacy duration pairing failed.' }
    if ([int]$report.mutating_event_count -ne 1) { throw 'Minimal PostTool mutation evidence was not counted.' }
    if ([string]$report.model_timing -notmatch 'unavailable') { throw 'Diagnostic overstated model timing visibility.' }
    [pscustomobject]@{ passed = $true; eventCount = [int]$report.event_count; legacyDurationMs = [int]$report.legacy_paired_tool_durations[0].duration_ms; modelTiming = [string]$report.model_timing } | ConvertTo-Json -Depth 5
} finally {
    Remove-Item -LiteralPath $root -Recurse -Force -ErrorAction SilentlyContinue
}
