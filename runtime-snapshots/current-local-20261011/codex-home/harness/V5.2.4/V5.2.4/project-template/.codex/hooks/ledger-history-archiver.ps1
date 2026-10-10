param(
    [string]$Root = '',
    [switch]$ForceEnabled,
    [switch]$SimulateArchiveWriteFailure
)
. "$PSScriptRoot/common.ps1"
if ([string]::IsNullOrWhiteSpace($Root)) { $Root = (Get-Location).Path }
$Root = [System.IO.Path]::GetFullPath($Root)
$configPath = Join-Path $Root '.codex/harness/ledger-retention.json'
if (-not (Test-Path -LiteralPath $configPath)) { @{ passed = $false; enabled = $false; errors = @('ledger-retention-missing') } | ConvertTo-Json -Compress; exit 0 }
$config = Get-Content -LiteralPath $configPath -Raw -Encoding UTF8 | ConvertFrom-Json
if (-not [bool]$config.enabled -and -not $ForceEnabled) { @{ passed = $true; enabled = $false; changed = $false; archived = 0; reason = 'candidate-retention-disabled' } | ConvertTo-Json -Compress; exit 0 }

$historyRoot = Join-Path $Root ([string]$config.historyRoot)
$indexPath = Join-Path $Root ([string]$config.index)
$txDir = Join-Path $Root ([string]$config.transactions)
New-Item -ItemType Directory -Path $historyRoot, $txDir -Force | Out-Null
if (-not (Test-Path -LiteralPath $indexPath)) { Write-Utf8BomFile $indexPath "# 历史记录库 INDEX`r`n`r`n> cold / explicit_or_trace`r`n`r`n| 归档时间 | 来源流水 | 记录 ID | 内容 Hash | 历史文件 |`r`n|---|---|---|---|---|`r`n" }

