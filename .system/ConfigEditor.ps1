# Kisa Sureli Dosya Temizleyici - Yapilandirma Editoru

$systemFolder = "$env:USERPROFILE\Desktop\short-term-files\.system"
$configFile = "$systemFolder\config.json"
$protectedFile = "$systemFolder\protected-files.json"

# Config yukle
function Load-Config {
    if (Test-Path $configFile) {
        return Get-Content $configFile -Raw | ConvertFrom-Json
    }
    return @{ warningDays = 7; deletionDays = 14 }
}

# Config kaydet
function Save-Config {
    param($config)
    $config.lastModified = (Get-Date -Format "yyyy-MM-ddTHH:mm:sszzz")
    $config | ConvertTo-Json | Out-File $configFile -Encoding UTF8
}

# Korunan dosyalari yukle
function Load-ProtectedFiles {
    if (Test-Path $protectedFile) {
        $protected = Get-Content $protectedFile -Raw | ConvertFrom-Json
        return $protected.files
    }
    return @()
}

# Korumayi kaldir
function Remove-Protection {
    param([string]$filePath)
    
    if (Test-Path $protectedFile) {
        $protected = Get-Content $protectedFile -Raw | ConvertFrom-Json
        $protected.files = $protected.files | Where-Object { $_.path -ne $filePath }
        $protected | ConvertTo-Json -Depth 10 | Out-File $protectedFile -Encoding UTF8
    }
}

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

$config = Load-Config
$protectedFiles = Load-ProtectedFiles

# Form olustur
$form = New-Object System.Windows.Forms.Form
$form.Text = "Yapilandirma Editoru"
$form.Size = New-Object System.Drawing.Size(600, 550)
$form.StartPosition = "CenterScreen"
$form.FormBorderStyle = "FixedDialog"
$form.MaximizeBox = $false

# Baslik
$labelTitle = New-Object System.Windows.Forms.Label
$labelTitle.Location = New-Object System.Drawing.Point(20, 20)
$labelTitle.Size = New-Object System.Drawing.Size(560, 30)
$labelTitle.Text = "Dosya Temizleme Ayarlari"
$labelTitle.Font = New-Object System.Drawing.Font("Segoe UI", 14, [System.Drawing.FontStyle]::Bold)
$form.Controls.Add($labelTitle)

# Uyari gun sayisi
$labelWarning = New-Object System.Windows.Forms.Label
$labelWarning.Location = New-Object System.Drawing.Point(20, 70)
$labelWarning.Size = New-Object System.Drawing.Size(300, 20)
$labelWarning.Text = "Uyari Gun Sayisi:"
$labelWarning.Font = New-Object System.Drawing.Font("Segoe UI", 10)
$form.Controls.Add($labelWarning)

$numericWarning = New-Object System.Windows.Forms.NumericUpDown
$numericWarning.Location = New-Object System.Drawing.Point(330, 68)
$numericWarning.Size = New-Object System.Drawing.Size(100, 25)
$numericWarning.Minimum = 1
$numericWarning.Maximum = 365
$numericWarning.Value = $config.warningDays
$numericWarning.Font = New-Object System.Drawing.Font("Segoe UI", 10)
$form.Controls.Add($numericWarning)

$labelWarningDesc = New-Object System.Windows.Forms.Label
$labelWarningDesc.Location = New-Object System.Drawing.Point(40, 95)
$labelWarningDesc.Size = New-Object System.Drawing.Size(520, 20)
$labelWarningDesc.Text = "Bu gun sayisi asildiginda uyari penceresi acar"
$labelWarningDesc.Font = New-Object System.Drawing.Font("Segoe UI", 8)
$labelWarningDesc.ForeColor = [System.Drawing.Color]::Gray
$form.Controls.Add($labelWarningDesc)

# Silme gun sayisi
$labelDeletion = New-Object System.Windows.Forms.Label
$labelDeletion.Location = New-Object System.Drawing.Point(20, 130)
$labelDeletion.Size = New-Object System.Drawing.Size(300, 20)
$labelDeletion.Text = "Otomatik Silme Gun Sayisi:"
$labelDeletion.Font = New-Object System.Drawing.Font("Segoe UI", 10)
$form.Controls.Add($labelDeletion)

$numericDeletion = New-Object System.Windows.Forms.NumericUpDown
$numericDeletion.Location = New-Object System.Drawing.Point(330, 128)
$numericDeletion.Size = New-Object System.Drawing.Size(100, 25)
$numericDeletion.Minimum = 1
$numericDeletion.Maximum = 365
$numericDeletion.Value = $config.deletionDays
$numericDeletion.Font = New-Object System.Drawing.Font("Segoe UI", 10)
$form.Controls.Add($numericDeletion)

$labelDeletionDesc = New-Object System.Windows.Forms.Label
$labelDeletionDesc.Location = New-Object System.Drawing.Point(40, 155)
$labelDeletionDesc.Size = New-Object System.Drawing.Size(520, 20)
$labelDeletionDesc.Text = "Bu gun sayisi asildiginda dosyalar otomatik silinir (korunanlar haric)"
$labelDeletionDesc.Font = New-Object System.Drawing.Font("Segoe UI", 8)
$labelDeletionDesc.ForeColor = [System.Drawing.Color]::Gray
$form.Controls.Add($labelDeletionDesc)

