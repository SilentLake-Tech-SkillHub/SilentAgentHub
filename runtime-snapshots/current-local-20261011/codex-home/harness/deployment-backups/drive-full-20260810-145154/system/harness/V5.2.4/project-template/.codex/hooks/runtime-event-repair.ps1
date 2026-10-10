param([string]$Root = '')
. "$PSScriptRoot/common.ps1"

if ([string]::IsNullOrWhiteSpace($Root)) { $Root = (Get-Location).Path }
$Root = [System.IO.Path]::GetFullPath($Root)
$runtimeDir = Join-Path $Root '.codex/harness'
$sourcePath = Join-Path $runtimeDir 'runtime-events.jsonl'
$quarantinePath = Join-Path $runtimeDir 'runtime-events-quarantine.jsonl'
if (-not (Test-Path -LiteralPath $sourcePath)) { @{ passed = $true; changed = $false; kept = 0; quarantined = 0 } | ConvertTo-Json -Compress; exit 0 }

$kept = [System.Collections.Generic.List[object]]::new()
$quarantined = [System.Collections.Generic.List[object]]::new()
foreach ($line in Get-Content -LiteralPath $sourcePath -Encoding UTF8) {
    if ([string]::IsNullOrWhiteSpace($line)) { continue }
    try {
        $event = $line | ConvertFrom-Json
        $cwd = [string](Get-PropertyValue $event 'cwd' '')
        $tool = [string](Get-PropertyValue $event 'tool' 'unknown')
        if ($tool -eq 'unknown' -or [string]::IsNullOrWhiteSpace($cwd) -or -not (Test-Path -LiteralPath $cwd)) {
            $quarantined.Add([ordered]@{ quarantined_at = [DateTime]::UtcNow.ToString('o'); reason = 'unknown-tool-or-invalid-cwd'; event = $event })
        } else { $kept.Add($event) }
    } catch {
        $quarantined.Add([ordered]@{ quarantined_at = [DateTime]::UtcNow.ToString('o'); reason = 'invalid-json'; raw_hash = Get-Sha256 $line })
    }
}
$encoding = New-Object System.Text.UTF8Encoding($false)
$writer = New-Object System.IO.StreamWriter($sourcePath, $false, $encoding)
try { foreach ($event in $kept) { $writer.WriteLine(($event | ConvertTo-Json -Depth 20 -Compress)) } }
finally { $writer.Dispose() }
foreach ($event in $quarantined) { Add-Utf8JsonLine $quarantinePath $event }
@{ passed = $true; changed = ($quarantined.Count -gt 0); kept = $kept.Count; quarantined = $quarantined.Count } | ConvertTo-Json -Compress
