param([string]$Root = '', [string]$ConversationId = '', [string]$SessionId = '')
. "$PSScriptRoot/common.ps1"

if ([string]::IsNullOrWhiteSpace($Root)) { $Root = (Get-Location).Path }
$Root = [System.IO.Path]::GetFullPath($Root)
$policy = Get-Content -LiteralPath (Join-Path $Root '.codex/harness/memory-policy.json') -Raw -Encoding UTF8 | ConvertFrom-Json
$shortPath = Join-Path $Root ([string]$policy.files.short)
if (-not (Test-Path -LiteralPath $shortPath)) { throw "SHORT_MEMORY is missing: $shortPath" }
$content = Get-Content -LiteralPath $shortPath -Raw -Encoding UTF8
$recordPattern = '(?ms)<!-- memory-record-begin -->\r?\n(?<meta>\{[^\r\n]+\})\r?\n(?<body>.*?)<!-- memory-record-end -->\r?\n?'
$selected = @([regex]::Matches($content, $recordPattern) | Where-Object {
    $meta = $_.Groups['meta'].Value | ConvertFrom-Json
    ($ConversationId -and [string](Get-PropertyValue $meta 'conversation_id' '') -eq $ConversationId) -or (-not $ConversationId -and $SessionId -and [string]$meta.session_id -eq $SessionId)
})
if ($selected.Count -eq 0) { @{ passed = $true; changed = $false; found = $false } | ConvertTo-Json -Compress; exit 0 }
$conversation = [string](Get-PropertyValue ($selected[-1].Groups['meta'].Value | ConvertFrom-Json) 'conversation_id' '')
$lines = [System.Collections.Generic.List[string]]::new()
foreach ($record in $selected | Select-Object -Last ([int]$policy.maxDetailedTurnsPerOpenConversation)) {
    $meta = $record.Groups['meta'].Value | ConvertFrom-Json
    $body = $record.Groups['body'].Value
    $prompt = [regex]::Match($body, '(?ms)### 用户 Prompt\s*(?<value>.*?)(?=\r?\n### 本轮结果)').Groups['value'].Value.Trim() -replace '\s+', ' '
    $result = [regex]::Match($body, '(?ms)### 本轮结果\s*(?<value>.*?)(?=\r?\n### 下一步)').Groups['value'].Value.Trim() -replace '\s+', ' '
    if ($prompt.Length -gt 160) { $prompt = $prompt.Substring(0, 160) + '…' }
    if ($result.Length -gt 120) { $result = $result.Substring(0, 120) + '…' }
    $lines.Add("- $($meta.timestamp) | turn=$($meta.turn_id) | status=$($meta.status) | prompt=$prompt | result=$result")
}
$summaryPattern = '(?ms)<!-- memory-active-summary-begin:' + [regex]::Escape($conversation) + ' -->.*?<!-- memory-active-summary-end:' + [regex]::Escape($conversation) + ' -->\r?\n?'
$summary = "<!-- memory-active-summary-begin:$conversation -->`r`n- compacted_at=$([DateTime]::UtcNow.ToString('o'))`r`n" + ($lines -join "`r`n") + "`r`n<!-- memory-active-summary-end:$conversation -->`r`n"
if ([regex]::IsMatch($content, $summaryPattern)) { $content = [regex]::Replace($content, $summaryPattern, $summary) } else { $content += "`r`n$summary" }
Write-Utf8BomFile $shortPath $content
$indexPath = Join-Path $Root ([string]$policy.files.index)
if (Test-Path -LiteralPath $indexPath) {
    $index = Get-Content -LiteralPath $indexPath -Raw -Encoding UTF8 | ConvertFrom-Json
    $latestMeta = $selected[-1].Groups['meta'].Value | ConvertFrom-Json
    $now = [DateTime]::UtcNow.ToString('o')
    $hash = Get-ShortConversationHash $content $conversation
    $foundIndex = $false
    $updated = @($index.conversations | ForEach-Object {
        if ([string]$_.conversationId -eq $conversation) {
            $foundIndex = $true
            $_.state = [string]$latestMeta.status
            $_.location = 'short'
            $_.updatedAt = $now
            $_.contentHash = $hash
        }
        $_
    })
    if (-not $foundIndex) { throw "Memory index entry missing during compact: $conversation" }
    $indexOutput = [ordered]@{ '$schema' = './memory-index.schema.json'; version = '1.0.0'; updatedAt = $now; conversations = $updated }
    Write-Utf8BomFile $indexPath (($indexOutput | ConvertTo-Json -Depth 8) + "`r`n")
}
@{ passed = $true; changed = $true; found = $true; conversationId = $conversation; summarizedTurns = $selected.Count } | ConvertTo-Json -Compress
