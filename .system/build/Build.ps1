# Kısa Süreli Dosya Temizleyici - derleme betiği (geliştiriciler için)
# 1) .system\assets altındaki simgeleri üretir (app.ico, folder.ico, app.png)
# 2) .system\App.cs'den kök klasördeki "Dosya Temizleyici.exe"yi derler
#
#   powershell -ExecutionPolicy Bypass -File .system\build\Build.ps1

param([switch]$SkipIcons)

. (Join-Path (Split-Path -Parent $PSScriptRoot) 'Core.ps1')

if (-not $SkipIcons) {
    Add-Type -TypeDefinition (Get-Content -LiteralPath (Join-Path $PSScriptRoot 'IconFactory.cs') -Raw -Encoding UTF8) -ReferencedAssemblies System.Drawing
    $assets = Join-Path $script:SystemFolder 'assets'
    New-Item -ItemType Directory -Path $assets -Force | Out-Null
    [StfcBuild.IconFactory]::WriteIco((Join-Path $assets 'app.ico'), [Func[int, System.Drawing.Bitmap]] { param($s) [StfcBuild.IconFactory]::App($s) })
    [StfcBuild.IconFactory]::WriteIco((Join-Path $assets 'folder.ico'), [Func[int, System.Drawing.Bitmap]] { param($s) [StfcBuild.IconFactory]::Folder($s) })
    $png = [StfcBuild.IconFactory]::App(256)
    $png.Save((Join-Path $assets 'app.png'), [System.Drawing.Imaging.ImageFormat]::Png)
    $png.Dispose()
    Write-Host 'Simgeler üretildi.' -ForegroundColor Green
}

if (Build-AppExe) { Write-Host "Derlendi: $script:AppExe" -ForegroundColor Green }
else { Write-Host 'Derleme başarısız, ayrıntılar .system\cleanup.log içinde.' -ForegroundColor Red; exit 1 }
