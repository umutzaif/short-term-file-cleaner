# Kısa Süreli Dosya Temizleyici v3.1
# Ana uygulama: Genel Bakış, İnceleme (Sil / Koru / Atla), Korunanlar, Ayarlar, Geçmiş, Hakkında
# GitHub: https://github.com/umutzaif/short-term-file-cleaner
#
# Normalde kök klasördeki "Dosya Temizleyici.exe" ile açılır (PowerShell penceresi olmadan).
#   MainApp.ps1                 -> Genel Bakış (ilk açılışta kurulum sihirbazı)
#   MainApp.ps1 -Startup        -> Oturum açılışı: süresi dolanları siler, uygulamayı açar
#                                  (incelenecek dosya varsa İnceleme sayfasıyla)
#   MainApp.ps1 -Setup a,b,c    -> Kurulum seçimlerini uygular (autostart, desktop, foldericon)

param([switch]$Startup, [string]$Setup)

. (Join-Path $PSScriptRoot 'Core.ps1')

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

# UI kitini derler; sonuç %LOCALAPPDATA% altında önbelleklenir, sonraki açılışlar anında olur.
function Import-UiKit {
    $source = Get-Content -LiteralPath (Join-Path $script:SystemFolder 'UiKit.cs') -Raw -Encoding UTF8
    $sha = [System.Security.Cryptography.SHA1]::Create()
    $hash = -join ($sha.ComputeHash([System.Text.Encoding]::UTF8.GetBytes($source))[0..5] | ForEach-Object { $_.ToString('x2') })
    $cacheDir = Join-Path $env:LOCALAPPDATA 'ShortTermFileCleaner'
    $dll = Join-Path $cacheDir "UiKit-$hash.dll"
    try {
        if (-not (Test-Path -LiteralPath $dll)) {
            New-Item -ItemType Directory -Path $cacheDir -Force | Out-Null
            Get-ChildItem -LiteralPath $cacheDir -Filter 'UiKit-*.dll' -ErrorAction SilentlyContinue | Remove-Item -Force -ErrorAction SilentlyContinue
            Add-Type -TypeDefinition $source -ReferencedAssemblies System.Windows.Forms, System.Drawing -OutputAssembly $dll -OutputType Library -ErrorAction Stop
        }
        Add-Type -Path $dll -ErrorAction Stop
    }
    catch {
        if (-not ('StfcUi.Theme' -as [type])) {
            Add-Type -TypeDefinition $source -ReferencedAssemblies System.Windows.Forms, System.Drawing
        }
    }
}

Import-UiKit
[StfcUi.Native]::HideOwnConsole()
[StfcUi.Native]::EnableDpiAwareness()
[System.Windows.Forms.Application]::EnableVisualStyles()

#region Tek örnek
$createdNew = $false
$script:InstanceMutex = New-Object System.Threading.Mutex($true, 'Local\ShortTermFileCleaner.UI', [ref]$createdNew)
if (-not $createdNew) {
    [void][StfcUi.Native]::ActivateWindow($script:AppTitle)
    exit
}
#endregion

Invoke-Migration
if ($Setup) { $script:SetupErrors = Invoke-Setup -Options ($Setup -split ',') -AllowElevation }

#region Oturum açılışı taraması
$script:AutoDeleted = 0
$script:StartupPending = 0
if ($Startup) {
    Invoke-LogRotation
    $cfg = Get-Config
    Write-Log "Baslangic taramasi: Uyari=$($cfg.warningDays) gun, Silme=$($cfg.deletionDays) gun"
    $script:AutoDeleted = Invoke-AutoCleanup -Config $cfg
    $script:StartupPending = @(Get-ManagedFiles -Config $cfg | Where-Object { $_.Stage -eq 'warning' }).Count
    if ($script:StartupPending -gt 0) { Write-Log "Uyari: $($script:StartupPending) dosya incelemeyi bekliyor" }
    elseif (-not $cfg.showOnStartup) {
        Write-Log 'Islem gerektiren dosya bulunamadi'
        exit
    }
}
#endregion

#region Tema ve yardımcılar
$screenDpi = [System.Drawing.Graphics]::FromHwnd([IntPtr]::Zero).DpiX
[StfcUi.Theme]::Scale = $screenDpi / 96
$installedFonts = (New-Object System.Drawing.Text.InstalledFontCollection).Families | ForEach-Object { $_.Name }
if ($installedFonts -contains 'Segoe Fluent Icons') { [StfcUi.Theme]::IconFamily = 'Segoe Fluent Icons' }

$C = @{
    Bg = [StfcUi.Theme]::Bg; Side = [StfcUi.Theme]::Side; Card = [StfcUi.Theme]::Card; CardHi = [StfcUi.Theme]::CardHi
    Border = [StfcUi.Theme]::Border; Text = [StfcUi.Theme]::Text; Muted = [StfcUi.Theme]::Muted
    Accent = [StfcUi.Theme]::Accent; Accent2 = [StfcUi.Theme]::Accent2
    Success = [StfcUi.Theme]::Success; Warning = [StfcUi.Theme]::Warning; Danger = [StfcUi.Theme]::Danger
}

$G = @{}
@{
    Home = 0xE80F; Review = 0xE7BA; Shield = 0xEA18; Settings = 0xE713; History = 0xE81C; Info = 0xE946
    Delete = 0xE74D; Folder = 0xE838; Refresh = 0xE72C; Skip = 0xE893; Add = 0xE710; Check = 0xE73E
    Clock = 0xE823; Files = 0xE8B7; Broom = 0xE75C; Power = 0xE7E8; Link = 0xE71B; Open = 0xE8E5
    Warn = 0xE7BA; Fire = 0xE945; Recycle = 0xE74D; Calendar = 0xE787; Bug = 0xEBE8; Clear = 0xE894
}.GetEnumerator() | ForEach-Object { $G[$_.Key] = [string][char]$_.Value }

function New-UiFont {
    param([float]$Size, [string]$Family = 'Segoe UI', [string]$Style = 'Regular')
    New-Object System.Drawing.Font($Family, $Size, [System.Drawing.FontStyle]$Style)
}

function Add-Dock {
    param($Parent, $Control, [string]$Dock = 'Top')
    $Control.Dock = $Dock
    $Parent.Controls.Add($Control)
    $Control.BringToFront()
}

function Add-Spacer {
    param($Parent, [int]$Height = 16, [string]$Dock = 'Top')
    $p = New-Object System.Windows.Forms.Panel
    $p.Height = $Height
    $p.Width = $Height
    Add-Dock $Parent $p $Dock
}

function New-Label {
    param([string]$Text, $Font, $Color = $C.Text, [string]$Align = 'MiddleLeft')
    $l = New-Object System.Windows.Forms.Label
    $l.Text = $Text
    $l.Font = $Font
    $l.ForeColor = $Color
    $l.BackColor = [System.Drawing.Color]::Transparent
    $l.TextAlign = $Align
    $l.AutoEllipsis = $true
    $l
}

function New-Button {
    param([string]$Text, [string]$Glyph = '', [string]$Kind = 'Solid', $Accent = $C.Accent, [int]$Width = 150, [int]$Height = 40, [scriptblock]$OnClick)
    $b = New-Object StfcUi.ModernButton
    $b.Text = $Text
    $b.Glyph = $Glyph
    $b.Kind = $Kind
    $b.Accent = $Accent
    $b.Size = New-Object System.Drawing.Size($Width, $Height)
    $b.Margin = New-Object System.Windows.Forms.Padding(10, 0, 0, 0)
    if ($OnClick) { $b.Add_Click($OnClick) }
    $b
}

function New-Card {
    param([int]$Height = 100, [int]$Pad = 20)
    $card = New-Object StfcUi.Card
    $card.Height = $Height
    $card.Padding = New-Object System.Windows.Forms.Padding($Pad)
    $card
}

function New-Grid {
    $grid = New-Object StfcUi.DarkGrid
    $grid.ScrollBars = 'Vertical'
    $grid
}

function Format-Size {
    param([double]$Bytes)
    if ($Bytes -ge 1GB) { return '{0:N1} GB' -f ($Bytes / 1GB) }
    if ($Bytes -ge 1MB) { return '{0:N1} MB' -f ($Bytes / 1MB) }
    if ($Bytes -ge 1KB) { return '{0:N0} KB' -f ($Bytes / 1KB) }
    return "$([int]$Bytes) B"
}

function Format-Age {
    param([double]$Days)
    if ($Days -lt 1) { return 'Bugün' }
    return '{0:N0} gün' -f [math]::Floor($Days)
}

