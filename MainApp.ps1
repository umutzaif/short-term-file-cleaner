# Kısa Süreli Dosya Temizleyici v2.0
# Ana GUI Uygulaması - Profesyonel Tasarım
# GitHub: https://github.com/[username]/short-term-file-cleaner

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

# Global değişkenler
$script:baseFolder = "$env:USERPROFILE\Desktop\short-term-files"
$script:systemFolder = "$baseFolder\.system"
$script:configFile = "$systemFolder\config.json"
$script:protectedFile = "$systemFolder\protected-files.json"
$script:logFile = "$systemFolder\cleanup.log"
$script:taskName = "ShortTermFileCleaner"

# Renkler - Modern tema
$script:colorPrimary = [System.Drawing.Color]::FromArgb(41, 128, 185)  # Mavi
$script:colorSuccess = [System.Drawing.Color]::FromArgb(39, 174, 96)   # Yeşil
$script:colorDanger = [System.Drawing.Color]::FromArgb(231, 76, 60)    # Kırmızı
$script:colorWarning = [System.Drawing.Color]::FromArgb(243, 156, 18)  # Turuncu
$script:colorLight = [System.Drawing.Color]::FromArgb(236, 240, 241)   # Açık gri
$script:colorDark = [System.Drawing.Color]::FromArgb(44, 62, 80)       # Koyu gri
$script:colorText = [System.Drawing.Color]::FromArgb(52, 73, 94)       # Metin

# Helper fonksiyonlar
function Get-Config {
    if (Test-Path $script:configFile) {
        try {
            return Get-Content $script:configFile -Raw | ConvertFrom-Json
        }
        catch {
            return @{ warningDays = 7; deletionDays = 14 }
        }
    }
    return @{ warningDays = 7; deletionDays = 14 }
}

function Set-Config {
    param($config)
    $config.lastModified = (Get-Date -Format "yyyy-MM-ddTHH:mm:sszzz")
    $config | ConvertTo-Json | Out-File $script:configFile -Encoding UTF8
}

function Get-ProtectedFiles {
    if (Test-Path $script:protectedFile) {
        try {
            $protected = Get-Content $script:protectedFile -Raw | ConvertFrom-Json
            return $protected.files
        }
        catch {
            return @()
        }
    }
    return @()
}

function Test-TaskInstalled {
    $task = Get-ScheduledTask -TaskName $script:taskName -ErrorAction SilentlyContinue
    return $null -ne $task
}

