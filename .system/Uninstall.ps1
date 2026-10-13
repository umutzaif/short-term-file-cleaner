# Kısa Süreli Dosya Temizleyici - Kaldırma Betiği
# Oturum açılışı görevini ve Başlat menüsü kısayolunu kaldırır; isteğe bağlı olarak klasörü siler.

. (Join-Path $PSScriptRoot 'Core.ps1')

Write-Host 'Kısa Süreli Dosya Temizleyici - Kaldırma' -ForegroundColor Cyan
Write-Host '=======================================' -ForegroundColor Cyan
Write-Host ''

try {
    if (Uninstall-CleanupTask -AllowElevation) { Write-Host 'Görev başarıyla kaldırıldı!' -ForegroundColor Green }
    else { Write-Host 'Görev bulunamadı. Zaten kaldırılmış olabilir.' -ForegroundColor Yellow }
}
catch {
    Write-Host 'HATA: Görev kaldırılamadı!' -ForegroundColor Red
    Write-Host $_.Exception.Message -ForegroundColor Red
}

Write-Host ''
Write-Host 'short-term-files klasörünü de silmek ister misiniz?' -ForegroundColor Yellow
Write-Host 'Klasör içindeki TÜM dosyalar silinecek!' -ForegroundColor Red
Write-Host "Klasör konumu: $script:BaseFolder" -ForegroundColor Cyan
Write-Host ''

$response = Read-Host 'Klasörü sil? (E/H)'
if ($response -eq 'E' -or $response -eq 'e') {
    try {
        Remove-Item -LiteralPath $script:BaseFolder -Recurse -Force
        Write-Host 'Klasör başarıyla silindi!' -ForegroundColor Green
    }
    catch {
        Write-Host 'HATA: Klasör silinemedi!' -ForegroundColor Red
        Write-Host $_.Exception.Message -ForegroundColor Red
    }
}
else {
    Write-Host 'Klasör korundu.' -ForegroundColor Green
}

Write-Host ''
pause
