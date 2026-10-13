# Kısa Süreli Dosya Temizleyici - ortak çekirdek
# MainApp.ps1, Install.ps1, Uninstall.ps1 ve build\Build.ps1 tarafından dot-source edilir.
# Not: Tüm dosya işlemleri -LiteralPath kullanır; köşeli parantez içeren adlar ([ ]) joker karakter sayılmaz.

$script:AppVersion    = '3.1.0'
$script:AppTitle      = 'Kısa Süreli Dosya Temizleyici'
$script:RepoUrl       = 'https://github.com/umutzaif/short-term-file-cleaner'
$script:SystemFolder  = $PSScriptRoot
$script:BaseFolder    = Split-Path -Parent $PSScriptRoot
$script:AssetsFolder  = Join-Path $script:SystemFolder 'assets'
$script:AppIcon       = Join-Path $script:AssetsFolder 'app.ico'
$script:AppPng        = Join-Path $script:AssetsFolder 'app.png'
$script:FolderIcon    = Join-Path $script:AssetsFolder 'folder.ico'
$script:ConfigFile    = Join-Path $script:SystemFolder 'config.json'
$script:ProtectedFile = Join-Path $script:SystemFolder 'protected-files.json'
$script:LogFile       = Join-Path $script:SystemFolder 'cleanup.log'
$script:AppExeName    = 'Dosya Temizleyici.exe'
$script:AppExe        = Join-Path $script:BaseFolder $script:AppExeName
$script:TaskName      = 'ShortTermFileCleaner'
$script:ShortcutName  = 'Kısa Süreli Dosya Temizleyici.lnk'
$script:StartMenuLink = Join-Path ([Environment]::GetFolderPath('Programs')) $script:ShortcutName
$script:DesktopLink   = Join-Path ([Environment]::GetFolderPath('Desktop')) $script:ShortcutName

# Kök klasörde uygulamaya ait olan, taramaya hiçbir zaman dahil edilmeyen ve korunamayan öğeler
$script:AppDirs  = @('.system', '.git', '.github')
$script:AppFiles = @($script:AppExeName, '.gitignore', 'desktop.ini')
# Eski sürümlerin kökte bıraktığı uygulama dosyaları (koruma listesinden temizlenir)
$script:LegacyRootFiles = @('MainApp.ps1', 'README.md', 'LICENSE', 'CHANGELOG.md', '.gitignore', 'cleanup.log')
$script:DataFiles = @('config.json', 'protected-files.json', 'cleanup.log', 'error.log')

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
    $cfg = [ordered]@{ warningDays = 7; deletionDays = 14; useRecycleBin = $false; showOnStartup = $true; setupDone = $false }
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
        showOnStartup = [bool]$cfg.showOnStartup
        setupDone     = [bool]$cfg.setupDone
    }
}

