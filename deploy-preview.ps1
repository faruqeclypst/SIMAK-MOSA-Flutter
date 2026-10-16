# Script deploy otomatis Flutter Web SIMAK-MOSA ke simak-preview.alfaruqasri.my.id

param (
    [switch]$SkipBuild = $false
)

$ErrorActionPreference = "Stop"

if (-not $SkipBuild) {
    Write-Host "`n>> [1/4] Mengompilasi Flutter Web (Release)..." -ForegroundColor Cyan
    flutter build web --release
} else {
    Write-Host "`n>> Melewati build, menggunakan build\web yang ada..." -ForegroundColor Yellow
}

Write-Host "`n>> [2/4] Mengompres artefak build/web..." -ForegroundColor Cyan
tar -czf build_web.tar.gz -C build\web .

Write-Host "`n>> [3/4] Mengunggah ke server 43.134.175.87..." -ForegroundColor Cyan
scp build_web.tar.gz ubuntu@43.134.175.87:/tmp/

Write-Host "`n>> [4/4] Mengekstrak ke /opt/simak-preview..." -ForegroundColor Cyan
ssh ubuntu@43.134.175.87 "tar -xzf /tmp/build_web.tar.gz -C /opt/simak-preview && rm /tmp/build_web.tar.gz"

if (Test-Path build_web.tar.gz) {
    Remove-Item -Force build_web.tar.gz
}

Write-Host "`n>> Deploy Sukses! Silakan akses: https://simak-preview.alfaruqasri.my.id/`n" -ForegroundColor Green