function Install-CleanupTask {
    $scriptPath = "$script:systemFolder\ShortTermFileCleaner.ps1"
    
    if (-not (Test-Path $script:systemFolder)) {
        New-Item -ItemType Directory -Path $script:systemFolder -Force | Out-Null
    }
    
    if (-not (Test-Path $script:configFile)) {
        @{ warningDays = 7; deletionDays = 14; lastModified = (Get-Date -Format "yyyy-MM-ddTHH:mm:sszzz") } | ConvertTo-Json | Out-File $script:configFile -Encoding UTF8
    }
    
    if (-not (Test-Path $script:protectedFile)) {
        @{ files = @() } | ConvertTo-Json | Out-File $script:protectedFile -Encoding UTF8
    }
    
    $action = New-ScheduledTaskAction -Execute "powershell.exe" -Argument "-WindowStyle Hidden -ExecutionPolicy Bypass -File `"$scriptPath`""
    $trigger = New-ScheduledTaskTrigger -AtLogOn -User $env:USERNAME
    $settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -StartWhenAvailable -ExecutionTimeLimit (New-TimeSpan -Minutes 5)
    
    Register-ScheduledTask -TaskName $script:taskName -Description "Kısa süreli dosyaları otomatik temizler" -Action $action -Trigger $trigger -Settings $settings -User $env:USERNAME -RunLevel Limited -Force | Out-Null
    
    return $true
}

function Uninstall-CleanupTask {
    if (Test-TaskInstalled) {
        Unregister-ScheduledTask -TaskName $script:taskName -Confirm:$false
        return $true
    }
    return $false
}

# Ana form
$mainForm = New-Object System.Windows.Forms.Form
$mainForm.Text = "Kısa Süreli Dosya Temizleyici v2.0"
$mainForm.Size = New-Object System.Drawing.Size(900, 650)
$mainForm.StartPosition = "CenterScreen"
$mainForm.FormBorderStyle = "FixedDialog"
$mainForm.MaximizeBox = $false
$mainForm.MinimizeBox = $true
$mainForm.BackColor = [System.Drawing.Color]::White
$mainForm.Font = New-Object System.Drawing.Font("Segoe UI", 9)

# TabControl
$tabControl = New-Object System.Windows.Forms.TabControl
$tabControl.Location = New-Object System.Drawing.Point(15, 15)
$tabControl.Size = New-Object System.Drawing.Size(860, 550)
$tabControl.Font = New-Object System.Drawing.Font("Segoe UI", 10)
$mainForm.Controls.Add($tabControl)

#region Tab 1: Ana Sayfa
$tabHome = New-Object System.Windows.Forms.TabPage
$tabHome.Text = "  Ana Sayfa  "
$tabHome.BackColor = [System.Drawing.Color]::White
$tabControl.Controls.Add($tabHome)

# Başlık paneli
$pnlHeader = New-Object System.Windows.Forms.Panel
$pnlHeader.Location = New-Object System.Drawing.Point(0, 0)
$pnlHeader.Size = New-Object System.Drawing.Size(860, 120)
$pnlHeader.BackColor = $script:colorPrimary
$tabHome.Controls.Add($pnlHeader)

$lblTitle = New-Object System.Windows.Forms.Label
$lblTitle.Location = New-Object System.Drawing.Point(30, 25)
$lblTitle.Size = New-Object System.Drawing.Size(800, 40)
$lblTitle.Text = "Kısa Süreli Dosya Temizleyici"
$lblTitle.Font = New-Object System.Drawing.Font("Segoe UI", 22, [System.Drawing.FontStyle]::Bold)
$lblTitle.ForeColor = [System.Drawing.Color]::White
$pnlHeader.Controls.Add($lblTitle)

$lblSubtitle = New-Object System.Windows.Forms.Label
$lblSubtitle.Location = New-Object System.Drawing.Point(30, 70)
$lblSubtitle.Size = New-Object System.Drawing.Size(800, 30)
$lblSubtitle.Text = "Geçici dosyalarınızı otomatik olarak yönetin"
$lblSubtitle.Font = New-Object System.Drawing.Font("Segoe UI", 11)
$lblSubtitle.ForeColor = [System.Drawing.Color]::FromArgb(236, 240, 241)
$pnlHeader.Controls.Add($lblSubtitle)

# Durum kartı
$pnlStatus = New-Object System.Windows.Forms.Panel
$pnlStatus.Location = New-Object System.Drawing.Point(30, 140)
$pnlStatus.Size = New-Object System.Drawing.Size(800, 140)
$pnlStatus.BackColor = $script:colorLight
$pnlStatus.BorderStyle = "None"
$tabHome.Controls.Add($pnlStatus)

$lblStatusTitle = New-Object System.Windows.Forms.Label
$lblStatusTitle.Location = New-Object System.Drawing.Point(20, 15)
$lblStatusTitle.Size = New-Object System.Drawing.Size(760, 30)
$lblStatusTitle.Text = "📊 Durum Bilgisi"
$lblStatusTitle.Font = New-Object System.Drawing.Font("Segoe UI", 13, [System.Drawing.FontStyle]::Bold)
$lblStatusTitle.ForeColor = $script:colorDark
$pnlStatus.Controls.Add($lblStatusTitle)

$lblTaskStatus = New-Object System.Windows.Forms.Label
$lblTaskStatus.Location = New-Object System.Drawing.Point(25, 55)
$lblTaskStatus.Size = New-Object System.Drawing.Size(750, 25)
$lblTaskStatus.Font = New-Object System.Drawing.Font("Segoe UI", 10)
$lblTaskStatus.ForeColor = $script:colorText
$pnlStatus.Controls.Add($lblTaskStatus)

$lblNextRun = New-Object System.Windows.Forms.Label
$lblNextRun.Location = New-Object System.Drawing.Point(25, 80)
$lblNextRun.Size = New-Object System.Drawing.Size(750, 25)
$lblNextRun.Font = New-Object System.Drawing.Font("Segoe UI", 10)
$lblNextRun.ForeColor = $script:colorText
$pnlStatus.Controls.Add($lblNextRun)

$lblProtectedCount = New-Object System.Windows.Forms.Label
$lblProtectedCount.Location = New-Object System.Drawing.Point(25, 105)
$lblProtectedCount.Size = New-Object System.Drawing.Size(750, 25)
$lblProtectedCount.Font = New-Object System.Drawing.Font("Segoe UI", 10)
$lblProtectedCount.ForeColor = $script:colorText
$pnlStatus.Controls.Add($lblProtectedCount)

# Hızlı işlemler kartı
$pnlActions = New-Object System.Windows.Forms.Panel
$pnlActions.Location = New-Object System.Drawing.Point(30, 300)
$pnlActions.Size = New-Object System.Drawing.Size(800, 200)
$pnlActions.BackColor = $script:colorLight
$tabHome.Controls.Add($pnlActions)

$lblActionsTitle = New-Object System.Windows.Forms.Label
$lblActionsTitle.Location = New-Object System.Drawing.Point(20, 15)
$lblActionsTitle.Size = New-Object System.Drawing.Size(760, 30)
$lblActionsTitle.Text = "⚡ Hızlı İşlemler"
$lblActionsTitle.Font = New-Object System.Drawing.Font("Segoe UI", 13, [System.Drawing.FontStyle]::Bold)
$lblActionsTitle.ForeColor = $script:colorDark
$pnlActions.Controls.Add($lblActionsTitle)

# Kurulum butonu
$btnInstall = New-Object System.Windows.Forms.Button
$btnInstall.Location = New-Object System.Drawing.Point(40, 60)
$btnInstall.Size = New-Object System.Drawing.Size(180, 50)
$btnInstall.Text = "✓ Kurulum Yap"
$btnInstall.Font = New-Object System.Drawing.Font("Segoe UI", 11, [System.Drawing.FontStyle]::Bold)
$btnInstall.BackColor = $script:colorSuccess
$btnInstall.ForeColor = [System.Drawing.Color]::White
$btnInstall.FlatStyle = "Flat"
$btnInstall.FlatAppearance.BorderSize = 0
$btnInstall.Cursor = [System.Windows.Forms.Cursors]::Hand
$btnInstall.Add_Click({
        try {
            if (Install-CleanupTask) {
                [System.Windows.Forms.MessageBox]::Show("Kurulum başarıyla tamamlandı!`n`nUygulama artık bilgisayar her açıldığında otomatik çalışacak.", "Başarılı", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Information)
                Update-StatusInfo
            }
        }
        catch {
            [System.Windows.Forms.MessageBox]::Show("Kurulum hatası: $($_.Exception.Message)", "Hata", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Error)
        }
    })
$pnlActions.Controls.Add($btnInstall)

# Kaldır butonu
$btnUninstall = New-Object System.Windows.Forms.Button
$btnUninstall.Location = New-Object System.Drawing.Point(240, 60)
$btnUninstall.Size = New-Object System.Drawing.Size(180, 50)
$btnUninstall.Text = "✕ Kaldır"
$btnUninstall.Font = New-Object System.Drawing.Font("Segoe UI", 11)
$btnUninstall.BackColor = $script:colorDanger
$btnUninstall.ForeColor = [System.Drawing.Color]::White
$btnUninstall.FlatStyle = "Flat"
$btnUninstall.FlatAppearance.BorderSize = 0
$btnUninstall.Cursor = [System.Windows.Forms.Cursors]::Hand
$btnUninstall.Add_Click({
        $result = [System.Windows.Forms.MessageBox]::Show("Otomatik görev kaldırılıyor. Devam edilsin mi?", "Onay", [System.Windows.Forms.MessageBoxButtons]::YesNo, [System.Windows.Forms.MessageBoxIcon]::Question)
        if ($result -eq [System.Windows.Forms.DialogResult]::Yes) {
            if (Uninstall-CleanupTask) {
                [System.Windows.Forms.MessageBox]::Show("Görev başarıyla kaldırıldı!", "Başarılı", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Information)
                Update-StatusInfo
            }
        }
    })
$pnlActions.Controls.Add($btnUninstall)

# Şimdi temizle butonu
$btnCleanNow = New-Object System.Windows.Forms.Button
$btnCleanNow.Location = New-Object System.Drawing.Point(440, 60)
$btnCleanNow.Size = New-Object System.Drawing.Size(180, 50)
$btnCleanNow.Text = "🗑️ Şimdi Temizle"
$btnCleanNow.Font = New-Object System.Drawing.Font("Segoe UI", 11, [System.Drawing.FontStyle]::Bold)
$btnCleanNow.BackColor = $script:colorPrimary
$btnCleanNow.ForeColor = [System.Drawing.Color]::White
$btnCleanNow.FlatStyle = "Flat"
$btnCleanNow.FlatAppearance.BorderSize = 0
$btnCleanNow.Cursor = [System.Windows.Forms.Cursors]::Hand
$btnCleanNow.Add_Click({
        $scriptPath = "$script:systemFolder\ShortTermFileCleaner.ps1"
        if (Test-Path $scriptPath) {
            Start-Process powershell.exe -ArgumentList "-ExecutionPolicy Bypass -File `"$scriptPath`""
        }
        else {
            [System.Windows.Forms.MessageBox]::Show("Temizleme betiği bulunamadı!", "Hata", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Error)
        }
    })
