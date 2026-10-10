param(
    [string]$Root = '',
    [string]$LogPath = '',
    [string]$ConversationId = '',
    [string]$TurnId = '',
    [int]$GapWarnMs = 300000,
    [string]$OutputPath = ''
)

$ErrorActionPreference = 'Stop'
if ([string]::IsNullOrWhiteSpace($Root)) { $Root = (Get-Location).Path }
$Root = [System.IO.Path]::GetFullPath($Root)

function Get-EventValue([object]$Item, [string]$Name, [object]$Default = $null) {
    if ($null -ne $Item -and $Item.PSObject.Properties.Name -contains $Name) { return $Item.$Name }
    $Default
}

if ([string]::IsNullOrWhiteSpace($LogPath)) {
    $LogPath = Join-Path $Root '.codex/harness/runtime-events.jsonl'
} elseif (-not [System.IO.Path]::IsPathRooted($LogPath)) {
    $LogPath = Join-Path $Root $LogPath
}
if (-not (Test-Path -LiteralPath $LogPath -PathType Leaf)) { throw "Runtime event log not found: $LogPath" }

$events = [System.Collections.Generic.List[object]]::new()
$invalidLines = 0
foreach ($line in Get-Content -LiteralPath $LogPath -Encoding UTF8) {
    if ([string]::IsNullOrWhiteSpace($line)) { continue }
    try {
        $item = $line | ConvertFrom-Json
        if (-not [string]::IsNullOrWhiteSpace($ConversationId) -and [string](Get-EventValue $item 'conversation_id' '') -ne $ConversationId) { continue }
        if (-not [string]::IsNullOrWhiteSpace($TurnId) -and [string](Get-EventValue $item 'turn_id' '') -ne $TurnId) { continue }
        $events.Add($item)
    } catch { $invalidLines++ }
}

$ordered = @($events | Sort-Object { [DateTimeOffset](Get-EventValue $_ 'timestamp' '1970-01-01T00:00:00Z') })
$maxGap = 0
for ($i = 1; $i -lt $ordered.Count; $i++) {
    $gap = ([DateTimeOffset](Get-EventValue $ordered[$i] 'timestamp' '1970-01-01T00:00:00Z') - [DateTimeOffset](Get-EventValue $ordered[$i - 1] 'timestamp' '1970-01-01T00:00:00Z')).TotalMilliseconds
    if ($gap -gt $maxGap) { $maxGap = $gap }
}

$legacyDurations = [System.Collections.Generic.List[object]]::new()
$open = @{}
foreach ($item in $ordered) {
    $phase = [string](Get-EventValue $item 'phase' '')
    $category = [string](Get-EventValue $item 'category' '')
    if ($category -ne 'tool' -or $phase -notin @('start','complete')) { continue }
    $key = [string](Get-EventValue $item 'operation_id' '')
    if ([string]::IsNullOrWhiteSpace($key)) { continue }
    if ($phase -eq 'start') { $open[$key] = $item; continue }
    if ($open.ContainsKey($key)) {
        $start = $open[$key]
        $duration = ([DateTimeOffset](Get-EventValue $item 'timestamp' '1970-01-01T00:00:00Z') - [DateTimeOffset](Get-EventValue $start 'timestamp' '1970-01-01T00:00:00Z')).TotalMilliseconds
        $legacyDurations.Add([pscustomobject]@{ operation_id = $key; tool = [string](Get-EventValue $item 'tool' (Get-EventValue $item 'name' 'unknown')); duration_ms = [math]::Round($duration) })
        $open.Remove($key)
    }
}

$first = if ($ordered.Count -gt 0) { [DateTimeOffset](Get-EventValue $ordered[0] 'timestamp' '1970-01-01T00:00:00Z') } else { $null }
$last = if ($ordered.Count -gt 0) { [DateTimeOffset](Get-EventValue $ordered[-1] 'timestamp' '1970-01-01T00:00:00Z') } else { $null }
$eventCounts = @($ordered | Group-Object { [string](Get-EventValue $_ 'event' 'unknown') } | Sort-Object Count -Descending | ForEach-Object { [pscustomobject]@{ event = $_.Name; count = $_.Count } })
$toolCounts = @($ordered | Where-Object { -not [string]::IsNullOrWhiteSpace([string](Get-EventValue $_ 'tool' '')) } | Group-Object { [string](Get-EventValue $_ 'tool' '') } | Sort-Object Count -Descending | ForEach-Object { [pscustomobject]@{ tool = $_.Name; count = $_.Count } })
$warnings = [System.Collections.Generic.List[string]]::new()
if ($maxGap -gt $GapWarnMs) { $warnings.Add("Longest event gap exceeded GapWarnMs=$GapWarnMs.") }
if ($invalidLines -gt 0) { $warnings.Add("$invalidLines invalid JSONL line(s) were ignored.") }

$summary = [ordered]@{
    generated_at = [DateTimeOffset]::Now.ToString('o')
    mode = 'manual_diagnostic'
    log_path = $LogPath
    conversation_id = $ConversationId
    turn_id = $TurnId
    event_count = $ordered.Count
    invalid_line_count = $invalidLines
    observable_span_ms = if ($null -ne $first -and $null -ne $last) { [math]::Round(($last - $first).TotalMilliseconds) } else { 0 }
    longest_event_gap_ms = [math]::Round($maxGap)
    gap_warn_ms = $GapWarnMs
    mutating_event_count = @($ordered | Where-Object { [bool](Get-EventValue $_ 'mutating' $false) }).Count
    event_counts = $eventCounts
    tool_counts = $toolCounts
    legacy_paired_tool_durations = @($legacyDurations | Sort-Object duration_ms -Descending | Select-Object -First 10)
    warnings = @($warnings)
    model_timing = 'unavailable: project event logs cannot observe model request or first-token timestamps'
}

$json = $summary | ConvertTo-Json -Depth 10
if (-not [string]::IsNullOrWhiteSpace($OutputPath)) {
    $target = if ([System.IO.Path]::IsPathRooted($OutputPath)) { $OutputPath } else { Join-Path $Root $OutputPath }
    $parent = Split-Path -Parent $target
    if ($parent -and -not (Test-Path -LiteralPath $parent)) { New-Item -ItemType Directory -Path $parent -Force | Out-Null }
    [System.IO.File]::WriteAllText($target, $json, (New-Object System.Text.UTF8Encoding($true)))
}
$json
