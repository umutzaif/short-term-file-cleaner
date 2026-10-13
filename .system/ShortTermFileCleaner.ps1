# Kısa Süreli Dosya Temizleyici - oturum açılışı giriş noktası (geriye dönük uyumluluk)
# v2 görev tanımları bu dosyayı çağırabilir. Uygulama açıldığında görev otomatik olarak
# "Dosya Temizleyici.exe /startup" komutuna taşınır.

& (Join-Path $PSScriptRoot 'MainApp.ps1') -Startup
