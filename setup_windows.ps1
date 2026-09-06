$ErrorActionPreference = "Stop"

$Root = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location $Root

if (-not (Get-Command flutter -ErrorAction SilentlyContinue)) {
    throw "Flutter nao encontrado no PATH. Instale/configure o Flutter e execute novamente."
}

Write-Host "Flutter encontrado:" -ForegroundColor Cyan
flutter --version

$Backup = Join-Path $env:TEMP ("mv_biblioteca_backup_" + [guid]::NewGuid().ToString())
New-Item -ItemType Directory -Path $Backup | Out-Null

# Arquivos do aplicativo que nao podem ser perdidos.
Copy-Item "$Root\lib" "$Backup\lib" -Recurse
Copy-Item "$Root\pubspec.yaml" "$Backup\pubspec.yaml"
if (Test-Path "$Root\.env") { Copy-Item "$Root\.env" "$Backup\.env" }
if (Test-Path "$Root\.env.example") { Copy-Item "$Root\.env.example" "$Backup\.env.example" }
if (Test-Path "$Root\android\app\src\main\AndroidManifest.xml") {
    Copy-Item "$Root\android\app\src\main\AndroidManifest.xml" "$Backup\AndroidManifest.xml"
}
if (Test-Path "$Root\android\app\src\main\res") {
    New-Item -ItemType Directory -Path "$Backup\icons" | Out-Null
    Get-ChildItem "$Root\android\app\src\main\res" -Directory | Where-Object { $_.Name -like 'mipmap*' } | ForEach-Object {
        Copy-Item $_.FullName "$Backup\icons\$($_.Name)" -Recurse
    }
}

Write-Host "" 
Write-Host "Recriando Android com Flutter embedding v2..." -ForegroundColor Yellow

# Remove a estrutura Android incompleta/antiga. O Flutter instalado no PC
# gera Gradle, Kotlin, MainActivity e wrapper nas versoes compativeis.
if (Test-Path "$Root\android") {
    Remove-Item "$Root\android" -Recurse -Force
}

flutter create --platforms=android --org io.mvcode --project-name mv_biblioteca_webview .

Write-Host "Restaurando codigo, configuracoes e icones..." -ForegroundColor Yellow
Remove-Item "$Root\lib" -Recurse -Force
Copy-Item "$Backup\lib" "$Root\lib" -Recurse
Copy-Item "$Backup\pubspec.yaml" "$Root\pubspec.yaml" -Force
if (Test-Path "$Backup\.env") { Copy-Item "$Backup\.env" "$Root\.env" -Force }
if (Test-Path "$Backup\.env.example") { Copy-Item "$Backup\.env.example" "$Root\.env.example" -Force }
if (Test-Path "$Backup\AndroidManifest.xml") {
    Copy-Item "$Backup\AndroidManifest.xml" "$Root\android\app\src\main\AndroidManifest.xml" -Force
}

# Mescla SOMENTE os mipmaps personalizados. Nao apaga values/styles gerados pelo Flutter.
if (Test-Path "$Backup\icons") {
    Get-ChildItem "$Backup\icons" -Directory | ForEach-Object {
        $dest = Join-Path "$Root\android\app\src\main\res" $_.Name
        if (-not (Test-Path $dest)) { New-Item -ItemType Directory -Path $dest | Out-Null }
        Copy-Item "$($_.FullName)\*" $dest -Recurse -Force
    }
}

Write-Host "Instalando dependencias..." -ForegroundColor Yellow
flutter clean
flutter pub get

$MainActivity = Get-ChildItem "$Root\android\app\src\main" -Recurse -File -Include MainActivity.kt,MainActivity.java | Select-Object -First 1
if (-not $MainActivity) {
    throw "MainActivity nao foi gerada. Verifique a instalacao do Flutter."
}

Write-Host "" 
Write-Host "OK: Android embedding v2 criado em:" -ForegroundColor Green
Write-Host $MainActivity.FullName
Write-Host "" 
Write-Host "Agora execute: flutter run" -ForegroundColor Green
Write-Host "APK release: flutter build apk --release"
