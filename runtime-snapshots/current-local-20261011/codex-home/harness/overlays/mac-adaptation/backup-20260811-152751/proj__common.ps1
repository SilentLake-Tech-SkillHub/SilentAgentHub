Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Read-HookInput {
    # Windows PowerShell 5.1 otherwise decodes redirected stdin with the active
    # console code page. Codex Desktop sends UTF-8 JSON regardless of that page.
    $stream = [Console]::OpenStandardInput()
    $utf8 = New-Object System.Text.UTF8Encoding($false, $true)
    $reader = New-Object System.IO.StreamReader($stream, $utf8, $true)
    try { $raw = $reader.ReadToEnd() }
    finally { $reader.Dispose() }
    if ([string]::IsNullOrWhiteSpace($raw)) { return [pscustomobject]@{} }
    try { return $raw | ConvertFrom-Json }
    catch { return [pscustomobject]@{ _parse_error = $_.Exception.Message; _raw_length = $raw.Length } }
}

function Resolve-ProjectRoot([object]$InputObject) {
    $cwdProperty = $InputObject.PSObject.Properties['cwd']
    $candidate = if ($null -ne $cwdProperty -and $cwdProperty.Value) {
        [string]$cwdProperty.Value
    } else { (Get-Location).Path }
    try {
        $gitRoot = (& git -C $candidate rev-parse --show-toplevel 2>$null | Select-Object -First 1)
        if ($LASTEXITCODE -eq 0 -and $gitRoot) { return [System.IO.Path]::GetFullPath(([string]$gitRoot).Trim()) }
    } catch { }
    if (-not (Test-Path -LiteralPath $candidate)) { $candidate = (Get-Location).Path }
    return [System.IO.Path]::GetFullPath([string]$candidate)
}

function Get-InputText([object]$InputObject) {
    return ($InputObject | ConvertTo-Json -Depth 30 -Compress)
}

function Test-SensitiveText([string]$Text) {
    return $Text -match '(?i)(BEGIN [A-Z ]*PRIVATE KEY|api[_-]?key|access[_-]?token|auth[_-]?token|cookie|client[_-]?secret|\.env(?!\.example))'
}

function Test-DestructiveText([string]$Text) {
    return $Text -match '(?i)(reset\s+--hard|clean\s+-fd|checkout\s+--|Remove-Item\s+.*-Recurse|rm\s+-rf|DROP\s+(DATABASE|TABLE)|TRUNCATE\s+TABLE|force-with-lease|--force|production|prod\b)'
}

function Write-HookOutput([hashtable]$Body) {
    $json = $Body | ConvertTo-Json -Depth 20 -Compress
    $bytes = (New-Object System.Text.UTF8Encoding($false)).GetBytes($json + "`n")
    $stdout = [Console]::OpenStandardOutput()
    try { $stdout.Write($bytes, 0, $bytes.Length); $stdout.Flush() }
    finally { $stdout.Dispose() }
}

function Write-StopBlock([string]$Reason) {
    Write-HookOutput @{ decision = 'block'; reason = $Reason }
}

function Get-PropertyValue([object]$Object, [string]$Name, [object]$Default = $null) {
    if ($null -ne $Object) {
        $property = $Object.PSObject.Properties[$Name]
        if ($null -ne $property) { return $property.Value }
    }
    return $Default
}

function Get-FirstPropertyValue([object]$Object, [string[]]$Names, [object]$Default = $null) {
    foreach ($name in $Names) {
        $value = Get-PropertyValue $Object $name $null
        if ($null -ne $value -and -not [string]::IsNullOrWhiteSpace([string]$value)) { return $value }
    }
    return $Default
}

function Get-Sha256([string]$Text) {
    $sha = [System.Security.Cryptography.SHA256]::Create()
    try {
        $bytes = [System.Text.Encoding]::UTF8.GetBytes([string]$Text)
        return (($sha.ComputeHash($bytes) | ForEach-Object { $_.ToString('x2') }) -join '')
    } finally { $sha.Dispose() }
}

