# Script para Cambiar Perfiles de Red - Lingma
# Este script permite cambiar rápidamente entre configuraciones de red para casa y oficina

param(
    [Parameter(Mandatory=$true)]
    [ValidateSet("office", "home")]
    [string]$Profile
)

# Configuración
$configPath = "C:\Users\boris\AppData\Local\.lingma\config.json"
$configDir = "C:\Users\boris\AppData\Local\.lingma"

# Colores para output
$GreenColor = [ConsoleColor]::Green
$CyanColor = [ConsoleColor]::Cyan
$YellowColor = [ConsoleColor]::Yellow
$RedColor = [ConsoleColor]::Red
$WhiteColor = [ConsoleColor]::White
$GrayColor = [ConsoleColor]::Gray

Write-Host "============================================" -ForegroundColor $CyanColor
Write-Host "  Configurador de Perfil de Red - Lingma" -ForegroundColor $CyanColor
Write-Host "============================================" -ForegroundColor $CyanColor
Write-Host ""

# Verificar si el directorio existe, si no crearlo
if (-not (Test-Path $configDir)) {
    Write-Host "Creando directorio de configuración..." -ForegroundColor $YellowColor
    New-Item -ItemType Directory -Force -Path $configDir | Out-Null
}

# Configurar según el perfil seleccionado
if ($Profile -eq "home") {
    # PERFIL CASA - Sin proxy, conexión directa
    $config = @{
        http_proxy = $null
        https_proxy = $null
        vpn_required = $false
        profile = "home"
        last_updated = (Get-Date -Format "yyyy-MM-ddTHH:mm:ssZ")
        timeout = 60000
        retry_count = 3
    } | ConvertTo-Json -Depth 10
    
    Write-Host "Configurando perfil CASA (sin proxy)..." -ForegroundColor $GreenColor
} else {
    # PERFIL OFICINA - Con proxy corporativo
    # IMPORTANTE: El usuario debe editar esta sección con sus datos reales
    $proxyUrl = "http://TU_USUARIO:TU_CONTRASEÑA@proxy.empresa.com:8080"
    
    # Verificar si el usuario necesita actualizar los datos del proxy
    if ($proxyUrl -like "*TU_USUARIO*") {
        Write-Host "" -ForegroundColor $RedColor
        Write-Host "ADVERTENCIA: Necesitas configurar los datos del proxy de tu oficina" -ForegroundColor $RedColor
        Write-Host "" -ForegroundColor $RedColor
        Write-Host "Edita este archivo y busca la línea con 'proxyUrl' (alrededor de la línea 45)" -ForegroundColor $YellowColor
        Write-Host "Reemplaza con los datos que te dio tu departamento de TI:" -ForegroundColor $YellowColor
        Write-Host "  - Dirección del proxy" -ForegroundColor $CyanColor
        Write-Host "  - Puerto" -ForegroundColor $CyanColor
        Write-Host "  - Usuario" -ForegroundColor $CyanColor
        Write-Host "  - Contraseña" -ForegroundColor $CyanColor
        Write-Host "" -ForegroundColor $RedColor
        Write-Host "Ejemplo:" -ForegroundColor $WhiteColor
        Write-Host '  $proxyUrl = "http://juan.perez:miPassword123@proxy.miempresa.com:8080"' -ForegroundColor $GrayColor
        Write-Host ""
        exit 1
    }
    
    $config = @{
        http_proxy = $proxyUrl
        https_proxy = $proxyUrl
        vpn_required = $true
        profile = "office"
        last_updated = (Get-Date -Format "yyyy-MM-ddTHH:mm:ssZ")
        timeout = 90000
        retry_count = 5
        proxy_bypass_list = @("localhost", "127.0.0.1")
    } | ConvertTo-Json -Depth 10
    
    Write-Host "Configurando perfil OFICINA (con proxy)..." -ForegroundColor $GreenColor
}

# Guardar configuración
try {
    $config | Set-Content -Path $configPath -Encoding UTF8 -Force
    Write-Host "✓ Configuración guardada exitosamente" -ForegroundColor $GreenColor
} catch {
    Write-Host "✗ Error al guardar la configuración: $_" -ForegroundColor $RedColor
    exit 1
}

Write-Host ""
Write-Host "============================================" -ForegroundColor $GreenColor
Write-Host "  Perfil '$Profile' activado correctamente" -ForegroundColor $GreenColor
Write-Host "============================================" -ForegroundColor $GreenColor
Write-Host ""
Write-Host "Próximos pasos:" -ForegroundColor $CyanColor
Write-Host "1. Cierra completamente tu IDE (Visual Studio / IntelliJ)" -ForegroundColor $WhiteColor
Write-Host "2. Espera 5 segundos" -ForegroundColor $WhiteColor
Write-Host "3. Vuelve a abrir el IDE" -ForegroundColor $WhiteColor
Write-Host "4. Inicia sesión en Lingma" -ForegroundColor $WhiteColor
Write-Host ""
Write-Host "Configuración aplicada:" -ForegroundColor $CyanColor

# Mostrar resumen de configuración
$configObj = $config | ConvertFrom-Json
if ($Profile -eq "home") {
    Write-Host "  - Proxy: DESACTIVADO (conexión directa)" -ForegroundColor $GreenColor
    Write-Host "  - VPN: NO requerida" -ForegroundColor $GreenColor
    Write-Host "  - Timeout: $($configObj.timeout)ms" -ForegroundColor $WhiteColor
} else {
    Write-Host "  - Proxy: ACTIVADO" -ForegroundColor $YellowColor
    Write-Host "  - VPN: REQUERIDA" -ForegroundColor $YellowColor
    Write-Host "  - Timeout: $($configObj.timeout)ms" -ForegroundColor $WhiteColor
}

Write-Host ""
Write-Host "Para verificar la configuración:" -ForegroundColor $CyanColor
Write-Host "  Get-Content $configPath" -ForegroundColor $GrayColor
Write-Host ""
