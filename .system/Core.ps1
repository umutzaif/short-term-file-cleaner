# Kısa Süreli Dosya Temizleyici - ortak çekirdek
# MainApp.ps1, Install.ps1 ve Uninstall.ps1 tarafından dot-source edilir.
# Not: Tüm dosya işlemleri -LiteralPath kullanır; köşeli parantez içeren adlar ([ ]) joker karakter sayılmaz.

$script:AppVersion    = '3.0.0'
$script:RepoUrl       = 'https://github.com/umutzaif/short-term-file-cleaner'
$script:SystemFolder  = $PSScriptRoot
$script:BaseFolder    = Split-Path -Parent $PSScriptRoot
$script:ConfigFile    = Join-Path $script:SystemFolder 'config.json'
$script:ProtectedFile = Join-Path $script:SystemFolder 'protected-files.json'
$script:LogFile       = Join-Path $script:SystemFolder 'cleanup.log'
$script:LauncherExe   = Join-Path $script:SystemFolder 'Launcher.exe'
$script:TaskName      = 'ShortTermFileCleaner'
$script:ShortcutPath  = Join-Path ([Environment]::GetFolderPath('Programs')) 'Kısa Süreli Dosya Temizleyici.lnk'
$script:PowerShellExe = Join-Path $env:SystemRoot 'System32\WindowsPowerShell\v1.0\powershell.exe'

# Kök klasörde uygulamaya ait olup taramaya dahil edilmeyen öğeler
$script:AppDirs  = @('.system', '.git')
$script:AppFiles = @('MainApp.ps1', 'README.md', 'LICENSE', 'CHANGELOG.md', '.gitignore')

#region Log
function Write-Log {
    param([string]$Message)
    $line = '{0} - {1}{2}' -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), $Message, [Environment]::NewLine
    try { [System.IO.File]::AppendAllText($script:LogFile, $line, [System.Text.Encoding]::UTF8) } catch { }
}

function Invoke-LogRotation {
    param([long]$MaxBytes = 1MB, [int]$KeepLines = 3000)
    try {
        $item = Get-Item -LiteralPath $script:LogFile -ErrorAction Stop
        if ($item.Length -gt $MaxBytes) {
            $lines = Get-Content -LiteralPath $script:LogFile -Encoding UTF8 -Tail $KeepLines
            [System.IO.File]::WriteAllLines($script:LogFile, [string[]]$lines, (New-Object System.Text.UTF8Encoding $true))
        }
    }
    catch { }
}
#endregion

#region Yapılandırma ve koruma listesi
function Write-JsonFile {
    param([string]$Path, $Data)
    $json = $Data | ConvertTo-Json -Depth 10
    [System.IO.File]::WriteAllText($Path, $json, (New-Object System.Text.UTF8Encoding $false))
}

function Get-Config {
    $cfg = [ordered]@{ warningDays = 7; deletionDays = 14; useRecycleBin = $false }
    if (Test-Path -LiteralPath $script:ConfigFile) {
        try {
            $json = Get-Content -LiteralPath $script:ConfigFile -Raw -Encoding UTF8 | ConvertFrom-Json
            foreach ($key in @($cfg.Keys)) {
                if ($null -ne $json.$key) { $cfg[$key] = $json.$key }
            }
        }
        catch { Write-Log 'Config okunamadi, varsayilan degerler kullaniliyor' }
    }
    [pscustomobject]@{
        warningDays   = [int]$cfg.warningDays
        deletionDays  = [int]$cfg.deletionDays
        useRecycleBin = [bool]$cfg.useRecycleBin
    }
}

function Save-Config {
    param($Config)
    Write-JsonFile $script:ConfigFile ([ordered]@{
            warningDays   = [int]$Config.warningDays
            deletionDays  = [int]$Config.deletionDays
            useRecycleBin = [bool]$Config.useRecycleBin
            lastModified  = (Get-Date -Format 'yyyy-MM-ddTHH:mm:sszzz')
        })
    Write-Log "Ayarlar kaydedildi: Uyari=$($Config.warningDays) gun, Silme=$($Config.deletionDays) gun, GeriDonusum=$($Config.useRecycleBin)"
}

function Get-ProtectedEntries {
    if (-not (Test-Path -LiteralPath $script:ProtectedFile)) { return @() }
    try {
        $data = Get-Content -LiteralPath $script:ProtectedFile -Raw -Encoding UTF8 | ConvertFrom-Json
        return @($data.files | Where-Object { $_ -and $_.path })
    }
    catch {
        Write-Log 'Korunan dosya listesi okunamadi'
        return @()
    }
}

function Save-ProtectedEntries {
    param([object[]]$Entries)
    Write-JsonFile $script:ProtectedFile @{ files = @($Entries) }
}

