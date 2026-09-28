param(
    [string]$Root = (Get-Location).Path
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Get-OptionalProperty([object]$Object, [string]$Name, [object]$Default = $null) {
    if ($null -ne $Object) {
        $property = $Object.PSObject.Properties[$Name]
        if ($null -ne $property) { return $property.Value }
    }
    return $Default
}

function Normalize-RelativePath([string]$Path) {
    if ([string]::IsNullOrWhiteSpace($Path)) { throw 'A relative path is empty.' }
    if ([System.IO.Path]::IsPathRooted($Path)) { throw "Absolute paths are not allowed: $Path" }
    $normalized = $Path.Replace('/', [System.IO.Path]::DirectorySeparatorChar).Replace('\', [System.IO.Path]::DirectorySeparatorChar).Trim([System.IO.Path]::DirectorySeparatorChar)
    if ([string]::IsNullOrWhiteSpace($normalized)) { return '.' }
    return $normalized
}

function Resolve-WithinRoot([string]$RootPath, [string]$RelativePath) {
    $rootFull = [System.IO.Path]::GetFullPath($RootPath).TrimEnd('\', '/')
    $relative = Normalize-RelativePath $RelativePath
    $candidate = if ($relative -eq '.') { $rootFull } else { [System.IO.Path]::GetFullPath((Join-Path $rootFull $relative)) }
    $prefix = $rootFull + [System.IO.Path]::DirectorySeparatorChar
    if ($candidate -ne $rootFull -and -not $candidate.StartsWith($prefix, [System.StringComparison]::OrdinalIgnoreCase)) {
        throw "Path escapes the project boundary: $RelativePath"
    }
    return $candidate
}

function New-Result([bool]$Configured, [bool]$Passed, [object[]]$Errors, [object[]]$Warnings, [int]$Checked) {
    return [ordered]@{
        configured = $Configured
        passed = $Passed
        checked = $Checked
        errors = @($Errors)
        warnings = @($Warnings)
    }
}

function Invoke-SourceLayoutIntegrity([string]$ProjectRoot) {
    $errors = [System.Collections.Generic.List[string]]::new()
    $warnings = [System.Collections.Generic.List[string]]::new()
    $checked = 0

    try {
        $rootFull = [System.IO.Path]::GetFullPath($ProjectRoot)
        $indexPath = Join-Path $rootFull '.codex/harness/index.json'
        if (-not (Test-Path -LiteralPath $indexPath -PathType Leaf)) {
            return New-Result $false $true @() @('Harness index is absent; source-layout enforcement is not configured.') 0
        }

        $index = Get-Content -LiteralPath $indexPath -Raw -Encoding UTF8 | ConvertFrom-Json
        $required = [bool](Get-OptionalProperty $index 'sourceLayoutRequired' $false)
        $manifestRelative = [string](Get-OptionalProperty $index 'sourceLayoutManifest' '')
        if ([string]::IsNullOrWhiteSpace($manifestRelative)) {
            if ($required) { $errors.Add('sourceLayoutManifest is missing from the harness index.') }
            else { $warnings.Add('Source-layout enforcement is disabled and no manifest path is configured.') }
            return New-Result $false ($errors.Count -eq 0) $errors $warnings 0
        }

        $manifestPath = Resolve-WithinRoot $rootFull $manifestRelative
        if (-not (Test-Path -LiteralPath $manifestPath -PathType Leaf)) {
            if ($required) { $errors.Add("Required source-layout manifest is missing: $manifestRelative") }
            else { $warnings.Add("Source-layout manifest is intentionally optional and absent: $manifestRelative") }
            return New-Result $false ($errors.Count -eq 0) $errors $warnings 0
        }

        $manifest = Get-Content -LiteralPath $manifestPath -Raw -Encoding UTF8 | ConvertFrom-Json
        $schemaVersion = [string](Get-OptionalProperty $manifest 'schema_version' '')
        if ($schemaVersion -ne '1.0') { $errors.Add("Unsupported source-layout schema_version: $schemaVersion") }
        $baseRelative = [string](Get-OptionalProperty $manifest 'base_path' '')
        if ([string]::IsNullOrWhiteSpace($baseRelative)) { $errors.Add('Manifest base_path is empty.') }
        $basePath = if ($errors.Count -eq 0) { Resolve-WithinRoot $rootFull $baseRelative } else { $rootFull }

        $entryValues = @(Get-OptionalProperty $manifest 'entries' @())
        if ($entryValues.Count -eq 0) { $errors.Add('Manifest entries are empty.') }
        $declared = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
        $enabledCount = 0

        foreach ($entry in $entryValues) {
            $pathValue = [string](Get-OptionalProperty $entry 'path' '')
            $roleValue = [string](Get-OptionalProperty $entry 'role' '')
            $enabledRaw = Get-OptionalProperty $entry 'enabled' $null
            $enabledValue = $false
            if ($enabledRaw -is [bool]) { $enabledValue = [bool]$enabledRaw }
            else { $errors.Add("Directory enabled flag must be boolean: $pathValue") }
            try { $key = Normalize-RelativePath $pathValue }
            catch { $errors.Add($_.Exception.Message); continue }
            if (-not $declared.Add($key)) { $errors.Add("Duplicate directory entry: $pathValue") }
            if ([string]::IsNullOrWhiteSpace($roleValue)) { $errors.Add("Directory responsibility is empty: $pathValue") }
            try { $entryPath = Resolve-WithinRoot $basePath $key }
            catch { $errors.Add($_.Exception.Message); continue }
            $checked++
            if ($enabledValue) {
                $enabledCount++
                if (-not (Test-Path -LiteralPath $entryPath -PathType Container)) { $errors.Add("Enabled directory is missing: $pathValue") }
            }
        }

        if ($required -and $enabledCount -eq 0) { $errors.Add('Source-layout enforcement is required but no directory entry is enabled.') }

        $exclusions = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
        foreach ($item in @(Get-OptionalProperty $manifest 'coverage_exclusions' @())) {
            if (-not [string]::IsNullOrWhiteSpace([string]$item)) { [void]$exclusions.Add(([string]$item).Trim()) }
        }

        $coverageValues = @(Get-OptionalProperty $manifest 'coverage_roots' @())
        if ($required -and $coverageValues.Count -eq 0) { $errors.Add('Source-layout enforcement is required but coverage_roots is empty.') }
        foreach ($coverage in $coverageValues) {
            $coverageKey = Normalize-RelativePath ([string]$coverage)
            $coveragePath = Resolve-WithinRoot $basePath $coverageKey
            if (-not (Test-Path -LiteralPath $coveragePath -PathType Container)) { continue }
            foreach ($directory in @(Get-ChildItem -LiteralPath $coveragePath -Directory -Force -ErrorAction Stop)) {
                if ($exclusions.Contains($directory.Name)) { continue }
                $actualKey = if ($coverageKey -eq '.') { $directory.Name } else { Join-Path $coverageKey $directory.Name }
                $actualKey = Normalize-RelativePath $actualKey
                if (-not $declared.Contains($actualKey)) { $errors.Add("Actual directory is not registered: $actualKey") }
            }
        }

        return New-Result $true ($errors.Count -eq 0) $errors $warnings $checked
    }
    catch {
        $errors.Add($_.Exception.Message)
        return New-Result $false $false $errors $warnings $checked
    }
}

$result = Invoke-SourceLayoutIntegrity $Root
$result | ConvertTo-Json -Depth 10 -Compress | Write-Output
