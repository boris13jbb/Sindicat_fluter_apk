# 🔧 Solución: Error en la Función de Agregar Candidatos

## Resumen del Problema

Al intentar agregar candidatos a una elección desde la pantalla "Editar Elección", la aplicación falló con el siguiente error:

```
'package:flutter/src/material/dropdown.dart': Failed assertion: line 1830 pos 10: 
'items == null || items.isEmpty ||
(initialValue == null && value == null) ||
items
.where((DropdownMenuItem<T> item) => item.value == (initialValue ?? value))
.length ==
1': There should be exactly one item with [DropdownButton]'s value: 1. 
Either zero or 2 or more [DropdownMenuItem]s were detected with the same value
```

## Análisis de la Causa Raíz

### Ubicación del Problema
**Archivo:** `lib/features/elections/edit_election_screen.dart`  
**Líneas:** 197-225 (DropdownButtonFormField para "Evento de asistencia")

### Detalles Técnicos

El error ocurrió en el widget `DropdownButtonFormField` que muestra los eventos de asistencia cuando se activa el interruptor "Requerir asistencia". El problema fue causado por:

1. **Uso de `initialValue` en lugar de `value`**: El dropdown usaba `initialValue: _eventoAsistenciaId`, que solo se verifica una vez cuando el widget se crea por primera vez. Cuando el stream emite nuevos datos o el widget se reconstruye, Flutter no revalida el `initialValue`.

2. **Validación de valor faltante**: El `_eventoAsistenciaId` podía contener un valor que:
   - No existe en la lista actual de eventos
   - Aún no se ha cargado desde el stream de Firestore
   - Era de un evento eliminado

3. **Sin manejo del estado de carga**: El dropdown se construía inmediatamente sin verificar si los datos del stream aún se estaban cargando, causando que la lista de elementos estuviera vacía inicialmente.

### Requisitos de DropdownButton

El `DropdownButton` de Flutter tiene un requisito estricto:
- Si se proporciona un `value` (o `initialValue`), **DEBE** coincidir exactamente con UN elemento en la lista `items`
- Si el valor no coincide con ningún elemento o coincide con múltiples elementos, la aserción falla

## Solución Implementada

### Cambios Realizados

**Archivo:** `lib/features/elections/edit_election_screen.dart`

#### 1. Agregada Verificación de Estado de Carga
```dart
if (snap.connectionState == ConnectionState.waiting) {
  return const CircularProgressIndicator();
}
```
Esto previene que el dropdown se construya con una lista vacía de elementos mientras se cargan los datos.

#### 2. Lógica de Validación de Valor
```dart
final isValidValue = _eventoAsistenciaId == null || 
    eventos.any((e) => e.id == _eventoAsistenciaId);
```
Esto asegura que el valor almacenado exista realmente en la lista actual de eventos.

#### 3. Cambio de `initialValue` a `value`
```dart
value: isValidValue ? _eventoAsistenciaId : null,
```
Usar `value` en lugar de `initialValue` hace que el dropdown sea reactivo y se revalide en cada reconstrucción.

### Solución Completa

