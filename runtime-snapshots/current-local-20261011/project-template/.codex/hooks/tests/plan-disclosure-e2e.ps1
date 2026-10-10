param([string]$SourceRoot = '')
$ErrorActionPreference = 'Stop'
if ([string]::IsNullOrWhiteSpace($SourceRoot)) { $SourceRoot = (Resolve-Path (Join-Path $PSScriptRoot '../../..')).Path }
$runId = Get-Date -Format 'yyyyMMddHHmmssfff'
$root = Join-Path ([System.IO.Path]::GetTempPath()) "Harness-PlanQuery-中文-$runId"
$hooks = Join-Path $root '.codex/hooks'
$harness = Join-Path $root '.codex/harness'
$planRoot = Join-Path $root '流程管理/执行计划'
New-Item -ItemType Directory -Path $hooks, $harness, $planRoot -Force | Out-Null
Copy-Item -Path (Join-Path $SourceRoot '.codex/hooks/*') -Destination $hooks -Recurse -Force
foreach ($name in @('memory-policy.json','memory-policy.schema.json','plan-disclosure-state.json','plan-disclosure-state.schema.json','index.json')) {
    Copy-Item -LiteralPath (Join-Path $SourceRoot ".codex/harness/$name") -Destination $harness -Force
}
$utf8Bom = New-Object System.Text.UTF8Encoding($true)
[System.IO.File]::WriteAllText((Join-Path $root 'MEMORY.md'), "# MEMORY Rules`r`n", $utf8Bom)
[System.IO.File]::WriteAllText((Join-Path $root 'SHORT_MEMORY.md'), "# SHORT MEMORY`r`n`r`n## Active Conversations`r`n", $utf8Bom)
[System.IO.File]::WriteAllText((Join-Path $root 'LONG_MEMORY.md'), "# LONG MEMORY`r`n`r`n## Closed Conversations`r`n", $utf8Bom)