$pnlActions.Controls.Add($btnCleanNow)

# Klasörü aç butonu
$btnOpenFolder = New-Object System.Windows.Forms.Button
$btnOpenFolder.Location = New-Object System.Drawing.Point(240, 125)
$btnOpenFolder.Size = New-Object System.Drawing.Size(180, 50)
$btnOpenFolder.Text = "📁 Klasörü Aç"
$btnOpenFolder.Font = New-Object System.Drawing.Font("Segoe UI", 11)
$btnOpenFolder.BackColor = $script:colorWarning
$btnOpenFolder.ForeColor = [System.Drawing.Color]::White
$btnOpenFolder.FlatStyle = "Flat"
$btnOpenFolder.FlatAppearance.BorderSize = 0
$btnOpenFolder.Cursor = [System.Windows.Forms.Cursors]::Hand
$btnOpenFolder.Add_Click({
        if (-not (Test-Path $script:baseFolder)) {
            New-Item -ItemType Directory -Path $script:baseFolder -Force | Out-Null
        }
        Start-Process explorer.exe -ArgumentList $script:baseFolder
    })
$pnlActions.Controls.Add($btnOpenFolder)

#endregion

#region Tab 2: Ayarlar
$tabSettings = New-Object System.Windows.Forms.TabPage
$tabSettings.Text = "  Ayarlar  "
$tabSettings.BackColor = [System.Drawing.Color]::White
$tabControl.Controls.Add($tabSettings)

