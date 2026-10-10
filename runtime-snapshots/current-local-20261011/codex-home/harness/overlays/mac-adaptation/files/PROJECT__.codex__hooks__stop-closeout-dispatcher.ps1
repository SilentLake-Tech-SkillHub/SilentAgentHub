. "$PSScriptRoot/common.ps1"
$inputObject = Read-HookInput
$root = Resolve-ProjectRoot $inputObject
$configPath = Join-Path $root '.codex/harness/index.json'
$config = $null
if (Test-Path -LiteralPath $configPath) {
    try { $config = Get-Content -LiteralPath $configPath -Raw -Encoding UTF8 | ConvertFrom-Json }
    catch {
        Write-StopBlock "Repair '$configPath' before ending the turn: Harness index is invalid JSON."
        exit 0
    }
}

$conversationId = [string](Get-FirstPropertyValue $inputObject @('conversation_id','conversationId','thread_id','threadId') '')
$sessionId = [string](Get-FirstPropertyValue $inputObject @('session_id','sessionId') '')
$turnId = [string](Get-FirstPropertyValue $inputObject @('turn_id','turnId') '')
$stopHookActive = [bool](Get-PropertyValue $inputObject 'stop_hook_active' $false)
$collaborationMode = Get-HookCollaborationMode $inputObject
$runtimeLog = Join-Path $root '.codex/harness/runtime-events.jsonl'
$memoryScript = Join-Path $PSScriptRoot 'memory-integrity.ps1'
$memory = $null
if (Test-Path -LiteralPath $memoryScript) {
    try {
        $memory = ((& $memoryScript -Root $root -Mode Stop -ConversationId $conversationId -SessionId $sessionId) | Out-String).Trim() | ConvertFrom-Json
        if ([string]::IsNullOrWhiteSpace($turnId) -and [bool]$memory.found) { $turnId = [string]$memory.turnId }
    } catch { }
}
$planDisclosureScript = Join-Path $PSScriptRoot 'plan-disclosure-integrity.ps1'
if (-not (Test-Path -LiteralPath $planDisclosureScript -PathType Leaf)) {
    Write-StopBlock "Restore '$planDisclosureScript' before ending the turn: Plan disclosure integrity module is missing."
    exit 0
}
try {
    $planDisclosure = (((& $planDisclosureScript -Root $root -ConversationId $conversationId -TurnId $turnId -StopHookActive:$stopHookActive) | Out-String).Trim()) | ConvertFrom-Json
    if (-not [bool]$planDisclosure.allowStop) {
        $reason = [string]$planDisclosure.systemMessage
        if ($null -ne $memory -and [bool]$memory.found -and $memory.status -in @('received','working','verifying')) {
            $reason += "`n`n【Agent 内部指令，用户无需操作】请在本次 continuation 内先用正式证据调用 memory-turn-closeout；等待 Plan 审批时记录为 needs_user。Conversation=$($memory.conversationId); Turn=$($memory.turnId)。不要等待第二次 Memory 注入，下一次 Stop 必须直接展示完整 Plan 回复。"
        }
        Write-StopBlock $reason
        exit 0
    }
} catch {
    Write-StopBlock "Repair the Plan disclosure check before ending: $($_.Exception.Message)"
    exit 0
}

# Codex Plan mode is read-only. UserPromptSubmit intentionally skips project
# Memory capture for these turns, so Stop must not create a write continuation.
# Plan disclosure integrity still runs above; only Memory/full-worktree closeout
# is bypassed after that query-bound gate allows Stop.
if ($collaborationMode -eq 'plan') {
    Write-HookOutput @{ continue = $true }
    exit 0
}

if (Test-Path -LiteralPath $memoryScript) {
    try {
        if ($null -eq $memory) { $memory = ((& $memoryScript -Root $root -Mode Stop -ConversationId $conversationId -SessionId $sessionId) | Out-String).Trim() | ConvertFrom-Json }
        if (-not [bool]$memory.passed) {
            Write-StopBlock ('Repair project Memory before ending: ' + (@($memory.errors) -join ', '))
            exit 0
        }
        if ($memory.found -and $memory.status -in @('received','working','verifying')) {
            if (-not $stopHookActive -and [int]$memory.verificationCycle -lt 1) {
                Write-StopBlock "【内部收尾处理中，无需操作】调用 memory-turn-closeout 更新当前轮：Conversation=$($memory.conversationId); Turn=$($memory.turnId)。"
                exit 0
            }
            Write-StopBlock "【内部收尾尚未落账，无需用户操作】更新现有 Memory turn：Conversation=$($memory.conversationId); Turn=$($memory.turnId)。"
            exit 0
        }
    } catch {
        Write-StopBlock "Repair the Memory check before ending: $($_.Exception.Message)"
        exit 0
    }
}

# A globally dirty worktree must not force full integrity scans on a read-only
# follow-up. Only current-turn mutation evidence enables the expensive checks.
$turnMutationKnown = $false
$turnHasMutation = $false
if (-not [string]::IsNullOrWhiteSpace($turnId) -and (Test-Path -LiteralPath $runtimeLog)) {
    foreach ($line in Get-Content -LiteralPath $runtimeLog -Encoding UTF8) {
        if ([string]::IsNullOrWhiteSpace($line)) { continue }
        try {
            $runtimeEvent = $line | ConvertFrom-Json
            if ([string](Get-PropertyValue $runtimeEvent 'turn_id' '') -ne $turnId) { continue }
            $isPostTool = [string](Get-PropertyValue $runtimeEvent 'event' '') -eq 'PostToolUse'
            $isLegacyCompletion = [string](Get-PropertyValue $runtimeEvent 'category' '') -eq 'tool' -and [string](Get-PropertyValue $runtimeEvent 'phase' '') -eq 'complete'
            if (-not $isPostTool -and -not $isLegacyCompletion) { continue }
            $turnMutationKnown = $true
            if ([bool](Get-PropertyValue $runtimeEvent 'mutating' $false)) { $turnHasMutation = $true }
        } catch { }
    }
}
if ($turnMutationKnown -and -not $turnHasMutation) {
    Write-HookOutput @{ continue = $true }
    exit 0
}