function Get-LeftInfo {
    param($File)
    switch ($File.Stage) {
        'protected' { return @('Korunuyor', $C.Success) }
        'expired' { return @('Süresi doldu', $C.Danger) }
    }
    $d = [math]::Max(0, $File.DaysLeft)
    $text = if ($d -le 0) { 'Bugün' } elseif ($d -eq 1) { 'Yarın' } else { "$d gün" }
    $color = if ($File.Stage -eq 'fresh') { $C.Muted } elseif ($d -le 2) { $C.Danger } else { $C.Warning }
    return @($text, $color)
}

function Open-InExplorer {
    param([string]$Path)
    if (Test-Path -LiteralPath $Path) { Start-Process explorer.exe -ArgumentList "/select,`"$Path`"" }
}
#endregion

#region Ana pencere
$form = New-Object System.Windows.Forms.Form
$form.Text = $script:AppTitle
$form.AutoScaleMode = 'None'
$form.ClientSize = New-Object System.Drawing.Size(1180, 740)
$form.StartPosition = 'CenterScreen'
$form.BackColor = $C.Bg
$form.ForeColor = $C.Text
$form.Font = New-UiFont 9.5
$form.Icon = if (Test-Path -LiteralPath $script:AppIcon) { New-Object System.Drawing.Icon($script:AppIcon) } else { [StfcUi.Gfx]::GlyphIcon($G.Clock, $C.Accent, $C.Accent2) }
$form.Add_HandleCreated({ [StfcUi.Native]::StyleWindow($form.Handle, $C.Side) })

# Kenar çubuğu
$side = New-Object System.Windows.Forms.Panel
$side.Width = 240
$side.BackColor = $C.Side
$side.Padding = New-Object System.Windows.Forms.Padding(14, 20, 14, 18)
Add-Dock $form $side 'Left'

$divider = New-Object System.Windows.Forms.Panel
$divider.Width = 1
$divider.BackColor = $C.Border
Add-Dock $form $divider 'Left'

$content = New-Object System.Windows.Forms.Panel
$content.BackColor = $C.Bg
$content.Padding = New-Object System.Windows.Forms.Padding(36, 28, 36, 26)
Add-Dock $form $content 'Fill'

# Marka alanı
$brand = New-Object System.Windows.Forms.Panel
$brand.Height = 64
Add-Dock $side $brand 'Top'

function Get-AppImage {
    if (-not (Test-Path -LiteralPath $script:AppPng)) { return $null }
    $ms = New-Object System.IO.MemoryStream(, [System.IO.File]::ReadAllBytes($script:AppPng))
    [System.Drawing.Image]::FromStream($ms)
}
$logo = New-Object System.Windows.Forms.PictureBox
$logo.SetBounds(2, 4, 50, 50)
$logo.SizeMode = 'Zoom'
$logo.BackColor = [System.Drawing.Color]::Transparent
$logo.Image = Get-AppImage
$brand.Controls.Add($logo)

$brandTitle = New-Label 'Kısa Süreli' (New-UiFont 11.5 'Segoe UI Semibold')
$brandTitle.SetBounds(60, 6, 160, 24)
$brand.Controls.Add($brandTitle)
$brandSub = New-Label 'Dosya Temizleyici' (New-UiFont 9) $C.Muted
$brandSub.SetBounds(60, 29, 160, 20)
$brand.Controls.Add($brandSub)

Add-Spacer $side 18
$navCaption = New-Label 'MENÜ' (New-UiFont 8 'Segoe UI Semibold') $C.Muted
$navCaption.Height = 26
$navCaption.Padding = New-Object System.Windows.Forms.Padding(10, 0, 0, 0)
Add-Dock $side $navCaption 'Top'

$script:Pages = [ordered]@{}
$script:NavItems = @{}
$navDefs = @(
    @('dash', 'Genel Bakış', $G.Home),
    @('review', 'İnceleme', $G.Review),
    @('protected', 'Korunanlar', $G.Shield),
    @('settings', 'Ayarlar', $G.Settings),
    @('log', 'Geçmiş', $G.History),
    @('about', 'Hakkında', $G.Info)
)
foreach ($def in $navDefs) {
    $nav = New-Object StfcUi.NavItem
    $nav.Tag = $def[0]
    $nav.Text = $def[1]
    $nav.Glyph = $def[2]
    $nav.Height = 44
    $nav.Add_Click({ Show-Page $this.Tag })
    Add-Dock $side $nav 'Top'
    Add-Spacer $side 4
    $script:NavItems[$def[0]] = $nav
}

# Kenar çubuğu alt kısmı: otomatik başlatma durumu
$sideStatus = New-Card 74 14
$sideStatus.Fill = [StfcUi.Gfx]::Mix($C.Side, [System.Drawing.Color]::White, 0.03)
$sideStatus.Radius = 12
Add-Dock $side $sideStatus 'Bottom'
$sideVersion = New-Label "v$script:AppVersion" (New-UiFont 8.5) $C.Muted 'MiddleCenter'
$sideVersion.Height = 30
Add-Dock $side $sideVersion 'Bottom'
$sideVersion.SendToBack()

$sideDot = New-Label '●' (New-UiFont 10) $C.Muted 'MiddleCenter'
$sideDot.SetBounds(10, 12, 20, 22)
$sideStatus.Controls.Add($sideDot)
$sideStatusTitle = New-Label 'Otomatik başlatma' (New-UiFont 9 'Segoe UI Semibold')
$sideStatusTitle.SetBounds(32, 10, 160, 22)
$sideStatus.Controls.Add($sideStatusTitle)
$sideStatusText = New-Label 'Kontrol ediliyor…' (New-UiFont 8.5) $C.Muted
$sideStatusText.SetBounds(32, 32, 170, 20)
$sideStatus.Controls.Add($sideStatusText)

# Bildirim (toast)
$toast = New-Card 46 0
$toast.Fill = $C.CardHi
$toast.Radius = 12
$toast.Visible = $false
$toastGlyph = New-Label '' (New-UiFont 11 ([StfcUi.Theme]::IconFamily)) $C.Success 'MiddleCenter'
$toastGlyph.SetBounds(10, 0, 30, 46)
$toast.Controls.Add($toastGlyph)
$toastText = New-Label '' (New-UiFont 9.75 'Segoe UI Semibold') $C.Text
$toastText.SetBounds(42, 0, 400, 46)
$toast.Controls.Add($toastText)
$content.Controls.Add($toast)
$toastTimer = New-Object System.Windows.Forms.Timer
$toastTimer.Interval = 3200
$toastTimer.Add_Tick({ $toastTimer.Stop(); $toast.Visible = $false })

function Show-Toast {
    param([string]$Message, $Color = $C.Success, [string]$Glyph = $G.Check)
    $toastText.Text = $Message
    $toastGlyph.Text = $Glyph
    $toastGlyph.ForeColor = $Color
    $toast.BorderColor = [StfcUi.Gfx]::Mix($C.CardHi, $Color, 0.5)
    $w = [System.Windows.Forms.TextRenderer]::MeasureText($Message, $toastText.Font).Width
    $toastText.Width = $w + 10
    $toast.Width = $w + 70
    $toast.Height = $toastText.Height
    $toast.Left = [int](($content.ClientSize.Width - $toast.Width) / 2)
    $toast.Top = $content.ClientSize.Height - $toast.Height - [StfcUi.Theme]::S(104)
    $toast.Visible = $true
    $toast.BringToFront()
    $toastTimer.Stop()
    $toastTimer.Start()
}

function New-Page {
    param([string]$Name, [string]$Title, [string]$Subtitle)
    $page = New-Object System.Windows.Forms.Panel
    $page.Visible = $false
    Add-Dock $content $page 'Fill'

    $header = New-Object System.Windows.Forms.Panel
    $header.Height = 66
    Add-Dock $page $header 'Top'

    $actions = New-Object System.Windows.Forms.FlowLayoutPanel
    $actions.FlowDirection = 'RightToLeft'
    $actions.WrapContents = $false
    $actions.AutoSize = $true
    $actions.AutoSizeMode = 'GrowAndShrink'
    $actions.Padding = New-Object System.Windows.Forms.Padding(0, 10, 0, 0)
    Add-Dock $header $actions 'Right'

    $titles = New-Object System.Windows.Forms.Panel
    Add-Dock $header $titles 'Fill'
    $lblTitle = New-Label $Title (New-UiFont 20 'Segoe UI Semibold')
    $lblTitle.Height = 38
    $lblTitle.TextAlign = 'BottomLeft'
    Add-Dock $titles $lblTitle 'Top'
    $lblSub = New-Label $Subtitle (New-UiFont 10) $C.Muted 'TopLeft'
    $lblSub.Height = 26
    Add-Dock $titles $lblSub 'Top'

    Add-Spacer $page 20
    $script:Pages[$Name] = $page
    @{ Page = $page; Actions = $actions; Subtitle = $lblSub; Title = $lblTitle }
}

function Show-Page {
    param([string]$Name)
    foreach ($key in @($script:Pages.Keys)) {
        $script:Pages[$key].Visible = ($key -eq $Name)
        $script:NavItems[$key].Active = ($key -eq $Name)
    }
    $script:CurrentPage = $Name
    if ($Name -eq 'log') { Update-LogView }
}
#endregion

#region Sayfa: Genel Bakış
$dash = New-Page 'dash' 'Genel Bakış' 'short-term-files klasörünün anlık durumu'
$dash.Actions.Controls.Add((New-Button 'Şimdi Temizle' $G.Broom 'Solid' $C.Accent 160 40 {
            $cfg = Get-Config
            Write-Log 'Manuel temizlik baslatildi'
            $n = Invoke-AutoCleanup -Config $cfg
            Update-All
            $warn = @($script:Files | Where-Object { $_.Stage -eq 'warning' }).Count
            if ($warn -gt 0) {
                Show-Page 'review'
                Show-Toast "$n dosyanın süresi dolmuştu ve silindi · $warn dosya incelemenizi bekliyor" $C.Warning $G.Review
            }
            else { Show-Toast "Temizlik tamamlandı · $n dosya silindi" }
        }))
$dash.Actions.Controls.Add((New-Button 'Klasörü Aç' $G.Folder 'Ghost' $C.Accent 140 40 {
            Start-Process explorer.exe -ArgumentList "`"$script:BaseFolder`""
        }))

