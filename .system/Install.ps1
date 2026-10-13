# Kısa Süreli Dosya Temizleyici - Kurulum Betiği (komut satırı)
# Normalde gerekmez: "Dosya Temizleyici.exe" ilk açılışta kurulum sihirbazını gösterir.
# Bu betik aynı adımları (otomatik başlatma, masaüstü kısayolu, klasör simgesi) doğrudan uygular.

. (Join-Path $PSScriptRoot 'Core.ps1')

Write-Host 'Kısa Süreli Dosya Temizleyici - Kurulum' -ForegroundColor Cyan
Write-Host '======================================' -ForegroundColor Cyan
Write-Host ''

Invoke-Migration
$errors = Invoke-Setup -Options @('autostart', 'desktop', 'foldericon') -AllowElevation
if ($errors) {
    Write-Host 'Kurulum bazı hatalarla tamamlandı:' -ForegroundColor Yellow
    $errors | ForEach-Object { Write-Host "  $_" -ForegroundColor Yellow }
}
else {
    Write-Host 'Kurulum başarıyla tamamlandı!' -ForegroundColor Green
    Write-Host 'Oturum her açıldığında uygulama açılacak ve süresi dolan dosyalar temizlenecek.' -ForegroundColor Green
    Write-Host 'Masaüstüne ve Başlat menüsüne kısayol eklendi.' -ForegroundColor Green
}
Write-Host ''
Write-Host "Klasör konumu: $script:BaseFolder" -ForegroundColor Cyan
Write-Host ''
pause