function Get-ShortConversationHash([string]$Content, [string]$ConversationId) {
    if ([string]::IsNullOrWhiteSpace($ConversationId)) { return Get-Sha256 '' }
    $parts = [System.Collections.Generic.List[string]]::new()
    $recordPattern = '(?ms)<!-- memory-record-begin -->\r?\n(?<meta>\{[^\r\n]+\})\r?\n(?<body>.*?)<!-- memory-record-end -->\r?\n?'
    foreach ($record in [regex]::Matches([string]$Content, $recordPattern)) {
        try {
            $meta = $record.Groups['meta'].Value | ConvertFrom-Json
            if ([string]$meta.conversation_id -eq $ConversationId) { $parts.Add($record.Value.Trim()) }
        } catch { }
    }
    foreach ($prefix in @('memory-rollup','memory-active-summary')) {
        $pattern = '(?ms)<!-- ' + $prefix + '-begin:' + [regex]::Escape($ConversationId) + ' -->.*?<!-- ' + $prefix + '-end:' + [regex]::Escape($ConversationId) + ' -->\r?\n?'
        $match = [regex]::Match([string]$Content, $pattern)
        if ($match.Success) { $parts.Add($match.Value.Trim()) }
    }
    return Get-Sha256 ($parts -join "`n")
}

function Protect-MemoryText([string]$Text) {
    if ([string]::IsNullOrEmpty($Text)) { return '' }
    $value = $Text
    $value = [regex]::Replace($value, '(?is)-----BEGIN [A-Z ]*PRIVATE KEY-----.*?-----END [A-Z ]*PRIVATE KEY-----', '[REDACTED_PRIVATE_KEY]')
    $value = [regex]::Replace($value, '(?i)\bBearer\s+[A-Za-z0-9._~+/=-]{8,}', 'Bearer [REDACTED]')
    $value = [regex]::Replace($value, '(?i)(\b(?:api[_-]?key|access[_-]?token|auth[_-]?token|token|client[_-]?secret|password|passwd|pwd|cookie|secret)\b\s*[:=]\s*)([^\s,;\]\}\)]+)', '$1[REDACTED]')
    $value = [regex]::Replace($value, '(?i)([?&](?:token|key|secret|password)=)[^&#\s]+', '$1[REDACTED]')
    return $value
}

function Test-InternalMemoryPrompt([string]$Prompt, [object]$Policy = $null) {
    if ([string]::IsNullOrWhiteSpace($Prompt)) { return $false }
    $normalized = ($Prompt -replace "`r`n", "`n").Trim()
    $builtIn = @(
        '(?is)^#\s*Overview\s*\n+Generate\s+0\s+to\s+3\s+hyperpersonalized\s+suggestions',
        '(?is)Generate\s+0\s+to\s+3\s+hyperpersonalized\s+suggestions.*?#\s*Response\s+format'
    )
    $patterns = [System.Collections.Generic.List[string]]::new()
    foreach ($pattern in $builtIn) { $patterns.Add($pattern) }
    if ($null -ne $Policy) {
        $rules = Get-PropertyValue $Policy 'internalPromptRules' $null
        if ($null -ne $rules) {
            foreach ($pattern in @(Get-PropertyValue $rules 'denyPatterns' @())) {
                if (-not [string]::IsNullOrWhiteSpace([string]$pattern)) { $patterns.Add([string]$pattern) }
            }
        }
    }
    foreach ($pattern in $patterns) {
        if ([regex]::IsMatch($normalized, $pattern)) { return $true }
    }
    return $false
}

function Get-NormalizedToolName([object]$InputObject) {
    $raw = [string](Get-FirstPropertyValue $InputObject @('tool_name','toolName','tool','name') '')
    if ([string]::IsNullOrWhiteSpace($raw)) {
        $toolObject = Get-PropertyValue $InputObject 'tool' $null
        if ($null -ne $toolObject -and -not ($toolObject -is [string])) {
            $raw = [string](Get-FirstPropertyValue $toolObject @('name','tool_name','toolName') '')
        }
    }
    if ([string]::IsNullOrWhiteSpace($raw)) {
        $call = Get-FirstPropertyValue $InputObject @('tool_call','toolCall') $null
        if ($null -ne $call) { $raw = [string](Get-FirstPropertyValue $call @('name','tool_name','toolName') '') }
    }
    if ([string]::IsNullOrWhiteSpace($raw)) { return 'unknown' }
    switch -Regex ($raw) {
        '^(functions\.)?exec_command$|^shell_command$|^powershell$|^bash$' { return 'Bash' }
        '^(functions\.)?apply_patch$|^edit$|^write$' { return 'apply_patch' }
        '^mcp__' { return $raw }
        default { return $raw }
    }
}

function Get-HookConversationId([object]$InputObject) {
    return [string](Get-FirstPropertyValue $InputObject @('conversation_id','conversationId','thread_id','threadId') '')
}

function Get-HookSessionId([object]$InputObject) {
    return [string](Get-FirstPropertyValue $InputObject @('session_id','sessionId') '')
}