# Verilen alanları mevcut yapılandırmanın üzerine yazar (verilmeyen alanlar korunur).
function Save-Config {
    param($Config)
    $cfg = Get-Config
    foreach ($p in $Config.PSObject.Properties) {
        if ($cfg.PSObject.Properties[$p.Name]) { $cfg.($p.Name) = $p.Value }
    }
    Write-JsonFile $script:ConfigFile ([ordered]@{
            warningDays   = [int]$cfg.warningDays
            deletionDays  = [int]$cfg.deletionDays
            useRecycleBin = [bool]$cfg.useRecycleBin
            showOnStartup = [bool]$cfg.showOnStartup
            setupDone     = [bool]$cfg.setupDone
            lastModified  = (Get-Date -Format 'yyyy-MM-ddTHH:mm:sszzz')
        })
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

# Uygulamanın kendi dosyası mı? (bu dosyalar listelenmez, silinmez, korunamaz)
function Test-SystemPath {
    param([string]$RelativePath)
    $rel = $RelativePath.TrimStart('\')
    $first = ($rel -split '\\')[0]
    if ($script:AppDirs -contains $first) { return $true }
    if ($rel -notmatch '\\' -and $script:AppFiles -contains $rel) { return $true }
    return $false
}

function Read-ProtectedRaw {
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

function Get-ProtectedEntries {
    return @(Read-ProtectedRaw | Where-Object { -not (Test-SystemPath ([string]$_.path)) })
}

function Save-ProtectedEntries {
    param([object[]]$Entries)
    Write-JsonFile $script:ProtectedFile @{ files = @($Entries) }
}

function Add-Protection {
    param([string[]]$FullPaths)
    $entries = New-Object System.Collections.ArrayList
    foreach ($e in Get-ProtectedEntries) { [void]$entries.Add($e) }
    $added = 0
    foreach ($path in $FullPaths) {
        $rel = Get-RelativePath $path
        if (-not (Test-InBaseFolder $path) -or (Test-SystemPath $rel)) { continue }
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
    $targets = @($RelativePaths | Where-Object { -not (Test-SystemPath $_) })
    $remaining = @(Get-ProtectedEntries | Where-Object { $targets -notcontains $_.path })
    Save-ProtectedEntries $remaining
    foreach ($rel in $targets) { Write-Log "Koruma kaldirildi: $rel" }
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
    if (Test-SystemPath (Get-RelativePath $FullPath)) { throw 'Uygulama dosyalari silinemez' }
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

# -OnProgress: her dosyadan sonra { param($Path, $Ok, $Error) } ile çağrılır (silme animasyonu için).
function Remove-Files {
    param([string[]]$Paths, [bool]$Recycle, [string]$Label = 'Silindi', [scriptblock]$OnProgress)
    $deleted = 0
    $freed = [long]0
    $failed = New-Object System.Collections.Generic.List[string]
    foreach ($path in $Paths) {
        $rel = Get-RelativePath $path
        $size = [long]0
        try { $size = (Get-Item -LiteralPath $path -Force -ErrorAction Stop).Length } catch { }
        $err = $null
        try {
            if (Remove-ManagedFile -FullPath $path -Recycle $Recycle) {
                $deleted++
                $freed += $size
                Write-Log "${Label}: $rel"
            }
            else { $err = 'dosya hala mevcut' }
        }
        catch { $err = $_.Exception.Message }
        if ($err) {
            $failed.Add("$rel ($err)")
            Write-Log "Silme hatasi: $rel - $err"
        }
        if ($OnProgress) { & $OnProgress $path (-not $err) $err }
    }
    if ($Paths.Count -gt 0) {
        Write-Log "Silme islemi tamamlandi. Silinen: $deleted, Hata: $($failed.Count)"
        [void](Remove-EmptyFolders)
    }
    [pscustomobject]@{ Deleted = $deleted; Freed = $freed; Failed = $failed.ToArray() }
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

#region Uygulama dosyası (exe), kısayollar, klasör simgesi
# .system\App.cs'den "Dosya Temizleyici.exe"yi derler (exe depoda hazır gelir; yalnızca eksikse gerekir).
function Build-AppExe {
    try {
        $csc = Join-Path ([System.Runtime.InteropServices.RuntimeEnvironment]::GetRuntimeDirectory()) 'csc.exe'
        $sma = [PSObject].Assembly.Location
        $src = Join-Path $script:SystemFolder 'App.cs'
        $out = & $csc /nologo /optimize+ /target:winexe /codepage:65001 "/win32icon:$script:AppIcon" "/out:$script:AppExe" `
            /reference:System.Windows.Forms.dll "/reference:$sma" $src 2>&1
        if ($LASTEXITCODE -ne 0) { throw ($out -join ' ') }
        return $true
    }
    catch {
        Write-Log "Uygulama derlenemedi: $($_.Exception.Message)"
        return $false
    }
}

function New-Shortcut {
    param([string]$Path, [string]$Arguments = '')
    try {
        $shell = New-Object -ComObject WScript.Shell
        $lnk = $shell.CreateShortcut($Path)
        $lnk.TargetPath = $script:AppExe
        $lnk.Arguments = $Arguments
        $lnk.WorkingDirectory = $script:BaseFolder
        $lnk.IconLocation = "$script:AppIcon,0"
        $lnk.Description = $script:AppTitle
        $lnk.Save()
        return $true
    }
    catch {
        Write-Log "Kisayol olusturulamadi: $Path - $($_.Exception.Message)"
        return $false
    }
}

function Install-Shortcuts {
    param([switch]$Desktop, [switch]$StartMenu)
    if ($StartMenu) { [void](New-Shortcut $script:StartMenuLink) }
    if ($Desktop) {
        if (New-Shortcut $script:DesktopLink) { Write-Log 'Masaustu kisayolu olusturuldu' }
    }
}

function Invoke-ShellRefresh {
    param([string]$Path)
    try {
        if (-not ('StfcShell.Notify' -as [type])) {
            Add-Type -Namespace StfcShell -Name Notify -MemberDefinition @'
[DllImport("shell32.dll", CharSet = CharSet.Unicode)]
public static extern void SHChangeNotify(int eventId, uint flags, string item1, IntPtr item2);
'@
        }
        if ($Path) { [StfcShell.Notify]::SHChangeNotify(0x00002000, 0x0005, $Path, [IntPtr]::Zero) }
        [StfcShell.Notify]::SHChangeNotify(0x08000000, 0x0000, $null, [IntPtr]::Zero)
    }
    catch { }
}

# Klasöre özel simge verir (desktop.ini). Klasör masaüstünde klasik sarı klasörden kolayca ayırt edilir.
function Set-FolderIcon {
    $ini = Join-Path $script:BaseFolder 'desktop.ini'
    try {
        if (Test-Path -LiteralPath $ini) { (Get-Item -LiteralPath $ini -Force).Attributes = 'Normal' }
        $content = "[.ShellClassInfo]`r`nIconResource=$script:FolderIcon,0`r`nInfoTip=Kısa süreli dosyalarınız - süresi dolanlar otomatik temizlenir`r`n"
        [System.IO.File]::WriteAllText($ini, $content, [System.Text.Encoding]::Unicode)
        (Get-Item -LiteralPath $ini -Force).Attributes = 'Hidden, System'
        $dir = Get-Item -LiteralPath $script:BaseFolder -Force
        $dir.Attributes = $dir.Attributes -bor [System.IO.FileAttributes]::ReadOnly
        Invoke-ShellRefresh $script:BaseFolder
        Write-Log 'Klasor simgesi uygulandi'
        return $true
    }
    catch {
        Write-Log "Klasor simgesi uygulanamadi: $($_.Exception.Message)"
        return $false
    }
}

function Remove-FolderIcon {
    $ini = Join-Path $script:BaseFolder 'desktop.ini'
    if (Test-Path -LiteralPath $ini) {
        (Get-Item -LiteralPath $ini -Force).Attributes = 'Normal'
        Remove-Item -LiteralPath $ini -Force -ErrorAction SilentlyContinue
        $dir = Get-Item -LiteralPath $script:BaseFolder -Force
        $dir.Attributes = $dir.Attributes -band (-bnot [System.IO.FileAttributes]::ReadOnly)
        Invoke-ShellRefresh $script:BaseFolder
    }
}

# Sistem klasörlerini gizler: kullanıcı klasörde yalnızca kendi dosyalarını ve uygulamayı görür.
function Set-AppAttributes {
    foreach ($name in @('.system', '.github', '.gitignore')) {
        $path = Join-Path $script:BaseFolder $name
        if (Test-Path -LiteralPath $path) {
            $item = Get-Item -LiteralPath $path -Force
            if (-not ($item.Attributes -band [System.IO.FileAttributes]::Hidden)) {
                $item.Attributes = $item.Attributes -bor [System.IO.FileAttributes]::Hidden
            }
        }
    }
}

# Eski sürümlerden kalanları düzenler (her açılışta çalışır, idempotent).
function Invoke-Migration {
    # v1'in kökte bıraktığı log
    $oldLog = Join-Path $script:BaseFolder 'cleanup.log'
    if (Test-Path -LiteralPath $oldLog) {
        try { Move-Item -LiteralPath $oldLog -Destination (Join-Path $script:SystemFolder 'cleanup-v1.log') -Force -ErrorAction Stop } catch { }
    }
    # Koruma listesinden uygulama dosyalarını çıkar
    $raw = @(Read-ProtectedRaw)
    $clean = @($raw | Where-Object {
            $p = [string]$_.path
            -not (Test-SystemPath $p) -and -not ($p -notmatch '\\' -and $script:LegacyRootFiles -contains $p)
        })
    if ($clean.Count -ne $raw.Count) {
        Save-ProtectedEntries $clean
        Write-Log "Koruma listesinden $($raw.Count - $clean.Count) uygulama dosyasi cikarildi"
    }
    # v3.0 sessiz başlatıcısı artık kullanılmıyor
    $oldLauncher = Join-Path $script:SystemFolder 'Launcher.exe'
    if (Test-Path -LiteralPath $oldLauncher) { Remove-Item -LiteralPath $oldLauncher -Force -ErrorAction SilentlyContinue }
    Set-AppAttributes
}

function Get-DesktopTarget {
    return (Join-Path ([Environment]::GetFolderPath('Desktop')) 'short-term-files')
}

function Test-AtDesktopTarget {
    return ($script:BaseFolder.TrimEnd('\') -ieq (Get-DesktopTarget))
}

# Uygulamayı Masaüstü\short-term-files klasörüne kopyalar (ZIP başka bir yere açıldıysa).
# Hedefte zaten bulunan ayar/koruma/log dosyalarının üzerine yazılmaz.
function Copy-AppToDesktop {
    $target = Get-DesktopTarget
    $targetSystem = Join-Path $target '.system'
    New-Item -ItemType Directory -Path $targetSystem -Force | Out-Null
    Copy-Item -LiteralPath $script:AppExe -Destination $target -Force
    foreach ($item in Get-ChildItem -LiteralPath $script:SystemFolder -Force) {
        if ($script:DataFiles -contains $item.Name -and (Test-Path -LiteralPath (Join-Path $targetSystem $item.Name))) { continue }
        Copy-Item -LiteralPath $item.FullName -Destination $targetSystem -Recurse -Force
    }
    Get-ChildItem -LiteralPath $target -Recurse -Force -File -ErrorAction SilentlyContinue |
        Where-Object { $_.FullName -like "$targetSystem*" -or $_.Name -eq $script:AppExeName } |
        Unblock-File -ErrorAction SilentlyContinue
    Write-Log "Uygulama masaustune kopyalandi: $target"
    return $target
}
#endregion

#region Otomatik başlatma (Görev Zamanlayıcı)
function Get-TaskInfo {
    $task = Get-ScheduledTask -TaskName $script:TaskName -ErrorAction SilentlyContinue
    if (-not $task) { return $null }
    $info = $task | Get-ScheduledTaskInfo -ErrorAction SilentlyContinue
    $exe = [string]$task.Actions[0].Execute
    $cmd = "$exe $([string]$task.Actions[0].Arguments)"
    [pscustomobject]@{
        State       = [string]$task.State
        LastRun     = $(if ($info -and $info.LastRunTime -and $info.LastRunTime.Year -gt 2000) { $info.LastRunTime } else { $null })
        IsCurrent   = ($exe.Trim('"') -ieq $script:AppExe)
        # Görev bu kurulum klasöründeki (eski) bir dosyayı mı çalıştırıyor?
        BelongsHere = ($cmd.IndexOf($script:BaseFolder.TrimEnd('\') + '\', [StringComparison]::OrdinalIgnoreCase) -ge 0)
    }
}

# Oturum açılışı görevini oluşturur/günceller: "Dosya Temizleyici.exe /startup".
# -AllowElevation: eski görev yönetici olarak oluşturulmuşsa UAC onayı istenmesine izin verir.
function Install-CleanupTask {
    param([switch]$AllowElevation)
    if (-not (Test-Path -LiteralPath $script:ConfigFile)) { Save-Config ([pscustomobject]@{}) }
    if (-not (Test-Path -LiteralPath $script:ProtectedFile)) { Save-ProtectedEntries @() }
    if (-not (Test-Path -LiteralPath $script:AppExe) -and -not (Build-AppExe)) { throw "$script:AppExeName bulunamadi ve derlenemedi" }

    $action = New-ScheduledTaskAction -Execute $script:AppExe -Argument '/startup' -WorkingDirectory $script:BaseFolder
    $trigger = New-ScheduledTaskTrigger -AtLogOn -User $env:USERNAME
    $trigger.Delay = 'PT20S'
    $settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -StartWhenAvailable `
        -ExecutionTimeLimit ([TimeSpan]::Zero) -MultipleInstances IgnoreNew
    $register = {
        Register-ScheduledTask -TaskName $script:TaskName -Description 'Kisa Sureli Dosya Temizleyici - oturum acilisinda baslatir' `
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

    Install-Shortcuts -StartMenu
    Write-Log 'Otomatik baslatma kuruldu'
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
    $ps = Join-Path $env:SystemRoot 'System32\WindowsPowerShell\v1.0\powershell.exe'
    $cmd = "Unregister-ScheduledTask -TaskName '$script:TaskName' -Confirm:`$false"
    $proc = Start-Process -FilePath $ps -Verb RunAs -WindowStyle Hidden -Wait -PassThru `
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
        Write-Log 'Otomatik baslatma kaldirildi'
        $removed = $true
    }
    return $removed
}

# Kurulum sihirbazındaki seçimleri uygular. $Options: 'autostart','desktop','foldericon' içeren dizi.
function Invoke-Setup {
    param([string[]]$Options, [switch]$AllowElevation)
    $errors = New-Object System.Collections.Generic.List[string]
    if ($Options -contains 'autostart') {
        try { Install-CleanupTask -AllowElevation:$AllowElevation } catch { $errors.Add("Otomatik başlatma: $($_.Exception.Message)") }
    }
    Install-Shortcuts -StartMenu -Desktop:($Options -contains 'desktop')
    if ($Options -contains 'foldericon') { [void](Set-FolderIcon) }
    Set-AppAttributes
    Save-Config ([pscustomobject]@{ setupDone = $true })
    Write-Log "Kurulum tamamlandi: $($Options -join ', ')"
    return $errors.ToArray()
}
#endregion
