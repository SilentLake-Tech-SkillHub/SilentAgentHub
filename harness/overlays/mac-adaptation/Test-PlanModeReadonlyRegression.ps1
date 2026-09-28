#!/usr/bin/env pwsh
param(
    [string]$ProjectRoot = (Join-Path $HOME 'Documents/Codex/Agent-Harness-V5.2.5')
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$runId = [Guid]::NewGuid().ToString('N').Substring(0, 10)
$root = Join-Path ([System.IO.Path]::GetTempPath()) "Harness-PlanMode-$runId"
$utf8NoBom = [System.Text.UTF8Encoding]::new($false)

function Invoke-Hook([string]$Name, [hashtable]$InputObject) {
    $json = $InputObject | ConvertTo-Json -Depth 20 -Compress
    $inputPath = Join-Path $root 'hook-input.json'
    [System.IO.File]::WriteAllText($inputPath, $json, $utf8NoBom)
    $outputPath = Join-Path $root 'hook-output.json'
    $errorPath = Join-Path $root 'hook-error.txt'
    $proc = Start-Process -FilePath (Get-Process -Id $PID).Path -ArgumentList @('-NoProfile','-File',(Join-Path $root ".codex/hooks/$Name")) `
        -RedirectStandardInput $inputPath -RedirectStandardOutput $outputPath -RedirectStandardError $errorPath -PassThru -Wait
    if ($proc.ExitCode -ne 0) { throw "Hook $Name failed: $(Get-Content -LiteralPath $errorPath -Raw -ErrorAction SilentlyContinue)" }
    return (Get-Content -LiteralPath $outputPath -Raw -Encoding UTF8).Trim()
}

function Write-Transcript([string]$Path, [string]$TurnId, [string]$Mode) {
    $rows = [System.Collections.Generic.List[object]]::new()
    $rows.Add(
        [ordered]@{ timestamp = [DateTime]::UtcNow.ToString('o'); type = 'event_msg'; payload = [ordered]@{ type = 'task_started'; turn_id = $TurnId; collaboration_mode_kind = $Mode } }
    )
    $rows.Add(
        [ordered]@{ timestamp = [DateTime]::UtcNow.ToString('o'); type = 'turn_context'; payload = [ordered]@{ turn_id = $TurnId; collaboration_mode = [ordered]@{ mode = $Mode } } }
    )
    # Put the mode markers outside the last-500-line window. This proves the
    # runtime scans the current turn across a long transcript.
    foreach ($i in 1..600) {
        $rows.Add([ordered]@{ timestamp = [DateTime]::UtcNow.ToString('o'); type = 'event_msg'; payload = [ordered]@{ type = 'filler'; turn_id = "other-turn-$i" } })
    }
    [System.IO.File]::WriteAllLines($Path, @($rows | ForEach-Object { $_ | ConvertTo-Json -Depth 10 -Compress }), $utf8NoBom)
}

try {
    New-Item -ItemType Directory -Path $root -Force | Out-Null
    Copy-Item -LiteralPath (Join-Path $ProjectRoot '.codex') -Destination (Join-Path $root '.codex') -Recurse
    $sourceShort = Join-Path $ProjectRoot 'SHORT_MEMORY.md'
    $sourceLong = Join-Path $ProjectRoot 'LONG_MEMORY.md'
    if (Test-Path -LiteralPath $sourceShort -PathType Leaf) {
        Copy-Item -LiteralPath $sourceShort -Destination (Join-Path $root 'SHORT_MEMORY.md')
    } else {
        [System.IO.File]::WriteAllText((Join-Path $root 'SHORT_MEMORY.md'), "# SHORT_MEMORY`r`n`r`n> Active conversations only. Managed by project Hooks and Skills.`r`n", $utf8NoBom)
    }
    if (Test-Path -LiteralPath $sourceLong -PathType Leaf) {
        Copy-Item -LiteralPath $sourceLong -Destination (Join-Path $root 'LONG_MEMORY.md')
    } else {
        [System.IO.File]::WriteAllText((Join-Path $root 'LONG_MEMORY.md'), "# LONG_MEMORY`r`n`r`n> Terminal verified conversations only.`r`n", $utf8NoBom)
    }
    & git -C $root init -q
    if ($LASTEXITCODE -ne 0) { throw 'Could not initialize Plan mode regression Git root.' }

    $shortPath = Join-Path $root 'SHORT_MEMORY.md'
    $indexPath = Join-Path $root '.codex/harness/memory-index.json'
    $shortBefore = (Get-FileHash -LiteralPath $shortPath -Algorithm SHA256).Hash
    $indexBefore = (Get-FileHash -LiteralPath $indexPath -Algorithm SHA256).Hash

    $planTurn = 'plan-turn'
    $planTranscript = Join-Path $root 'plan-transcript.jsonl'
    Write-Transcript $planTranscript $planTurn 'plan'
    $planPrompt = Invoke-Hook 'user-prompt-dispatcher.ps1' ([ordered]@{
        session_id = 'plan-session'; turn_id = $planTurn; cwd = $root; transcript_path = $planTranscript
        hook_event_name = 'UserPromptSubmit'; prompt = '只制定两步方案，不修改任何文件。'
    }) | ConvertFrom-Json
    if ([string]$planPrompt.hookSpecificOutput.additionalContext -notmatch 'Plan collaboration mode is active') {
        throw 'UserPromptSubmit did not report the Plan-mode read-only Memory bypass.'
    }
    if ((Get-FileHash -LiteralPath $shortPath -Algorithm SHA256).Hash -ne $shortBefore -or
        (Get-FileHash -LiteralPath $indexPath -Algorithm SHA256).Hash -ne $indexBefore) {
        throw 'Plan-mode UserPromptSubmit changed project Memory files.'
    }

    $planStopRaw = Invoke-Hook 'stop-closeout-dispatcher.ps1' ([ordered]@{
        session_id = 'plan-session'; turn_id = $planTurn; cwd = $root; transcript_path = $planTranscript
        hook_event_name = 'Stop'; stop_hook_active = $false; last_assistant_message = '两步只读方案。'
    })
    $planStop = $planStopRaw | ConvertFrom-Json
    if (-not [bool]$planStop.continue -or $planStop.PSObject.Properties.Name -contains 'decision') {
        throw "Plan-mode Stop was blocked: $planStopRaw"
    }
    if ((Get-FileHash -LiteralPath $shortPath -Algorithm SHA256).Hash -ne $shortBefore -or
        (Get-FileHash -LiteralPath $indexPath -Algorithm SHA256).Hash -ne $indexBefore) {
        throw 'Plan-mode Stop changed project Memory files.'
    }

    $defaultTurn = 'default-turn'
    $defaultTranscript = Join-Path $root 'default-transcript.jsonl'
    Write-Transcript $defaultTranscript $defaultTurn 'default'
    $defaultPrompt = Invoke-Hook 'user-prompt-dispatcher.ps1' ([ordered]@{
        session_id = 'default-session'; turn_id = $defaultTurn; cwd = $root; transcript_path = $defaultTranscript
        hook_event_name = 'UserPromptSubmit'; prompt = '验证默认模式 Memory 捕获。'
    }) | ConvertFrom-Json
    if ([string]$defaultPrompt.hookSpecificOutput.additionalContext -notmatch 'Project Memory captured') {
        throw 'Default-mode UserPromptSubmit no longer captured Memory.'
    }
    $defaultStop = Invoke-Hook 'stop-closeout-dispatcher.ps1' ([ordered]@{
        session_id = 'default-session'; turn_id = $defaultTurn; cwd = $root; transcript_path = $defaultTranscript
        hook_event_name = 'Stop'; stop_hook_active = $false; last_assistant_message = '默认模式测试。'
    }) | ConvertFrom-Json
    if ($defaultStop.decision -ne 'block' -or [string]$defaultStop.reason -notmatch 'memory-turn-closeout') {
        throw 'Default-mode Stop no longer enforces Memory closeout.'
    }

    [ordered]@{
        passed = $true
        planModeDetectedFromTranscript = $true
        planModeMemoryUnchanged = $true
        planModeStopAllowed = $true
        defaultModeMemoryCaptured = $true
        defaultModeCloseoutEnforced = $true
    } | ConvertTo-Json -Compress
} finally {
    if (Test-Path -LiteralPath $root) { Remove-Item -LiteralPath $root -Recurse -Force }
}