function Invoke-Hook([string]$ScriptName, [object]$InputObject) {
    $psi = New-Object System.Diagnostics.ProcessStartInfo
    # 跨平台：复用当前 PowerShell 宿主，而不是写死 powershell.exe（macOS/Linux 上不存在）
    $isWin = ($null -eq $IsWindows) -or $IsWindows
    $psi.FileName = [System.Diagnostics.Process]::GetCurrentProcess().MainModule.FileName
    $policyArg = if ($isWin) { '-ExecutionPolicy Bypass ' } else { '' }
    $psi.Arguments = "-NoProfile $policyArg-File `"$(Join-Path $hooks $ScriptName)`""
    $psi.UseShellExecute = $false
    $psi.RedirectStandardInput = $true
    $psi.RedirectStandardOutput = $true
    $psi.RedirectStandardError = $true
    $psi.StandardOutputEncoding = New-Object System.Text.UTF8Encoding($false)
    $psi.StandardErrorEncoding = New-Object System.Text.UTF8Encoding($false)
    $process = New-Object System.Diagnostics.Process
    $process.StartInfo = $psi
    [void]$process.Start()
    $json = $InputObject | ConvertTo-Json -Depth 20 -Compress
    $bytes = (New-Object System.Text.UTF8Encoding($false)).GetBytes($json)
    $process.StandardInput.BaseStream.Write($bytes, 0, $bytes.Length)
    $process.StandardInput.BaseStream.Close()
    $stdout = $process.StandardOutput.ReadToEnd()
    $stderr = $process.StandardError.ReadToEnd()
    $process.WaitForExit()
    if ($process.ExitCode -ne 0 -or -not [string]::IsNullOrWhiteSpace($stderr)) { throw "$ScriptName failed: $stderr" }
    $stdout.Trim()
}

function Capture-Turn([string]$TurnId, [string]$Prompt) {
    $inputObject = [ordered]@{ session_id = 'desktop-session'; conversation_id = 'desktop-conversation'; turn_id = $TurnId; cwd = $root; hook_event_name = 'UserPromptSubmit'; prompt = $Prompt }
    $output = Invoke-Hook 'user-prompt-dispatcher.ps1' $inputObject | ConvertFrom-Json
    if (-not [bool]$output.continue) { throw "Prompt capture failed for $TurnId" }
}

function Read-JsonOutput([object]$Output) {
    (($Output | Out-String).Trim()) | ConvertFrom-Json
}

try {
    $planA = Join-Path $planRoot 'T-A_PlanA/plans.md'
    $planB = Join-Path $planRoot 'T-B_PlanB/plans.md'
    New-Item -ItemType Directory -Path (Split-Path -Parent $planA), (Split-Path -Parent $planB) -Force | Out-Null
    [System.IO.File]::WriteAllText($planA, "# PLAN A`r`n`r`n## State`r`n`r`nState: awaiting_review`r`n", $utf8Bom)
    [System.IO.File]::WriteAllText($planB, "# PLAN B`r`n`r`n## State`r`n`r`nState: awaiting_review`r`n", $utf8Bom)

    # Stop 的 draft 门禁必须同时接受 CRLF 和列表项格式，不得被 `- State: draft` 绕过。
    $draftPlan = Join-Path $planRoot 'T-DRAFT_DraftGate/plans.md'
    New-Item -ItemType Directory -Path (Split-Path -Parent $draftPlan) -Force | Out-Null
    [System.IO.File]::WriteAllText($draftPlan, "# DRAFT`r`n`r`n## State`r`n`r`n- State: draft`r`n", $utf8Bom)
    & (Join-Path $hooks 'memory-runtime.ps1') -Event Capture -Root $root -Prompt '验证 draft Stop 门禁。' `
        -ConversationId 'draft-conversation' -SessionId 'desktop-session' -TurnId 'draft-turn' | Out-Null
    & (Join-Path $hooks 'memory-runtime.ps1') -Event Closeout -Root $root -ConversationId 'draft-conversation' `
        -TurnId 'draft-turn' -Status needs_user -Result '待检查 draft 门禁。' -NextAction '运行 Stop。' | Out-Null
    & git -C $root init --quiet
    $draftStopInput = [ordered]@{ session_id = 'desktop-session'; conversation_id = 'draft-conversation'; turn_id = 'draft-turn'; cwd = $root; hook_event_name = 'Stop'; stop_hook_active = $false }
    $draftStop = Invoke-Hook 'stop-closeout-dispatcher.ps1' $draftStopInput | ConvertFrom-Json
    if ($draftStop.decision -ne 'block' -or [string]$draftStop.reason -notmatch 'draft Plan') { throw 'CRLF/list draft Plan bypassed the Stop gate.' }
    Remove-Item -LiteralPath (Join-Path $root '.git') -Recurse -Force
    Remove-Item -LiteralPath (Split-Path -Parent $draftPlan) -Recurse -Force

    Capture-Turn 'turn-create' '请创建并完整展示 PLAN A。'
    $register = Read-JsonOutput (& (Join-Path $hooks 'plan-disclosure-runtime.ps1') -Event Register -Root $root -ConversationId 'desktop-conversation' -TurnId 'turn-create' -PlanPath '流程管理/执行计划/T-A_PlanA/plans.md' -QueryRoute plan_create_or_update)
    if (-not [bool]$register.passed -or [string]$register.record.planPath -notmatch 'T-A_PlanA') { throw 'Current Query was not bound to PLAN A.' }

    $stopInput = [ordered]@{ session_id = 'desktop-session'; conversation_id = 'desktop-conversation'; turn_id = 'turn-create'; cwd = $root; hook_event_name = 'Stop'; stop_hook_active = $false }
    $firstStop = Invoke-Hook 'stop-closeout-dispatcher.ps1' $stopInput | ConvertFrom-Json
    if ($firstStop.decision -ne 'block') { throw 'First Plan Stop did not block.' }
    if ([string]$firstStop.reason -notmatch '# PLAN A' -or [string]$firstStop.reason -match '# PLAN B') { throw 'Stop did not disclose only the Query-bound Plan.' }
    if ([string]$firstStop.reason -notmatch '本次 continuation' -or [string]$firstStop.reason -notmatch 'memory-turn-closeout') { throw 'Plan and Memory closeout were not aggregated into one continuation.' }

    $needsUser = Read-JsonOutput (& (Join-Path $hooks 'memory-runtime.ps1') -Event Closeout -Root $root -ConversationId 'desktop-conversation' -TurnId 'turn-create' -Status needs_user -Result '等待 Plan 审批。' -Evidence @('PLAN A fully disclosed') -NextAction '用户审批。')
    if ([string]$needsUser.status -ne 'needs_user') { throw 'Plan turn Memory did not close to needs_user.' }
    $secondStopInput = [ordered]@{ session_id = 'desktop-session'; conversation_id = 'desktop-conversation'; turn_id = 'turn-create'; cwd = $root; hook_event_name = 'Stop'; stop_hook_active = $true }
    $secondStopRaw = Invoke-Hook 'stop-closeout-dispatcher.ps1' $secondStopInput
    if (-not [string]::IsNullOrWhiteSpace($secondStopRaw)) {
        $secondStop = $secondStopRaw | ConvertFrom-Json
        if ($secondStop.decision -eq 'block') { throw "Second Stop blocked the final Plan response: $($secondStop.reason)" }
    }
    $readReceipt = Read-JsonOutput (& (Join-Path $hooks 'plan-disclosure-runtime.ps1') -Event Read -Root $root -ConversationId 'desktop-conversation' -TurnId 'turn-create')
    if ([string]$readReceipt.record.state -ne 'disclosed') { throw 'Disclosure receipt was not persisted.' }

    Capture-Turn 'turn-followup' 'hooks 和 skills 上传了吗？'
    $followup = Read-JsonOutput (& (Join-Path $hooks 'plan-disclosure-integrity.ps1') -Root $root -ConversationId 'desktop-conversation' -TurnId 'turn-followup')
    if (-not [bool]$followup.allowStop -or [bool]$followup.requiresDisclosure) { throw 'Unrelated follow-up was hijacked by an awaiting Plan.' }

    Capture-Turn 'turn-approval' '批准 PLAN A。'
    $approval = Read-JsonOutput (& (Join-Path $hooks 'plan-disclosure-integrity.ps1') -Root $root -ConversationId 'desktop-conversation' -TurnId 'turn-approval')
    if (-not [bool]$approval.allowStop -or [bool]$approval.requiresDisclosure) { throw 'Approval Query incorrectly triggered redisclosure.' }

    Capture-Turn 'turn-update' '修改 PLAN A 后重新展示。'
    [System.IO.File]::AppendAllText($planA, "`r`nUpdate: changed scope.`r`n", $utf8Bom)
    $updateRegister = Read-JsonOutput (& (Join-Path $hooks 'plan-disclosure-runtime.ps1') -Event Register -Root $root -ConversationId 'desktop-conversation' -TurnId 'turn-update' -PlanPath '流程管理/执行计划/T-A_PlanA/plans.md' -QueryRoute plan_create_or_update)
    $updateCheck = Read-JsonOutput (& (Join-Path $hooks 'plan-disclosure-integrity.ps1') -Root $root -ConversationId 'desktop-conversation' -TurnId 'turn-update')
    if (-not [bool]$updateRegister.passed -or [bool]$updateCheck.allowStop -or [string]$updateCheck.planHash -eq [string]$register.record.planHash) { throw 'Changed Plan hash did not trigger one new disclosure.' }

    $conflict = Read-JsonOutput (& (Join-Path $hooks 'plan-disclosure-runtime.ps1') -Event Register -Root $root -ConversationId 'desktop-conversation' -TurnId 'turn-update' -PlanPath '流程管理/执行计划/T-B_PlanB/plans.md' -QueryRoute plan_create_or_update)
    if ([bool]$conflict.passed -or @($conflict.errors) -notmatch 'multiple-plan-bindings') { throw 'Multiple Plans were allowed for one Query.' }

    Capture-Turn 'turn-redisclose' '请把 PLAN A 完整再发一遍。'
    $redisclose = Read-JsonOutput (& (Join-Path $hooks 'plan-disclosure-runtime.ps1') -Event Register -Root $root -ConversationId 'desktop-conversation' -TurnId 'turn-redisclose' -PlanPath '流程管理/执行计划/T-A_PlanA/plans.md' -QueryRoute plan_redisclose)
    if (-not [bool]$redisclose.passed -or [string]$redisclose.record.queryRoute -ne 'plan_redisclose') { throw 'Explicit redisclosure was not registered.' }

    $validation = Read-JsonOutput (& (Join-Path $hooks 'plan-disclosure-runtime.ps1') -Event Validate -Root $root)
    if (-not [bool]$validation.passed) { throw "Disclosure state validation failed: $($validation.errors -join ',')" }
    $stateText = Get-Content -LiteralPath (Join-Path $harness 'plan-disclosure-state.json') -Raw -Encoding UTF8
    if ($stateText -match 'hooks 和 skills|请创建并完整展示|# PLAN A') { throw 'Disclosure state leaked Prompt or Plan body.' };

    $missingIds = Read-JsonOutput (& (Join-Path $hooks 'plan-disclosure-integrity.ps1') -Root $root)
    if (-not [bool]$missingIds.allowStop -or [bool]$missingIds.requiresDisclosure) { throw 'Missing current IDs triggered a global Plan scan.' }

    Capture-Turn 'turn-outside' '尝试绑定越界 Plan。'
    $outside = Read-JsonOutput (& (Join-Path $hooks 'plan-disclosure-runtime.ps1') -Event Register -Root $root -ConversationId 'desktop-conversation' -TurnId 'turn-outside' -PlanPath '../outside/plans.md' -QueryRoute plan_create_or_update)
    if ([bool]$outside.passed -or @($outside.errors) -notmatch 'outside-root') { throw 'Out-of-root Plan path was not rejected.' }

    Capture-Turn 'turn-hash' '绑定后修改 Plan。'
    $hashRegister = Read-JsonOutput (& (Join-Path $hooks 'plan-disclosure-runtime.ps1') -Event Register -Root $root -ConversationId 'desktop-conversation' -TurnId 'turn-hash' -PlanPath '流程管理/执行计划/T-B_PlanB/plans.md' -QueryRoute plan_create_or_update)
    [System.IO.File]::AppendAllText($planB, "`r`nChanged after binding.`r`n", $utf8Bom)
    $hashCheck = Read-JsonOutput (& (Join-Path $hooks 'plan-disclosure-integrity.ps1') -Root $root -ConversationId 'desktop-conversation' -TurnId 'turn-hash')
    if (-not [bool]$hashRegister.passed -or [bool]$hashCheck.allowStop -or [string]$hashCheck.systemMessage -notmatch 'Re-register') { throw 'Changed Plan hash was not blocked with a re-register instruction.' }

    $cleanState = Get-Content -LiteralPath (Join-Path $harness 'plan-disclosure-state.json') -Raw -Encoding UTF8
    [System.IO.File]::WriteAllText((Join-Path $harness 'plan-disclosure-state.json'), '{"version":"broken","records":[]}', $utf8Bom)
    $corrupt = Read-JsonOutput (& (Join-Path $hooks 'plan-disclosure-integrity.ps1') -Root $root -ConversationId 'desktop-conversation' -TurnId 'turn-followup')
    if ([bool]$corrupt.allowStop -or [string]$corrupt.systemMessage -match '# PLAN') { throw 'Corrupt disclosure state did not fail with a short non-Plan error.' }
    [System.IO.File]::WriteAllText((Join-Path $harness 'plan-disclosure-state.json'), $cleanState, $utf8Bom)

    Write-Output '{"passed":true,"draftGateCrlfList":true,"queryBoundPlanOnly":true,"planAndMemoryAggregated":true,"finalPlanResponseAllowed":true,"unrelatedQueryAllowed":true,"approvalQueryAllowed":true,"changedHashRedisclosed":true,"multiplePlanBindingRejected":true,"explicitRedisclosureSupported":true,"disclosureStateValidated":true,"missingIdsIgnored":true,"outsidePathRejected":true,"hashMismatchBlocked":true,"corruptStateShortError":true}'
} catch {
    $failure = [ordered]@{ passed = $false; fixtureRoot = $root; error = $_.Exception.Message }
    $failure | ConvertTo-Json -Depth 6
    exit 1
}