function Get-HookTurnId([object]$InputObject) {
    return [string](Get-FirstPropertyValue $InputObject @('turn_id','turnId') '')
}

function Get-HookOperationId([object]$InputObject) {
    $id = [string](Get-FirstPropertyValue $InputObject @('tool_use_id','toolUseId','tool_call_id','toolCallId','call_id','callId') '')
    if (-not [string]::IsNullOrWhiteSpace($id)) { return $id }
    $turn = Get-HookTurnId $InputObject
    $tool = Get-NormalizedToolName $InputObject
    return "$turn::$tool"
}

function Get-QueryRouteCandidate([string]$Prompt) {
    $value = ([string]$Prompt).Trim()
    if ([string]::IsNullOrWhiteSpace($value)) { return 'other' }
    if ($value -match '(?i)^(批准|同意|通过|approve|approved)(\s|[:：]|$)') { return 'plan_review' }
    $explicitAction = $value -match '(?i)(请|帮我|继续|开始|执行|创建|新增|修改|修复|实现|建设|部署|发布|迁移|重构|初始化|打包|上传|删除|回滚)'
    $action = $explicitAction -or ($value -match '(?i)需要')
    $question = $value -match '(?i)(为什么|是什么|什么意思|哪些|多少|如何|怎么|是否|有没有|进展|状态|修复完|完成了|上传了|吗[？?]?$)'
    if ($question -and -not $explicitAction) { return 'status_or_readonly' }
    if ($action -and $value -match '(?i)(方案|架构|重构|初始化|多个模块|分阶段|部署|发布|迁移|agent|hook|skill|生产|跨机器)') { return 'complex_candidate' }
    if ($action) { return 'change_candidate' }
    return 'other'
}

function Test-ToolMutation([object]$InputObject) {
    $tool = Get-NormalizedToolName $InputObject
    if ($tool -eq 'apply_patch' -or $tool -match '^(Edit|Write)$') { return $true }
    if ($tool -match '^mcp__') {
        return $tool -match '(?i)(create|update|edit|delete|upload|send|write|resolve|reply|move|copy|deploy|publish)'
    }
    if ($tool -ne 'Bash') { return $false }
    $text = Get-InputText $InputObject
    return $text -match '(?i)(apply_patch|Set-Content|Add-Content|Out-File|Copy-Item|Move-Item|Remove-Item|New-Item|Compress-Archive|Expand-Archive|robocopy|rsync|git\s+(add|commit|tag|push|merge|checkout|switch|init)|npm\s+(install|publish)|pip\s+install|\btee\b|\btouch\b|\bmkdir\b)'
}

function Get-ApprovalType([object]$InputObject) {
    $text = Get-InputText $InputObject
    if (Test-SensitiveText $text) { return 'secret_or_sensitive' }
    if ($text -match '(?i)(production|prod\b|deploy|publish|push|C:\\Users\\[^\\]+\\\.codex)') { return 'production_or_system_write' }
    if (Test-DestructiveText $text) { return 'destructive_or_irreversible' }
    return 'tool_permission'
}

function Add-Utf8JsonLine([string]$Path, [object]$Value) {
    $parent = Split-Path -Parent $Path
    if ($parent -and -not (Test-Path -LiteralPath $parent)) { New-Item -ItemType Directory -Path $parent -Force | Out-Null }
    $encoding = New-Object System.Text.UTF8Encoding($false)
    $writer = New-Object System.IO.StreamWriter($Path, $true, $encoding)
    try { $writer.WriteLine(($Value | ConvertTo-Json -Depth 20 -Compress)) }
    finally { $writer.Dispose() }
}

function Write-Utf8BomFile([string]$Path, [string]$Content) {
    $parent = Split-Path -Parent $Path
    if ($parent -and -not (Test-Path -LiteralPath $parent)) { New-Item -ItemType Directory -Path $parent -Force | Out-Null }
    $encoding = New-Object System.Text.UTF8Encoding($true)
    [System.IO.File]::WriteAllText($Path, $Content, $encoding)
}

function ConvertTo-SafeId([string]$Value, [string]$FallbackPrefix = 'id') {
    if ([string]::IsNullOrWhiteSpace($Value)) { return "$FallbackPrefix-$(Get-Date -Format 'yyyyMMddHHmmssfff')" }
    $safe = [regex]::Replace($Value, '[^A-Za-z0-9._-]', '-')
    $safe = $safe.Trim('-')
    if ([string]::IsNullOrWhiteSpace($safe)) { return "$FallbackPrefix-$(Get-Date -Format 'yyyyMMddHHmmssfff')" }
    return $safe
}