# Ayirici cizgi
$separator = New-Object System.Windows.Forms.Label
$separator.Location = New-Object System.Drawing.Point(20, 190)
$separator.Size = New-Object System.Drawing.Size(560, 2)
$separator.BorderStyle = "Fixed3D"
$form.Controls.Add($separator)

# Korunan dosyalar
$labelProtected = New-Object System.Windows.Forms.Label
$labelProtected.Location = New-Object System.Drawing.Point(20, 205)
$labelProtected.Size = New-Object System.Drawing.Size(560, 25)
$labelProtected.Text = "Korunan Dosyalar ($($protectedFiles.Count) dosya)"
$labelProtected.Font = New-Object System.Drawing.Font("Segoe UI", 11, [System.Drawing.FontStyle]::Bold)
$form.Controls.Add($labelProtected)

# Korunan dosyalar listesi
$listProtected = New-Object System.Windows.Forms.ListBox
$listProtected.Location = New-Object System.Drawing.Point(20, 235)
$listProtected.Size = New-Object System.Drawing.Size(560, 180)
$listProtected.Font = New-Object System.Drawing.Font("Consolas", 9)

foreach ($file in $protectedFiles) {
    $listProtected.Items.Add("$($file.path) - Korunma: $($file.protectedDate)") | Out-Null
}

$form.Controls.Add($listProtected)

# Koruma kaldir butonu
$buttonRemoveProtection = New-Object System.Windows.Forms.Button
$buttonRemoveProtection.Location = New-Object System.Drawing.Point(20, 425)
$buttonRemoveProtection.Size = New-Object System.Drawing.Size(150, 30)
$buttonRemoveProtection.Text = "Korumayi Kaldir"
$buttonRemoveProtection.Font = New-Object System.Drawing.Font("Segoe UI", 9)
$buttonRemoveProtection.BackColor = [System.Drawing.Color]::LightCoral
$buttonRemoveProtection.FlatStyle = "Flat"
$buttonRemoveProtection.Add_Click({
        if ($listProtected.SelectedIndex -ge 0) {
            $selectedText = $listProtected.SelectedItem
            $filePath = $selectedText.Split(" - ")[0]
        
            $result = [System.Windows.Forms.MessageBox]::Show(
                "Bu dosyanin korumasini kaldirmak istediginize emin misiniz?`n`n$filePath",
                "Koruma Kaldirma",
                [System.Windows.Forms.MessageBoxButtons]::YesNo,
                [System.Windows.Forms.MessageBoxIcon]::Question
            )
        
            if ($result -eq [System.Windows.Forms.DialogResult]::Yes) {
                Remove-Protection -filePath $filePath
                $listProtected.Items.RemoveAt($listProtected.SelectedIndex)
                $labelProtected.Text = "Korunan Dosyalar ($($listProtected.Items.Count) dosya)"
                [System.Windows.Forms.MessageBox]::Show("Koruma kaldirildi!", "Basarili", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Information)
            }
        }
        else {
            [System.Windows.Forms.MessageBox]::Show("Lutfen bir dosya secin", "Uyari", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Warning)
        }
    })
$form.Controls.Add($buttonRemoveProtection)

# Kaydet butonu
$buttonSave = New-Object System.Windows.Forms.Button
$buttonSave.Location = New-Object System.Drawing.Point(430, 470)
$buttonSave.Size = New-Object System.Drawing.Size(150, 35)
$buttonSave.Text = "Kaydet"
$buttonSave.Font = New-Object System.Drawing.Font("Segoe UI", 10, [System.Drawing.FontStyle]::Bold)
$buttonSave.BackColor = [System.Drawing.Color]::LightGreen
$buttonSave.FlatStyle = "Flat"
$buttonSave.Add_Click({
        # Validasyon
        if ($numericDeletion.Value -le $numericWarning.Value) {
            [System.Windows.Forms.MessageBox]::Show(
                "Otomatik silme gun sayisi, uyari gun sayisindan buyuk olmalidir!",
                "Hata",
                [System.Windows.Forms.MessageBoxButtons]::OK,
                [System.Windows.Forms.MessageBoxIcon]::Error
            )
            return
        }
    
        $config.warningDays = $numericWarning.Value
        $config.deletionDays = $numericDeletion.Value
        Save-Config -config $config
    
        [System.Windows.Forms.MessageBox]::Show("Ayarlar kaydedildi!", "Basarili", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Information)
        $form.Close()
    })
$form.Controls.Add($buttonSave)

# Iptal butonu
$buttonCancel = New-Object System.Windows.Forms.Button
$buttonCancel.Location = New-Object System.Drawing.Point(270, 470)
$buttonCancel.Size = New-Object System.Drawing.Size(150, 35)
$buttonCancel.Text = "Iptal"
$buttonCancel.Font = New-Object System.Drawing.Font("Segoe UI", 10)
$buttonCancel.BackColor = [System.Drawing.Color]::LightGray
$buttonCancel.FlatStyle = "Flat"
$buttonCancel.Add_Click({
        $form.Close()
    })
$form.Controls.Add($buttonCancel)

$form.ShowDialog() | Out-Null
