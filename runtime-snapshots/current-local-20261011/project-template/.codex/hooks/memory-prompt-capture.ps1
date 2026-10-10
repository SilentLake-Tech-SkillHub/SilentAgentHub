param(
    [string]$Root = '',
    [string]$Prompt = '',
    [string]$ConversationId = '',
    [string]$SessionId = '',
    [string]$TurnId = '',
    [string]$TaskId = '',
    [string]$PlanId = ''
)
. "$PSScriptRoot/common.ps1"

if ([string]::IsNullOrWhiteSpace($Root)) { $Root = (Get-Location).Path }
$Root = [System.IO.Path]::GetFullPath($Root)
$policyPath = Join-Path $Root '.codex/harness/memory-policy.json'
if (-not (Test-Path -LiteralPath $policyPath)) { throw "Memory policy is missing: $policyPath" }
$policy = Get-Content -LiteralPath $policyPath -Raw -Encoding UTF8 | ConvertFrom-Json

if (Test-InternalMemoryPrompt $Prompt $policy) {
    $quarantineRelative = [string](Get-PropertyValue $policy.files 'quarantine' '.codex/harness/memory-quarantine.jsonl')
    $quarantinePath = Join-Path $Root $quarantineRelative
    $event = [ordered]@{
        timestamp = [DateTime]::UtcNow.ToString('o')
        reason = 'internal-or-system-prompt'
        prompt_hash = Get-Sha256 $Prompt
        prompt_preview = (Protect-MemoryText (($Prompt -replace '\s+', ' ').Trim())).Substring(0, [Math]::Min(160, (Protect-MemoryText (($Prompt -replace '\s+', ' ').Trim())).Length))
        conversation_id = ConvertTo-SafeId $ConversationId 'conversation'
        session_id = ConvertTo-SafeId $SessionId 'session'
        turn_id = ConvertTo-SafeId $TurnId 'turn'
    }
    Add-Utf8JsonLine $quarantinePath $event
    @{ passed = $true; captured = $false; quarantined = $true; reason = $event.reason; promptHash = $event.prompt_hash } | ConvertTo-Json -Compress
    exit 0
}

$workspaceId = 'ws-' + (Get-Sha256 $Root).Substring(0, 12)
$SessionId = ConvertTo-SafeId $SessionId 'session'
$ConversationId = ConvertTo-SafeId ($(if ($ConversationId) { $ConversationId } else { $SessionId })) 'conversation'
$promptHash = Get-Sha256 $Prompt
$TurnId = ConvertTo-SafeId ($(if ($TurnId) { $TurnId } else { 'turn-' + $promptHash.Substring(0, 12) })) 'turn'
$shortPath = Join-Path $Root ([string]$policy.files.short)
$indexPath = Join-Path $Root ([string]$policy.files.index)
$lockDir = Join-Path $Root ([string]$policy.files.locks)
$lockPath = Join-Path $lockDir ($ConversationId + '.lock')
New-Item -ItemType Directory -Path $lockDir -Force | Out-Null

