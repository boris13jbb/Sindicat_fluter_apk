param(
    [string]$Branch = "main",
    [string]$Owner = "boris13jbb",
    [string]$Repo = "Sindicat_fluter_apk",
    [switch]$DryRun
)

$ErrorActionPreference = "Stop"

$requiredCheck = "CI Gate"

Write-Host "Configurando protección de rama '$Branch' en $Owner/$Repo" -ForegroundColor Cyan
Write-Host "Check requerido: $requiredCheck" -ForegroundColor Cyan
Write-Host ""
Write-Host "NOTA: '$requiredCheck' debe existir en GitHub (ejecuta el workflow CI al menos una vez antes)." -ForegroundColor Yellow
Write-Host ""

$payload = @{
    required_status_checks = @{
        strict = $true
        contexts = @($requiredCheck)
    }
    enforce_admins = $true
    required_pull_request_reviews = @{
        required_approving_review_count = 0
        dismiss_stale_reviews = $true
    }
    restrictions = $null
    allow_force_pushes = $false
    allow_deletions = $false
    required_linear_history = $false
} | ConvertTo-Json -Depth 6

if ($DryRun) {
    Write-Host "Dry-run. Payload:" -ForegroundColor DarkGray
    Write-Host $payload
    exit 0
}

$payload | gh api `
    --method PUT `
    -H "Accept: application/vnd.github+json" `
    "repos/$Owner/$Repo/branches/$Branch/protection"

if ($LASTEXITCODE -ne 0) {
    Write-Host ""
    Write-Host "Si falla porque no existe el check '$requiredCheck':" -ForegroundColor Yellow
    Write-Host "  1. Haz push de .github/workflows/ci.yml" -ForegroundColor Yellow
    Write-Host "  2. Abre un PR o ejecuta Actions manualmente" -ForegroundColor Yellow
    Write-Host "  3. Vuelve a ejecutar este script" -ForegroundColor Yellow
    exit $LASTEXITCODE
}

Write-Host ""
Write-Host "Protección aplicada correctamente en '$Branch'." -ForegroundColor Green
Write-Host "Flujo: feature/* -> PR -> CI Gate verde -> merge a main" -ForegroundColor Green
