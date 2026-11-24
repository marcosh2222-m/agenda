# Arma la versión portable: dist\Agenda-portable-<versión>.zip con la carpeta lista para copiar y ejecutar.
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

if (Test-Path dist) { Remove-Item dist -Recurse -Force }
New-Item -ItemType Directory $carpeta | Out-Null
Copy-Item 'build\windows\x64\runner\Release\*' $carpeta -Recurse
Compress-Archive -Path $carpeta -DestinationPath $zip

Write-Host "Listo: $zip ($([math]::Round((Get-Item $zip).Length / 1MB, 1)) MB)"
Write-Host "Para usarla: descomprimir y abrir Agenda\agenda.exe. Los datos quedan en %APPDATA%\Agenda."
