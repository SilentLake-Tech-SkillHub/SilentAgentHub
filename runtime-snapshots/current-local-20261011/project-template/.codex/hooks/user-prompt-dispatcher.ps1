. "$PSScriptRoot/common.ps1"
$inputObject = Read-HookInput
$text = Get-InputText $inputObject
$root = Resolve-ProjectRoot $inputObject
$prompt = [string](Get-FirstPropertyValue $inputObject @('prompt','user_prompt','userPrompt','message') '')
$conversationId = [string](Get-FirstPropertyValue $inputObject @('conversation_id','conversationId','thread_id','threadId') '')
$sessionId = [string](Get-FirstPropertyValue $inputObject @('session_id','sessionId') '')
$turnId = [string](Get-FirstPropertyValue $inputObject @('turn_id','turnId') '')
$queryClass = Get-QueryRouteCandidate $prompt
$collaborationMode = Get-HookCollaborationMode $inputObject
$memoryResult = $null
if ($collaborationMode -ne 'plan' -and -not [string]::IsNullOrWhiteSpace($prompt) -and (Test-Path -LiteralPath (Join-Path $root '.codex/harness/memory-policy.json'))) {
    try { $memoryResult = (& (Join-Path $PSScriptRoot 'memory-runtime.ps1') -Event Capture -Root $root -Prompt $prompt -ConversationId $conversationId -SessionId $sessionId -TurnId $turnId | Out-String).Trim() | ConvertFrom-Json }
    catch { Write-HookOutput @{ continue = $false; stopReason = 'Project Memory capture failed.'; systemMessage = "Repair project-level SHORT_MEMORY capture before proceeding: $($_.Exception.Message)" }; exit 0 }
}
$message = if ($queryClass -eq 'plan_review') {
    'This Query is an approval/review candidate for an existing Plan. Do not create or register a new Plan disclosure. Read the explicitly named active Plan, record the approval, and execute only within its approved scope.'
} elseif ($queryClass -eq 'status_or_readonly') {
    'This Query is a status/read-only follow-up candidate. Do not create a Plan merely because the text mentions Plan, Hook, Skill, deployment, or another complex object. Read the minimum active evidence and answer directly unless the user actually requests a material change.'
} elseif ($queryClass -eq 'complex_candidate') {
    'This request may be complex. First determine the current lifecycle stage and use requirement-clarification. Complete requirements review and technical review before registering a construction Plan. A scoped design or Demo Plan is allowed only after clarification when the user explicitly chooses that work. A bounded local repair may be plan_required:false with documented scope and validation. Obtain user review for any required Plan before engineering; action intent does not bypass Plan review.'
} else {
    'Confirm the user-visible result, scope, acceptance evidence, and routed write target before editing. Use the smallest validation profile that matches the actual change.'
}
if ($collaborationMode -eq 'plan') {
    $message += ' Codex Plan collaboration mode is active. Preserve its read-only contract: project Memory capture and closeout are intentionally skipped for this turn, and Stop must not request a Memory write continuation.'
}
if ($null -ne $memoryResult) {
    if ([bool](Get-PropertyValue $memoryResult 'captured' $false)) {
        $message += " Project Memory captured conversation '$($memoryResult.conversationId)', turn '$($memoryResult.turnId)' after redaction. If this exact Query creates or materially changes a Plan, plan-orchestrator/doc-plan must register that Plan against these IDs through plan-disclosure-runtime before the final response; approval, status, follow-up, and unrelated Queries must not register a disclosure."
    }
    elseif ([bool](Get-PropertyValue $memoryResult 'quarantined' $false)) { $message += ' An internal/system prompt was quarantined and was not written to SHORT_MEMORY.' }
    elseif ([string](Get-PropertyValue $memoryResult 'reason' '') -eq 'duplicate-turn') { $message += ' The current user turn was already captured; keep its existing Memory record and do not capture it again.' }
}
Write-HookOutput @{
    continue = $true
    hookSpecificOutput = @{
        hookEventName = 'UserPromptSubmit'
        additionalContext = $message
    }
}