# Başlık
$lblSettingsHeader = New-Object System.Windows.Forms.Label
$lblSettingsHeader.Location = New-Object System.Drawing.Point(30, 30)
$lblSettingsHeader.Size = New-Object System.Drawing.Size(800, 40)
$lblSettingsHeader.Text = "⚙️ Yapılandırma Ayarları"
$lblSettingsHeader.Font = New-Object System.Drawing.Font("Segoe UI", 18, [System.Drawing.FontStyle]::Bold)
$lblSettingsHeader.ForeColor = $script:colorDark
$tabSettings.Controls.Add($lblSettingsHeader)

# Ayarlar paneli
$pnlSettingsCard = New-Object System.Windows.Forms.Panel
$pnlSettingsCard.Location = New-Object System.Drawing.Point(30, 90)
$pnlSettingsCard.Size = New-Object System.Drawing.Size(800, 380)
$pnlSettingsCard.BackColor = $script:colorLight
$tabSettings.Controls.Add($pnlSettingsCard)

# Uyarı gün sayısı
$lblWarningDays = New-Object System.Windows.Forms.Label
$lblWarningDays.Location = New-Object System.Drawing.Point(40, 40)
$lblWarningDays.Size = New-Object System.Drawing.Size(400, 30)
$lblWarningDays.Text = "📅 Uyarı Gün Sayısı:"
$lblWarningDays.Font = New-Object System.Drawing.Font("Segoe UI", 12, [System.Drawing.FontStyle]::Bold)
$lblWarningDays.ForeColor = $script:colorDark
$pnlSettingsCard.Controls.Add($lblWarningDays)

$numWarningDays = New-Object System.Windows.Forms.NumericUpDown
$numWarningDays.Location = New-Object System.Drawing.Point(500, 38)
$numWarningDays.Size = New-Object System.Drawing.Size(150, 30)
$numWarningDays.Minimum = 1
$numWarningDays.Maximum = 365
$numWarningDays.Font = New-Object System.Drawing.Font("Segoe UI", 12)
$numWarningDays.BackColor = [System.Drawing.Color]::White
$pnlSettingsCard.Controls.Add($numWarningDays)

$lblWarningDesc = New-Object System.Windows.Forms.Label
$lblWarningDesc.Location = New-Object System.Drawing.Point(60, 75)
$lblWarningDesc.Size = New-Object System.Drawing.Size(700, 25)
$lblWarningDesc.Text = "Bu gün sayısı aşıldığında uyarı penceresi açar"
$lblWarningDesc.Font = New-Object System.Drawing.Font("Segoe UI", 9, [System.Drawing.FontStyle]::Italic)
$lblWarningDesc.ForeColor = $script:colorText
$pnlSettingsCard.Controls.Add($lblWarningDesc)

# Çizgi
$line1 = New-Object System.Windows.Forms.Label
$line1.Location = New-Object System.Drawing.Point(40, 120)
$line1.Size = New-Object System.Drawing.Size(720, 2)
$line1.BorderStyle = "Fixed3D"
$pnlSettingsCard.Controls.Add($line1)

