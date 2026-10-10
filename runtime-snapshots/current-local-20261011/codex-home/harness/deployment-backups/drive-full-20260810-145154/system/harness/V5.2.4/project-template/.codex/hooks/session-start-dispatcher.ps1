. "$PSScriptRoot/common.ps1"
$inputObject = Read-HookInput
$root = Resolve-ProjectRoot $inputObject
$router = Join-Path $root 'ROUTER.md'
$index = Join-Path $root '.codex/harness/index.json'

$context = if (-not (Test-Path -LiteralPath $router)) {
    "Project Router is missing at '$router'. Before substantial work, use project-initialization and create only the required governance areas. The system-level AGENTS.md belongs to the Codex root, not this project."
} else {
    "Project root: '$root'. Read '$router' first, then load only the active Plan, applicable module rule, open problems/risks, acceptance criteria, and required Skills."
}
if (Test-Path -LiteralPath $index) { $context += " Harness path configuration: '$index'." }
$conversationId = [string](Get-FirstPropertyValue $inputObject @('conversation_id','conversationId','thread_id','threadId') '')
$sessionId = [string](Get-FirstPropertyValue $inputObject @('session_id','sessionId') '')
$memoryScript = Join-Path $PSScriptRoot 'memory-integrity.ps1'
if (Test-Path -LiteralPath $memoryScript) {
    try {
        & (Join-Path $PSScriptRoot 'runtime-event-repair.ps1') -Root $root | Out-Null
        & (Join-Path $PSScriptRoot 'memory-runtime.ps1') -Event Repair -Root $root | Out-Null
        $memory = ((& $memoryScript -Root $root -Mode Read -ConversationId $conversationId -SessionId $sessionId) | Out-String).Trim() | ConvertFrom-Json
        if ($memory.found) { $context += " Active project SHORT_MEMORY for this conversation follows; LONG_MEMORY was not read:`n$($memory.context)" }
        else { $context += ' No matching active SHORT_MEMORY was found. Do not read LONG_MEMORY unless the request explicitly traces history or long-memory-retriever confirms a Short miss.' }
    } catch { $context += " Project Memory could not be loaded: $($_.Exception.Message)." }
}

Write-HookOutput @{
    continue = $true
    hookSpecificOutput = @{
        hookEventName = 'SessionStart'
        additionalContext = $context
    }
}
