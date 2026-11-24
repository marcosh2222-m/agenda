# Arma la versión portable (dist\Agenda-portable-<versión>.zip) y, si está Inno Setup 6, el instalador (dist\Agenda-instalador-<versión>.exe).
# Uso: .\tool\empaquetar.ps1
$ErrorActionPreference = 'Stop'
Set-Location (Split-Path $PSScriptRoot)

# Con google.json (credenciales, fuera del repo) se puede sincronizar; sin él, el resto anda igual.
$credenciales = @(if (Test-Path google.json) { '--dart-define-from-file=google.json' })
flutter build windows --release @credenciales
if ($LASTEXITCODE -ne 0) { throw 'Falló el build de release' }

$version = ((Select-String -Path pubspec.yaml -Pattern '^version:\s*(\S+)').Matches[0].Groups[1].Value -split '\+')[0]
$carpeta = 'dist\Agenda'
$zip = "dist\Agenda-portable-$version.zip"

# Solo lo de Windows: en dist también están las APK.
foreach ($viejo in $carpeta, $zip) { if (Test-Path $viejo) { Remove-Item $viejo -Recurse -Force } }
New-Item -ItemType Directory $carpeta | Out-Null
Copy-Item 'build\windows\x64\runner\Release\*' $carpeta -Recurse
Compress-Archive -Path $carpeta -DestinationPath $zip

$inno = "$env:LOCALAPPDATA\Programs\Inno Setup 6\ISCC.exe", "${env:ProgramFiles(x86)}\Inno Setup 6\ISCC.exe" | Where-Object { Test-Path $_ } | Select-Object -First 1
if ($inno) {
  & $inno /Qp "/DVersion=$version" tool\instalador.iss
  if ($LASTEXITCODE -ne 0) { throw 'Falló el instalador' }
  Write-Host "Listo: dist\Agenda-instalador-$version.exe"
} else { Write-Host 'Sin instalador: falta Inno Setup 6 (winget install JRSoftware.InnoSetup)' }

Write-Host "Listo: $zip ($([math]::Round((Get-Item $zip).Length / 1MB, 1)) MB)"
Write-Host "Para usarla: descomprimir y abrir Agenda\agenda.exe. Los datos quedan en %APPDATA%\Agenda."
