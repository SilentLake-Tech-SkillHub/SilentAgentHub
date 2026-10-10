. "$PSScriptRoot/common.ps1"
$inputObject = Read-HookInput
$text = Get-InputText $inputObject
$root = Resolve-ProjectRoot $inputObject
$tool = Get-NormalizedToolName $inputObject
$mutating = Test-ToolMutation $inputObject
$hookEvent = [string](Get-PropertyValue $inputObject 'hook_event_name' 'PreToolUse')
$approvalType = if ($hookEvent -eq 'PermissionRequest') { Get-ApprovalType $inputObject } else { '' }
Add-Utf8JsonLine (Join-Path $root '.codex/harness/runtime-events.jsonl') ([ordered]@{
    timestamp = [DateTimeOffset]::Now.ToString('o')
    event = $hookEvent
    phase = if ($hookEvent -eq 'PermissionRequest') { 'request' } else { 'start' }
    category = if ($hookEvent -eq 'PermissionRequest') { 'approval' } else { 'tool' }
    name = $tool
    tool = $tool
    session_id = Get-HookSessionId $inputObject
    conversation_id = Get-HookConversationId $inputObject
    turn_id = Get-HookTurnId $inputObject
    operation_id = Get-HookOperationId $inputObject
    query_class = ''
    approval_type = $approvalType
    mutating = $mutating
    cwd = $root
})
$messages = [System.Collections.Generic.List[string]]::new()

if (Test-SensitiveText $text) {
    $messages.Add('Possible secret or sensitive-file operation detected. Do not expose values; use .env.example for names only and verify ignore rules before writing, syncing, or committing.')
}
if (Test-DestructiveText $text) {
    $messages.Add('Potentially destructive, forced, production, or permission-changing operation detected. Confirm exact target, impact, authorization, backup, rollback, and validation before proceeding.')
}
if ($hookEvent -eq 'PermissionRequest' -and $messages.Count -eq 0) {
    $messages.Add("Permission category: $approvalType. Tool access does not approve a Plan or authorize production scope; avoid requesting it again for the same unchanged action batch.")
}

if ($messages.Count -eq 0) { exit 0 }
# Codex currently accepts systemMessage only for PreToolUse and PermissionRequest.
Write-HookOutput @{ systemMessage = ($messages -join ' ') }
