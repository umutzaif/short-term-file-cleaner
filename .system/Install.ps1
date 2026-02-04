# Kisa Sureli Dosya Temizleyici - Kurulum Betigi
# Bu betik uygulamayi Windows Gorev ZamanLayici'ya kaydeder

Write-Host "Kisa Sureli Dosya Temizleyici - Kurulum" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Yonetici yetkisi kontrolu
$isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

if (-not $isAdmin) {
    Write-Host "UYARI: Bu betik yonetici yetkisi olmadan calisabilir, ancak bazi sistemlerde sorun yasanabilir." -ForegroundColor Yellow
    Write-Host "Sorun yasarsaniz PowerShell'i 'Yonetici olarak calistir' ile acip tekrar deneyin." -ForegroundColor Yellow
    Write-Host ""
}

# Klasor ve betik yolu
$targetFolder = "$env:USERPROFILE\Desktop\short-term-files"
$systemFolder = "$targetFolder\.system"
$scriptPath = "$systemFolder\ShortTermFileCleaner.ps1"

# Ana klasor kontrolu
if (-not (Test-Path $targetFolder)) {
    Write-Host "Ana klasor olusturuluyor: $targetFolder" -ForegroundColor Yellow
    New-Item -ItemType Directory -Path $targetFolder -Force | Out-Null
}

# .system klasoru olustur
if (-not (Test-Path $systemFolder)) {
    Write-Host ".system klasoru olusturuluyor..." -ForegroundColor Yellow
    New-Item -ItemType Directory -Path $systemFolder -Force | Out-Null
}

# Default config dosyalari olustur
$configFile = "$systemFolder\config.json"
if (-not (Test-Path $configFile)) {
    Write-Host "Default config olusturuluyor..." -ForegroundColor Yellow
    $defaultConfig = @{
        warningDays  = 7
        deletionDays = 14
        lastModified = (Get-Date -Format "yyyy-MM-ddTHH:mm:sszzz")
    }
    $defaultConfig | ConvertTo-Json | Out-File $configFile -Encoding UTF8
}

$protectedFile = "$systemFolder\protected-files.json"
if (-not (Test-Path $protectedFile)) {
    Write-Host "Protected files listesi olusturuluyor..." -ForegroundColor Yellow
    @{ files = @() } | ConvertTo-Json | Out-File $protectedFile -Encoding UTF8
}

# Betik kontrolu
if (-not (Test-Path $scriptPath)) {
    Write-Host "HATA: ShortTermFileCleaner.ps1 bulunamadi!" -ForegroundColor Red
    Write-Host "Lutfen betigin su konumda oldugunu emin olun: $scriptPath" -ForegroundColor Red
    pause
    exit
}

# Gorev Zamanlayici gorevi olustur
$taskName = "ShortTermFileCleaner"
$taskDescription = "7 gunden eski dosyalari Desktop\short-term-files klasorundan temizler"

# Mevcut gorevi kontrol et
$existingTask = Get-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue

if ($existingTask) {
    Write-Host "Mevcut gorev bulundu. Kaldiriliyor..." -ForegroundColor Yellow
    Unregister-ScheduledTask -TaskName $taskName -Confirm:$false
}

# Gorev eylemi: PowerShell betigini gizli modda calistir
$action = New-ScheduledTaskAction -Execute "powershell.exe" `
    -Argument "-WindowStyle Hidden -ExecutionPolicy Bypass -File `"$scriptPath`""

# Tetikleyici: Kullanici oturum actiginda
$trigger = New-ScheduledTaskTrigger -AtLogOn -User $env:USERNAME

# Ayarlar: Gorev tamamlandiktan sonra tekrar calismasin
$settings = New-ScheduledTaskSettingsSet `
    -AllowStartIfOnBatteries `
    -DontStopIfGoingOnBatteries `
    -StartWhenAvailable `
    -RunOnlyIfNetworkAvailable:$false `
    -ExecutionTimeLimit (New-TimeSpan -Minutes 5)

# Gorevi kaydet
try {
    Register-ScheduledTask -TaskName $taskName `
        -Description $taskDescription `
        -Action $action `
        -Trigger $trigger `
        -Settings $settings `
        -User $env:USERNAME `
        -RunLevel Limited `
        -Force | Out-Null
    
    Write-Host ""
    Write-Host "Kurulum basariyla tamamlandi!" -ForegroundColor Green
    Write-Host ""
    Write-Host "Uygulama artik bilgisayar her acildiginda otomatik olarak calisacak." -ForegroundColor Green
    Write-Host "7 gunden eski dosyalar varsa bir bildirim goreceksiniz." -ForegroundColor Green
    Write-Host ""
    Write-Host "Klasor konumu: $targetFolder" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Kaldirmak icin: Uninstall.ps1 betigini calistirin" -ForegroundColor Gray
}
catch {
    Write-Host ""
    Write-Host "HATA: Gorev kaydedilemedi!" -ForegroundColor Red
    Write-Host $_.Exception.Message -ForegroundColor Red
    Write-Host ""
    Write-Host "Cozum: PowerShell'i 'Yonetici olarak calistir' ile acip tekrar deneyin." -ForegroundColor Yellow
}

Write-Host ""
Write-Host "Devam etmek icin bir tusa basin..." -ForegroundColor Gray
pause
