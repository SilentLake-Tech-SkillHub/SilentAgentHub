param(
    [Parameter(Mandatory = $true)][ValidateSet('Record','Report','Validate')][string]$Event,
    [string]$Root = '',
    [string]$HookEvent = '',
    [string]$Phase = '',
    [string]$Category = '',
    [string]$Name = '',
    [string]$SessionId = '',
    [string]$ConversationId = '',
    [string]$TurnId = '',
    [string]$OperationId = '',
    [string]$QueryClass = '',
    [string]$ApprovalType = '',
    [bool]$Mutating = $false,
    [string]$OutputPath = ''
)
. "$PSScriptRoot/common.ps1"

if ([string]::IsNullOrWhiteSpace($Root)) { $Root = (Get-Location).Path }
$Root = [System.IO.Path]::GetFullPath($Root)
$indexPath = Join-Path $Root '.codex/harness/index.json'
$index = Get-Content -LiteralPath $indexPath -Raw -Encoding UTF8 | ConvertFrom-Json
$policyPath = Join-Path $Root ([string]$index.performancePolicy)
$policy = Get-Content -LiteralPath $policyPath -Raw -Encoding UTF8 | ConvertFrom-Json
$logPath = Join-Path $Root ([string]$index.runtimeEventLog)

if ($Event -eq 'Record') {
    $record = [ordered]@{
        timestamp = [DateTimeOffset]::Now.ToString('o')
        event = $HookEvent
        phase = $Phase
        category = $Category
        name = $Name
        tool = $Name
        session_id = $SessionId
        conversation_id = $ConversationId
        turn_id = $TurnId
        operation_id = $OperationId
        query_class = $QueryClass
        approval_type = $ApprovalType
        mutating = $Mutating
        cwd = $Root
    }
    Add-Utf8JsonLine $logPath $record
    $record | ConvertTo-Json -Depth 6 -Compress
    exit 0
}

if ($Event -eq 'Validate') {
    $errors = [System.Collections.Generic.List[string]]::new()
    foreach ($required in @('version','thresholds','validationProfiles')) {
        if ($policy.PSObject.Properties.Name -notcontains $required) { $errors.Add("missing policy property: $required") }
    }
    foreach ($requiredProfile in @('readonly','simple_change','complex_engineering','production_release')) {
        if ($policy.validationProfiles.PSObject.Properties.Name -notcontains $requiredProfile) { $errors.Add("missing validation profile: $requiredProfile") }
    }
    @{ passed = ($errors.Count -eq 0); errors = @($errors); policy = $policyPath } | ConvertTo-Json -Depth 8
    exit 0
}

