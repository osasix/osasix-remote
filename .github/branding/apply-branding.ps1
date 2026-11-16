# Aplica la marca de Osasix sobre una copia del codigo OFICIAL de RustDesk.
# Uso: powershell -ExecutionPolicy Bypass -File apply-branding.ps1 -Root <carpeta con el codigo de RustDesk>
# Los cambios criticos (servidor, clave, nombre) son obligatorios: si el codigo oficial
# cambia y no se encuentra el texto a sustituir, el script FALLA en vez de compilar un
# cliente que apunte al servidor de RustDesk.
param([Parameter(Mandatory = $true)][string]$Root)
$ErrorActionPreference = 'Stop'

# ---- Configuracion de Osasix (editar aqui) ---------------------------------------------
$Server    = 'remote.osasix.com'
$Key       = 'QrkfQHfIegqnGFpDLVMH8Q6dtjiB7TMAaOrzM361akI='
$AppName   = 'Osasix Remote'
$Company   = 'Osasix'
$Copyright = 'Copyright (c) 2026 Osasix. Based on RustDesk (AGPL-3.0).'
# ----------------------------------------------------------------------------------------

$Root = (Resolve-Path $Root).Path

function Replace-InFile {
    param([string]$Rel, [string]$Pattern, [string]$Replacement, [switch]$Required)
    $path = Join-Path $Root $Rel
    if (-not (Test-Path $path)) {
        if ($Required) { throw "No existe el archivo obligatorio: $Rel" }
        Write-Warning "No existe $Rel (se omite)"; return
    }
    $bytes = [System.IO.File]::ReadAllBytes($path)
    $bom = ($bytes.Length -ge 3 -and $bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF)
    $text = [System.Text.Encoding]::UTF8.GetString($bytes)
    if ($bom) { $text = $text.Substring(1) }
    $rx = New-Object System.Text.RegularExpressions.Regex($Pattern, 'Multiline')
    if (-not $rx.IsMatch($text)) {
        if ($Required) { throw "No se encontro el patron en ${Rel}: $Pattern" }
        Write-Warning "Patron no encontrado en ${Rel}: $Pattern"; return
    }
    $new = $rx.Replace($text, $Replacement)
    $enc = New-Object System.Text.UTF8Encoding($bom)
    [System.IO.File]::WriteAllText($path, $new, $enc)
    Write-Host "OK  $Rel  <- $Pattern"
}

# 1) Servidor, clave y nombre por defecto (OBLIGATORIO)
$cfg = 'libs/hbb_common/src/config.rs'
Replace-InFile $cfg '(APP_NAME: RwLock<String> = RwLock::new\()"[^"]*"' ('${1}"' + $AppName + '"') -Required
Replace-InFile $cfg '(pub const RENDEZVOUS_SERVERS: &\[&str\] = &\[)"[^"]*"(\];)' ('${1}"' + $Server + '"${2}') -Required
Replace-InFile $cfg '(pub const RS_PUB_KEY: &str = )"[^"]*"(;)' ('${1}"' + $Key + '"${2}') -Required

$cfgText = [System.IO.File]::ReadAllText((Join-Path $Root $cfg))
if (-not $cfgText.Contains($Server) -or -not $cfgText.Contains($Key) -or -not $cfgText.Contains($AppName)) {
    throw "Verificacion fallida: config.rs no contiene el servidor, la clave y el nombre esperados"
}

# 2) Metadatos del .exe de Windows (informativo)
$rc = 'flutter/windows/runner/Runner.rc'
Replace-InFile $rc '(VALUE "CompanyName", )"[^"]*"'     ('${1}"' + $Company + '"')
Replace-InFile $rc '(VALUE "FileDescription", )"[^"]*"' ('${1}"' + $AppName + '"')
Replace-InFile $rc '(VALUE "LegalCopyright", )"[^"]*"'  ('${1}"' + $Copyright + '"')
Replace-InFile $rc '(VALUE "ProductName", )"[^"]*"'     ('${1}"' + $AppName + '"')
Replace-InFile 'Cargo.toml' '^(ProductName = )"[^"]*"'     ('${1}"' + $AppName + '"')
Replace-InFile 'Cargo.toml' '^(FileDescription = )"[^"]*"' ('${1}"' + $AppName + '"')
Replace-InFile 'Cargo.toml' '^(LegalCopyright = )"[^"]*"'  ('${1}"' + $Copyright + '"')
Replace-InFile 'Cargo.toml' '^(name = )"RustDesk"'          ('${1}"' + $AppName + '"')

# 3) Logos SVG
$svg = Join-Path $PSScriptRoot 'osasix-isotype.svg'
foreach ($dest in 'res/logo.svg', 'res/scalable.svg', 'flutter/assets/icon.svg') {
    $d = Join-Path $Root $dest
    New-Item -ItemType Directory -Force (Split-Path $d) | Out-Null
    Copy-Item $svg $d -Force
    Write-Host "OK  $dest  <- osasix-isotype.svg"
}

# 4) Iconos PNG / ICO
& (Join-Path $PSScriptRoot 'gen_osasix_icons.ps1') -Root $Root

Write-Host "Marca de Osasix aplicada correctamente en $Root"