$tiles = New-Object System.Windows.Forms.TableLayoutPanel
$tiles.Height = 134
$tiles.ColumnCount = 4
$tiles.RowCount = 1
for ($i = 0; $i -lt 4; $i++) { [void]$tiles.ColumnStyles.Add((New-Object System.Windows.Forms.ColumnStyle('Percent', 25))) }
[void]$tiles.RowStyles.Add((New-Object System.Windows.Forms.RowStyle('Percent', 100)))
Add-Dock $dash.Page $tiles 'Top'

function New-Tile {
    param([string]$Title, [string]$Glyph, $Accent, [int]$Col)
    $t = New-Object StfcUi.StatTile
    $t.Title = $Title
    $t.Glyph = $Glyph
    $t.Accent = $Accent
    $t.Dock = 'Fill'
    $right = if ($Col -lt 3) { 16 } else { 0 }
    $t.Margin = New-Object System.Windows.Forms.Padding(0, 0, $right, 0)
    $tiles.Controls.Add($t, $Col, 0)
    $t
}
$tileTotal = New-Tile 'Toplam dosya' $G.Files $C.Accent 0
$tileWarn = New-Tile 'İnceleme bekliyor' $G.Review $C.Warning 1
$tileSoon = New-Tile 'Yakında silinecek' $G.Clock $C.Danger 2
$tileProt = New-Tile 'Korunan' $G.Shield $C.Success 3

Add-Spacer $dash.Page 18
$lifeCard = New-Card 140 22
Add-Dock $dash.Page $lifeCard 'Top'
$lifeTitle = New-Label 'Dosya yaşam döngüsü' (New-UiFont 11 'Segoe UI Semibold')
$lifeTitle.Height = 28
Add-Dock $lifeCard $lifeTitle 'Top'
Add-Spacer $lifeCard 12
$lifeBar = New-Object StfcUi.LifecycleBar
Add-Dock $lifeCard $lifeBar 'Fill'

Add-Spacer $dash.Page 18
$dashBottom = New-Object System.Windows.Forms.TableLayoutPanel
$dashBottom.ColumnCount = 2
$dashBottom.RowCount = 1
[void]$dashBottom.ColumnStyles.Add((New-Object System.Windows.Forms.ColumnStyle('Percent', 62)))
[void]$dashBottom.ColumnStyles.Add((New-Object System.Windows.Forms.ColumnStyle('Percent', 38)))
[void]$dashBottom.RowStyles.Add((New-Object System.Windows.Forms.RowStyle('Percent', 100)))
Add-Dock $dash.Page $dashBottom 'Fill'

# Yaklaşan silmeler
$upCard = New-Card 100 18
$upCard.Dock = 'Fill'
$upCard.Margin = New-Object System.Windows.Forms.Padding(0, 0, 16, 0)
$dashBottom.Controls.Add($upCard, 0, 0)
$upHeader = New-Object System.Windows.Forms.Panel
$upHeader.Height = 40
Add-Dock $upCard $upHeader 'Top'
$upAll = New-Button 'Tümünü incele' $G.Skip 'Soft' $C.Accent 150 34 { Show-Page 'review' }
Add-Dock $upHeader $upAll 'Right'
$upTitle = New-Label 'Yaklaşan otomatik silmeler' (New-UiFont 11 'Segoe UI Semibold')
Add-Dock $upHeader $upTitle 'Fill'
Add-Spacer $upCard 6
$upGrid = New-Grid
[void]$upGrid.AddText('ext', 'TÜR', 64, $false)
[void]$upGrid.AddText('name', 'DOSYA', 0, $true)
[void]$upGrid.AddText('left', 'KALAN', 96, $false)
$upGrid.Add_CellDoubleClick({ param($s, $e) if ($e.RowIndex -ge 0) { Open-InExplorer ([string]$upGrid.Rows[$e.RowIndex].Tag) } })
Add-Dock $upCard $upGrid 'Fill'
$upEmpty = New-Label 'Önümüzdeki günlerde silinecek dosya yok.' (New-UiFont 10) $C.Muted 'MiddleCenter'
$upEmpty.Visible = $false
Add-Dock $upCard $upEmpty 'Fill'

# Otomatik başlatma kartı
$autoCard = New-Card 100 22
$autoCard.Dock = 'Fill'
$autoCard.Margin = New-Object System.Windows.Forms.Padding(0)
$dashBottom.Controls.Add($autoCard, 1, 0)
$autoTitle = New-Label 'Otomatik başlatma' (New-UiFont 11 'Segoe UI Semibold')
$autoTitle.Height = 30
Add-Dock $autoCard $autoTitle 'Top'
$autoState = New-Label 'Kontrol ediliyor…' (New-UiFont 18 'Segoe UI Semibold') $C.Muted
$autoState.Height = 44
Add-Dock $autoCard $autoState 'Top'
$autoDesc = New-Label '' (New-UiFont 9.5) $C.Muted 'TopLeft'
$autoDesc.Height = 64
Add-Dock $autoCard $autoDesc 'Top'
$autoLast = New-Label '' (New-UiFont 9) $C.Muted 'TopLeft'
$autoLast.Height = 24
Add-Dock $autoCard $autoLast 'Top'
$autoBtn = New-Button 'Kur' $G.Power 'Solid' $C.Accent 200 42 {
    try {
        if ($script:TaskInfo -and $script:TaskInfo.IsCurrent) {
            $ans = [System.Windows.Forms.MessageBox]::Show('Otomatik başlatma kapatılsın mı? Oturum açılışında dosyalar artık denetlenmeyecek.', 'Onay', 'YesNo', 'Question')
            if ($ans -ne 'Yes') { return }
            [void](Uninstall-CleanupTask -AllowElevation)
            Show-Toast 'Otomatik başlatma kapatıldı' $C.Warning $G.Power
        }
        else {
            Install-CleanupTask -AllowElevation
            Show-Toast 'Otomatik başlatma etkin · oturum açılışında uygulama açılacak'
        }
    }
    catch { [System.Windows.Forms.MessageBox]::Show("İşlem başarısız: $($_.Exception.Message)", 'Hata', 'OK', 'Error') | Out-Null }
    Update-TaskStatus
}
Add-Dock $autoCard $autoBtn 'Bottom'
#endregion

#region Sayfa: İnceleme
$rev = New-Page 'review' 'İnceleme' ''
$script:ReviewMode = 'warning'

$revToolbar = New-Object System.Windows.Forms.FlowLayoutPanel
$revToolbar.Height = 38
$revToolbar.WrapContents = $false
Add-Dock $rev.Page $revToolbar 'Top'
$chipWarn = New-Button 'Uyarıdakiler' $G.Review 'Ghost' $C.Accent 150 36 { $script:ReviewMode = 'warning'; Update-ReviewGrid }
$chipAll = New-Button 'Tüm dosyalar' $G.Files 'Ghost' $C.Accent 150 36 { $script:ReviewMode = 'all'; Update-ReviewGrid }
foreach ($chip in @($chipWarn, $chipAll)) {
    $chip.Margin = New-Object System.Windows.Forms.Padding(0, 0, 10, 0)
    $revToolbar.Controls.Add($chip)
}
$revHint = New-Label 'Satıra tıklayarak seçin · çift tıklayarak klasörde gösterin' (New-UiFont 9) $C.Muted
$revHint.AutoSize = $false
$revHint.Size = New-Object System.Drawing.Size(420, 36)
$revHint.Margin = New-Object System.Windows.Forms.Padding(8, 0, 0, 0)
$revToolbar.Controls.Add($revHint)

