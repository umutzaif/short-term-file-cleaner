# Kısa Süreli Dosya Temizleyici - Kurulum Betiği
# Sessiz başlatıcıyı derler, oturum açılışı görevini ve Başlat menüsü kısayolunu oluşturur.
# (Aynı işlem MainApp.ps1 > Genel Bakış > Otomatik başlatma kartından da yapılabilir.)

. (Join-Path $PSScriptRoot 'Core.ps1')

Write-Host 'Kısa Süreli Dosya Temizleyici - Kurulum' -ForegroundColor Cyan
Write-Host '======================================' -ForegroundColor Cyan
Write-Host ''

try {
    $mode = Install-CleanupTask -AllowElevation
    Write-Host 'Kurulum başarıyla tamamlandı!' -ForegroundColor Green
    if ($mode -eq 'launcher') {
        Write-Host 'Oturum her açıldığında klasör, hiçbir pencere açılmadan denetlenecek.' -ForegroundColor Green
    }
    else {
        Write-Host 'Sessiz başlatıcı derlenemedi; yedek yöntem (conhost --headless) kullanıldı.' -ForegroundColor Yellow
    }
    Write-Host "Başlat menüsüne 'Kısa Süreli Dosya Temizleyici' kısayolu eklendi." -ForegroundColor Green
    Write-Host ''
    Write-Host "Klasör konumu: $script:BaseFolder" -ForegroundColor Cyan
}
catch {
    Write-Host 'HATA: Görev kaydedilemedi!' -ForegroundColor Red
    Write-Host $_.Exception.Message -ForegroundColor Red
}

Write-Host ''
pause