```dart
if (_requireAttendance) ...[
  const SizedBox(height: 8),
  StreamBuilder<List<EventoAsistencia>>(
    stream: AsistenciaService().getAllEventos(),
    builder: (context, snap) {
      if (snap.connectionState == ConnectionState.waiting) {
        return const CircularProgressIndicator();
      }
      final eventos = snap.data ?? [];
      // Validar que _eventoAsistenciaId exista en la lista de eventos
      final isValidValue = _eventoAsistenciaId == null || 
          eventos.any((e) => e.id == _eventoAsistenciaId);
      
      return DropdownButtonFormField<String?>(
        value: isValidValue ? _eventoAsistenciaId : null,
        decoration: const InputDecoration(
          labelText: 'Evento de asistencia',
          border: OutlineInputBorder(),
        ),
        items: [
          const DropdownMenuItem(
            value: null,
            child: Text('Seleccionar evento'),
          ),
          ...eventos.map(
            (e) => DropdownMenuItem(
              value: e.id,
              child: Text(e.nombre),
            ),
          ),
        ],
        onChanged: (v) => setState(() => _eventoAsistenciaId = v),
      );
    },
  ),
],
```
```

## Lista de Verificación de Pruebas

### ✅ Flujo Corregido
1. **Navegar a la Pantalla de Edición de Elección**
   - Ir a la lista de elecciones
   - Hacer clic en editar en cualquier elección
   - La pantalla se carga sin errores

2. **Activar "Requerir asistencia"**
   - Activar el interruptor → aparece el dropdown
   - El estado de carga se muestra mientras se cargan los eventos desde Firestore
   - Sin error de aserción cuando se construye el dropdown

3. **Seleccionar Evento**
   - El dropdown muestra todos los eventos disponibles
   - Se puede seleccionar un evento exitosamente
   - La selección se mantiene al activar/desactivar el interruptor

4. **Agregar Candidato**
   - Hacer clic en el botón "Agregar Candidato"
   - Completar el formulario del candidato
   - Enviar exitosamente
   - El candidato aparece en la lista inmediatamente

5. **Verificar Integración con Firestore**
   - Documento del candidato creado en Firestore
   - Ruta del documento: `elections/{electionId}/candidates/{candidateId}`
   - Todos los campos guardados correctamente

### Comportamiento Esperado

- **Sin cierres inesperados** al editar elecciones con requerimiento de asistencia
- **Indicador de carga** aparece mientras se obtienen los eventos
- **Fallback seguro** a null si el ID de evento almacenado no existe
- **Actualizaciones reactivas** cuando cambia la lista de eventos
- **Flujo suave de agregación de candidatos**

## Archivos Relacionados

### Archivos Modificados
- ✅ `lib/features/elections/edit_election_screen.dart` - DropdownButtonFormField corregido

### Archivos Relacionados pero No Modificados
- ✅ `lib/features/elections/add_candidate_screen.dart` - UI del formulario de candidatos (funciona correctamente)
- ✅ `lib/services/election_service.dart` - Operaciones de Firestore (funciona correctamente)
- ✅ `lib/core/models/candidate.dart` - Modelo de datos (funciona correctamente)
- ✅ `firestore.rules` - Reglas de seguridad (configuradas correctamente)

## Mejoras Adicionales

### Mejores Prácticas Aplicadas

1. **Estados de Carga de StreamBuilder**: Siempre verificar `connectionState` antes de usar datos del stream
2. **Validación de Valor**: Verificar que los valores del dropdown existan en la lista de elementos
3. **Valor Reactivo**: Usar `value` en lugar de `initialValue` para dropdowns dinámicos
4. **Null Safety**: Proveer fallback seguro a `null` cuando el valor es inválido

### Calidad del Código

- ✅ Agregados comentarios claros explicando la lógica de validación
- ✅ Mantenido estilo de código consistente
- ✅ Sin cambios disruptivos en funcionalidades existentes
- ✅ Solución mínima y específica

## Notas de Despliegue

### Configuración de Firebase

Asegúrate de que las reglas de Firestore estén desplegadas correctamente:

```bash
firebase deploy --only firestore
```

O manualmente vía Firebase Console:
1. Ir a Firestore Database → Rules
2. Copiar contenido desde `firestore.rules`
3. Publicar

### Pruebas en Producción

Después del despliegue, verificar:
1. Se pueden agregar candidatos a elecciones existentes
2. Se pueden editar elecciones con requerimientos de asistencia
3. Se pueden eliminar candidatos sin errores
4. Los candidatos aparecen en tiempo real en todas las pantallas

## Resumen

**Problema:** Fallo de aserción de DropdownButton al editar elecciones  
**Causa Raíz:** Valor inválido en el dropdown debido a validación faltante y estado de carga  
**Solución:** Agregada verificación de carga, validación de valor y vinculación reactiva  
**Impacto:** Los usuarios ahora pueden agregar candidatos a elecciones sin cierres inesperados  
**Archivos Modificados:** 1 archivo (`edit_election_screen.dart`)  
**Cambios Disruptivos:** Ninguno  
**Compatible con Versiones Anteriores:** Sí  

---

**Corregido en:** 27 de Marzo, 2026  
**Probado en:** Windows Desktop  
**Estado:** ✅ Resuelto