Add-Spacer $rev.Page 14

# Alt eylem çubuğu
$revBar = New-Card 72 14
Add-Dock $rev.Page $revBar 'Bottom'
Add-Spacer $rev.Page 14 'Bottom'
$revButtons = New-Object System.Windows.Forms.FlowLayoutPanel
$revButtons.FlowDirection = 'RightToLeft'
$revButtons.WrapContents = $false
$revButtons.Width = 600
Add-Dock $revBar $revButtons 'Right'
$revSummary = New-Label '' (New-UiFont 10 'Segoe UI Semibold')
$revSummary.Padding = New-Object System.Windows.Forms.Padding(8, 0, 0, 0)
Add-Dock $revBar $revSummary 'Fill'

function Wait-Ui {
    param([int]$Milliseconds)
    $sw = [System.Diagnostics.Stopwatch]::StartNew()
    do {
        [System.Windows.Forms.Application]::DoEvents()
        Start-Sleep -Milliseconds 8
    } while ($sw.ElapsedMilliseconds -lt $Milliseconds)
}

# Onay -> animasyonlu silme -> sonuç özeti. Her dosya gerçekten silindikçe ilerleme halkası dolar.
function Invoke-DeleteFlow {
    param([string[]]$Paths)
    $script:DelPaths = $Paths
    $script:DelConfig = Get-Config
    $script:DelResult = $null
    $size = [long]0
    foreach ($p in $Paths) { if ($script:FileIndex.ContainsKey($p)) { $size += $script:FileIndex[$p].Size } }

    $script:DelDialog = New-Object StfcUi.DeleteDialog
    $script:DelDialog.Icon = $form.Icon
    $script:DelDialog.Prepare([string[]]@($Paths | ForEach-Object { [System.IO.Path]::GetFileName($_) }), (Format-Size $size), $script:DelConfig.useRecycleBin)
    $script:DelDialog.Add_Confirmed({
            $script:DelPace = [math]::Max(25, [math]::Min(220, [int](1800 / [math]::Max(1, $script:DelPaths.Count))))
            Wait-Ui 250
            $r = Remove-Files -Paths $script:DelPaths -Recycle $script:DelConfig.useRecycleBin -OnProgress {
                param($Path, $Ok, $Err)
                $script:DelDialog.Advance([System.IO.Path]::GetFileName($Path), $Ok)
                Wait-Ui $script:DelPace
            }
            Wait-Ui 450
            $freed = Format-Size $r.Freed
            if ($r.Failed.Count -eq 0) {
                $title = 'Temizlik tamamlandı'
                $sub = "$($r.Deleted) dosya silindi · $freed yer açıldı"
            }
            else {
                $title = 'Kısmen tamamlandı'
                $sub = "$($r.Deleted) dosya silindi · $($r.Failed.Count) dosya silinemedi"
            }
            $note = if ($r.Failed.Count -gt 0) { 'Silinemeyen dosyalar başka bir programda açık olabilir. Ayrıntılar Geçmiş sayfasında.' }
            elseif ($script:DelConfig.useRecycleBin) { "Dosyalar Geri Dönüşüm Kutusu'nda; istediğiniz zaman geri alabilirsiniz." }
            else { 'Dosyalar kalıcı olarak silindi. Her işlem Geçmiş sayfasına kaydedildi.' }
            $script:DelDialog.Finish($title, $sub, $note, [string[]]$r.Failed)
            $script:DelResult = $r
        })
    [void]$script:DelDialog.ShowDialog($form)
    $script:DelDialog.Dispose()
    if ($script:DelResult) { Update-All }
}

$btnDelete = New-Button 'Sil' $G.Delete 'Solid' $C.Danger 130 42 {
    $paths = Get-CheckedPaths $revGrid
    if ($paths.Count -eq 0) { Show-Toast 'Önce en az bir dosya seçin' $C.Warning $G.Warn; return }
    Invoke-DeleteFlow $paths
}
$btnProtect = New-Button 'Koru' $G.Shield 'Solid' $C.Success 130 42 {
    $paths = Get-CheckedPaths $revGrid
    if ($paths.Count -eq 0) { Show-Toast 'Önce en az bir dosya seçin' $C.Warning $G.Warn; return }
    $n = Add-Protection $paths
    Update-All
    Show-Toast "$n dosya korumaya alındı" $C.Success $G.Shield
}
$btnSkip = New-Button 'Atla' $G.Skip 'Ghost' $C.Accent 120 42 {
    Write-Log 'Kullanici dosyalari atlamayi secti'
    if ($Startup) { $form.Close() } else { Show-Page 'dash' }
}
$btnSelectAll = New-Button 'Tümünü seç' $G.Check 'Ghost' $C.Accent 140 42 { $revGrid.SetAll(-not $revGrid.AllChecked()) }
foreach ($b in @($btnDelete, $btnProtect, $btnSkip, $btnSelectAll)) { $revButtons.Controls.Add($b) }
$revButtons.Padding = New-Object System.Windows.Forms.Padding(0, 1, 0, 0)

$revCard = New-Card 100 10
Add-Dock $rev.Page $revCard 'Fill'
$revGrid = New-Grid
[void]$revGrid.AddCheck()
[void]$revGrid.AddText('ext', 'TÜR', 64, $false)
[void]$revGrid.AddText('name', 'DOSYA', 0, $true)
[void]$revGrid.AddText('folder', 'KLASÖR', 190, $false)
[void]$revGrid.AddText('size', 'BOYUT', 96, $false)
[void]$revGrid.AddText('age', 'YAŞ', 86, $false)
[void]$revGrid.AddText('left', 'SİLİNMESİNE', 120, $false)
$revGrid.Columns['size'].DefaultCellStyle.Alignment = 'MiddleRight'
$revGrid.Columns['folder'].DefaultCellStyle.ForeColor = $C.Muted
$revGrid.Columns['age'].DefaultCellStyle.ForeColor = $C.Muted
$revGrid.Add_CellValueChanged({ Update-ReviewSummary })
$revGrid.Add_CellDoubleClick({ param($s, $e) if ($e.RowIndex -ge 0) { Open-InExplorer ([string]$revGrid.Rows[$e.RowIndex].Tag) } })
Add-Dock $revCard $revGrid 'Fill'

$revEmpty = New-Object System.Windows.Forms.Panel
$revEmpty.Visible = $false
Add-Dock $revCard $revEmpty 'Fill'
$revEmptyGlyph = New-Label $G.Check (New-UiFont 34 ([StfcUi.Theme]::IconFamily)) $C.Success 'BottomCenter'
$revEmptyGlyph.Height = 150
Add-Dock $revEmpty $revEmptyGlyph 'Top'
$revEmptyTitle = New-Label 'Her şey yolunda' (New-UiFont 15 'Segoe UI Semibold') $C.Text 'MiddleCenter'
$revEmptyTitle.Height = 44
Add-Dock $revEmpty $revEmptyTitle 'Top'
$revEmptyText = New-Label 'İncelenecek dosya kalmadı. Diğer sayfalara soldaki menüden ulaşabilirsiniz.' (New-UiFont 10) $C.Muted 'TopCenter'
$revEmptyText.Height = 30
Add-Dock $revEmpty $revEmptyText 'Top'

function Get-CheckedPaths {
    param($Grid)
    $list = New-Object System.Collections.Generic.List[string]
    for ($i = 0; $i -lt $Grid.Rows.Count; $i++) {
        if ($Grid.IsChecked($i)) { $list.Add([string]$Grid.Rows[$i].Tag) }
    }
    , $list.ToArray()
}

function Update-ReviewSummary {
    $paths = Get-CheckedPaths $revGrid
    $size = 0
    foreach ($p in $paths) { if ($script:FileIndex.ContainsKey($p)) { $size += $script:FileIndex[$p].Size } }
    if ($revGrid.Rows.Count -eq 0) { $revSummary.Text = '' }
    elseif ($paths.Count -eq 0) { $revSummary.Text = 'Seçili dosya yok'; $revSummary.ForeColor = $C.Muted }
    else { $revSummary.Text = "$($paths.Count) dosya seçili · $(Format-Size $size)"; $revSummary.ForeColor = $C.Text }
    $btnSelectAll.Text = if ($revGrid.AllChecked()) { 'Seçimi kaldır' } else { 'Tümünü seç' }
    foreach ($b in @($btnDelete, $btnProtect)) { $b.Enabled = ($paths.Count -gt 0) }
}