# Otomatik silme gün sayısı
$lblDeletionDays = New-Object System.Windows.Forms.Label
$lblDeletionDays.Location = New-Object System.Drawing.Point(40, 145)
$lblDeletionDays.Size = New-Object System.Drawing.Size(400, 30)
$lblDeletionDays.Text = "🗑️ Otomatik Silme Gün Sayısı:"
$lblDeletionDays.Font = New-Object System.Drawing.Font("Segoe UI", 12, [System.Drawing.FontStyle]::Bold)
$lblDeletionDays.ForeColor = $script:colorDark
$pnlSettingsCard.Controls.Add($lblDeletionDays)

$numDeletionDays = New-Object System.Windows.Forms.NumericUpDown
$numDeletionDays.Location = New-Object System.Drawing.Point(500, 143)
$numDeletionDays.Size = New-Object System.Drawing.Size(150, 30)
$numDeletionDays.Minimum = 1
$numDeletionDays.Maximum = 365
$numDeletionDays.Font = New-Object System.Drawing.Font("Segoe UI", 12)
$numDeletionDays.BackColor = [System.Drawing.Color]::White
$pnlSettingsCard.Controls.Add($numDeletionDays)

$lblDeletionDesc = New-Object System.Windows.Forms.Label
$lblDeletionDesc.Location = New-Object System.Drawing.Point(60, 180)
$lblDeletionDesc.Size = New-Object System.Drawing.Size(700, 25)
$lblDeletionDesc.Text = "Bu gün sayısı aşıldığında dosyalar otomatik silinir (korunanlar hariç)"
$lblDeletionDesc.Font = New-Object System.Drawing.Font("Segoe UI", 9, [System.Drawing.FontStyle]::Italic)
$lblDeletionDesc.ForeColor = $script:colorText
$pnlSettingsCard.Controls.Add($lblDeletionDesc)

# Bilgi kutusu
$pnlInfo = New-Object System.Windows.Forms.Panel
$pnlInfo.Location = New-Object System.Drawing.Point(40, 230)
$pnlInfo.Size = New-Object System.Drawing.Size(720, 80)
$pnlInfo.BackColor = [System.Drawing.Color]::FromArgb(255, 243, 205)
$pnlSettingsCard.Controls.Add($pnlInfo)

$lblInfo = New-Object System.Windows.Forms.Label
$lblInfo.Location = New-Object System.Drawing.Point(15, 15)
$lblInfo.Size = New-Object System.Drawing.Size(690, 50)
$lblInfo.Text = "ℹ️ Önemli: Otomatik silme gün sayısı, uyarı gün sayısından büyük olmalıdır!`nÖrnek: Uyarı 7 gün, Otomatik silme 14 gün"
$lblInfo.Font = New-Object System.Drawing.Font("Segoe UI", 9)
$lblInfo.ForeColor = [System.Drawing.Color]::FromArgb(133, 100, 4)
$pnlInfo.Controls.Add($lblInfo)

# Kaydet butonu
$btnSaveSettings = New-Object System.Windows.Forms.Button
$btnSaveSettings.Location = New-Object System.Drawing.Point(500, 325)
$btnSaveSettings.Size = New-Object System.Drawing.Size(150, 45)
$btnSaveSettings.Text = "💾 Kaydet"
$btnSaveSettings.Font = New-Object System.Drawing.Font("Segoe UI", 12, [System.Drawing.FontStyle]::Bold)
$btnSaveSettings.BackColor = $script:colorSuccess
$btnSaveSettings.ForeColor = [System.Drawing.Color]::White
$btnSaveSettings.FlatStyle = "Flat"
$btnSaveSettings.FlatAppearance.BorderSize = 0
$btnSaveSettings.Cursor = [System.Windows.Forms.Cursors]::Hand
$btnSaveSettings.Add_Click({
        if ($numDeletionDays.Value -le $numWarningDays.Value) {
            [System.Windows.Forms.MessageBox]::Show("Otomatik silme gün sayısı, uyarı gün sayısından büyük olmalıdır!", "Hata", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Error)
            return
        }
    
        $config = @{
            warningDays  = $numWarningDays.Value
            deletionDays = $numDeletionDays.Value
        }
        Set-Config -config $config
        [System.Windows.Forms.MessageBox]::Show("Ayarlar başarıyla kaydedildi!", "Başarılı", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Information)
    })
$pnlSettingsCard.Controls.Add($btnSaveSettings)

#endregion

#region Tab 3: Korunan Dosyalar
$tabProtected = New-Object System.Windows.Forms.TabPage
$tabProtected.Text = "  Korunan Dosyalar  "
$tabProtected.BackColor = [System.Drawing.Color]::White
$tabControl.Controls.Add($tabProtected)

