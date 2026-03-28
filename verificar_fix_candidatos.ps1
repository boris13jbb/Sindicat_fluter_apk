#!/usr/bin/env pwsh
# Script de Verificación del Fix de Candidatos
# Este script ayuda a verificar que los candidatos se están creando y mostrando correctamente

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Verificación del Fix - Candidatos" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Paso 1: Verificar que Flutter esté instalado
Write-Host "1. Verificando Flutter..." -ForegroundColor Yellow
$flutterVersion = flutter --version
if ($LASTEXITCODE -eq 0) {
    Write-Host "✓ Flutter está instalado" -ForegroundColor Green
} else {
    Write-Host "✗ Error: Flutter no está instalado o no está en el PATH" -ForegroundColor Red
    exit 1
}

Write-Host ""

# Paso 2: Verificar dependencias
Write-Host "2. Verificando dependencias..." -ForegroundColor Yellow
flutter pub get
if ($LASTEXITCODE -eq 0) {
    Write-Host "✓ Dependencias verificadas" -ForegroundColor Green
} else {
    Write-Host "✗ Error al obtener dependencias" -ForegroundColor Red
    exit 1
}

Write-Host ""

# Paso 3: Análisis estático del código
Write-Host "3. Ejecutando análisis estático..." -ForegroundColor Yellow
flutter analyze
if ($LASTEXITCODE -eq 0) {
    Write-Host "✓ No se encontraron errores de análisis" -ForegroundColor Green
} else {
    Write-Host "⚠ Se encontraron advertencias en el análisis (puede continuar)" -ForegroundColor Yellow
}

Write-Host ""

