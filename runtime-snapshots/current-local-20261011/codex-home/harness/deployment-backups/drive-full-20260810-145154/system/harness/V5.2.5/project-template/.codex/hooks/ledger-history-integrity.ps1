param([string]$Root = '', [switch]$ForceEnabled)
. "$PSScriptRoot/common.ps1"
if ([string]::IsNullOrWhiteSpace($Root)) { $Root = (Get-Location).Path }
$Root = [System.IO.Path]::GetFullPath($Root)
$configPath = Join-Path $Root '.codex/harness/ledger-retention.json'
if (-not (Test-Path -LiteralPath $configPath)) { @{ passed = $false; errors = @('ledger-retention-missing') } | ConvertTo-Json -Compress; exit 0 }
$config = Get-Content -LiteralPath $configPath -Raw -Encoding UTF8 | ConvertFrom-Json
if (-not [bool]$config.enabled -and -not $ForceEnabled) { @{ passed = $true; enabled = $false; errors = @() } | ConvertTo-Json -Compress; exit 0 }
$errors = [System.Collections.Generic.List[string]]::new()
$hashes = @{}
$historyRoot = Join-Path $Root ([string]$config.historyRoot)
$indexPath = [System.IO.Path]::GetFullPath((Join-Path $Root ([string]$config.index)))
if (Test-Path -LiteralPath $historyRoot) {
    foreach ($file in Get-ChildItem -LiteralPath $historyRoot -Filter '*.md' -File -Recurse) {
        if ($file.FullName -eq $indexPath) { continue }
        $body = Get-Content -LiteralPath $file.FullName -Raw -Encoding UTF8
        foreach ($m in [regex]::Matches($body, '\|\s*(?<hash>[a-f0-9]{64})\s*\|')) {
            $hash = $m.Groups['hash'].Value
            if ($hashes.ContainsKey($hash)) { $errors.Add("duplicate-history-hash:$hash") } else { $hashes[$hash] = $file.FullName }
        }
    }
}
$txDir = Join-Path $Root ([string]$config.transactions)
if (Test-Path -LiteralPath $txDir) {
    foreach ($tx in Get-ChildItem -LiteralPath $txDir -Filter '*.json' -File) {
        try { $state = (Get-Content -LiteralPath $tx.FullName -Raw -Encoding UTF8 | ConvertFrom-Json).status; if ($state -notin @('committed','failed')) { $errors.Add("unfinished-history-transaction:$($tx.Name)") } }
        catch { $errors.Add("invalid-history-transaction:$($tx.Name)") }
    }
}
@{ passed = ($errors.Count -eq 0); enabled = $true; archivedHashes = $hashes.Count; errors = @($errors) } | ConvertTo-Json -Depth 6
