# 📋 FORMATO DE CÓDIGOS QR PARA ASISTENCIA

## 🎯 Formato Estándar Recomendado

### JSON (Recomendado)
```json
{"nombres":"Juan Carlos","apellidos":"Pérez García","identificador":"12345"}
```

**Campos obligatorios:**
- `identificador`: Número de trabajador (UNIQUE)
- `nombres`: Nombres completos
- `apellidos`: Apellidos completos

### CSV (Alternativa)
```
Juan Carlos,Pérez García,12345
```
Formato: `nombres,apellidos,identificador`

### Simple (Solo identificador)
```
12345
```
Solo el número de trabajador

---

## 🔧 CÓDIGOS GENERADOS DESDE LA APP

Para generar códigos QR desde la app:

```dart
import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../core/utils/qr_encoding_helper.dart';

// Ejemplo de uso
final persona = PersonaAsistencia(
  id: '',
  nombres: 'Juan Carlos',
  apellidos: 'Pérez García',
  identificador: '12345',
);

// Generar código QR JSON
final qrCode = QREncodingHelper.generateQRCode(persona);
// Resultado: {"nombres":"Juan Carlos","apellidos":"Pérez García","identificador":"12345"}

// Generar widget QR
QrImageView(
  data: qrCode,
  size: 200,
  backgroundColor: Colors.white,
)
```

---

## ✅ REGLAS IMPORTANTES

### 1. **El identificador (número de trabajador) es OBLIGATORIO**
- Cada persona DEBE tener un número de trabajador único
- Sin identificador, no se puede votar en elecciones que requieren asistencia
- El sistema evita duplicados basándose en el identificador

### 2. **No se crean personas duplicadas**
- Al escanear un QR, el sistema busca por identificador
- Si ya existe una persona con ese identificador, NO crea duplicado
- Usa la persona existente para registrar asistencia

### 3. **Verificación de asistencia para votación**
- El sistema busca la persona por: UID, email O número de trabajador
- Si encuentra coincidencia en cualquiera de estos campos, verifica asistencia
- Sin persona en la colección `personas` con su identificador, no puede votar

### 4. **Registro manual vs Escaneo QR**
**Registro Manual:**
- Selecciona persona existente de la lista
- O crea persona nueva con nombres, apellidos e identificador obligatorios
- Valida que no exista persona con mismo identificador antes de crear

**Escaneo QR:**
- Busca persona por código QR exacto
- Si no encuentra, busca por identificador en el QR
- Si no encuentra, crea nueva persona
- **IMPORTANTE**: Si el QR tiene identificador, NO crea duplicado

---

## 🐛 PROBLEMAS RESUELTOS

### ❌ ANTES (Problemas)
1. Registro manual creaba personas con nombres = identificador
2. No validaba duplicados de personas
3. Identificador era opcional
4. Verificación de asistencia fallaba
5. QR solo funcionaba si contenía código exacto

### ✅ AHORA (Soluciones)
1. ✅ Registro manual usa ID de Firestore directamente
2. ✅ Valida que persona no exista por identificador antes de crear
3. ✅ Identificador ahora es OBLIGATORIO
4. ✅ Verificación busca por UID, email O número de trabajador
5. ✅ QR soporta JSON, CSV o solo identificador

---

## 📝 EJEMPLOS DE USO

### Ejemplo 1: Generar QR para socio existente
```dart
final persona = PersonaAsistencia(
  id: 'abc123',
  nombres: 'María',
  apellidos: 'González López',
  identificador: '67890',
);

final qrJSON = QREncodingHelper.generateQRCode(persona);
// {"nombres":"María","apellidos":"González López","identificador":"67890"}
```

### Ejemplo 2: Escanear QR y registrar asistencia
```dart
// El sistema automáticamente:
// 1. Parsea el código QR (JSON, CSV o simple)
// 2. Busca persona por identificador
// 3. Si no existe, la crea
// 4. Registra asistencia si no existe duplicado
// 5. Retorna null si ya tenía asistencia
```

### Ejemplo 3: Verificar asistencia para votar
```dart
// El sistema verifica automáticamente:
// 1. Obtiene usuario actual (UID, email, employeeNumber)
// 2. Busca persona por cada identificador
// 3. Si encuentra persona, verifica asistencia en evento
// 4. Retorna true/false para habilitar/deshabilitar voto
```

---

## 🔄 MIGRACIÓN DE DATOS

Si tienes personas sin identificador en Firestore:

1. Ve a la sección "Socios"
2. Edita cada persona
3. Agrega su número de trabajador
4. Guarda los cambios

**Las personas sin identificador:**
- ❌ No pueden votar en elecciones que requieren asistencia
- ❌ Generan error en registro manual
- ⚠️ Pueden generar duplicados si escanean QR sin identificador

---

## 📊 ESTRUCTURA DE DATOS

### Colección `personas`
```json
{
  "id": "abc123",
  "nombres": "Juan Carlos",
  "apellidos": "Pérez García",
  "identificador": "12345",
  "codigoQR": "{\"nombres\":\"Juan Carlos\",\"apellidos\":\"Pérez García\",\"identificador\":\"12345\"}"
}
```

### Colección `asistencias`
```json
{
  "id": "xyz789",
  "eventoId": "evento123",
  "personaId": "abc123",
  "asistio": true,
  "metodoRegistro": "escaneoQr",
  "fechaRegistro": 1712000000000
}
```

---

## ⚠️ IMPORTANTE

1. **El campo `identificador` en personas es UNIQUE**
   - Dos personas no pueden tener el mismo número de trabajador
   - El sistema valida esto antes de crear

2. **Las asistencias se validan por `eventoId + personaId`**
   - Una persona solo puede registrarse una vez por evento
   - El sistema retorna null si ya existe asistencia

3. **Para votar, se requiere:**
   - Usuario autenticado
   - Persona en colección `personas` con su identificador
   - Asistencia registrada para el evento vinculado a la elección

4. **Formatos de QR soportados:**
   - JSON con 3 campos (recomendado)
   - CSV con 3 campos
   - Solo identificador (cadena de texto)
