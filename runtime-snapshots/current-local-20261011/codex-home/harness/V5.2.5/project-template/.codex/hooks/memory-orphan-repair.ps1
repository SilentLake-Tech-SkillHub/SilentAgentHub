param([string]$Root = '')
. "$PSScriptRoot/common.ps1"

if ([string]::IsNullOrWhiteSpace($Root)) { $Root = (Get-Location).Path }
$Root = [System.IO.Path]::GetFullPath($Root)
$policyPath = Join-Path $Root '.codex/harness/memory-policy.json'
if (-not (Test-Path -LiteralPath $policyPath)) { throw "Memory policy is missing: $policyPath" }
$policy = Get-Content -LiteralPath $policyPath -Raw -Encoding UTF8 | ConvertFrom-Json
$shortPath = Join-Path $Root ([string]$policy.files.short)
$indexPath = Join-Path $Root ([string]$policy.files.index)
$quarantinePath = Join-Path $Root ([string](Get-PropertyValue $policy.files 'quarantine' '.codex/harness/memory-quarantine.jsonl'))
$pattern = '(?ms)<!-- memory-record-begin -->\r?\n(?<meta>\{[^\r\n]+\})\r?\n(?<body>.*?)<!-- memory-record-end -->\r?\n?'
$content = if (Test-Path -LiteralPath $shortPath) { Get-Content -LiteralPath $shortPath -Raw -Encoding UTF8 } else { '' }
$removed = [System.Collections.Generic.List[string]]::new()
$repaired = [System.Collections.Generic.List[string]]::new()
$now = [DateTime]::UtcNow

$matches = @([regex]::Matches($content, $pattern))
foreach ($match in $matches) {
    $meta = $match.Groups['meta'].Value | ConvertFrom-Json
    $body = $match.Groups['body'].Value
    $prompt = [regex]::Match($body, '(?ms)### 用户 Prompt\s*(?<prompt>.*?)(?:\r?\n### 本轮结果)').Groups['prompt'].Value.Trim()
    if (Test-InternalMemoryPrompt $prompt $policy) {
        Add-Utf8JsonLine $quarantinePath ([ordered]@{ timestamp = $now.ToString('o'); reason = 'orphan-internal-prompt'; prompt_hash = Get-Sha256 $prompt; conversation_id = [string]$meta.conversation_id; session_id = [string]$meta.session_id; turn_id = [string]$meta.turn_id })
        $removed.Add([string]$meta.conversation_id)
        $content = $content.Replace($match.Value, '')
        continue
    }
    $timestamp = [DateTime]$meta.timestamp
    if ([string]$meta.status -eq 'received' -and ($now - $timestamp.ToUniversalTime()).TotalMinutes -ge [int]$policy.receivedStaleMinutes) {
        $meta.status = 'needs_user'
        $meta.verification_cycle = 1
        $body = [regex]::Replace($body, '(?ms)### 本轮结果\s*.*?(?=\r?\n### 下一步)', "### 本轮结果`r`n`r`n检测到孤儿 received 记录；已保留需求并修复为 needs_user，未迁移到 LONG_MEMORY。`r`n")
        $body = [regex]::Replace($body, '(?ms)### 下一步\s*.*?$', "### 下一步`r`n`r`n恢复该 conversation 后重新确认任务状态。`r`n")
        $repaired.Add([string]$meta.conversation_id)
        $replacement = "<!-- memory-record-begin -->`r`n$($meta | ConvertTo-Json -Depth 8 -Compress)`r`n$($body.Trim())`r`n<!-- memory-record-end -->`r`n"
        $content = $content.Replace($match.Value, $replacement)
    }
}

if ($removed.Count -gt 0 -or $repaired.Count -gt 0) { Write-Utf8BomFile $shortPath $content }
if (Test-Path -LiteralPath $indexPath) {
    $index = Get-Content -LiteralPath $indexPath -Raw -Encoding UTF8 | ConvertFrom-Json
    $entries = @($index.conversations | Where-Object { $removed -notcontains [string]$_.conversationId } | ForEach-Object {
        if ($repaired -contains [string]$_.conversationId) { $_.state = 'needs_user'; $_.updatedAt = $now.ToString('o') }
        $_
    })
    $output = [ordered]@{ '$schema' = './memory-index.schema.json'; version = '1.0.0'; updatedAt = $now.ToString('o'); conversations = $entries }
    Write-Utf8BomFile $indexPath (($output | ConvertTo-Json -Depth 8) + "`r`n")
}
@{ passed = $true; changed = ($removed.Count -gt 0 -or $repaired.Count -gt 0); quarantined = @($removed); repaired = @($repaired) } | ConvertTo-Json -Depth 6 -Compress