$events = [System.Collections.Generic.List[object]]::new()
if (Test-Path -LiteralPath $logPath) {
    foreach ($line in Get-Content -LiteralPath $logPath -Encoding UTF8) {
        if ([string]::IsNullOrWhiteSpace($line)) { continue }
        try {
            $item = $line | ConvertFrom-Json
            if (-not [string]::IsNullOrWhiteSpace($TurnId) -and [string](Get-PropertyValue $item 'turn_id' '') -ne $TurnId) { continue }
            if (-not [string]::IsNullOrWhiteSpace($ConversationId) -and $item.PSObject.Properties.Name -contains 'conversation_id' -and [string]$item.conversation_id -ne $ConversationId) { continue }
            $events.Add($item)
        } catch { }
    }
}
$ordered = @($events | Sort-Object { [DateTimeOffset]$_.timestamp })
$durations = [System.Collections.Generic.List[object]]::new()
$open = @{}
foreach ($item in $ordered) {
    $itemCategory = [string](Get-PropertyValue $item 'category' '')
    $itemPhase = [string](Get-PropertyValue $item 'phase' '')
    if ($itemCategory -ne 'tool') { continue }
    $key = [string](Get-PropertyValue $item 'operation_id' '')
    if ([string]::IsNullOrWhiteSpace($key)) { $key = "$(Get-PropertyValue $item 'turn_id' '')::$(Get-PropertyValue $item 'name' '')" }
    if ($itemPhase -eq 'start') {
        if (-not $open.ContainsKey($key)) { $open[$key] = [System.Collections.Queue]::new() }
        $open[$key].Enqueue($item)
    } elseif ($itemPhase -eq 'complete' -and $open.ContainsKey($key) -and $open[$key].Count -gt 0) {
        $start = $open[$key].Dequeue()
        $duration = ([DateTimeOffset]$item.timestamp - [DateTimeOffset]$start.timestamp).TotalMilliseconds
        $durations.Add([pscustomobject]@{ name = [string]$item.name; operation_id = $key; duration_ms = [math]::Round($duration); mutating = [bool](Get-PropertyValue $item 'mutating' $false) })
    }
}
$maxGap = 0
for ($i = 1; $i -lt $ordered.Count; $i++) {
    $gap = ([DateTimeOffset]$ordered[$i].timestamp - [DateTimeOffset]$ordered[$i - 1].timestamp).TotalMilliseconds
    if ($gap -gt $maxGap) { $maxGap = $gap }
}
$first = if ($ordered.Count -gt 0) { [DateTimeOffset]$ordered[0].timestamp } else { $null }
$last = if ($ordered.Count -gt 0) { [DateTimeOffset]$ordered[-1].timestamp } else { $null }
$queryClasses = @($ordered | Where-Object { -not [string]::IsNullOrWhiteSpace([string](Get-PropertyValue $_ 'query_class' '')) } | Select-Object -Last 1 | ForEach-Object { [string]$_.query_class })
$incompleteOperations = @($open.GetEnumerator() | Where-Object { $_.Value.Count -gt 0 } | ForEach-Object { [pscustomobject]@{ operation_id = [string]$_.Key; pending_starts = $_.Value.Count } })
$slowTools = @($durations | Where-Object { $_.duration_ms -gt [double]$policy.thresholds.toolWarnMs } | Sort-Object duration_ms -Descending)
$warnings = [System.Collections.Generic.List[string]]::new()
if ($slowTools.Count -gt 0) { $warnings.Add("$($slowTools.Count) tool operation(s) exceeded toolWarnMs=$($policy.thresholds.toolWarnMs).") }
if ($maxGap -gt [double]$policy.thresholds.unexplainedGapWarnMs) { $warnings.Add("Longest observable event gap exceeded unexplainedGapWarnMs=$($policy.thresholds.unexplainedGapWarnMs).") }
if ($incompleteOperations.Count -gt 0) { $warnings.Add("$($incompleteOperations.Count) tool operation(s) have a start event without a completion event.") }
$summary = [ordered]@{
    generated_at = [DateTimeOffset]::Now.ToString('o')
    turn_id = $TurnId
    conversation_id = $ConversationId
    query_class = if ($queryClasses.Count -gt 0) { $queryClasses[0] } else { 'unknown' }
    event_count = $ordered.Count
    matched_tool_count = $durations.Count
    mutating_tool_count = @($durations | Where-Object { $_.mutating }).Count
    approval_event_count = @($ordered | Where-Object { [string](Get-PropertyValue $_ 'category' '') -eq 'approval' }).Count
    observable_span_ms = if ($null -ne $first -and $null -ne $last) { [math]::Round(($last - $first).TotalMilliseconds) } else { 0 }
    longest_event_gap_ms = [math]::Round($maxGap)
    thresholds = $policy.thresholds
    longest_tools = @($durations | Sort-Object duration_ms -Descending | Select-Object -First 5)
    slow_tools = $slowTools
    incomplete_tool_operations = $incompleteOperations
    automatic_retry_limit = [int]$policy.thresholds.automaticRetries
    warnings = @($warnings)
    model_timing = 'unavailable: hook telemetry cannot observe model request or first-token timestamps'
}
if (-not [string]::IsNullOrWhiteSpace($OutputPath)) {
    $target = if ([System.IO.Path]::IsPathRooted($OutputPath)) { $OutputPath } else { Join-Path $Root $OutputPath }
    Write-Utf8BomFile $target ($summary | ConvertTo-Json -Depth 10)
}
$summary | ConvertTo-Json -Depth 10