$lblProtectedHeader = New-Object System.Windows.Forms.Label
$lblProtectedHeader.Location = New-Object System.Drawing.Point(30, 30)
$lblProtectedHeader.Size = New-Object System.Drawing.Size(800, 40)
$lblProtectedHeader.Text = "🛡️ Korunan Dosyalar"
$lblProtectedHeader.Font = New-Object System.Drawing.Font("Segoe UI", 18, [System.Drawing.FontStyle]::Bold)
$lblProtectedHeader.ForeColor = $script:colorDark
$tabProtected.Controls.Add($lblProtectedHeader)

$dgvProtected = New-Object System.Windows.Forms.DataGridView
$dgvProtected.Location = New-Object System.Drawing.Point(30, 90)
$dgvProtected.Size = New-Object System.Drawing.Size(800, 350)
$dgvProtected.AutoSizeColumnsMode = "Fill"
$dgvProtected.SelectionMode = "FullRowSelect"
$dgvProtected.MultiSelect = $false
$dgvProtected.ReadOnly = $true
$dgvProtected.AllowUserToAddRows = $false
$dgvProtected.BackgroundColor = [System.Drawing.Color]::White
$dgvProtected.BorderStyle = "None"
$dgvProtected.Font = New-Object System.Drawing.Font("Segoe UI", 10)
$tabProtected.Controls.Add($dgvProtected)

$btnRemoveProtection = New-Object System.Windows.Forms.Button
$btnRemoveProtection.Location = New-Object System.Drawing.Point(30, 455)
$btnRemoveProtection.Size = New-Object System.Drawing.Size(200, 45)
$btnRemoveProtection.Text = "✕ Korumayı Kaldır"
$btnRemoveProtection.Font = New-Object System.Drawing.Font("Segoe UI", 11)
$btnRemoveProtection.BackColor = $script:colorDanger
$btnRemoveProtection.ForeColor = [System.Drawing.Color]::White
$btnRemoveProtection.FlatStyle = "Flat"
$btnRemoveProtection.FlatAppearance.BorderSize = 0
$btnRemoveProtection.Cursor = [System.Windows.Forms.Cursors]::Hand
$btnRemoveProtection.Add_Click({
        if ($dgvProtected.SelectedRows.Count -gt 0) {
            $selectedPath = $dgvProtected.SelectedRows[0].Cells[0].Value
        
            $result = [System.Windows.Forms.MessageBox]::Show("Bu dosyanın korumasını kaldırmak istediğinize emin misiniz?`n`n$selectedPath", "Onay", [System.Windows.Forms.MessageBoxButtons]::YesNo, [System.Windows.Forms.MessageBoxIcon]::Question)
        
            if ($result -eq [System.Windows.Forms.DialogResult]::Yes) {
                $protected = Get-Content $script:protectedFile -Raw | ConvertFrom-Json
                $protected.files = $protected.files | Where-Object { $_.path -ne $selectedPath }
                $protected | ConvertTo-Json -Depth 10 | Out-File $script:protectedFile -Encoding UTF8
            
                Load-ProtectedFilesGrid
                Update-StatusInfo
                [System.Windows.Forms.MessageBox]::Show("Koruma kaldırıldı!", "Başarılı", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Information)
            }
        }
        else {
            [System.Windows.Forms.MessageBox]::Show("Lütfen bir dosya seçin", "Uyarı", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Warning)
        }
    })
$tabProtected.Controls.Add($btnRemoveProtection)

$btnRefreshProtected = New-Object System.Windows.Forms.Button
$btnRefreshProtected.Location = New-Object System.Drawing.Point(630, 455)
$btnRefreshProtected.Size = New-Object System.Drawing.Size(200, 45)
$btnRefreshProtected.Text = "🔄 Yenile"
$btnRefreshProtected.Font = New-Object System.Drawing.Font("Segoe UI", 11)
$btnRefreshProtected.BackColor = $script:colorPrimary
$btnRefreshProtected.ForeColor = [System.Drawing.Color]::White
$btnRefreshProtected.FlatStyle = "Flat"
$btnRefreshProtected.FlatAppearance.BorderSize = 0
$btnRefreshProtected.Cursor = [System.Windows.Forms.Cursors]::Hand
$btnRefreshProtected.Add_Click({
        Load-ProtectedFilesGrid
    })
$tabProtected.Controls.Add($btnRefreshProtected)

#endregion

#region Tab 4: Log
$tabLog = New-Object System.Windows.Forms.TabPage
$tabLog.Text = "  Log  "
$tabLog.BackColor = [System.Drawing.Color]::White
$tabControl.Controls.Add($tabLog)