$archiveCount = 0
$errors = [System.Collections.Generic.List[string]]::new()
foreach ($ledger in @($config.ledgers)) {
    $sourcePath = Join-Path $Root ([string]$ledger.path)
    if (-not (Test-Path -LiteralPath $sourcePath)) { continue }
    $sourceContent = Get-Content -LiteralPath $sourcePath -Raw -Encoding UTF8
    $lines = @($sourceContent -split '\r?\n')
    $headerIndex = -1
    $headers = @()
    for ($i = 0; $i -lt $lines.Count - 1; $i++) {
        if ($lines[$i].Trim().StartsWith('|') -and $lines[$i + 1] -match '^\s*\|(?:\s*:?-{3,}:?\s*\|)+\s*$') {
            $candidate = @($lines[$i].Trim().Trim('|').Split('|') | ForEach-Object { $_.Trim() })
            if ($candidate -contains [string]$ledger.idField -and $candidate -contains [string]$ledger.statusField) { $headerIndex = $i; $headers = $candidate; break }
        }
    }
    if ($headerIndex -lt 0) { $errors.Add("table-header-not-found:$($ledger.path)"); continue }
    $idIndex = [array]::IndexOf($headers, [string]$ledger.idField)
    $statusIndex = [array]::IndexOf($headers, [string]$ledger.statusField)
    $rowIndexes = [System.Collections.Generic.List[int]]::new()
    for ($i = $headerIndex + 2; $i -lt $lines.Count; $i++) {
        if (-not $lines[$i].Trim().StartsWith('|')) { break }
        $cells = @($lines[$i].Trim().Trim('|').Split('|') | ForEach-Object { $_.Trim() })
        if ($cells.Count -ne $headers.Count) { continue }
        $state = $cells[$statusIndex]
        $isTerminal = $false
        foreach ($terminal in @($ledger.terminalStates)) {
            if ($state -eq [string]$terminal -or $state.StartsWith(([string]$terminal + ':')) -or $state.StartsWith(([string]$terminal + '：'))) { $isTerminal = $true; break }
        }
        if ($isTerminal) { $rowIndexes.Add($i) }
    }
    foreach ($rowIndex in @($rowIndexes | Sort-Object -Descending)) {
        try {
            $row = $lines[$rowIndex]
            $cells = @($row.Trim().Trim('|').Split('|') | ForEach-Object { $_.Trim() })
            $recordId = ConvertTo-SafeId $cells[$idIndex] 'record'
            $rowHash = Get-Sha256 $row
            $now = [DateTime]::UtcNow
            $archiveDir = Join-Path $historyRoot ($now.ToString('yyyy/MM'))
            New-Item -ItemType Directory -Path $archiveDir -Force | Out-Null
            $archivePath = Join-Path $archiveDir ([string]$ledger.archiveName)
            $relativeArchive = $archivePath.Substring($Root.Length).TrimStart('\','/') -replace '\\','/'
            $txId = "history-$recordId-$(Get-Date -Format 'yyyyMMddHHmmssfff')"
            $txPath = Join-Path $txDir ($txId + '.json')
            $tx = [ordered]@{ transactionId = $txId; source = [string]$ledger.path; recordId = $recordId; rowHash = $rowHash; archive = $relativeArchive; status = 'prepared'; createdAt = $now.ToString('o') }
            Write-Utf8BomFile $txPath (($tx | ConvertTo-Json -Depth 6) + "`r`n")
            if ($SimulateArchiveWriteFailure) { throw 'Simulated history archive write failure.' }
            $archiveContent = if (Test-Path -LiteralPath $archivePath) { Get-Content -LiteralPath $archivePath -Raw -Encoding UTF8 } else { "# $([IO.Path]::GetFileNameWithoutExtension([string]$ledger.archiveName)) 历史`r`n`r`n| $($headers -join ' | ') | 归档时间 | 源文件 | 内容 Hash |`r`n|$((@($headers + @('归档时间','源文件','内容 Hash')) | ForEach-Object { '---' }) -join '|')|`r`n" }
            $archiveRow = $row.TrimEnd().TrimEnd('|') + "| $($now.ToString('o')) | $($ledger.path) | $rowHash |"
            $alreadyArchived = $archiveContent -match [regex]::Escape("| $rowHash |")
            if (-not $alreadyArchived) { $archiveContent += $archiveRow + "`r`n" }
            $archiveTemp = "$archivePath.$txId.tmp"
            Write-Utf8BomFile $archiveTemp $archiveContent
            $verifiedArchive = Get-Content -LiteralPath $archiveTemp -Raw -Encoding UTF8
            if ($verifiedArchive -notmatch [regex]::Escape("| $rowHash |")) { throw 'Archive row verification failed.' }
            Move-Item -LiteralPath $archiveTemp -Destination $archivePath -Force
            $tx.status = 'archive_verified'; Write-Utf8BomFile $txPath (($tx | ConvertTo-Json -Depth 6) + "`r`n")

            $newLines = [System.Collections.Generic.List[string]]::new()
            for ($j = 0; $j -lt $lines.Count; $j++) { if ($j -ne $rowIndex) { $newLines.Add($lines[$j]) } }
            $sourceTemp = "$sourcePath.$txId.tmp"
            Write-Utf8BomFile $sourceTemp (($newLines -join "`r`n").TrimEnd() + "`r`n")
            if ((Get-Content -LiteralPath $sourceTemp -Raw -Encoding UTF8) -match [regex]::Escape($row)) { throw 'Source cleanup verification failed.' }
            Move-Item -LiteralPath $sourceTemp -Destination $sourcePath -Force
            $lines = @($newLines)
            $index = Get-Content -LiteralPath $indexPath -Raw -Encoding UTF8
            if ($index -notmatch [regex]::Escape("| $rowHash |")) { $index += "| $($now.ToString('o')) | $($ledger.path) | $recordId | $rowHash | $relativeArchive |`r`n"; Write-Utf8BomFile $indexPath $index }
            $tx.status = 'committed'; $tx.completedAt = [DateTime]::UtcNow.ToString('o'); Write-Utf8BomFile $txPath (($tx | ConvertTo-Json -Depth 6) + "`r`n")
            $archiveCount++
        } catch {
            $errors.Add("archive-failed:$($ledger.path):$($_.Exception.Message)")
            if ($txPath -and (Test-Path -LiteralPath $txPath)) {
                try { $failed = Get-Content -LiteralPath $txPath -Raw -Encoding UTF8 | ConvertFrom-Json; $failed.status = 'failed'; $failed | Add-Member -NotePropertyName error -NotePropertyValue $_.Exception.Message -Force; Write-Utf8BomFile $txPath (($failed | ConvertTo-Json -Depth 8) + "`r`n") } catch { }
            }
        }
    }
}
@{ passed = ($errors.Count -eq 0); enabled = $true; changed = ($archiveCount -gt 0); archived = $archiveCount; errors = @($errors) } | ConvertTo-Json -Depth 6
