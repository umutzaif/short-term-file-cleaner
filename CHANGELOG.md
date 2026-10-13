# Changelog

All notable changes to this project will be documented in this file.

## [3.0.0] - 2026-10-13

### Fixed
- **Sil butonu bazı dosyaları silmiyordu**: Seçili dosyalar liste metninden `Split(" - ")` ile ayrıştırılıyordu;
  PowerShell 5.1'de bu, boşluk ve `-` karakterlerinin her birinde böldüğü için adında boşluk veya tire olan
  dosyalar hiç eşleşmiyor, silinmiyor ve ertesi gün yeniden listeleniyordu. Satırlar artık tam yolu doğrudan taşıyor.
- **Köşeli parantezli dosyalar silinmiyordu**: `Remove-Item -Path` `[ ]` karakterlerini joker olarak yorumluyordu
  (ör. `Arduino 328 [Proteus 8.9].pdsprj` her gün "silindi" diye loglanıp yerinde kalıyordu). Tüm dosya işlemleri
  artık `-LiteralPath` kullanıyor ve silme sonrası dosyanın gerçekten gittiği doğrulanıyor.
- **Açılışta PowerShell penceresi görünüyordu**: Görev artık `Launcher.exe` sessiz başlatıcısıyla çalışıyor
  (`CREATE_NO_WINDOW`); konsol penceresi hiç oluşmuyor. Eski görevler ilk açılışta otomatik taşınıyor.
- Görevin 5 dakikalık çalışma sınırı, inceleme penceresi açık bırakıldığında uygulamayı kapatıyordu; sınır kaldırıldı.
- "Şimdi Temizle" artık ayrı bir PowerShell penceresi açmıyor.

### Added
- **Tamamen yeni arayüz**: Koyu tema, kenar çubuğu menüsü, istatistik kartları, dosya yaşam döngüsü grafiği,
  dosya türü rozetleri, bildirimler, koyu başlık çubuğu ve yüksek DPI desteği.
- **Birleşik uygulama**: Açılış inceleme ekranı ile panel artık aynı pencere; incelemeden Genel Bakış, Korunanlar,
  Ayarlar ve Geçmiş'e geçilebilir.
- İnceleme ekranında **Tüm dosyalar** görünümü, seçili toplam boyut, çift tıklayarak klasörde gösterme.
- Korunanlar sayfasında **Dosya Ekle** ve **Eksikleri Temizle**.
- **Geri Dönüşüm Kutusu** seçeneği (`useRecycleBin`).
- Silme öncesi onay penceresi.
- **Başlat menüsü kısayolu**.
- Log dosyası 1 MB'ı aşınca otomatik kırpılıyor.

### Changed
- Dosya yaşı, oluşturma ve değiştirme tarihlerinden yenisine göre hesaplanıyor (klasöre kopyalanan eski dosyalar
  hemen silinmez).
- Ortak mantık `.system/Core.ps1` içinde toplandı; `ConfigEditor.ps1` kaldırıldı (Ayarlar sayfası yerini aldı).
- Tarama gizli/sistem öğelerini, `.git` klasörünü ve bağlantı noktalarını (junction) atlıyor.

## [2.0.0] - 2026-02-04

### Added
- **Main GUI Application** (MainApp.ps1)
  - Tab-based interface with 5 sections
  - One-click installation and uninstallation
  - Real-time status monitoring
  - Manual cleanup trigger
  - Settings editor
  - Protected files manager
  - Log viewer
  
- **Advanced Configuration System**
  - Customizable warning days
  - Customizable auto-deletion days
  - JSON-based configuration
  
- **Two-Stage Deletion**
  - Warning stage (configurable days)
  - Auto-deletion stage (configurable days)
  
- **File Protection System**
  - Protect files from auto-deletion
  - Manage protected files via GUI
  - JSON-based protection list
  
- **Enhanced Cleanup Dialog**
  - Checkbox-based file selection
  - Three action buttons: Delete / Skip / Protect
  - Relative path display
  - File age and size information

### Changed
- Reorganized scripts into `.system` folder
- Improved user interface with modern Windows Forms
- Enhanced logging system

## [1.0.0] - 2026-02-03

### Added
- Initial release
- Basic file cleanup functionality
- Recursive folder scanning
- Windows Task Scheduler integration
- Simple GUI for file deletion confirmation
- Logging system