$lblLogHeader = New-Object System.Windows.Forms.Label
$lblLogHeader.Location = New-Object System.Drawing.Point(30, 30)
$lblLogHeader.Size = New-Object System.Drawing.Size(800, 40)
$lblLogHeader.Text = "📋 İşlem Geçmişi"
$lblLogHeader.Font = New-Object System.Drawing.Font("Segoe UI", 18, [System.Drawing.FontStyle]::Bold)
$lblLogHeader.ForeColor = $script:colorDark
$tabLog.Controls.Add($lblLogHeader)

$txtLog = New-Object System.Windows.Forms.RichTextBox
$txtLog.Location = New-Object System.Drawing.Point(30, 90)
$txtLog.Size = New-Object System.Drawing.Size(800, 350)
$txtLog.Font = New-Object System.Drawing.Font("Consolas", 9)
$txtLog.ReadOnly = $true
$txtLog.BackColor = [System.Drawing.Color]::FromArgb(250, 250, 250)
$txtLog.BorderStyle = "None"
$tabLog.Controls.Add($txtLog)

$btnRefreshLog = New-Object System.Windows.Forms.Button
$btnRefreshLog.Location = New-Object System.Drawing.Point(430, 455)
$btnRefreshLog.Size = New-Object System.Drawing.Size(190, 45)
$btnRefreshLog.Text = "🔄 Yenile"
$btnRefreshLog.Font = New-Object System.Drawing.Font("Segoe UI", 11)
$btnRefreshLog.BackColor = $script:colorPrimary
$btnRefreshLog.ForeColor = [System.Drawing.Color]::White
$btnRefreshLog.FlatStyle = "Flat"
$btnRefreshLog.FlatAppearance.BorderSize = 0
$btnRefreshLog.Cursor = [System.Windows.Forms.Cursors]::Hand
$btnRefreshLog.Add_Click({
        Load-LogContent
    })
$tabLog.Controls.Add($btnRefreshLog)

$btnOpenLog = New-Object System.Windows.Forms.Button
$btnOpenLog.Location = New-Object System.Drawing.Point(640, 455)
$btnOpenLog.Size = New-Object System.Drawing.Size(190, 45)
$btnOpenLog.Text = "📄 Dosyayı Aç"
$btnOpenLog.Font = New-Object System.Drawing.Font("Segoe UI", 11)
$btnOpenLog.BackColor = $script:colorWarning
$btnOpenLog.ForeColor = [System.Drawing.Color]::White
$btnOpenLog.FlatStyle = "Flat"
$btnOpenLog.FlatAppearance.BorderSize = 0
$btnOpenLog.Cursor = [System.Windows.Forms.Cursors]::Hand
$btnOpenLog.Add_Click({
        if (Test-Path $script:logFile) {
            Start-Process notepad.exe -ArgumentList $script:logFile
        }
        else {
            [System.Windows.Forms.MessageBox]::Show("Log dosyası bulunamadı!", "Uyarı", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Warning)
        }
    })
$tabLog.Controls.Add($btnOpenLog)

#endregion

#region Tab 5: Hakkında
$tabAbout = New-Object System.Windows.Forms.TabPage
$tabAbout.Text = "  Hakkında  "
$tabAbout.BackColor = [System.Drawing.Color]::White
$tabControl.Controls.Add($tabAbout)

# Logo/Başlık paneli
$pnlAboutHeader = New-Object System.Windows.Forms.Panel
$pnlAboutHeader.Location = New-Object System.Drawing.Point(0, 0)
$pnlAboutHeader.Size = New-Object System.Drawing.Size(860, 150)
$pnlAboutHeader.BackColor = $script:colorPrimary
$tabAbout.Controls.Add($pnlAboutHeader)

$lblAboutTitle = New-Object System.Windows.Forms.Label
$lblAboutTitle.Location = New-Object System.Drawing.Point(30, 40)
$lblAboutTitle.Size = New-Object System.Drawing.Size(800, 50)
$lblAboutTitle.Text = "Kısa Süreli Dosya Temizleyici"
$lblAboutTitle.Font = New-Object System.Drawing.Font("Segoe UI", 20, [System.Drawing.FontStyle]::Bold)
$lblAboutTitle.ForeColor = [System.Drawing.Color]::White
$lblAboutTitle.TextAlign = "MiddleCenter"
$pnlAboutHeader.Controls.Add($lblAboutTitle)

$lblVersion = New-Object System.Drawing.Font("Segoe UI", 12)
$lblVersionText = New-Object System.Windows.Forms.Label
$lblVersionText.Location = New-Object System.Drawing.Point(30, 100)
$lblVersionText.Size = New-Object System.Drawing.Size(800, 30)
$lblVersionText.Text = "Versiyon 2.0.0"
$lblVersionText.Font = $lblVersion
$lblVersionText.ForeColor = [System.Drawing.Color]::FromArgb(236, 240, 241)
$lblVersionText.TextAlign = "MiddleCenter"
$pnlAboutHeader.Controls.Add($lblVersionText)