$lockStream = $null
try {
    $lockStream = [System.IO.File]::Open($lockPath, 'OpenOrCreate', 'ReadWrite', 'None')
    if (-not (Test-Path -LiteralPath $shortPath)) { Write-Utf8BomFile $shortPath "# SHORT_MEMORY`r`n`r`n> Active conversations only. Managed by project Hooks and Skills.`r`n" }
    $content = Get-Content -LiteralPath $shortPath -Raw -Encoding UTF8
    $recordPattern = '(?ms)<!-- memory-record-begin -->\r?\n(?<meta>\{[^\r\n]+\})\r?\n(?<body>.*?)<!-- memory-record-end -->\r?\n?'
    $records = @([regex]::Matches($content, $recordPattern))
    foreach ($record in $records) {
        $meta = $record.Groups['meta'].Value | ConvertFrom-Json
        if ([string](Get-PropertyValue $meta 'conversation_id' '') -eq $ConversationId -and [string]$meta.turn_id -eq $TurnId) {
            @{ passed = $true; changed = $false; reason = 'duplicate-turn'; conversationId = $ConversationId; turnId = $TurnId; promptHash = $promptHash } | ConvertTo-Json -Compress
            exit 0
        }
    }

    $now = [DateTime]::UtcNow.ToString('o')
    $safePrompt = Protect-MemoryText $Prompt
    $metaObject = [ordered]@{
        workspace_id = $workspaceId
        session_id = $SessionId
        conversation_id = $ConversationId
        turn_id = $TurnId
        timestamp = $now
        status = 'received'
        prompt_hash = $promptHash
        redacted = ($safePrompt -ne $Prompt)
        verification_cycle = 0
        task_id = (Protect-MemoryText $TaskId)
        plan_id = (Protect-MemoryText $PlanId)
        evidence = @()
    }
    $metaJson = $metaObject | ConvertTo-Json -Depth 8 -Compress
    $block = "`r`n<!-- memory-record-begin -->`r`n$metaJson`r`n### 用户 Prompt`r`n`r`n$safePrompt`r`n`r`n### 本轮结果`r`n`r`n待判定。`r`n`r`n### 下一步`r`n`r`n执行中。`r`n<!-- memory-record-end -->`r`n"
    $content += $block

    $matchesForConversation = @([regex]::Matches($content, $recordPattern) | Where-Object {
        [string](Get-PropertyValue ($_.Groups['meta'].Value | ConvertFrom-Json) 'conversation_id' '') -eq $ConversationId
    })
    $maxTurns = [int]$policy.maxDetailedTurnsPerOpenConversation
    if ($matchesForConversation.Count -gt $maxTurns) {
        $overflow = @($matchesForConversation | Select-Object -First ($matchesForConversation.Count - $maxTurns))
        $rollupLines = [System.Collections.Generic.List[string]]::new()
        foreach ($old in $overflow) {
            $oldMeta = $old.Groups['meta'].Value | ConvertFrom-Json
            $oldPrompt = [regex]::Match($old.Groups['body'].Value, '(?ms)### 用户 Prompt\s*(?<prompt>.*?)(?:\r?\n### 本轮结果)').Groups['prompt'].Value.Trim()
            if ($oldPrompt.Length -gt 160) { $oldPrompt = $oldPrompt.Substring(0, 160) + '…' }
            $rollupLines.Add("- $($oldMeta.timestamp) | $($oldMeta.turn_id) | $($oldMeta.status) | $oldPrompt")
            $content = $content.Replace($old.Value, '')
        }
        $rollupPattern = '(?ms)<!-- memory-rollup-begin:' + [regex]::Escape($ConversationId) + ' -->.*?<!-- memory-rollup-end:' + [regex]::Escape($ConversationId) + ' -->\r?\n?'
        $existing = [regex]::Match($content, $rollupPattern)
        $existingLines = ''
        if ($existing.Success) {
            $existingLines = [regex]::Match($existing.Value, '(?ms)\r?\n(?<lines>- .*?)\r?\n<!-- memory-rollup-end').Groups['lines'].Value
            $content = $content.Replace($existing.Value, '')
        }
        $allLines = (@($existingLines) + @($rollupLines)) | Where-Object { -not [string]::IsNullOrWhiteSpace($_) }
        $rollup = "`r`n<!-- memory-rollup-begin:$ConversationId -->`r`n" + ($allLines -join "`r`n") + "`r`n<!-- memory-rollup-end:$ConversationId -->`r`n"
        $content += $rollup
    }
    Write-Utf8BomFile $shortPath $content

    $index = if (Test-Path -LiteralPath $indexPath) { Get-Content -LiteralPath $indexPath -Raw -Encoding UTF8 | ConvertFrom-Json } else { [pscustomobject]@{ version = '1.0.0'; updatedAt = $null; conversations = @() } }
    $kept = @($index.conversations | Where-Object { $_.conversationId -ne $ConversationId })
    $entry = [pscustomobject]@{ conversationId = $ConversationId; workspaceId = $workspaceId; sessionId = $SessionId; state = 'received'; location = 'short'; updatedAt = $now; contentHash = (Get-ShortConversationHash $content $ConversationId); tags = @($TaskId, $PlanId | Where-Object { $_ }) }
    $indexOutput = [ordered]@{ '$schema' = './memory-index.schema.json'; version = '1.0.0'; updatedAt = $now; conversations = @($kept) + @($entry) }
    Write-Utf8BomFile $indexPath (($indexOutput | ConvertTo-Json -Depth 8) + "`r`n")
    @{ passed = $true; captured = $true; quarantined = $false; changed = $true; conversationId = $ConversationId; turnId = $TurnId; promptHash = $promptHash; redacted = ($safePrompt -ne $Prompt) } | ConvertTo-Json -Compress
} finally {
    if ($null -ne $lockStream) { $lockStream.Dispose() }
    Remove-Item -LiteralPath $lockPath -Force -ErrorAction SilentlyContinue
}