$changed = @()
try { $changed = @(& git -C $root status --porcelain 2>$null) } catch { }
if ($changed.Count -eq 0) { exit 0 }

$problems = [System.Collections.Generic.List[string]]::new()
$changedText = $changed -join "`n"
if (Test-SensitiveText $changedText) { $problems.Add('changed paths may contain a secret-bearing or real environment file') }

$required = @('ROUTER.md', 'ARCHITECTURE.md', '流程管理/任务管理.md', '流程管理/验收清单.md', '流程管理/版本控制.md')
if ($null -ne $config -and $config.PSObject.Properties.Name -contains 'requiredCloseoutPaths') {
    $required = @($config.requiredCloseoutPaths)
}
foreach ($relative in $required) {
    if (-not (Test-Path -LiteralPath (Join-Path $root $relative))) { $problems.Add("missing closeout record: $relative") }
}

$planFiles = @(Get-ChildItem -LiteralPath (Join-Path $root '流程管理/执行计划') -Filter 'plans.md' -File -Recurse -ErrorAction SilentlyContinue)
foreach ($plan in $planFiles) {
    $body = Get-Content -LiteralPath $plan.FullName -Raw -Encoding UTF8
    if ($body -match '(?im)^[ \t]{0,3}(?:[-*+][ \t]+)?(?:\*\*|__)?[ \t]*State[ \t]*(?:\*\*|__)?[ \t]*[:：][ \t]*(?:\*\*|__|`)?[ \t]*draft[ \t]*(?:`|\*\*|__)?[ \t]*\r?$') { $problems.Add("draft Plan has not entered user review: $($plan.FullName)") }
}

$layoutScript = Join-Path $PSScriptRoot 'source-layout-integrity.ps1'
if (-not (Test-Path -LiteralPath $layoutScript -PathType Leaf)) {
    $problems.Add('missing Stop integrity module: .codex/hooks/source-layout-integrity.ps1')
} else {
    try {
        $layoutOutput = ((& $layoutScript -Root $root) | Out-String).Trim()
        $layoutResult = $layoutOutput | ConvertFrom-Json
        if (-not [bool]$layoutResult.passed) {
            $layoutErrors = @($layoutResult.errors) -join ', '
            $problems.Add("source layout integrity failed: $layoutErrors")
        }
    } catch {
        $problems.Add("source layout integrity checker failed to run: $($_.Exception.Message)")
    }
}

$controllerScript = Join-Path $PSScriptRoot 'document-controller-integrity.ps1'
if (-not (Test-Path -LiteralPath $controllerScript -PathType Leaf)) {
    $problems.Add('missing Stop integrity module: .codex/hooks/document-controller-integrity.ps1')
} else {
    try {
        $controllerResult = (((& $controllerScript -Root $root) | Out-String).Trim()) | ConvertFrom-Json
        if (-not [bool]$controllerResult.passed) { $problems.Add('document controller integrity failed: ' + (@($controllerResult.errors) -join ', ')) }
    } catch { $problems.Add("document controller integrity checker failed to run: $($_.Exception.Message)") }
}

$lifecycleScript = Join-Path $PSScriptRoot 'lifecycle-state-integrity.ps1'
if (-not (Test-Path -LiteralPath $lifecycleScript -PathType Leaf)) {
    $problems.Add('missing Stop integrity module: .codex/hooks/lifecycle-state-integrity.ps1')
} else {
    try {
        $lifecycleResult = (((& $lifecycleScript -Root $root) | Out-String).Trim()) | ConvertFrom-Json
        if (-not [bool]$lifecycleResult.passed) { $problems.Add('lifecycle state machine integrity failed: ' + (@($lifecycleResult.errors) -join ', ')) }
    } catch { $problems.Add("lifecycle state machine integrity checker failed to run: $($_.Exception.Message)") }
}

$historyArchiveScript = Join-Path $PSScriptRoot 'ledger-history-archiver.ps1'
$historyIntegrityScript = Join-Path $PSScriptRoot 'ledger-history-integrity.ps1'
if (-not (Test-Path -LiteralPath $historyArchiveScript) -or -not (Test-Path -LiteralPath $historyIntegrityScript)) {
    $problems.Add('missing ledger history archive or integrity module')
} else {
    try {
        $historyArchive = (((& $historyArchiveScript -Root $root) | Out-String).Trim()) | ConvertFrom-Json
        if (-not [bool]$historyArchive.passed) { $problems.Add('ledger history archive failed: ' + (@($historyArchive.errors) -join ', ')) }
        $historyIntegrity = (((& $historyIntegrityScript -Root $root) | Out-String).Trim()) | ConvertFrom-Json
        if (-not [bool]$historyIntegrity.passed) { $problems.Add('ledger history integrity failed: ' + (@($historyIntegrity.errors) -join ', ')) }
    } catch { $problems.Add("ledger history closeout failed to run: $($_.Exception.Message)") }
}

if ($problems.Count -gt 0) {
    Write-StopBlock ('Before ending: ' + ($problems -join '; ') + '. Use project-validation, code-review-closeout, and management-record-sync. Do not auto-commit or deploy from this Hook.')
    exit 0
}

Write-HookOutput @{ continue = $true }
