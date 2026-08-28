# Flujo Git — feature → PR → CI → main

Política de entrega para **VotaSind**: ningún cambio llega a `main` sin Pull Request y sin CI en verde.

## Diagrama

```text
Nueva función / fix
        ↓
rama feature/nombre-corto
        ↓
Pull Request → main
        ↓
┌─────────────────────────────────┐
│  CI (GitHub Actions)            │
│  • Flutter Analyze & Tests  ✅  │
│  • Cloud Functions          ✅  │
│  • Security Rules           ✅  │
│  • Migration Tests          ✅  │
│  • CI Gate                  ✅  │
└─────────────────────────────────┘
        ↓
   merge a main
```

## 1. Crear rama desde main

```powershell
cd D:\Sindicat_fluter_apk
git checkout main
git pull origin main
git checkout -b feature/mi-nueva-funcion
```

Convención de ramas:

| Prefijo | Uso |
|---------|-----|
| `feature/` | Funcionalidad nueva |
| `fix/` | Corrección de bug |
| `hotfix/` | Urgente en producción |

## 2. Desarrollar y validar localmente

```powershell
.\tool\verify.ps1
```

Equivale a: formato, `dart analyze`, `flutter test`, `functions` tests y reglas Firestore en emulador.

## 3. Commit y push

```powershell
git add .
git commit -m "feat: descripción breve del cambio"
git push -u origin feature/mi-nueva-funcion
```

## 4. Abrir Pull Request hacia `main`

```powershell
gh pr create --base main --title "feat: mi nueva función" --body-file .github/pull_request_template.md
```

O desde GitHub: **Compare & pull request** → base: `main`.

## 5. Esperar CI (obligatorio)

El workflow `.github/workflows/ci.yml` debe mostrar **5 checks verdes**:

1. **Flutter Analyze & Tests** — analyze + tests Flutter
2. **Cloud Functions** — `npm run check` en `functions/`
3. **Security Rules** — emulador + `firebase_rules_test`
4. **Migration Tests** — `npm test` en `tool/migrations/` (fixtures, sin producción)
5. **CI Gate** — confirma que los 4 anteriores pasaron

**No hacer merge** si alguno está rojo o pendiente.

## 6. Merge a main

Solo cuando **CI Gate** esté en verde:

- Merge con **Squash merge** o **Merge commit** (según preferencia del equipo).
- Borrar la rama `feature/...` tras el merge.

## Protección de rama `main`

`main` debe exigir:

- Pull Request antes de merge
- Status check requerido: **CI Gate**
- Sin push directo a `main` (salvo emergencia documentada)

### Activar protección (una vez, tras el primer CI en GitHub)

```powershell
.\tool\setup_branch_protection.ps1
```

Requisito: el workflow CI debe haber corrido al menos una vez en el repo para que GitHub reconozca el check **CI Gate**.

## PowerShell y referencias Git (`^{commit}`)

En **PowerShell**, no ejecutar sin comillas:

```powershell
git rev-parse v1.4.1-migration-dry-run^{commit}
```

El carácter `^` y las llaves pueden fragmentar el argumento; Git puede recibir solo `commit` y fallar con:

```text
fatal: ambiguous argument 'YwBvAG0AbQBpAHQA': unknown revision or path
```

(`YwBvAG0AbQBpAHQA` es la cadena `commit` en Base64 UTF-16, típico de invocaciones con `-EncodedCommand`.)

**Forma segura:**

```powershell
git rev-parse "v1.4.1-migration-dry-run^{commit}"
# o
.\tool\git_resolve_ref.ps1 -Ref v1.4.1-migration-dry-run
```

En Bash no aplica este problema; use comillas si el shell lo requiere.

## Qué NO hacer

- Push directo a `main` con código sin revisar
- Merge con CI fallido o omitido
- `--no-verify` en hooks si bloquean por calidad
- Desplegar a producción sin CI verde en el commit que se despliega

## Referencias

- CI detallado: `docs/deployment/ci.md`
- Verificación local: `tool/verify.ps1`
- Seguridad members: `docs/security-members.md`
