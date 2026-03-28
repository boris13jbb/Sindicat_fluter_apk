#!/usr/bin/env pwsh
# Script de Monitoreo en Tiempo Real para el Fix de Candidatos
# Este script monitorea los logs de la aplicación Flutter en busca del problema de streams

param(
    [switch]$WatchOnly,
    [switch]$SaveLogs
)

$timestamp = Get-Date -Format "yyyy-MM-dd_HH-mm-ss"
$logFile = "logs_candidatos_$timestamp.txt"

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "MONITOREO DE STREAMS - CANDIDATOS" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Buscando procesos de Flutter..." -ForegroundColor Yellow

# Intentar encontrar el proceso de Flutter
$flutterProcess = Get-Process | Where-Object { $_.ProcessName -like "*flutter*" -or $_.MainWindowTitle -like "*Flutter*" }

if ($flutterProcess) {
    Write-Host "✓ Aplicación Flutter detectada: $($flutterProcess.ProcessName)" -ForegroundColor Green
} else {
    Write-Host "⚠ No se detectó aplicación Flutter corriendo" -ForegroundColor Yellow
    Write-Host "  Ejecuta: flutter run" -ForegroundColor Gray
    Write-Host ""
}

Write-Host ""
Write-Host "Iniciando monitoreo de logs..." -ForegroundColor Yellow
Write-Host "Presiona Ctrl+C para detener" -ForegroundColor Gray
Write-Host ""

# Contadores para estadísticas
$global:streamStartCount = 0
$global:snapshotReceivedCount = 0
$global:deserializedCount = 0
$global:emptySnapshotCount = 0
$global:errorCount = 0
$global:streamBuilderActiveCount = 0
$global:streamBuilderEmptyCount = 0

# Función para procesar cada línea de log
function Process-LogLine {
    param([string]$line)
    
    $timestamp = Get-Date -Format "HH:mm:ss.fff"
    
    # Mostrar siempre la línea completa
    Write-Host "[$timestamp] $line" -ForegroundColor Gray
    
    # Buscar patrones específicos
    if ($line -match "getCandidates: Starting stream") {
        $script:streamStartCount++
        Write-Host "  └─ 📡 Stream iniciado #$streamStartCount" -ForegroundColor Cyan
    }
    
    if ($line -match "getCandidates: Snapshot received - (\d+) documents") {
        $count = [int]$matches[1]
        $script:snapshotReceivedCount++
        
        if ($count -eq 0) {
            $script:emptySnapshotCount++
            Write-Host "  └─ ⚠️ SNAPSHOT VACÍO #$emptySnapshotCount (Posible causa del problema!)" -ForegroundColor Red
        } else {
            Write-Host "  └─ ✅ Snapshot #$snapshotReceivedCount con $count documentos" -ForegroundColor Green
        }
    }
    
    if ($line -match "getCandidates: Deserialized (\d+) candidates:") {
        $count = [int]$matches[1]
        $script:deserializedCount++
        
        if ($count -gt 0) {
            $candidates = $matches[2]
            Write-Host "  └─ ✅ Deserializados $count candidatos: $candidates" -ForegroundColor Green
        } else {
            Write-Host "  └─ ⚠️ Deserializados 0 candidatos" -ForegroundColor Yellow
        }
    }
    
    if ($line -match "getCandidates: Is from cache:") {
        $cacheStatus = $line -replace ".*getCandidates: Is from cache: ", ""
        if ($cacheStatus -eq "true") {
            Write-Host "  └─ 💾 Datos desde caché local" -ForegroundColor DarkGray
        } else {
            Write-Host "  └─ 🌐 Datos desde servidor" -ForegroundColor DarkGray
        }
    }
    
    if ($line -match "getCandidates: Has pending writes:") {
        $pendingStatus = $line -replace ".*getCandidates: Has pending writes: ", ""
        if ($pendingStatus -eq "true") {
            Write-Host "  └─ ✏️ Escrituras pendientes detectadas" -ForegroundColor DarkCyan
        }
    }
    
    if ($line -match "getCandidates: ERROR en el stream") {
        $script:errorCount++
        Write-Host "  └─ ❌ ERROR EN STREAM #$errorCount" -ForegroundColor Red
        Write-Host "     Mensaje: $($line -replace '.*ERROR en el stream - ', '')" -ForegroundColor Red
    }
    
    if ($line -match "StreamBuilder: ConnectionState = (\w+), hasData = (\w+)") {
        $state = $matches[1]
        $hasData = $matches[2]
        
        if ($state -eq "active" -and $hasData -eq "True") {
            $script:streamBuilderActiveCount++
            Write-Host "  └─ 🟢 StreamBuilder ACTIVO #$streamBuilderActiveCount" -ForegroundColor Green
        }
    }
    
    if ($line -match "StreamBuilder: Sin datos o lista vacía") {
        $script:streamBuilderEmptyCount++
        Write-Host "  └─ 🔴 StreamBuilder muestra VACÍO #$streamBuilderEmptyCount" -ForegroundColor Red
    }
    
    if ($line -match "StreamBuilder: Mostrando (\d+) candidatos") {
        $count = [int]$matches[1]
        Write-Host "  └─ ✅ MOSTRANDO $count candidatos en UI" -ForegroundColor Green
        Write-Host "     └─ ¡ESTO ES LO QUE ESPERAMOS VER!" -ForegroundColor DarkGreen
    }
    
    if ($line -match "_VotingContentState: Stream inicializado") {
        Write-Host "  └─ 🎯 Instancia de servicio creada correctamente" -ForegroundColor Cyan
    }
    
    if ($line -match "_VotingContentState: Dispose") {
        Write-Host "  └─ 🗑️ Widget disposed (limpieza de stream)" -ForegroundColor DarkGray
    }
}

