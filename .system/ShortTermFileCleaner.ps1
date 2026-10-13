# Kısa Süreli Dosya Temizleyici - oturum açılışı giriş noktası (geriye dönük uyumluluk)
# v3'ten itibaren tüm mantık "MainApp.ps1 -Startup" içindedir. Eski görev tanımları bu dosyayı
# çağırabilir; uygulama ilk açılışta görevi otomatik olarak sessiz başlatıcıya (Launcher.exe) taşır.

& (Join-Path (Split-Path -Parent $PSScriptRoot) 'MainApp.ps1') -Startup
