param([string]$SourceRoot = '')
$ErrorActionPreference = 'Stop'
if ([string]::IsNullOrWhiteSpace($SourceRoot)) { $SourceRoot = (Resolve-Path (Join-Path $PSScriptRoot '../../..')).Path }
$runId = Get-Date -Format 'yyyyMMddHHmmssfff'
$root = Join-Path ([System.IO.Path]::GetTempPath()) "Harness-Memory-中文-$runId"
$hooks = Join-Path $root '.codex/hooks'
$harness = Join-Path $root '.codex/harness'
New-Item -ItemType Directory -Path $hooks, $harness -Force | Out-Null
Copy-Item -Path (Join-Path $SourceRoot '.codex/hooks/*') -Destination $hooks -Recurse -Force
Copy-Item -LiteralPath (Join-Path $SourceRoot '.codex/harness/memory-policy.json') -Destination $harness -Force
Copy-Item -LiteralPath (Join-Path $SourceRoot '.codex/harness/memory-policy.schema.json') -Destination $harness -Force
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
    $process.StandardInput.BaseStream.Flush()
    $process.StandardInput.BaseStream.Close()
    $stdout = $process.StandardOutput.ReadToEnd()
    $stderr = $process.StandardError.ReadToEnd()
    $process.WaitForExit()
    if ($process.ExitCode -ne 0 -or -not [string]::IsNullOrWhiteSpace($stderr)) { throw "$ScriptName failed: $stderr" }
    return $stdout.Trim()
}

