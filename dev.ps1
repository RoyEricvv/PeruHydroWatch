# Arranque en Windows, sin instalar nada en el sistema:
#   .\dev.ps1            instala lo necesario la primera vez y abre la app en http://localhost:3000
#   .\dev.ps1 -Prod      compila y sirve en modo producción
#   .\dev.ps1 -RefreshData   vuelve a descargar los datos oficiales
param([switch]$Prod, [switch]$RefreshData)
$ErrorActionPreference = "Stop"
$root = $PSScriptRoot
$nodeVersion = "v24.22.1"
$nodeDir = Join-Path $root ".tools\node-$nodeVersion-win-x64"

if (Get-Command node -ErrorAction SilentlyContinue) {
  Write-Host "Usando Node del sistema: $(node -v)"
} else {
  if (-not (Test-Path (Join-Path $nodeDir "node.exe"))) {
    Write-Host "Descargando Node $nodeVersion portable en .tools ..."
    New-Item -ItemType Directory -Force (Join-Path $root ".tools") | Out-Null
    $zip = Join-Path $root ".tools\node.zip"
    & curl.exe -s -L -o $zip "https://nodejs.org/dist/$nodeVersion/node-$nodeVersion-win-x64.zip"
    $sums = & curl.exe -s -L "https://nodejs.org/dist/$nodeVersion/SHASUMS256.txt"
    $expected = (($sums | Where-Object { $_ -match "node-$nodeVersion-win-x64.zip" }) -split '\s+')[0]
    if ((Get-FileHash $zip -Algorithm SHA256).Hash.ToLower() -ne $expected) { throw "El checksum de Node no coincide" }
    Expand-Archive -Force $zip (Join-Path $root ".tools")
    Remove-Item $zip
  }
  $env:Path = "$nodeDir;$env:Path"
}

# INGEMMET no envía su certificado intermedio; el almacén de Windows sí lo resuelve.
$env:NODE_OPTIONS = "--use-system-ca"
$env:NEXT_TELEMETRY_DISABLED = "1"
Set-Location (Join-Path $root "frontend")
if (-not (Test-Path "node_modules")) { npm ci --no-audit --no-fund }
if ($RefreshData -or -not (Test-Path "public\data\manifest.json")) {
  if ($RefreshData -and (Test-Path ".data-cache")) { Remove-Item -Recurse -Force ".data-cache" }
  node scripts/build-data.mjs
}
if ($Prod) {
  npm run build
  npm run start
} else {
  npm run dev
}
