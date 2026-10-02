$ErrorActionPreference = 'Stop'

Write-Host 'Cleaning Flutter build artifacts...'
flutter clean

Write-Host 'Resolving dependencies...'
flutter pub get

Write-Host 'Running analyzer...'
flutter analyze

Write-Host 'Building production Web bundle...'
flutter build web --release --base-href '/field-measure-pro/'

Write-Host ''
Write-Host 'SUCCESS: Web build is in build/web' -ForegroundColor Green
