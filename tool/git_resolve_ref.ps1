<#
.SYNOPSIS
  Resuelve de forma segura un tag o ref de Git a su hash de commit en PowerShell.

.DESCRIPTION
  En PowerShell, sintaxis como `git rev-parse tag^{commit}` sin comillas hace que `^`
  y `{commit}` se interpreten como tokens del shell. Eso puede provocar errores como:

    fatal: ambiguous argument 'YwBvAG0AbQBpAHQA': unknown revision or path

  (Base64 UTF-16 de "commit" cuando el argumento se fragmenta o se pasa mal a git.)

  Use este script o comillas explícitas: git rev-parse "tag^{commit}"

.PARAMETER Ref
  Tag, rama u otra referencia de Git (ej. v1.4.1-migration-dry-run).

.EXAMPLE
  .\tool\git_resolve_ref.ps1 -Ref v1.4.1-migration-dry-run
#>
param(
    [Parameter(Mandatory = $true, Position = 0)]
    [string]$Ref
)

$ErrorActionPreference = 'Stop'

$resolved = & git rev-parse "${Ref}^{commit}" 2>&1
if ($LASTEXITCODE -ne 0) {
    Write-Error "No se pudo resolver '$Ref' a commit: $resolved"
    exit $LASTEXITCODE
}

Write-Output $resolved.Trim()
