# Kisa Sureli Dosya Temizleyici - Kaldirma Betigi
# Bu betik uygulamayi Windows Gorev Zamanlayici'dan kaldirir

Write-Host "Kisa Sureli Dosya Temizleyici - Kaldirma" -ForegroundColor Cyan
Write-Host "=========================================" -ForegroundColor Cyan
Write-Host ""

# Gorev adi
$taskName = "ShortTermFileCleaner"

# Mevcut gorevi kontrol et
$existingTask = Get-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue

if ($existingTask) {
    Write-Host "Gorev bulundu. Kaldiriliyor..." -ForegroundColor Yellow
    
    try {
        Unregister-ScheduledTask -TaskName $taskName -Confirm:$false
        Write-Host "Gorev basariyla kaldirildi!" -ForegroundColor Green
    }
    catch {
        Write-Host "HATA: Gorev kaldirilamadi!" -ForegroundColor Red
        Write-Host $_.Exception.Message -ForegroundColor Red
        Write-Host ""
        Write-Host "Cozum: PowerShell'i 'Yonetici olarak calistir' ile acip tekrar deneyin." -ForegroundColor Yellow
    }
}
else {
    Write-Host "Gorev bulunamadi. Zaten kaldirilmis olabilir." -ForegroundColor Yellow
}

Write-Host ""

# Klasoru silme secenegi
$targetFolder = "$env:USERPROFILE\Desktop\short-term-files"

if (Test-Path $targetFolder) {
    Write-Host "short-term-files klasorunu de silmek ister misiniz?" -ForegroundColor Yellow
    Write-Host "Klasor icindeki TUM dosyalar silinecek!" -ForegroundColor Red
    Write-Host ""
    Write-Host "Klasor konumu: $targetFolder" -ForegroundColor Cyan
    Write-Host ""
    
    $response = Read-Host "Klasoru sil? (E/H)"
    
    if ($response -eq "E" -or $response -eq "e") {
        try {
            Remove-Item -Path $targetFolder -Recurse -Force
            Write-Host "Klasor basariyla silindi!" -ForegroundColor Green
        }
        catch {
            Write-Host "HATA: Klasor silinemedi!" -ForegroundColor Red
            Write-Host $_.Exception.Message -ForegroundColor Red
        }
    }
    else {
        Write-Host "Klasor korundu." -ForegroundColor Green
    }
}

Write-Host ""
Write-Host "Kaldirma islemi tamamlandi." -ForegroundColor Green
Write-Host ""
Write-Host "Devam etmek icin bir tusa basin..." -ForegroundColor Gray
pause
