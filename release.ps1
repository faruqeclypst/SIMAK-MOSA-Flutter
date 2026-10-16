# Script Otomatis Full Release SIMAK-MOSA (APK + Web Online)
# Dijalankan langsung atau via: npm run release

param (
    [switch]$SkipApk = $false,
    [switch]$SkipWeb = $false
)

$ErrorActionPreference = "Stop"

Write-Host "`n========================================================" -ForegroundColor Green
Write-Host "   >> SIMAK-MOSA FULL RELEASE (APK + WEB ONLINE) <<" -ForegroundColor Green
Write-Host "========================================================`n" -ForegroundColor Green

$apkPath = "build\app\outputs\flutter-apk\app-release.apk"

# 1. Build APK Android
if (-not $SkipApk) {
    Write-Host ">> [1/2] Membangun Android APK (Release)..." -ForegroundColor Cyan
    flutter build apk --release
    if ($LASTEXITCODE -ne 0) {
        Write-Host "`n[ERROR] Gagal membangun APK!" -ForegroundColor Red
        exit 1
    }

    if (Test-Path $apkPath) {
        $sizeMb = [Math]::Round(((Get-Item $apkPath).Length / 1MB), 2)
        Write-Host "`n>> [SUKSES] APK Release selesai:" -ForegroundColor Green
        Write-Host "   Lokasi: $apkPath" -ForegroundColor White
        Write-Host "   Ukuran: $sizeMb MB`n" -ForegroundColor White
    }
} else {
    Write-Host ">> [1/2] Melewati build APK (-SkipApk)..." -ForegroundColor Yellow
}

# 2. Build & Deploy Web Online
if (-not $SkipWeb) {
    Write-Host ">> [2/2] Membangun & Mengunggah Web ke Server..." -ForegroundColor Cyan
    powershell -ExecutionPolicy Bypass -File ".\deploy-preview.ps1"
    if ($LASTEXITCODE -ne 0) {
        Write-Host "`n[ERROR] Gagal deploy web!" -ForegroundColor Red
        exit 1
    }
} else {
    Write-Host ">> [2/2] Melewati deploy web (-SkipWeb)..." -ForegroundColor Yellow
}

Write-Host "`n========================================================" -ForegroundColor Green
Write-Host "   >> SEMUA PROSES RELEASE SELESAI DENGAN SUKSES! <<" -ForegroundColor Green
Write-Host "========================================================" -ForegroundColor Green
if (-not $SkipApk -and (Test-Path $apkPath)) {
    Write-Host ">> APK Android: $apkPath" -ForegroundColor White
}
if (-not $SkipWeb) {
    Write-Host ">> Web Online : https://simak-preview.alfaruqasri.my.id/" -ForegroundColor White
}
Write-Host "========================================================`n" -ForegroundColor Green