try {
    $internal = [ordered]@{ session_id = 'desktop-session'; conversation_id = 'desktop-conversation'; turn_id = 'internal-turn'; cwd = $root; hook_event_name = 'UserPromptSubmit'; prompt = "# Overview`n`nGenerate 0 to 3 hyperpersonalized suggestions for this project.`n`n# Response format" }
    $internalOutput = Invoke-Hook 'user-prompt-dispatcher.ps1' $internal | ConvertFrom-Json
    $short = Get-Content -LiteralPath (Join-Path $root 'SHORT_MEMORY.md') -Raw -Encoding UTF8
    if ($short -match 'hyperpersonalized') { throw 'Internal recommendation prompt entered SHORT_MEMORY.' }
    if (-not (Test-Path -LiteralPath (Join-Path $harness 'memory-quarantine.jsonl'))) { throw 'Internal recommendation prompt was not quarantined.' }

    $prompt = '请修复 Memory Hook：中文路径必须完整，状态要从 received 正确关闭并迁移。'
    $real = [ordered]@{ session_id = 'desktop-session'; conversation_id = 'desktop-conversation'; turn_id = 'real-turn'; cwd = $root; hook_event_name = 'UserPromptSubmit'; prompt = $prompt }
    $captureOutput = Invoke-Hook 'user-prompt-dispatcher.ps1' $real | ConvertFrom-Json
    $duplicateOutput = Invoke-Hook 'user-prompt-dispatcher.ps1' $real | ConvertFrom-Json
    if (-not [bool]$duplicateOutput.continue) { throw 'Duplicate user turn blocked hook dispatch.' }
    $duplicateShort = Get-Content -LiteralPath (Join-Path $root 'SHORT_MEMORY.md') -Raw -Encoding UTF8
    if ([regex]::Matches($duplicateShort, '"turn_id":"real-turn"').Count -ne 1) { throw 'Duplicate dispatch recaptured the same user turn.' }
    $short = Get-Content -LiteralPath (Join-Path $root 'SHORT_MEMORY.md') -Raw -Encoding UTF8
    if ($short -notmatch [regex]::Escape($prompt)) { throw 'UTF-8 user prompt was not captured exactly.' }
    if ($short -match '椤圭洰|锟|�') { throw 'Mojibake detected after Desktop stdin capture.' }

    $stop = [ordered]@{ session_id = 'desktop-session'; conversation_id = 'desktop-conversation'; cwd = $root; hook_event_name = 'Stop'; stop_hook_active = $false }
    $stopOutput = Invoke-Hook 'stop-closeout-dispatcher.ps1' $stop | ConvertFrom-Json
    if ($stopOutput.decision -ne 'block' -or [string]::IsNullOrWhiteSpace([string]$stopOutput.reason)) { throw 'Stop did not use decision:block continuation contract.' }
    if ([string]$stopOutput.reason -match 'COMPLETE PLAN|awaiting user review') { throw 'Memory-only Stop was hijacked by an unrelated Plan.' }
    if ([string]$stopOutput.reason -notmatch '内部收尾' -or ([string]$stopOutput.reason).Length -gt 240) { throw 'Memory fallback was not reduced to a short user-safe card.' }

    $needsUserRaw = & (Join-Path $hooks 'memory-runtime.ps1') -Event Closeout -Root $root -ConversationId 'desktop-conversation' -TurnId 'real-turn' -Status needs_user -Result '等待用户完成安全复核。' -Evidence @('UTF-8 exact prompt match','Stop decision:block') -NextAction '用户复核。'
    $needsUser = (($needsUserRaw | Out-String).Trim()) | ConvertFrom-Json
    if ($needsUser.status -ne 'needs_user' -or [bool]$needsUser.migrated) { throw 'needs_user closeout returned the wrong state.' }
    $short = Get-Content -LiteralPath (Join-Path $root 'SHORT_MEMORY.md') -Raw -Encoding UTF8
    $index = Get-Content -LiteralPath (Join-Path $harness 'memory-index.json') -Raw -Encoding UTF8 | ConvertFrom-Json
    if ($short -notmatch '"status":"needs_user"' -or $short -notmatch 'status=needs_user') { throw 'needs_user did not refresh SHORT record and active summary.' }
    if ($index.conversations.Count -ne 1 -or $index.conversations[0].state -ne 'needs_user' -or $index.conversations[0].location -ne 'short') { throw 'needs_user did not update the Memory index.' }
    $integrity = & (Join-Path $hooks 'memory-runtime.ps1') -Event Validate -Root $root | ConvertFrom-Json
    if (-not $integrity.passed) { throw "needs_user integrity failed: $($integrity.errors -join ',')" }
    & git -C $root init --quiet
    & git -C $root config user.email 'harness-e2e@example.invalid'
    & git -C $root config user.name 'Harness E2E'
    & git -C $root add -A
    & git -C $root commit --quiet -m 'fixture baseline'
    if ($LASTEXITCODE -ne 0) { throw 'Could not create the dirty-worktree Stop fixture baseline.' }
    $readOnlyTool = [ordered]@{ session_id = 'desktop-session'; conversation_id = 'desktop-conversation'; turn_id = 'real-turn'; cwd = $root; hook_event_name = 'PostToolUse'; toolCall = @{ name = 'functions.exec_command' }; tool_input = @{ cmd = 'Get-Content README.md' } }
    $null = Invoke-Hook 'posttool-change-capture.ps1' $readOnlyTool
    if (@(& git -C $root status --porcelain).Count -eq 0) { throw 'Read-only Stop fixture did not become globally dirty.' }
    $proactiveStopRaw = Invoke-Hook 'stop-closeout-dispatcher.ps1' ([ordered]@{ session_id = 'desktop-session'; conversation_id = 'desktop-conversation'; turn_id = 'real-turn'; cwd = $root; hook_event_name = 'Stop'; stop_hook_active = $false })
    if (-not [string]::IsNullOrWhiteSpace($proactiveStopRaw)) {
        $proactiveStop = $proactiveStopRaw | ConvertFrom-Json
        if ($proactiveStop.decision -eq 'block') { throw 'Proactively closed needs_user turn still produced a Stop card.' }
    }

    $closeoutRaw = & (Join-Path $hooks 'memory-runtime.ps1') -Event Closeout -Root $root -ConversationId 'desktop-conversation' -TurnId 'real-turn' -Status completed -Result 'Memory Desktop 输入链验收通过。' -Evidence @('UTF-8 exact prompt match','Stop decision:block','SHORT to LONG transaction') -NextAction '无。'
    $closeout = (($closeoutRaw | Out-String).Trim()) | ConvertFrom-Json
    if (-not [bool]$closeout.migrated) { throw 'Terminal conversation did not migrate to LONG_MEMORY.' }
    $short = Get-Content -LiteralPath (Join-Path $root 'SHORT_MEMORY.md') -Raw -Encoding UTF8
    $long = Get-Content -LiteralPath (Join-Path $root 'LONG_MEMORY.md') -Raw -Encoding UTF8
    if ($short -match 'desktop-conversation') { throw 'Closed conversation remains in SHORT_MEMORY.' }
    if ($long -notmatch 'desktop-conversation' -or $long -notmatch [regex]::Escape($prompt)) { throw 'Closed conversation is missing from LONG_MEMORY.' }

    $toolEvent = [ordered]@{ session_id = 'desktop-session'; turn_id = 'tool-turn'; cwd = $root; hook_event_name = 'PostToolUse'; toolCall = @{ name = 'functions.exec_command' } }
    $null = Invoke-Hook 'posttool-change-capture.ps1' $toolEvent
    $runtime = @(Get-Content -LiteralPath (Join-Path $harness 'runtime-events.jsonl') -Encoding UTF8 |
        Where-Object { -not [string]::IsNullOrWhiteSpace($_) } |
        ForEach-Object { $_ | ConvertFrom-Json })
    $toolRuntime = @($runtime | Where-Object { $_.event -eq 'PostToolUse' -and $_.turn_id -eq 'tool-turn' } | Select-Object -Last 1)
    if ($toolRuntime.Count -ne 1 -or [string]$toolRuntime[0].tool -ne 'Bash' -or [string]$toolRuntime[0].cwd -ne $root) { throw 'Tool-name mapping or UTF-8 cwd capture failed.' }

    [ordered]@{
        passed = $true
        fixtureRoot = $root
        internalPromptQuarantined = $true
        utf8PromptCaptured = $true
        duplicateTurnIsIdempotent = $true
        stopDecisionBlock = $true
        readonlyDirtyStopAllowed = $true
        needsUserIndexSynced = $true
        shortToLongMigrated = $true
        toolNameMapped = $true
        transaction = [string]$closeout.transaction
    } | ConvertTo-Json -Depth 6
} catch {
    [ordered]@{ passed = $false; fixtureRoot = $root; error = $_.Exception.Message } | ConvertTo-Json -Depth 6
    exit 1
}