function Update-ReviewGrid {
    $chipWarn.Selected = ($script:ReviewMode -eq 'warning')
    $chipAll.Selected = ($script:ReviewMode -eq 'all')
    $files = if ($script:ReviewMode -eq 'all') { $script:Files } else { $script:Files | Where-Object { $_.Stage -eq 'warning' } }
    $files = @($files | Sort-Object @{ Expression = { if ($_.Stage -eq 'protected') { 1 } else { 0 } } }, DaysLeft, Name)
    $defaultCheck = ($script:ReviewMode -eq 'warning')

    $revGrid.SuspendLayout()
    $revGrid.Rows.Clear()
    foreach ($f in $files) {
        $left = Get-LeftInfo $f
        $folder = if ($f.Folder) { $f.Folder } else { '—' }
        $check = $defaultCheck -and $f.Stage -ne 'protected'
        $i = $revGrid.Rows.Add($check, $f.Extension, $f.Name, $folder, (Format-Size $f.Size), (Format-Age $f.AgeDays), $left[0])
        $row = $revGrid.Rows[$i]
        $row.Tag = $f.FullName
        $row.Cells['left'].Style.ForeColor = $left[1]
    }
    $revGrid.ResumeLayout()
    $revGrid.ClearSelection()

    $warnCount = @($script:Files | Where-Object { $_.Stage -eq 'warning' }).Count
    $chipWarn.Text = "Uyarıdakiler ($warnCount)"
    $chipAll.Text = "Tüm dosyalar ($($script:Files.Count))"
    $rev.Subtitle.Text = if ($warnCount -gt 0) {
        "$warnCount dosya $($script:Config.warningDays) günden eski. Silmek, korumak ya da atlamak için seçin."
    }
    else { 'İncelenecek dosya yok.' }

    $empty = ($files.Count -eq 0)
    $revEmpty.Visible = $empty
    $revGrid.Visible = -not $empty
    Update-ReviewSummary
}
#endregion

#region Sayfa: Korunanlar
$prot = New-Page 'protected' 'Korunan Dosyalar' 'Bu dosyalar süreleri dolsa bile otomatik silinmez.'
$prot.Actions.Controls.Add((New-Button 'Dosya Ekle' $G.Add 'Solid' $C.Accent 140 40 {
            $dlg = New-Object System.Windows.Forms.OpenFileDialog
            $dlg.InitialDirectory = $script:BaseFolder
            $dlg.Multiselect = $true
            $dlg.Title = 'Korunacak dosyaları seçin'
            if ($dlg.ShowDialog($form) -ne 'OK') { return }
            $inside = @($dlg.FileNames | Where-Object { (Test-InBaseFolder $_) -and -not (Test-SystemPath (Get-RelativePath $_)) })
            if ($inside.Count -lt $dlg.FileNames.Count) { Show-Toast 'Yalnızca short-term-files içindeki kendi dosyalarınız korunabilir' $C.Warning $G.Warn }
            if ($inside.Count -gt 0) {
                $n = Add-Protection $inside
                Update-All
                Show-Toast "$n dosya korumaya alındı" $C.Success $G.Shield
            }
        }))
$prot.Actions.Controls.Add((New-Button 'Korumayı Kaldır' $G.Clear 'Outline' $C.Danger 170 40 {
            $rels = Get-CheckedPaths $protGrid
            if ($rels.Count -eq 0) { Show-Toast 'Önce en az bir dosya seçin' $C.Warning $G.Warn; return }
            Remove-Protection $rels
            Update-All
            Show-Toast "$($rels.Count) dosyanın koruması kaldırıldı" $C.Warning $G.Shield
        }))
$prot.Actions.Controls.Add((New-Button 'Eksikleri Temizle' $G.Refresh 'Ghost' $C.Accent 170 40 {
            $missing = @(Get-ProtectedEntries | Where-Object { -not (Test-Path -LiteralPath (Join-Path $script:BaseFolder $_.path)) } | ForEach-Object { $_.path })
            if ($missing.Count -eq 0) { Show-Toast 'Listede eksik dosya yok'; return }
            Remove-Protection $missing
            Update-All
            Show-Toast "$($missing.Count) eksik kayıt listeden çıkarıldı"
        }))

$protCard = New-Card 100 10
Add-Dock $prot.Page $protCard 'Fill'
$protGrid = New-Grid
[void]$protGrid.AddCheck()
[void]$protGrid.AddText('ext', 'TÜR', 64, $false)
[void]$protGrid.AddText('path', 'DOSYA YOLU', 0, $true)
[void]$protGrid.AddText('date', 'KORUNMA TARİHİ', 170, $false)
[void]$protGrid.AddText('status', 'DURUM', 120, $false)
$protGrid.Columns['date'].DefaultCellStyle.ForeColor = $C.Muted
$protGrid.Add_CellDoubleClick({ param($s, $e) if ($e.RowIndex -ge 0) { Open-InExplorer (Join-Path $script:BaseFolder ([string]$protGrid.Rows[$e.RowIndex].Tag)) } })
Add-Dock $protCard $protGrid 'Fill'

function Update-ProtectedGrid {
    $protGrid.Rows.Clear()
    foreach ($e in Get-ProtectedEntries) {
        $exists = Test-Path -LiteralPath (Join-Path $script:BaseFolder $e.path)
        $date = [string]$e.protectedDate
        try { $date = ([datetime]$e.protectedDate).ToString('dd.MM.yyyy HH:mm') } catch { }
        $i = $protGrid.Rows.Add($false, [System.IO.Path]::GetExtension($e.path), $e.path, $date, $(if ($exists) { 'Mevcut' } else { 'Bulunamadı' }))
        $protGrid.Rows[$i].Tag = [string]$e.path
        $protGrid.Rows[$i].Cells['status'].Style.ForeColor = if ($exists) { $C.Success } else { $C.Muted }
    }
    $protGrid.ClearSelection()
}
#endregion

#region Sayfa: Ayarlar
$set = New-Page 'settings' 'Ayarlar' 'Süreleri ve silme davranışını kendinize göre ayarlayın.'

function New-SettingRow {
    param($Parent, [string]$Title, [string]$Desc, [int]$Y)
    $t = New-Label $Title (New-UiFont 11 'Segoe UI Semibold')
    $t.SetBounds(22, $Y, 520, 26)
    $Parent.Controls.Add($t)
    $d = New-Label $Desc (New-UiFont 9.5) $C.Muted 'TopLeft'
    $d.SetBounds(22, $Y + 28, 560, 22)
    $Parent.Controls.Add($d)
}

function New-DayInput {
    param($Parent, [int]$Y)
    $n = New-Object System.Windows.Forms.NumericUpDown
    $n.Minimum = 1
    $n.Maximum = 365
    $n.Font = New-UiFont 13 'Segoe UI Semibold'
    $n.BackColor = $C.CardHi
    $n.ForeColor = $C.Text
    $n.BorderStyle = 'None'
    $n.TextAlign = 'Center'
    $n.SetBounds(820, $Y + 6, 84, 30)
    $n.Anchor = 'Top,Right'
    $Parent.Controls.Add($n)
    $u = New-Label 'gün' (New-UiFont 10) $C.Muted
    $u.SetBounds(912, $Y + 6, 40, 30)
    $u.Anchor = 'Top,Right'
    $Parent.Controls.Add($u)
    $n
}

# Kartlar, sağa sabitlenen kontroller doğru konumlansın diye içerikleri eklendikten sonra yerleştirilir.
$durCard = New-Card 230 0
$durCard.Width = 980
New-SettingRow $durCard 'Uyarı süresi' 'Bu kadar gün eski dosyalar için inceleme penceresi açılır.' 22
$numWarn = New-DayInput $durCard 22
$sep = New-Object System.Windows.Forms.Panel
$sep.BackColor = $C.Border
$sep.SetBounds(22, 92, 936, 1)
$sep.Anchor = 'Top,Left,Right'
$durCard.Controls.Add($sep)
New-SettingRow $durCard 'Otomatik silme süresi' 'Bu kadar gün eski dosyalar (korunanlar hariç) oturum açılışında otomatik silinir.' 112
$numDel = New-DayInput $durCard 112
$durPreview = New-Label '' (New-UiFont 9.5 'Segoe UI Semibold') ([StfcUi.Gfx]::Mix($C.Accent, [System.Drawing.Color]::White, 0.35)) 'MiddleLeft'
$durPreview.SetBounds(22, 178, 900, 30)
$durCard.Controls.Add($durPreview)
Add-Dock $set.Page $durCard 'Top'