# Intentar leer desde diferentes fuentes
try {
    if ($SaveLogs) {
        Write-Host "Guardando logs en: $logFile" -ForegroundColor Yellow
    }
    
    # Método 1: Leer desde stdout de flutter run (si está corriendo en esta terminal)
    # Método 2: Leer desde archivos de log de Android/iOS
    # Método 3: Leer desde el buffer de la terminal
    
    Write-Host ""
    Write-Host "Métodos de monitoreo disponibles:" -ForegroundColor Cyan
    Write-Host "  1. Si estás ejecutando 'flutter run' en esta terminal:" -ForegroundColor White
    Write-Host "     - Los logs aparecerán automáticamente arriba" -ForegroundColor Gray
    Write-Host ""
    Write-Host "  2. Si la app ya está corriendo en otro lado:" -ForegroundColor White
    Write-Host "     - Ejecuta: flutter logs | Select-String 'getCandidates|StreamBuilder'" -ForegroundColor Gray
    Write-Host "     - O usa el Device Logging en DevTools" -ForegroundColor Gray
    Write-Host ""
    Write-Host "  3. Para ver logs de Android:" -ForegroundColor White
    Write-Host "     adb logcat | Select-String 'flutter|getCandidates'" -ForegroundColor Gray
    Write-Host ""
    Write-Host "  4. Para ver logs de iOS:" -ForegroundColor White
    Write-Host "     tail -f ~/Library/Logs/CoreSimulator/*/system.log | grep flutter" -ForegroundColor Gray
    Write-Host ""
    
    # Monitoreo interactivo
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host "PATRONES A BUSCAR MANUALMENTE" -ForegroundColor Cyan
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "✅ SECUENCIA CORRECTA (lo que queremos ver):" -ForegroundColor Green
    Write-Host "  1. getCandidates: Starting stream for election XYZ" -ForegroundColor DarkGreen
    Write-Host "  2. getCandidates: Snapshot received - X documents (X > 0)" -ForegroundColor DarkGreen
    Write-Host "  3. getCandidates: Deserialized X candidates: Nombre1, Nombre2..." -ForegroundColor DarkGreen
    Write-Host "  4. StreamBuilder: Mostrando X candidatos" -ForegroundColor DarkGreen
    Write-Host ""
    Write-Host "❌ SECUENCIA PROBLEMÁTICA (lo que NO queremos ver):" -ForegroundColor Red
    Write-Host "  1. getCandidates: Snapshot received - X documents ✓" -ForegroundColor DarkRed
    Write-Host "  2. getCandidates: Deserialized X candidates ✓" -ForegroundColor DarkRed
    Write-Host "  3. getCandidates: Snapshot received - 0 documents ❌" -ForegroundColor DarkRed
    Write-Host "  4. StreamBuilder: Sin datos o lista vacía ❌" -ForegroundColor DarkRed
    Write-Host ""
    Write-Host "🔍 POSIBLES CAUSAS SI DESAPARECEN:" -ForegroundColor Yellow
    Write-Host "  - Segundo snapshot vacío desde Firestore" -ForegroundColor DarkYellow
    Write-Host "  - Error silencioso después del primer snapshot exitoso" -ForegroundColor DarkYellow
    Write-Host "  - Índice de Firestore faltante causando error diferido" -ForegroundColor DarkYellow
    Write-Host "  - Stream que se cierra prematuramente" -ForegroundColor DarkYellow
    Write-Host ""
    
    # Loop de monitoreo
    while ($true) {
        Start-Sleep -Milliseconds 500
        
        # Actualizar estadísticas cada segundo
        if ((Get-Date).Millisecond -lt 100) {
            Clear-Host
            Write-Host "========================================" -ForegroundColor Cyan
            Write-Host "ESTADÍSTICAS EN TIEMPO REAL" -ForegroundColor Cyan
            Write-Host "========================================" -ForegroundColor Cyan
            Write-Host "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" -ForegroundColor DarkGray
            Write-Host ""
            Write-Host "Streams Iniciados:          $script:streamStartCount" -ForegroundColor Cyan
            Write-Host "Snapshots Recibidos:        $script:snapshotReceivedCount" -ForegroundColor Cyan
            Write-Host "  ├─ Con datos:             $($script:snapshotReceivedCount - $script:emptySnapshotCount)" -ForegroundColor Green
            Write-Host "  └─ Vacíos:                $script:emptySnapshotCount" -ForegroundColor $(if ($emptySnapshotCount -gt 0) {"Red"} else {"DarkGray"})
            Write-Host "Candidatos Deserializados:  $script:deserializedCount" -ForegroundColor Cyan
            Write-Host "StreamBuilder Activo:       $script:streamBuilderActiveCount" -ForegroundColor Cyan
            Write-Host "StreamBuilder Vacío:        $script:streamBuilderEmptyCount" -ForegroundColor $(if ($streamBuilderEmptyCount -gt 0) {"Red"} else {"DarkGray"})
            Write-Host "Errores en Stream:          $script:errorCount" -ForegroundColor $(if ($errorCount -gt 0) {"Red"} else {"DarkGray"})
            Write-Host ""
            
            if ($emptySnapshotCount -gt 0) {
                Write-Host "⚠️ ALERTA: Se detectaron snapshots vacíos!" -ForegroundColor Red
                Write-Host "   Esto podría ser la causa de que los candidatos desaparezcan." -ForegroundColor Yellow
                Write-Host ""
            }
            
            if ($errorCount -gt 0) {
                Write-Host "❌ ALERTA: Se detectaron errores en el stream!" -ForegroundColor Red
                Write-Host "   Revisa los logs completos para ver el detalle del error." -ForegroundColor Yellow
                Write-Host ""
            }
            
            Write-Host "Presiona Ctrl+C para salir..." -ForegroundColor Gray
        }
    }
}
catch {
    Write-Host ""
    Write-Host "Monitoreo detenido." -ForegroundColor Yellow
}
finally {
    Write-Host ""
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host "RESUMEN FINAL" -ForegroundColor Cyan
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host "Streams Iniciados:           $script:streamStartCount" -ForegroundColor Cyan
    Write-Host "Snapshots Recibidos:         $script:snapshotReceivedCount" -ForegroundColor Cyan
    Write-Host "  ├─ Con datos:              $($script:snapshotReceivedCount - $script:emptySnapshotCount)" -ForegroundColor Green
    Write-Host "  └─ Vacíos:                 $script:emptySnapshotCount" -ForegroundColor $(if ($emptySnapshotCount -gt 0) {"Red"} else {"DarkGray"})
    Write-Host "Candidatos Deserializados:   $script:deserializedCount" -ForegroundColor Cyan
    Write-Host "StreamBuilder Vacío:         $script:streamBuilderEmptyCount" -ForegroundColor $(if ($streamBuilderEmptyCount -gt 0) {"Red"} else {"DarkGray"})
    Write-Host "Errores Detectados:          $script:errorCount" -ForegroundColor $(if ($errorCount -gt 0) {"Red"} else {"DarkGray"})
    Write-Host ""
    
    if ($emptySnapshotCount -eq 0 -and $errorCount -eq 0 -and $streamBuilderEmptyCount -eq 0) {
        Write-Host "✅ ¡TODO FUNCIONA CORRECTAMENTE!" -ForegroundColor Green
        Write-Host "   Los candidatos deberían permanecer visibles." -ForegroundColor DarkGreen
    } else {
        Write-Host "⚠️ PROBLEMAS DETECTADOS:" -ForegroundColor Red
        if ($emptySnapshotCount -gt 0) { Write-Host "  - Snapshots vacíos recibidos" -ForegroundColor Red }
        if ($errorCount -gt 0) { Write-Host "  - Errores en el stream" -ForegroundColor Red }
        if ($streamBuilderEmptyCount -gt 0) { Write-Host "  - StreamBuilder muestra vacío" -ForegroundColor Red }
        Write-Host ""
        Write-Host "Revisa el archivo FIX_AVANZADO_CANDIDATOS_STREAM.md para soluciones." -ForegroundColor Yellow
    }
    
    Write-Host ""
    Write-Host "Logs guardados en: $logFile" -ForegroundColor Yellow
}