# Paso 4: Instrucciones para el usuario
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Próximos Pasos - Prueba Manual" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Sigue estos pasos para verificar el fix:" -ForegroundColor White
Write-Host ""
Write-Host "1. Ejecuta la aplicación:" -ForegroundColor Yellow
Write-Host "   flutter run -d chrome" -ForegroundColor Gray
Write-Host ""
Write-Host "2. Inicia sesión con una cuenta de administrador" -ForegroundColor Yellow
Write-Host ""
Write-Host "3. Navega a 'Editar Elección' y selecciona una elección" -ForegroundColor Yellow
Write-Host ""
Write-Host "4. Agrega un nuevo candidato:" -ForegroundColor Yellow
Write-Host "   - Haz clic en 'Agregar Candidato'" -ForegroundColor Gray
Write-Host "   - Completa el nombre (reququerido)" -ForegroundColor Gray
Write-Host "   - Opcional: descripción, URL de imagen, orden" -ForegroundColor Gray
Write-Host "   - Haz clic en 'Agregar Candidato'" -ForegroundColor Gray
Write-Host ""
Write-Host "5. Observa la consola (VS Code / Terminal):" -ForegroundColor Yellow
Write-Host "   Deberías ver mensajes como:" -ForegroundColor Gray
Write-Host "   - 'addCandidate: Starting to add candidate...'" -ForegroundColor DarkGray
Write-Host "   - 'addCandidate: Data to be saved: {...}'" -ForegroundColor DarkGray
Write-Host "   - 'addCandidate: Successfully added candidate with ID: ...'" -ForegroundColor DarkGray
Write-Host "   - 'getCandidates: Retrieved X candidates...'" -ForegroundColor DarkGray
Write-Host "   - 'getCandidates: Deserialized X candidates: Nombre1, Nombre2, ...'" -ForegroundColor DarkGray
Write-Host ""
Write-Host "6. Verifica en la UI:" -ForegroundColor Yellow
Write-Host "   - El candidato debe aparecer inmediatamente en la lista" -ForegroundColor Gray
Write-Host "   - En Firestore Console: elections/{id}/candidates/{id}" -ForegroundColor Gray
Write-Host ""
Write-Host "7. Verifica en Firebase Console:" -ForegroundColor Yellow
Write-Host "   - Ve a: https://console.firebase.google.com" -ForegroundColor Gray
Write-Host "   - Selecciona tu proyecto" -ForegroundColor Gray
Write-Host "   - Firestore Database" -ForegroundColor Gray
Write-Host "   - Navega a: elections/{electionId}/candidates" -ForegroundColor Gray
Write-Host "   - Verifica que el documento tenga los campos:" -ForegroundColor Gray
Write-Host "     * id: string" -ForegroundColor DarkGray
Write-Host "     * electionId: string (DEBE COINCIDIR con el ID de la elección)" -ForegroundColor DarkGray
Write-Host "     * name: string" -ForegroundColor DarkGray
Write-Host "     * order: number (debe ser 0 si no se especificó)" -ForegroundColor DarkGray
Write-Host "     * voteCount: number (inicialmente 0)" -ForegroundColor DarkGray
Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Posibles Problemas y Soluciones" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "PROBLEMA: Los candidatos aparecen en Firestore pero NO en la UI" -ForegroundColor Red
Write-Host "SOLUCIÓN:" -ForegroundColor Yellow
Write-Host "  1. Revisa la consola en busca de errores sobre índices de Firestore" -ForegroundColor Gray
Write-Host "  2. Si ves un error sobre índices, crea el índice desde el enlace proporcionado" -ForegroundColor Gray
Write-Host "  3. O ve a: Firebase Console > Firestore > Indexes > Create Index" -ForegroundColor Gray
Write-Host "  4. Configura: Collection: candidates, Field: order (Ascending)" -ForegroundColor Gray
Write-Host ""
Write-Host "PROBLEMA: Error de permisos / Acceso denegado" -ForegroundColor Red
Write-Host "SOLUCIÓN:" -ForegroundColor Yellow
Write-Host "  1. Verifica que estás autenticado en la app" -ForegroundColor Gray
Write-Host "  2. Revisa las reglas en firestore.rules (ya están correctas)" -ForegroundColor Gray
Write-Host "  3. Verifica en Firebase Console > Authentication que el usuario existe" -ForegroundColor Gray
Write-Host ""
Write-Host "PROBLEMA: Candidatos antiguos no aparecen" -ForegroundColor Red
Write-Host "SOLUCIÓN:" -ForegroundColor Yellow
Write-Host "  Los candidatos creados antes del fix pueden no tener el campo 'order'" -ForegroundColor Gray
Write-Host "  Para solucionarlo:" -ForegroundColor Gray
Write-Host "  1. Ve a Firebase Console > Firestore" -ForegroundColor Gray
Write-Host "  2. Navega a cada candidato antiguo" -ForegroundColor Gray
Write-Host "  3. Agrega el campo 'order' de tipo número con valor 0" -ForegroundColor Gray
Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Estado del Fix" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Archivos modificados:" -ForegroundColor Yellow
Write-Host "  ✓ lib/services/election_service.dart" -ForegroundColor Green
Write-Host "  ✓ lib/core/models/candidate.dart" -ForegroundColor Green
Write-Host ""
Write-Host "Mejoras aplicadas:" -ForegroundColor Yellow
Write-Host "  ✓ orderBy explícito con dirección (descending: false)" -ForegroundColor Green
Write-Host "  ✓ Validación del campo 'order' al guardar" -ForegroundColor Green
Write-Host "  ✓ Logging detallado para debugging" -ForegroundColor Green
Write-Host "  ✓ Manejo de errores mejorado" -ForegroundColor Green
Write-Host "  ✓ Extracción robusta de electionId" -ForegroundColor Green
Write-Host ""
Write-Host "Reglas de seguridad:" -ForegroundColor Yellow
Write-Host "  ✓ firestore.rules - Sin cambios necesarios (ya son correctas)" -ForegroundColor Green
Write-Host ""
Write-Host "Presiona cualquier tecla para salir..." -ForegroundColor Gray
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