function Update-DurationPreview {
    $w = [int]$numWarn.Value
    $d = [int]$numDel.Value
    if ($d -le $w) {
        $durPreview.Text = '⚠  Otomatik silme süresi, uyarı süresinden büyük olmalı.'
        $durPreview.ForeColor = $C.Danger
    }
    else {
        $durPreview.Text = "0–$($w - 1) gün: yeni   ›   $w–$($d - 1) gün: inceleme   ›   $d+ gün: otomatik silinir"
        $durPreview.ForeColor = [StfcUi.Gfx]::Mix($C.Accent, [System.Drawing.Color]::White, 0.35)
    }
}
$numWarn.Add_ValueChanged({ Update-DurationPreview })
$numDel.Add_ValueChanged({ Update-DurationPreview })

Add-Spacer $set.Page 16
$recCard = New-Card 182 0
$recCard.Width = 980
New-SettingRow $recCard "Geri Dönüşüm Kutusu'nu kullan" 'Açıkken silinen dosyalar kalıcı olarak silinmek yerine Geri Dönüşüm Kutusu''na taşınır.' 22
$togRecycle = New-Object StfcUi.Toggle
$togRecycle.SetBounds(892, 34, 50, 26)
$togRecycle.Anchor = 'Top,Right'
$recCard.Controls.Add($togRecycle)
$sep2 = New-Object System.Windows.Forms.Panel
$sep2.BackColor = $C.Border
$sep2.SetBounds(22, 92, 936, 1)
$sep2.Anchor = 'Top,Left,Right'
$recCard.Controls.Add($sep2)
New-SettingRow $recCard 'Oturum açılışında her zaman göster' 'Kapalıyken uygulama yalnızca incelenecek dosya olduğunda açılır.' 110
$togStartup = New-Object StfcUi.Toggle
$togStartup.SetBounds(892, 122, 50, 26)
$togStartup.Anchor = 'Top,Right'
$recCard.Controls.Add($togStartup)
Add-Dock $set.Page $recCard 'Top'

Add-Spacer $set.Page 20
$setBar = New-Object System.Windows.Forms.FlowLayoutPanel
$setBar.Height = 44
$setBar.WrapContents = $false
Add-Dock $set.Page $setBar 'Top'
$btnSave = New-Button 'Kaydet' $G.Check 'Solid' $C.Accent 140 42 {
    if ($numDel.Value -le $numWarn.Value) {
        Show-Toast 'Otomatik silme süresi, uyarı süresinden büyük olmalı' $C.Danger $G.Warn
        return
    }
    Save-Config ([pscustomobject]@{ warningDays = [int]$numWarn.Value; deletionDays = [int]$numDel.Value; useRecycleBin = $togRecycle.Checked; showOnStartup = $togStartup.Checked })
    Update-All
    Show-Toast 'Ayarlar kaydedildi'
}
$btnSave.Margin = New-Object System.Windows.Forms.Padding(0, 0, 10, 0)
$setBar.Controls.Add($btnSave)
$btnDefaults = New-Button 'Varsayılanlar' $G.Refresh 'Ghost' $C.Accent 150 42 {
    $numWarn.Value = 7
    $numDel.Value = 14
    $togRecycle.Checked = $false
    $togStartup.Checked = $true
}
$btnDefaults.Margin = New-Object System.Windows.Forms.Padding(0, 0, 10, 0)
$setBar.Controls.Add($btnDefaults)
$btnDeskLink = New-Button 'Masaüstü kısayolu' $G.Link 'Ghost' $C.Accent 190 42 {
    Install-Shortcuts -Desktop -StartMenu
    Show-Toast 'Masaüstüne kısayol oluşturuldu'
}
$btnDeskLink.Margin = New-Object System.Windows.Forms.Padding(0, 0, 10, 0)
$setBar.Controls.Add($btnDeskLink)
$btnFolderIcon = New-Button 'Klasör simgesi' $G.Folder 'Ghost' $C.Accent 170 42 {
    if (Set-FolderIcon) { Show-Toast 'Klasör simgesi uygulandı (masaüstü yenilenince görünür)' }
    else { Show-Toast 'Klasör simgesi uygulanamadı' $C.Danger $G.Warn }
}
$btnFolderIcon.Margin = New-Object System.Windows.Forms.Padding(0)
$setBar.Controls.Add($btnFolderIcon)

function Update-SettingsView {
    $numDel.Value = [math]::Min(365, [math]::Max(1, $script:Config.deletionDays))
    $numWarn.Value = [math]::Min(365, [math]::Max(1, $script:Config.warningDays))
    $togRecycle.Checked = $script:Config.useRecycleBin
    $togStartup.Checked = $script:Config.showOnStartup
    Update-DurationPreview
}
#endregion