function Get-RelativePath {
    param([string]$FullPath)
    $prefix = $script:BaseFolder.TrimEnd('\') + '\'
    if ($FullPath.StartsWith($prefix, [StringComparison]::OrdinalIgnoreCase)) { return $FullPath.Substring($prefix.Length) }
    return $FullPath
}

function Test-InBaseFolder {
    param([string]$FullPath)
    $prefix = $script:BaseFolder.TrimEnd('\') + '\'
    return $FullPath.StartsWith($prefix, [StringComparison]::OrdinalIgnoreCase)
}

function Add-Protection {
    param([string[]]$FullPaths)
    $entries = New-Object System.Collections.ArrayList
    foreach ($e in Get-ProtectedEntries) { [void]$entries.Add($e) }
    $added = 0
    foreach ($path in $FullPaths) {
        $rel = Get-RelativePath $path
        if (-not ($entries | Where-Object { $_.path -eq $rel })) {
            [void]$entries.Add([pscustomobject]@{
                    path          = $rel
                    protectedDate = (Get-Date -Format 'yyyy-MM-ddTHH:mm:sszzz')
                    reason        = 'Kullanici korumaya aldi'
                })
            Write-Log "Korumaya alindi: $rel"
            $added++
        }
    }
    Save-ProtectedEntries $entries.ToArray()
    return $added
}

function Remove-Protection {
    param([string[]]$RelativePaths)
    $remaining = @(Get-ProtectedEntries | Where-Object { $RelativePaths -notcontains $_.path })
    Save-ProtectedEntries $remaining
    foreach ($rel in $RelativePaths) { Write-Log "Koruma kaldirildi: $rel" }
}
#endregion

#region Tarama
# Klasör ağacını gezer; uygulama dosyalarını, gizli/sistem öğelerini ve bağlantı noktalarını (junction) atlar.
function Get-ManagedItems {
    $stack = New-Object System.Collections.Stack
    $stack.Push($script:BaseFolder)
    while ($stack.Count -gt 0) {
        $dir = $stack.Pop()
        $isRoot = ($dir -eq $script:BaseFolder)
        foreach ($item in Get-ChildItem -LiteralPath $dir -ErrorAction SilentlyContinue) {
            if ($item.PSIsContainer) {
                if ($isRoot -and $script:AppDirs -contains $item.Name) { continue }
                if ($item.Attributes -band [System.IO.FileAttributes]::ReparsePoint) { continue }
                $stack.Push($item.FullName)
                $item
            }
            else {
                if ($isRoot -and $script:AppFiles -contains $item.Name) { continue }
                if ($item.Extension -eq '.ps1' -or $item.Name -eq 'README.md') { continue }
                $item
            }
        }
    }
}

# Dosyanın klasöre geliş zamanı: oluşturma ve değiştirme tarihlerinden yenisi.
# Böylece klasöre kopyalanan eski bir dosya hemen "süresi dolmuş" sayılmaz.
function Get-FileArrival {
    param([System.IO.FileInfo]$File)
    if ($File.CreationTime -gt $File.LastWriteTime) { return $File.CreationTime }
    return $File.LastWriteTime
}

function Get-ManagedFiles {
    param($Config = (Get-Config))
    $now = Get-Date
    $protected = @{}
    foreach ($e in Get-ProtectedEntries) { $protected[([string]$e.path).ToLowerInvariant()] = $true }

    foreach ($f in Get-ManagedItems) {
        if ($f.PSIsContainer) { continue }
        $rel = Get-RelativePath $f.FullName
        $age = ($now - (Get-FileArrival $f)).TotalDays
        $isProtected = $protected.ContainsKey($rel.ToLowerInvariant())
        $stage = if ($isProtected) { 'protected' }
        elseif ($age -ge $Config.deletionDays) { 'expired' }
        elseif ($age -ge $Config.warningDays) { 'warning' }
        else { 'fresh' }
        $folder = Split-Path -Parent $rel

        [pscustomobject]@{
            FullName  = $f.FullName
            RelPath   = $rel
            Name      = $f.Name
            Folder    = $(if ($folder) { $folder } else { '' })
            Extension = $f.Extension
            Size      = $f.Length
            AgeDays   = $age
            DaysLeft  = [int][math]::Ceiling($Config.deletionDays - $age)
            Stage     = $stage
        }
    }
}
#endregion

#region Silme
function Remove-ManagedFile {
    param([string]$FullPath, [bool]$Recycle)
    if (-not (Test-InBaseFolder $FullPath)) { throw 'Dosya short-term-files klasorunun disinda' }
    if (-not (Test-Path -LiteralPath $FullPath -PathType Leaf)) { return $true }
    if ($Recycle) {
        Add-Type -AssemblyName Microsoft.VisualBasic
        [Microsoft.VisualBasic.FileIO.FileSystem]::DeleteFile($FullPath,
            [Microsoft.VisualBasic.FileIO.UIOption]::OnlyErrorDialogs,
            [Microsoft.VisualBasic.FileIO.RecycleOption]::SendToRecycleBin)
    }
    else {
        Remove-Item -LiteralPath $FullPath -Force -ErrorAction Stop
    }
    return -not (Test-Path -LiteralPath $FullPath)
}

function Remove-Files {
    param([string[]]$Paths, [bool]$Recycle, [string]$Label = 'Silindi')
    $deleted = 0
    $failed = New-Object System.Collections.Generic.List[string]
    foreach ($path in $Paths) {
        $rel = Get-RelativePath $path
        try {
            if (Remove-ManagedFile -FullPath $path -Recycle $Recycle) {
                $deleted++
                Write-Log "${Label}: $rel"
            }
            else {
                $failed.Add("$rel (dosya hala mevcut)")
                Write-Log "Silme hatasi: $rel - dosya hala mevcut"
            }
        }
        catch {
            $failed.Add("$rel ($($_.Exception.Message))")
            Write-Log "Silme hatasi: $rel - $($_.Exception.Message)"
        }
    }
    if ($Paths.Count -gt 0) {
        Write-Log "Silme islemi tamamlandi. Silinen: $deleted, Hata: $($failed.Count)"
        [void](Remove-EmptyFolders)
    }
    [pscustomobject]@{ Deleted = $deleted; Failed = $failed.ToArray() }
}

function Remove-EmptyFolders {
    $removed = 0
    $dirs = @(Get-ManagedItems | Where-Object { $_.PSIsContainer } | Sort-Object { $_.FullName.Length } -Descending)
    foreach ($dir in $dirs) {
        if (Get-ChildItem -LiteralPath $dir.FullName -Force -ErrorAction SilentlyContinue | Select-Object -First 1) { continue }
        try {
            Remove-Item -LiteralPath $dir.FullName -Force -ErrorAction Stop
            Write-Log "Bos klasor silindi: $(Get-RelativePath $dir.FullName)"
            $removed++
        }
        catch { Write-Log "Bos klasor silme hatasi: $(Get-RelativePath $dir.FullName) - $($_.Exception.Message)" }
    }
    return $removed
}

function Invoke-AutoCleanup {
    param($Config = (Get-Config))
    $expired = @(Get-ManagedFiles -Config $Config | Where-Object { $_.Stage -eq 'expired' })
    if ($expired.Count -eq 0) { return 0 }
    Write-Log "Otomatik silme: $($expired.Count) dosya bulundu"
    $result = Remove-Files -Paths ($expired | ForEach-Object { $_.FullName }) -Recycle $Config.useRecycleBin -Label 'Otomatik silindi'
    return $result.Deleted
}
#endregion

#region Otomatik başlatma (Görev Zamanlayıcı)
function Build-Launcher {
    try {
        if (Test-Path -LiteralPath $script:LauncherExe) { Remove-Item -LiteralPath $script:LauncherExe -Force -ErrorAction Stop }
        $source = Get-Content -LiteralPath (Join-Path $script:SystemFolder 'Launcher.cs') -Raw -Encoding UTF8
        Add-Type -TypeDefinition $source -OutputAssembly $script:LauncherExe -OutputType WindowsApplication -ErrorAction Stop
        return (Test-Path -LiteralPath $script:LauncherExe)
    }
    catch {
        Write-Log "Sessiz baslatici derlenemedi: $($_.Exception.Message)"
        return $false
    }
}

function Get-TaskInfo {
    $task = Get-ScheduledTask -TaskName $script:TaskName -ErrorAction SilentlyContinue
    if (-not $task) { return $null }
    $info = $task | Get-ScheduledTaskInfo -ErrorAction SilentlyContinue
    $exe = [string]$task.Actions[0].Execute
    [pscustomobject]@{
        State   = [string]$task.State
        LastRun = $(if ($info -and $info.LastRunTime -and $info.LastRunTime.Year -gt 2000) { $info.LastRunTime } else { $null })
        Silent  = ($exe -like '*Launcher.exe' -or $exe -like '*conhost.exe')
    }
}

function New-AppShortcut {
    param([bool]$UseLauncher)
    try {
        $shell = New-Object -ComObject WScript.Shell
        $lnk = $shell.CreateShortcut($script:ShortcutPath)
        if ($UseLauncher) {
            $lnk.TargetPath = $script:LauncherExe
            $lnk.Arguments = ''
        }
        else {
            $lnk.TargetPath = $script:PowerShellExe
            $lnk.Arguments = "-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File `"$(Join-Path $script:BaseFolder 'MainApp.ps1')`""
        }
        $lnk.WorkingDirectory = $script:BaseFolder
        $lnk.IconLocation = "$env:SystemRoot\System32\shell32.dll,31"
        $lnk.Description = 'Kısa Süreli Dosya Temizleyici'
        $lnk.Save()
    }
    catch { Write-Log "Baslat menusu kisayolu olusturulamadi: $($_.Exception.Message)" }
}

# Görevi oluşturur/günceller. Dönüş: 'launcher' (pencere yok) veya 'conhost' (yedek yöntem).
# -AllowElevation: eski görev yönetici olarak oluşturulmuşsa UAC onayı istenmesine izin verir.
function Install-CleanupTask {
    param([switch]$AllowElevation)
    foreach ($f in @($script:ConfigFile, $script:ProtectedFile)) {
        if (-not (Test-Path -LiteralPath $f)) {
            if ($f -eq $script:ConfigFile) { Save-Config (Get-Config) } else { Save-ProtectedEntries @() }
        }
    }

    $useLauncher = Build-Launcher
    if ($useLauncher) {
        $action = New-ScheduledTaskAction -Execute $script:LauncherExe -Argument '/startup' -WorkingDirectory $script:SystemFolder
        $mode = 'launcher'
    }
    else {
        $mainApp = Join-Path $script:BaseFolder 'MainApp.ps1'
        $action = New-ScheduledTaskAction -Execute (Join-Path $env:SystemRoot 'System32\conhost.exe') `
            -Argument "--headless `"$script:PowerShellExe`" -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File `"$mainApp`" -Startup"
        $mode = 'conhost'
    }

    $trigger = New-ScheduledTaskTrigger -AtLogOn -User $env:USERNAME
    $trigger.Delay = 'PT20S'
    $settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -StartWhenAvailable `
        -ExecutionTimeLimit ([TimeSpan]::Zero) -MultipleInstances IgnoreNew
    $register = {
        Register-ScheduledTask -TaskName $script:TaskName -Description 'Kisa sureli dosyalari oturum acilisinda pencere acmadan denetler' `
            -Action $action -Trigger $trigger -Settings $settings -User $env:USERNAME -RunLevel Limited -Force -ErrorAction Stop | Out-Null
    }

    try { & $register }
    catch {
        # Yönetici olarak oluşturulmuş eski bir görev normal kullanıcı tarafından üzerine yazılamaz:
        # önce kaldırılır, ardından görev kullanıcı adına yeniden oluşturulur.
        if (-not (Get-ScheduledTask -TaskName $script:TaskName -ErrorAction SilentlyContinue)) { throw }
        Write-Log "Mevcut gorev guncellenemedi ($($_.Exception.Message)), kaldirilip yeniden olusturuluyor"
        Remove-TaskWithFallback -AllowElevation:$AllowElevation
        & $register
    }

    New-AppShortcut -UseLauncher $useLauncher
    Write-Log "Otomatik gorev kuruldu ($mode)"
    return $mode
}

# Görevi kaldırır; erişim reddedilirse ve izin verilmişse tek seferlik yönetici onayı (UAC) ister.
function Remove-TaskWithFallback {
    param([switch]$AllowElevation)
    try {
        Unregister-ScheduledTask -TaskName $script:TaskName -Confirm:$false -ErrorAction Stop
        return
    }
    catch {
        if (-not $AllowElevation) { throw }
    }
    $cmd = "Unregister-ScheduledTask -TaskName '$script:TaskName' -Confirm:`$false"
    $proc = Start-Process -FilePath $script:PowerShellExe -Verb RunAs -WindowStyle Hidden -Wait -PassThru `
        -ArgumentList "-NoProfile -ExecutionPolicy Bypass -Command $cmd"
    if (Get-ScheduledTask -TaskName $script:TaskName -ErrorAction SilentlyContinue) {
        throw "Eski gorev kaldirilamadi (cikis kodu: $($proc.ExitCode))"
    }
}

function Uninstall-CleanupTask {
    param([switch]$AllowElevation)
    $removed = $false
    if (Get-ScheduledTask -TaskName $script:TaskName -ErrorAction SilentlyContinue) {
        Remove-TaskWithFallback -AllowElevation:$AllowElevation
        Write-Log 'Otomatik gorev kaldirildi'
        $removed = $true
    }
    if (Test-Path -LiteralPath $script:ShortcutPath) { Remove-Item -LiteralPath $script:ShortcutPath -Force -ErrorAction SilentlyContinue }
    return $removed
}
#endregion
