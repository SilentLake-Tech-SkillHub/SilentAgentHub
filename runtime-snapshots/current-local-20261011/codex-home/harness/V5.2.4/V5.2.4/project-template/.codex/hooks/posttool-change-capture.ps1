. "$PSScriptRoot/common.ps1"
$inputObject = Read-HookInput
$root = Resolve-ProjectRoot $inputObject
$runtimeDir = Join-Path $root '.codex/harness'
New-Item -ItemType Directory -Path $runtimeDir -Force | Out-Null
$logPath = Join-Path $runtimeDir 'runtime-events.jsonl'

$tool = Get-NormalizedToolName $inputObject
$event = [ordered]@{
    timestamp = [DateTimeOffset]::Now.ToString('o')
    event = [string](Get-PropertyValue $inputObject 'hook_event_name' 'PostToolUse')
    phase = 'complete'
    category = 'tool'
    name = $tool
    tool = $tool
    session_id = Get-HookSessionId $inputObject
    conversation_id = Get-HookConversationId $inputObject
    turn_id = Get-HookTurnId $inputObject
    operation_id = Get-HookOperationId $inputObject
    query_class = ''
    approval_type = ''
    mutating = Test-ToolMutation $inputObject
    cwd = [string](Get-PropertyValue $inputObject 'cwd' $root)
}
Add-Utf8JsonLine $logPath $event

Write-HookOutput @{
    continue = $true
}
