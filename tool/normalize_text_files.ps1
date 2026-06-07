$ErrorActionPreference = 'Stop'
Set-Location (Split-Path -Parent $PSScriptRoot)

$extensions = @(
    '.dart',
    '.json',
    '.lock',
    '.md',
    '.rules',
    '.yaml',
    '.yml'
)

$files = @()
$files += git diff --name-only
$files += git ls-files --others --exclude-standard
$files = $files | Where-Object {
    $_ -and $extensions.Contains([IO.Path]::GetExtension($_).ToLowerInvariant())
} | Sort-Object -Unique

$utf8WithoutBom = [Text.UTF8Encoding]::new($false)
foreach ($file in $files) {
    if (-not (Test-Path -LiteralPath $file -PathType Leaf)) {
        continue
    }

    $content = [IO.File]::ReadAllText((Resolve-Path -LiteralPath $file))
    $normalized = $content.Replace("`r`n", "`n").Replace("`r", "`n")
    $normalized = [Text.RegularExpressions.Regex]::Replace(
        $normalized,
        '[ \t]+(?=\n|$)',
        ''
    )
    $normalized = $normalized.Replace("`n", [Environment]::NewLine)

    [IO.File]::WriteAllText(
        (Resolve-Path -LiteralPath $file),
        $normalized,
        $utf8WithoutBom
    )
}

Write-Host "Normalizados $($files.Count) archivos de texto modificados." -ForegroundColor Green
