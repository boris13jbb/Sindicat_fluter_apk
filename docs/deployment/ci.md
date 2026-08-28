# CI/CD — VotaSind

Pipeline de integración continua para validar cada push y pull request antes de desplegar.

## Flujo obligatorio hacia `main`

Ver **`docs/deployment/git-workflow.md`** — resumen:

```text
feature/... → Pull Request → CI Gate ✅ → merge a main
```

## Qué ejecuta el pipeline

| Job (GitHub) | Qué valida |
|--------------|------------|
| **Flutter Analyze & Tests** | `dart format`, `dart analyze`, `flutter test` |
| **Cloud Functions** | `cd functions && npm run check` |
| **Security Rules** | emulador Firestore + `npm run test:rules` |
| **CI Gate** | Los 3 anteriores deben estar en verde (requerido para merge) |

## GitHub Actions

Workflow: `.github/workflows/ci.yml`

Se dispara en:

- **Pull Request** hacia `main`
- **Push** a `main`, `feature/**`, `fix/**`, `hotfix/**`

### Proteger `main` (una vez)

Tras el primer CI exitoso en GitHub:

```powershell
.\tool\setup_branch_protection.ps1
```

Esto exige **CI Gate** verde y Pull Request antes de merge.

## GitLab CI

Archivo: `.gitlab-ci.yml`

Mismas tres etapas: `flutter_quality`, `functions_test`, `firestore_rules`.

## Verificación local (recomendada antes de push)

### Windows

```powershell
cd D:\Sindicat_fluter_apk
.\tool\verify.ps1
```

Sin emulador (más rápido, no sustituye certificación completa):

```powershell
.\tool\verify.ps1 -SkipRules
```

### Linux / macOS / GitHub Actions local

```bash
cd /ruta/al/proyecto
bash tool/verify.sh
```

Solo reglas Firestore:

```bash
bash tool/test_firebase_rules.sh
```

## Requisitos locales para reglas

- Node.js 22+
- Java 17+ (emulador Firestore)
- `npm install` en la raíz del repo
- Firebase CLI (`npm install -g firebase-tools`)

## Política de merge

No fusionar ni desplegar a producción si falla cualquiera de:

1. `flutter analyze`
2. `flutter test`
3. `npm test` (functions)
4. `npm run test:rules` (emulador)

## Deploy (manual, fuera del CI)

El pipeline **no despliega** automáticamente. Tras un CI verde:

```powershell
firebase deploy --only firestore:rules
# o el subset que corresponda (functions, hosting, etc.)
```

Ver `docs/deployment/deployment-guide.md`.

## Extensión futura

- Deploy preview de Hosting en PR (requiere `FIREBASE_TOKEN` o Workload Identity).
- App Check en `lookupMemberByEmployee`.
- Job de build Android release firmado (secrets de keystore).
