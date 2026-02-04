# Kisa Sureli Dosya Temizleyici v2.0
# Gelismis yapilandirma ve koruma sistemi ile

# Yapilandirma
$targetFolder = "$env:USERPROFILE\Desktop\short-term-files"
$systemFolder = "$targetFolder\.system"
$configFile = "$systemFolder\config.json"
$protectedFile = "$systemFolder\protected-files.json"
$logFile = "$systemFolder\cleanup.log"

# Log fonksiyonu
function Write-Log {
    param([string]$message)
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    "$timestamp - $message" | Out-File -FilePath $logFile -Append -Encoding UTF8
}

# Bos klasorleri sil
function Remove-EmptyFolders {
    param([string]$path)
    
    $deletedCount = 0
    
    # Alt klasorlerden baslayarak yukari dogru tara
    $folders = Get-ChildItem -Path $path -Directory -Recurse | Sort-Object -Property FullName -Descending
    
    foreach ($folder in $folders) {
        # .system klasorunu atla
        if ($folder.FullName -like "*\.system*") {
            continue
        }
        
        # Klasor bos mu kontrol et (dosya ve alt klasor yok)
        $items = Get-ChildItem -Path $folder.FullName -Force
        if ($items.Count -eq 0) {
            try {
                Remove-Item -Path $folder.FullName -Force
                $relativePath = $folder.FullName.Replace("$targetFolder\", "")
                Write-Log "Bos klasor silindi: $relativePath"
                $deletedCount++
            }
            catch {
                Write-Log "Bos klasor silme hatasi: $($folder.Name) - $($_.Exception.Message)"
            }
        }
    }
    
    if ($deletedCount -gt 0) {
        Write-Log "Toplam $deletedCount bos klasor silindi"
    }
    
    return $deletedCount
}

# Config yukleme
function Load-Config {
    if (Test-Path $configFile) {
        try {
            $config = Get-Content $configFile -Raw | ConvertFrom-Json
            return $config
        }
        catch {
            Write-Log "Config yukleme hatasi, default degerler kullaniliyor"
            return @{ warningDays = 7; deletionDays = 14 }
        }
    }
    else {
        # Default config olustur
        $defaultConfig = @{
            warningDays  = 7
            deletionDays = 14
            lastModified = (Get-Date -Format "yyyy-MM-ddTHH:mm:sszzz")
        }
        $defaultConfig | ConvertTo-Json | Out-File $configFile -Encoding UTF8
        return $defaultConfig
    }
}

# Korunan dosyalari yukle
function Load-ProtectedFiles {
    if (Test-Path $protectedFile) {
        try {
            $protected = Get-Content $protectedFile -Raw | ConvertFrom-Json
            return $protected.files
        }
        catch {
            Write-Log "Protected files yukleme hatasi"
            return @()
        }
    }
    else {
        @{ files = @() } | ConvertTo-Json | Out-File $protectedFile -Encoding UTF8
        return @()
    }
}

# Dosyayi korumaya al
function Add-ProtectedFile {
    param([string]$filePath)
    
    $protected = @{ files = @() }
    if (Test-Path $protectedFile) {
        $protected = Get-Content $protectedFile -Raw | ConvertFrom-Json
    }
    
    $relativePath = $filePath.Replace("$targetFolder\", "")
    
    # Zaten korunuyorsa ekleme
    $exists = $protected.files | Where-Object { $_.path -eq $relativePath }
    if (-not $exists) {
        $newEntry = @{
            path          = $relativePath
            protectedDate = (Get-Date -Format "yyyy-MM-ddTHH:mm:sszzz")
            reason        = "Kullanici korumaya aldi"
        }
        $protected.files += $newEntry
        $protected | ConvertTo-Json -Depth 10 | Out-File $protectedFile -Encoding UTF8
        Write-Log "Korumaya alindi: $relativePath"
    }
}

# Klasor kontrolu
if (-not (Test-Path $targetFolder)) {
    Write-Log "Klasor bulunamadi: $targetFolder"
    exit
}

# .system klasorunu olustur (yoksa)
if (-not (Test-Path $systemFolder)) {
    New-Item -ItemType Directory -Path $systemFolder -Force | Out-Null
}

# Config ve korunan dosyalari yukle
$config = Load-Config
$protectedFiles = Load-ProtectedFiles
$protectedPaths = $protectedFiles | ForEach-Object { "$targetFolder\$($_.path)" }

Write-Log "Config yuklendi: Uyari=$($config.warningDays) gun, Silme=$($config.deletionDays) gun"

# Dosyalari tara
$now = Get-Date
$warningDate = $now.AddDays(-$config.warningDays)
$deletionDate = $now.AddDays(-$config.deletionDays)

$allFiles = Get-ChildItem -Path $targetFolder -File -Recurse | Where-Object { 
    $_.FullName -notlike "*\.system\*" -and
    $_.Name -notlike "*.ps1" -and
    $_.Name -ne "README.md"
}

# Otomatik silme (Y gun asilmis, korunmayan dosyalar)
$autoDeleteFiles = $allFiles | Where-Object {
    $_.LastWriteTime -lt $deletionDate -and
    $protectedPaths -notcontains $_.FullName
}

if ($autoDeleteFiles.Count -gt 0) {
    Write-Log "Otomatik silme: $($autoDeleteFiles.Count) dosya bulundu"
    foreach ($file in $autoDeleteFiles) {
        try {
            Remove-Item -Path $file.FullName -Force
            $relativePath = $file.FullName.Replace("$targetFolder\", "")
            Write-Log "Otomatik silindi: $relativePath"
        }
        catch {
            Write-Log "Otomatik silme hatasi: $($file.Name) - $($_.Exception.Message)"
        }
    }
    
    # Bos klasorleri temizle
    Remove-EmptyFolders -path $targetFolder
}

# Uyari dosyalari (X gun asilmis ama Y gun asilmamis)
$warningFiles = $allFiles | Where-Object {
    $_.LastWriteTime -lt $warningDate -and
    $_.LastWriteTime -ge $deletionDate -and
    $protectedPaths -notcontains $_.FullName
}

# Uyari dosyasi yoksa sessizce cik
if ($warningFiles.Count -eq 0) {
    if ($autoDeleteFiles.Count -eq 0) {
        Write-Log "Islem gerektiren dosya bulunamadi"
    }
    exit
}

Write-Log "Uyari: $($warningFiles.Count) dosya bulundu"

# Windows Forms GUI olustur
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

$form = New-Object System.Windows.Forms.Form
$form.Text = "Kisa Sureli Dosya Temizleyici v2.0"
$form.Size = New-Object System.Drawing.Size(700, 500)
$form.StartPosition = "CenterScreen"
$form.FormBorderStyle = "FixedDialog"
$form.MaximizeBox = $false
$form.MinimizeBox = $false
$form.TopMost = $true

# Baslik etiketi
$labelTitle = New-Object System.Windows.Forms.Label
$labelTitle.Location = New-Object System.Drawing.Point(20, 20)
$labelTitle.Size = New-Object System.Drawing.Size(660, 30)
$labelTitle.Text = "Asagidaki dosyalar $($config.warningDays) gunden eski. Ne yapmak istersiniz?"
$labelTitle.Font = New-Object System.Drawing.Font("Segoe UI", 10, [System.Drawing.FontStyle]::Bold)
$form.Controls.Add($labelTitle)

# CheckedListBox (checkbox'li liste)
$checkedListBox = New-Object System.Windows.Forms.CheckedListBox
$checkedListBox.Location = New-Object System.Drawing.Point(20, 60)
$checkedListBox.Size = New-Object System.Drawing.Size(660, 320)
$checkedListBox.Font = New-Object System.Drawing.Font("Consolas", 9)
$checkedListBox.CheckOnClick = $true

foreach ($file in $warningFiles) {
    $fileAge = [math]::Round(($now - $file.LastWriteTime).TotalDays, 1)
    $fileSize = if ($file.Length -lt 1MB) { 
        "{0:N2} KB" -f ($file.Length / 1KB) 
    }
    else { 
        "{0:N2} MB" -f ($file.Length / 1MB) 
    }
    $relativePath = $file.FullName.Replace("$targetFolder\", "")
    $displayText = "$relativePath - $fileSize - $fileAge gun once"
    
    # Listeye ekle ve default olarak sec
    $index = $checkedListBox.Items.Add($displayText)
    $checkedListBox.SetItemChecked($index, $true)
}

$form.Controls.Add($checkedListBox)

# Bilgi etiketi
$labelInfo = New-Object System.Windows.Forms.Label
$labelInfo.Location = New-Object System.Drawing.Point(20, 390)
$labelInfo.Size = New-Object System.Drawing.Size(660, 20)
$labelInfo.Text = "Toplam: $($warningFiles.Count) dosya | $($config.deletionDays) gun sonra otomatik silinecek"
$labelInfo.Font = New-Object System.Drawing.Font("Segoe UI", 9)
$labelInfo.ForeColor = [System.Drawing.Color]::DarkOrange
$form.Controls.Add($labelInfo)

# Butonlar
$buttonY = 420

# Sil butonu
$buttonDelete = New-Object System.Windows.Forms.Button
$buttonDelete.Location = New-Object System.Drawing.Point(20, $buttonY)
$buttonDelete.Size = New-Object System.Drawing.Size(120, 35)
$buttonDelete.Text = "Sil"
$buttonDelete.Font = New-Object System.Drawing.Font("Segoe UI", 10, [System.Drawing.FontStyle]::Bold)
$buttonDelete.BackColor = [System.Drawing.Color]::IndianRed
$buttonDelete.ForeColor = [System.Drawing.Color]::White
$buttonDelete.FlatStyle = "Flat"
$buttonDelete.Tag = "DELETE"
$buttonDelete.DialogResult = [System.Windows.Forms.DialogResult]::Yes
$form.Controls.Add($buttonDelete)

# Atla butonu
$buttonSkip = New-Object System.Windows.Forms.Button
$buttonSkip.Location = New-Object System.Drawing.Point(150, $buttonY)
$buttonSkip.Size = New-Object System.Drawing.Size(120, 35)
$buttonSkip.Text = "Atla"
$buttonSkip.Font = New-Object System.Drawing.Font("Segoe UI", 10)
$buttonSkip.BackColor = [System.Drawing.Color]::LightGray
$buttonSkip.FlatStyle = "Flat"
$buttonSkip.Tag = "SKIP"
$buttonSkip.DialogResult = [System.Windows.Forms.DialogResult]::No
$form.Controls.Add($buttonSkip)

# Koru butonu
$buttonProtect = New-Object System.Windows.Forms.Button
$buttonProtect.Location = New-Object System.Drawing.Point(280, $buttonY)
$buttonProtect.Size = New-Object System.Drawing.Size(120, 35)
$buttonProtect.Text = "Koru"
$buttonProtect.Font = New-Object System.Drawing.Font("Segoe UI", 10, [System.Drawing.FontStyle]::Bold)
$buttonProtect.BackColor = [System.Drawing.Color]::LightGreen
$buttonProtect.FlatStyle = "Flat"
$buttonProtect.Tag = "PROTECT"
$buttonProtect.DialogResult = [System.Windows.Forms.DialogResult]::OK
$form.Controls.Add($buttonProtect)

# X butonuna basildiginda
$form.Add_FormClosing({
        param($s, $e)
        if ($form.DialogResult -eq [System.Windows.Forms.DialogResult]::None) {
            Write-Log "Kullanici pencereyi kapatti (X butonu)"
        }
    })

# Formu goster
$result = $form.ShowDialog()

# Secili dosyalari al
$selectedFiles = @()
for ($i = 0; $i -lt $checkedListBox.CheckedItems.Count; $i++) {
    $itemText = $checkedListBox.CheckedItems[$i]
    # Dosya yolunu ayikla (ilk kisim)
    $relativePath = $itemText.Split(" - ")[0]
    $fullPath = "$targetFolder\$relativePath"
    $selectedFiles += $warningFiles | Where-Object { $_.FullName -eq $fullPath }
}

Write-Log "Secili dosya sayisi: $($selectedFiles.Count)"

# Kullanici secime gore islem yap
if ($result -eq [System.Windows.Forms.DialogResult]::Yes) {
    # SIL
    $deletedCount = 0
    $errorCount = 0
    
    foreach ($file in $selectedFiles) {
        try {
            Remove-Item -Path $file.FullName -Force
            $relativePath = $file.FullName.Replace("$targetFolder\", "")
            Write-Log "Silindi: $relativePath"
            $deletedCount++
        }
        catch {
            Write-Log "Hata (silinemedi): $($file.Name) - $($_.Exception.Message)"
            $errorCount++
        }
    }
    
    Write-Log "Silme islemi tamamlandi. Silinen: $deletedCount, Hata: $errorCount"
    
    # Bos klasorleri temizle
    Remove-EmptyFolders -path $targetFolder
}
elseif ($result -eq [System.Windows.Forms.DialogResult]::OK) {
    # KORU
    foreach ($file in $selectedFiles) {
        Add-ProtectedFile -filePath $file.FullName
    }
    Write-Log "Koruma islemi tamamlandi. Korunan: $($selectedFiles.Count)"
}
elseif ($result -eq [System.Windows.Forms.DialogResult]::No) {
    # ATLA
    Write-Log "Kullanici dosyalari atlamayi secti"
}

# Formu temizle
$form.Dispose()