# İçerik
$lblDescription = New-Object System.Windows.Forms.Label
$lblDescription.Location = New-Object System.Drawing.Point(60, 180)
$lblDescription.Size = New-Object System.Drawing.Size(740, 100)
$lblDescription.Text = "Geçici dosyalarınızı otomatik olarak yönetin. Ayarlanabilir gün sayıları, dosya koruma sistemi ve kullanıcı dostu arayüz ile dosya yaşam döngüsünü tam kontrol edin."
$lblDescription.Font = New-Object System.Drawing.Font("Segoe UI", 11)
$lblDescription.ForeColor = $script:colorText
$lblDescription.TextAlign = "MiddleCenter"
$tabAbout.Controls.Add($lblDescription)

$linkGitHub = New-Object System.Windows.Forms.LinkLabel
$linkGitHub.Location = New-Object System.Drawing.Point(60, 310)
$linkGitHub.Size = New-Object System.Drawing.Size(740, 30)
$linkGitHub.Text = "🔗 GitHub: github.com/[username]/short-term-file-cleaner"
$linkGitHub.Font = New-Object System.Drawing.Font("Segoe UI", 11)
$linkGitHub.TextAlign = "MiddleCenter"
$linkGitHub.LinkColor = $script:colorPrimary
$linkGitHub.Add_LinkClicked({
        Start-Process "https://github.com"
    })
$tabAbout.Controls.Add($linkGitHub)

$lblLicense = New-Object System.Windows.Forms.Label
$lblLicense.Location = New-Object System.Drawing.Point(60, 360)
$lblLicense.Size = New-Object System.Drawing.Size(740, 30)
$lblLicense.Text = "📜 MIT License - Kişisel kullanım için özgürce kullanılabilir"
$lblLicense.Font = New-Object System.Drawing.Font("Segoe UI", 10)
$lblLicense.ForeColor = $script:colorText
$lblLicense.TextAlign = "MiddleCenter"
$tabAbout.Controls.Add($lblLicense)

#endregion

# StatusStrip
$statusStrip = New-Object System.Windows.Forms.StatusStrip
$statusStrip.BackColor = $script:colorLight
$statusLabel = New-Object System.Windows.Forms.ToolStripStatusLabel
$statusLabel.Text = "Hazır"
$statusLabel.Font = New-Object System.Drawing.Font("Segoe UI", 9)
$statusStrip.Items.Add($statusLabel) | Out-Null
$mainForm.Controls.Add($statusStrip)

# Helper fonksiyonlar
function Update-StatusInfo {
    $config = Get-Config
    $protected = Get-ProtectedFiles
    $isInstalled = Test-TaskInstalled
    
    if ($isInstalled) {
        $lblTaskStatus.Text = "✓ Durum: Kurulu ve aktif"
        $lblTaskStatus.ForeColor = $script:colorSuccess
        $lblNextRun.Text = "⏰ Sonraki çalışma: Bilgisayar açıldığında"
    }
    else {
        $lblTaskStatus.Text = "✕ Durum: Kurulu değil"
        $lblTaskStatus.ForeColor = $script:colorDanger
        $lblNextRun.Text = "⏰ Sonraki çalışma: -"
    }
    
    $lblProtectedCount.Text = "🛡️ Korunan dosya sayısı: $($protected.Count)"
}

function Load-ProtectedFilesGrid {
    $dgvProtected.Rows.Clear()
    $dgvProtected.Columns.Clear()
    
    $dgvProtected.Columns.Add("Path", "Dosya Yolu") | Out-Null
    $dgvProtected.Columns.Add("Date", "Korunma Tarihi") | Out-Null
    
    $protected = Get-ProtectedFiles
    foreach ($file in $protected) {
        $dgvProtected.Rows.Add($file.path, $file.protectedDate) | Out-Null
    }
}

function Load-LogContent {
    if (Test-Path $script:logFile) {
        $txtLog.Text = Get-Content $script:logFile -Raw
        $txtLog.SelectionStart = $txtLog.Text.Length
        $txtLog.ScrollToCaret()
    }
    else {
        $txtLog.Text = "Log dosyası henüz oluşturulmamış."
    }
}

# Form yüklendiğinde
$mainForm.Add_Load({
        $config = Get-Config
        $numWarningDays.Value = $config.warningDays
        $numDeletionDays.Value = $config.deletionDays
    
        Update-StatusInfo
        Load-ProtectedFilesGrid
        Load-LogContent
    })

# Formu göster
[void]$mainForm.ShowDialog()
