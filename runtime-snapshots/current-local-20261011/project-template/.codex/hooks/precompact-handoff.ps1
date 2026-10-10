. "$PSScriptRoot/common.ps1"
$inputObject = Read-HookInput
$root = Resolve-ProjectRoot $inputObject
$indexPath = Join-Path $root '.codex/harness/index.json'
$index = if (Test-Path -LiteralPath $indexPath) { Get-Content -LiteralPath $indexPath -Raw -Encoding UTF8 | ConvertFrom-Json } else { $null }
$handoffRelative = [string](Get-PropertyValue $index 'handoffRecord' 'process-management/context-handoff.md')
$planRootRelative = [string](Get-PropertyValue $index 'planRoot' 'process-management/execution-plans')
$handoff = Join-Path $root $handoffRelative
$planRoot = Join-Path $root $planRootRelative
$conversationId = [string](Get-FirstPropertyValue $inputObject @('conversation_id','conversationId','thread_id','threadId') '')
$sessionId = [string](Get-FirstPropertyValue $inputObject @('session_id','sessionId') '')
try {
    $compact = (((& (Join-Path $PSScriptRoot 'memory-runtime.ps1') -Event Compact -Root $root -ConversationId $conversationId -SessionId $sessionId) | Out-String).Trim()) | ConvertFrom-Json
    if (-not [bool]$compact.passed) { throw 'Memory compact returned passed=false.' }
} catch {
    Write-HookOutput @{ continue = $false; stopReason = "Project Memory compaction failed: $($_.Exception.Message)" }
    exit 0
}
$message = "Before compaction, update the active plans.md Progress with current objective, completed work, changed absolute paths, validation results, blockers, decisions, and next action."
$message += " SHORT_MEMORY active summary was refreshed through user-memory-recorder for conversation '$conversationId'. Update Handoff with the same conversation/task/Plan IDs and do not copy secrets or duplicate full ledgers."
if (-not (Test-Path -LiteralPath $handoff)) { $message += " Handoff record is missing at '$handoff'." }
if (-not (Test-Path -LiteralPath $planRoot)) { $message += " No V5 Plan root exists at '$planRoot'; use project-initialization if this project adopts the V5 harness." }
Write-HookOutput @{
    continue = $true
    hookSpecificOutput = @{
        hookEventName = 'PreCompact'
        additionalContext = $message
    }
}