#region Sayfa: Geçmiş
$logPage = New-Page 'log' 'Geçmiş' 'Son işlemler (en yenisi en altta)'
$logPage.Actions.Controls.Add((New-Button 'Dosyayı Aç' $G.Open 'Ghost' $C.Accent 140 40 {
            if (Test-Path -LiteralPath $script:LogFile) { Start-Process notepad.exe -ArgumentList "`"$script:LogFile`"" }
        }))
$logPage.Actions.Controls.Add((New-Button 'Yenile' $G.Refresh 'Ghost' $C.Accent 120 40 { Update-LogView }))

$logCard = New-Card 100 18
Add-Dock $logPage.Page $logCard 'Fill'
$txtLog = New-Object System.Windows.Forms.RichTextBox
$txtLog.ReadOnly = $true
$txtLog.BorderStyle = 'None'
$txtLog.BackColor = $C.Card
$txtLog.ForeColor = $C.Text
$txtLog.Font = New-UiFont 9.5 'Consolas'
$txtLog.DetectUrls = $false
Add-Dock $logCard $txtLog 'Fill'
[StfcUi.Native]::DarkTheme($txtLog)

function Update-LogView {
    $txtLog.Clear()
    if (-not (Test-Path -LiteralPath $script:LogFile)) { $txtLog.Text = 'Henüz kayıt yok.'; return }
    $lines = Get-Content -LiteralPath $script:LogFile -Encoding UTF8 -Tail 400
    $txtLog.SuspendLayout()
    foreach ($line in $lines) {
        if ($line.Length -gt 22 -and $line[19] -eq ' ') {
            $txtLog.SelectionColor = $C.Muted
            $txtLog.AppendText($line.Substring(0, 19) + '   ')
            $msg = $line.Substring(22)
        }
        else { $msg = $line }
        $color = if ($msg -match 'hata|hatasi') { $C.Warning }
        elseif ($msg -match '^(Otomatik silindi|Silindi)') { [StfcUi.Gfx]::Mix($C.Danger, [System.Drawing.Color]::White, 0.25) }
        elseif ($msg -match '^Korumaya|^Koruma') { $C.Success }
        elseif ($msg -match '^(Config|Baslangic|Uyari)') { [StfcUi.Gfx]::Mix($C.Accent2, [System.Drawing.Color]::White, 0.2) }
        else { $C.Text }
        $txtLog.SelectionColor = $color
        $txtLog.AppendText($msg + "`n")
    }
    $txtLog.ResumeLayout()
    $txtLog.SelectionStart = $txtLog.TextLength
    $txtLog.ScrollToCaret()
}
#endregion

#region Sayfa: Hakkında
$about = New-Page 'about' 'Hakkında' 'Geçici dosyalarınızı akıllıca yönetin.'
$hero = New-Card 170 30
$hero.Fill = [StfcUi.Gfx]::Mix($C.Card, $C.Accent, 0.45)
$hero.Fill2 = [StfcUi.Gfx]::Mix($C.Card, $C.Accent2, 0.30)
$hero.BorderColor = [StfcUi.Gfx]::Mix($C.Border, $C.Accent, 0.4)
Add-Dock $about.Page $hero 'Top'
$heroTitle = New-Label 'Kısa Süreli Dosya Temizleyici' (New-UiFont 22 'Segoe UI Semibold') ([System.Drawing.Color]::White)
$heroTitle.Height = 46
Add-Dock $hero $heroTitle 'Top'
$heroVer = New-Label "Sürüm $script:AppVersion  ·  MIT Lisansı  ·  Umut Zaif" (New-UiFont 10) ([System.Drawing.Color]::FromArgb(220, 225, 255))
$heroVer.Height = 26
Add-Dock $hero $heroVer 'Top'
$heroDesc = New-Label 'Masaüstündeki short-term-files klasörüne bıraktığınız dosyaları takip eder; süresi yaklaşanları size sorar, süresi dolanları otomatik temizler.' (New-UiFont 10.5) ([System.Drawing.Color]::FromArgb(235, 238, 255)) 'TopLeft'
$heroDesc.Height = 50
Add-Dock $hero $heroDesc 'Top'

Add-Spacer $about.Page 18
$steps = New-Object System.Windows.Forms.TableLayoutPanel
$steps.Height = 132
$steps.ColumnCount = 3
$steps.RowCount = 1
for ($i = 0; $i -lt 3; $i++) { [void]$steps.ColumnStyles.Add((New-Object System.Windows.Forms.ColumnStyle('Percent', 33.33))) }
[void]$steps.RowStyles.Add((New-Object System.Windows.Forms.RowStyle('Percent', 100)))
Add-Dock $about.Page $steps 'Top'
$stepDefs = @(
    @('1 · Bırak', 'Geçici dosyalarınızı short-term-files klasörüne atın; alt klasörler de taranır.', $C.Accent2),
    @('2 · İncele', 'Uyarı süresi dolan dosyalar için oturum açılışında İnceleme ekranı açılır.', $C.Warning),
    @('3 · Temizlen', 'Otomatik silme süresini aşan ve korunmayan dosyalar sessizce silinir.', $C.Success)
)
for ($i = 0; $i -lt 3; $i++) {
    $sc = New-Card 100 20
    $sc.Dock = 'Fill'
    $sc.Margin = New-Object System.Windows.Forms.Padding(0, 0, $(if ($i -lt 2) { 16 } else { 0 }), 0)
    $steps.Controls.Add($sc, $i, 0)
    $st = New-Label $stepDefs[$i][0] (New-UiFont 12 'Segoe UI Semibold') $stepDefs[$i][2]
    $st.Height = 30
    Add-Dock $sc $st 'Top'
    $sd = New-Label $stepDefs[$i][1] (New-UiFont 9.5) $C.Muted 'TopLeft'
    Add-Dock $sc $sd 'Fill'
}

Add-Spacer $about.Page 18
$linkBar = New-Object System.Windows.Forms.FlowLayoutPanel
$linkBar.Height = 44
$linkBar.WrapContents = $false
Add-Dock $about.Page $linkBar 'Top'
$btnRepo = New-Button 'GitHub deposu' $G.Link 'Soft' $C.Accent 170 42 { Start-Process $script:RepoUrl }
$btnRepo.Margin = New-Object System.Windows.Forms.Padding(0, 0, 10, 0)
$linkBar.Controls.Add($btnRepo)
$btnIssue = New-Button 'Sorun bildir' $G.Bug 'Ghost' $C.Accent 150 42 { Start-Process "$script:RepoUrl/issues" }
$btnIssue.Margin = New-Object System.Windows.Forms.Padding(0)
$linkBar.Controls.Add($btnIssue)
#endregion

#region Veri yenileme
function Update-Dashboard {
    $files = $script:Files
    $warn = @($files | Where-Object { $_.Stage -eq 'warning' })
    $soon = @($warn | Where-Object { $_.DaysLeft -le 2 })
    $fresh = @($files | Where-Object { $_.Stage -eq 'fresh' }).Count
    $expired = @($files | Where-Object { $_.Stage -eq 'expired' }).Count
    $protectedFiles = @($files | Where-Object { $_.Stage -eq 'protected' }).Count
    $totalSize = ($files | Measure-Object -Property Size -Sum).Sum

    $tileTotal.Value = "$($files.Count)"
    $tileTotal.Sub = "Toplam $(Format-Size $totalSize)"
    $tileWarn.Value = "$($warn.Count)"
    $tileWarn.Sub = "$($script:Config.warningDays)+ gün eski, kararınızı bekliyor"
    $tileSoon.Value = "$($soon.Count + $expired)"
    $tileSoon.Sub = '2 gün içinde otomatik silinecek'
    $tileProt.Value = "$protectedFiles"
    $tileProt.Sub = 'Otomatik silmeden muaf'

    $lifeBar.SetData(
        [int[]]@($fresh, ($warn.Count - $soon.Count), ($soon.Count + $expired), $protectedFiles),
        [System.Drawing.Color[]]@($C.Accent2, $C.Warning, $C.Danger, $C.Success),
        [string[]]@('Yeni', 'İncelemede', 'Kritik', 'Korunan'))

    $upGrid.Rows.Clear()
    foreach ($f in @($warn | Sort-Object DaysLeft, Name | Select-Object -First 12)) {
        $left = Get-LeftInfo $f
        $i = $upGrid.Rows.Add($f.Extension, $f.RelPath, $left[0])
        $upGrid.Rows[$i].Tag = $f.FullName
        $upGrid.Rows[$i].Cells['left'].Style.ForeColor = $left[1]
    }
    $upGrid.ClearSelection()
    $upEmpty.Visible = ($warn.Count -eq 0)
    $upGrid.Visible = ($warn.Count -gt 0)
    $upAll.Visible = ($warn.Count -gt 0)

    $script:NavItems['review'].Badge = $warn.Count
    $dash.Subtitle.Text = "Klasörün anlık durumu · son tarama $(Get-Date -Format 'HH:mm')"
}

function Update-All {
    $script:Config = Get-Config
    $script:Files = @(Get-ManagedFiles -Config $script:Config)
    $script:FileIndex = @{}
    foreach ($f in $script:Files) { $script:FileIndex[$f.FullName] = $f }
    Update-Dashboard
    Update-ReviewGrid
    Update-ProtectedGrid
    if ($script:CurrentPage -eq 'log') { Update-LogView }
}

function Update-TaskStatus {
    $script:TaskInfo = $null
    try { $script:TaskInfo = Get-TaskInfo } catch { }
    if ($script:TaskInfo) {
        $autoState.Text = 'Etkin'
        $autoState.ForeColor = $C.Success
        $autoLast.Text = if ($script:TaskInfo.LastRun) { "Son çalışma: $($script:TaskInfo.LastRun.ToString('dd.MM.yyyy HH:mm'))" } else { 'Henüz çalışmadı' }
        if ($script:TaskInfo.IsCurrent) {
            $autoDesc.Text = if ($script:Config.showOnStartup) { 'Oturum açıldığında uygulama PowerShell penceresi olmadan açılır; süresi dolan dosyalar temizlenir.' }
            else { 'Oturum açıldığında süresi dolanlar temizlenir; uygulama yalnızca incelenecek dosya varsa açılır.' }
            $autoBtn.Text = 'Kapat'
            $autoBtn.Kind = 'Outline'
            $autoBtn.Accent = $C.Danger
            $sideDot.ForeColor = $C.Success
            $sideStatusText.Text = 'Etkin · açılışta başlar'
        }
        else {
            $autoState.ForeColor = $C.Warning
            if ($script:TaskInfo.BelongsHere) {
                $autoDesc.Text = 'Eski bir sürümle kurulmuş. Uygulamanın yeni sürümüyle açılması için güncelleyin.'
                $autoBtn.Text = 'Güncelle'
            }
            else {
                $autoDesc.Text = 'Otomatik başlatma başka bir klasördeki kopyaya bağlı. Bu kopyayı kullanmak için buraya taşıyın.'
                $autoBtn.Text = 'Bu kopyaya taşı'
            }
            $autoBtn.Kind = 'Solid'
            $autoBtn.Accent = $C.Warning
            $sideDot.ForeColor = $C.Warning
            $sideStatusText.Text = if ($script:TaskInfo.BelongsHere) { 'Etkin · güncelleme gerekli' } else { 'Başka bir kopyada etkin' }
        }
    }
    else {
        $autoState.Text = 'Kapalı'
        $autoState.ForeColor = $C.Danger
        $autoDesc.Text = 'Kurulduğunda, oturum her açıldığında uygulama açılır ve süresi dolan dosyalar temizlenir.'
        $autoLast.Text = ''
        $autoBtn.Text = 'Otomatik başlatmayı kur'
        $autoBtn.Kind = 'Solid'
        $autoBtn.Accent = $C.Accent
        $sideDot.ForeColor = $C.Danger
        $sideStatusText.Text = 'Kapalı'
    }
}
#endregion

#region Kurulum sihirbazı (ilk açılış)
function Show-SetupDialog {
    $dlg = New-Object System.Windows.Forms.Form
    $dlg.Text = 'Kurulum'
    $dlg.FormBorderStyle = 'FixedDialog'
    $dlg.MaximizeBox = $false
    $dlg.MinimizeBox = $false
    $dlg.ShowInTaskbar = $false
    $dlg.StartPosition = 'CenterParent'
    $dlg.AutoScaleMode = 'None'
    $dlg.ClientSize = New-Object System.Drawing.Size(560, 540)
    $dlg.BackColor = $C.Bg
    $dlg.ForeColor = $C.Text
    $dlg.Font = New-UiFont 9.5
    $dlg.Icon = $form.Icon
    $script:WizDlg = $dlg
    $dlg.Add_HandleCreated({ [StfcUi.Native]::StyleWindow($this.Handle, $C.Bg) })

    $hero = New-Card 150 0
    $hero.SetBounds(20, 20, 520, 150)
    $hero.Fill = [StfcUi.Gfx]::Mix($C.Card, $C.Accent, 0.40)
    $hero.Fill2 = [StfcUi.Gfx]::Mix($C.Card, $C.Accent2, 0.28)
    $hero.BorderColor = [StfcUi.Gfx]::Mix($C.Border, $C.Accent, 0.4)
    $dlg.Controls.Add($hero)
    $pic = New-Object System.Windows.Forms.PictureBox
    $pic.SetBounds(26, 36, 76, 76)
    $pic.SizeMode = 'Zoom'
    $pic.BackColor = [System.Drawing.Color]::Transparent
    $pic.Image = Get-AppImage
    $hero.Controls.Add($pic)
    $t = New-Label 'Hoş geldiniz!' (New-UiFont 18 'Segoe UI Semibold') ([System.Drawing.Color]::White)
    $t.SetBounds(120, 30, 380, 40)
    $hero.Controls.Add($t)
    $cfg = Get-Config
    $d = New-Label "short-term-files klasörüne bıraktığınız dosyalar $($cfg.warningDays) gün sonra size sorulur, $($cfg.deletionDays) gün sonra otomatik temizlenir." (New-UiFont 10) ([System.Drawing.Color]::FromArgb(230, 234, 255)) 'TopLeft'
    $d.SetBounds(122, 72, 380, 60)
    $hero.Controls.Add($d)

    $opts = New-Card 238 0
    $opts.SetBounds(20, 186, 520, 238)
    $dlg.Controls.Add($opts)
    $rows = @(
        @('autostart', 'Oturum açılışında başlat', 'Bilgisayar açıldığında uygulama açılır ve süresi dolanları temizler.'),
        @('desktop', 'Masaüstüne kısayol ekle', 'Uygulamayı masaüstündeki kısayoldan tek tıkla açın.'),
        @('foldericon', 'Klasöre özel simge ver', 'short-term-files klasörü masaüstünde kolayca fark edilsin.')
    )
    $script:WizToggles = @{}
    for ($i = 0; $i -lt $rows.Count; $i++) {
        $y = 18 + $i * 72
        $rt = New-Label $rows[$i][1] (New-UiFont 10.5 'Segoe UI Semibold')
        $rt.SetBounds(20, $y, 380, 24)
        $opts.Controls.Add($rt)
        $rd = New-Label $rows[$i][2] (New-UiFont 9) $C.Muted 'TopLeft'
        $rd.SetBounds(20, $y + 25, 400, 36)
        $opts.Controls.Add($rd)
        $tg = New-Object StfcUi.Toggle
        $tg.SetBounds(450, $y + 8, 50, 26)
        $tg.Checked = $true
        $opts.Controls.Add($tg)
        $script:WizToggles[$rows[$i][0]] = $tg
    }

    if (-not (Test-AtDesktopTarget)) {
        $loc = New-Label "Uygulama Masaüstü\short-term-files klasörüne kurulacak." (New-UiFont 9 'Segoe UI Semibold') $C.Warning
        $loc.SetBounds(22, 432, 520, 24)
        $dlg.Controls.Add($loc)
    }

    $script:WizardChoice = $null
    $later = New-Button 'Şimdi değil' '' 'Ghost' $C.Accent 150 44 { $script:WizardChoice = @(); $script:WizDlg.Close() }
    $later.SetBounds(214, 470, 150, 44)
    $dlg.Controls.Add($later)
    $ok = New-Button 'Kur' $G.Check 'Solid' $C.Accent 160 44 {
        $script:WizardChoice = @($script:WizToggles.Keys | Where-Object { $script:WizToggles[$_].Checked })
        if ($script:WizardChoice.Count -eq 0) { $script:WizardChoice = @('none') }
        $script:WizDlg.Close()
    }
    $ok.SetBounds(380, 470, 160, 44)
    $dlg.Controls.Add($ok)

    $scale = [StfcUi.Theme]::Scale
    if ([math]::Abs($scale - 1) -gt 0.01) { $dlg.Scale((New-Object System.Drawing.SizeF($scale, $scale))) }
    [void]$dlg.ShowDialog($form)
    $dlg.Dispose()
    return $script:WizardChoice
}

function Invoke-SetupWizard {
    $choice = Show-SetupDialog
    if ($null -eq $choice -or $choice.Count -eq 0) {
        Save-Config ([pscustomobject]@{ setupDone = $true })
        Write-Log 'Kurulum sihirbazi atlandi'
        return
    }
    $options = @($choice | Where-Object { $_ -ne 'none' })
    if (-not (Test-AtDesktopTarget)) {
        try {
            $target = Copy-AppToDesktop
            $script:RelaunchExe = Join-Path $target $script:AppExeName
            $script:RelaunchArgs = '/setup:' + $(if ($options) { $options -join ',' } else { 'none' })
            Save-Config ([pscustomobject]@{ setupDone = $true })
            $form.Close()
        }
        catch { [System.Windows.Forms.MessageBox]::Show("Kurulum başarısız: $($_.Exception.Message)", 'Hata', 'OK', 'Error') | Out-Null }
        return
    }
    $errors = Invoke-Setup -Options $options -AllowElevation
    Update-TaskStatus
    if ($errors) { Show-Toast ($errors -join ' · ') $C.Warning $G.Warn }
    else { Show-Toast 'Kurulum tamamlandı' }
}
#endregion

#region Başlatma
$form.Add_Load({
        Update-All
        Update-SettingsView
        if ($Startup -and $script:StartupPending -gt 0) { Show-Page 'review' } else { Show-Page 'dash' }
    })

$form.Add_Shown({
        if ($Startup) {
            $form.TopMost = $true
            $form.Activate()
            $form.TopMost = $false
        }
        if ($script:AutoDeleted -gt 0) { Show-Toast "Süresi dolan $($script:AutoDeleted) dosya otomatik temizlendi" $C.Accent2 $G.Clock }
        if ($script:SetupErrors) { Show-Toast ($script:SetupErrors -join ' · ') $C.Warning $G.Warn }
        # Görev Zamanlayıcı sorgusu yavaş olabilir; pencere çizildikten sonra çalıştır.
        $deferred = New-Object System.Windows.Forms.Timer
        $deferred.Interval = 150
        $deferred.Add_Tick({
                $this.Stop()
                Update-TaskStatus
                # Bu klasörde eski sürümle kurulmuş görevi yeni exe'ye taşı (başka konumdaki kurulumlara dokunma)
                if ($script:TaskInfo -and -not $script:TaskInfo.IsCurrent -and $script:TaskInfo.BelongsHere) {
                    try { Install-CleanupTask; Update-TaskStatus }
                    catch { Write-Log "Gorev otomatik guncellenemedi: $($_.Exception.Message)" }
                }
                if (-not $Startup -and -not $script:Config.setupDone) { Invoke-SetupWizard }
            })
        $deferred.Start()
    })

$form.Add_FormClosed({
        if ($Startup) { Write-Log 'Inceleme penceresi kapatildi' }
        try { $script:InstanceMutex.ReleaseMutex() } catch { }
    })

[StfcUi.Native]::DarkTheme($content)
# Yüksek DPI: tüm yerleşimi ekran ölçeğine göre büyüt (yazı tipleri zaten DPI'a göre çizilir)
$scale = [StfcUi.Theme]::Scale
if ([math]::Abs($scale - 1) -gt 0.01) { $form.Scale((New-Object System.Drawing.SizeF($scale, $scale))) }
$form.MinimumSize = New-Object System.Drawing.Size([StfcUi.Theme]::S(1060), [StfcUi.Theme]::S(700))
[void]$form.ShowDialog()
try { $script:InstanceMutex.ReleaseMutex() } catch { }
# Kurulum masaüstüne taşındıysa yeni konumdaki uygulamayı başlat
if ($script:RelaunchExe) { Start-Process -FilePath $script:RelaunchExe -ArgumentList $script:RelaunchArgs }
#endregion
