# 🗂️ Kısa Süreli Dosya Temizleyici

> Geçici dosyalarınızı otomatik olarak yönetin - Akıllı, kolay, güçlü

[![Platform](https://img.shields.io/badge/platform-Windows-blue.svg)](https://www.microsoft.com/windows)
[![PowerShell](https://img.shields.io/badge/PowerShell-5.1%2B-blue.svg)](https://docs.microsoft.com/powershell/)
[![License](https://img.shields.io/badge/license-MIT-green.svg)](LICENSE)
[![Version](https://img.shields.io/badge/version-2.0.0-orange.svg)](CHANGELOG.md)

Masaüstünüzde biriken geçici dosyalardan kurtulun! Bu uygulama, belirlediğiniz süre sonunda dosyalarınızı otomatik olarak temizler. Kod yazmaya gerek yok, sadece kurulum yapın ve kullanmaya başlayın.

---

## ✨ Özellikler

### 🎯 Temel Özellikler
- **Otomatik Temizlik**: Bilgisayar her açıldığında arka planda çalışır
- **Akıllı İki Aşamalı Sistem**: Önce uyarı, sonra otomatik silme
- **Dosya Koruma**: Önemli dosyalarınızı kalıcı olarak koruyun
- **Boş Klasör Temizliği**: Dosyalarla birlikte boş klasörler de silinir
- **Sıfır Bağımlılık**: Sadece Windows yerleşik araçları kullanır

### 🖥️ Kullanıcı Dostu Arayüz
- **Modern GUI**: 5 tab'lı profesyonel arayüz
- **Tek Tıkla Kurulum**: Otomatik Task Scheduler entegrasyonu
- **Görsel Durum Takibi**: Anlık durum bilgisi
- **Kolay Ayarlar**: Gün sayılarını kolayca değiştirin
- **Log Görüntüleyici**: Tüm işlemleri takip edin

### ⚙️ Gelişmiş Özellikler
- **Özelleştirilebilir Süreler**: Uyarı ve silme günlerini kendiniz belirleyin
- **Checkbox Seçimi**: Hangi dosyaların silineceğini seçin
- **Recursive Tarama**: Tüm alt klasörleri otomatik tarar
- **Minimal Kaynak**: ~5-10MB RAM kullanımı

---

## 📸 Ekran Görüntüleri

### Ana Sayfa
Modern, temiz arayüz ile durum bilgisi ve hızlı işlemler

### Temizlik Penceresi
Checkbox'larla dosya seçimi ve 3 işlem seçeneği: Sil, Atla, Koru

---

## 🚀 Hızlı Başlangıç

### Gereksinimler
- Windows 10/11
- PowerShell 5.1+ (yerleşik)

### Kurulum Adımları

#### 1️⃣ Projeyi İndirin
```bash
# Git ile
git clone https://github.com/umutzaif/short-term-file-cleaner.git

# veya ZIP olarak indirip çıkartın
```

#### 2️⃣ Ana Uygulamayı Çalıştırın
- `MainApp.ps1` dosyasına **sağ tıklayın**
- **"Run with PowerShell"** seçeneğini seçin

> **Not**: İlk çalıştırmada PowerShell execution policy uyarısı alabilirsiniz. Bu durumda:
> ```powershell
> Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
> ```

#### 3️⃣ Kurulum Yapın
- Ana Sayfa tab'inde **"Kurulum Yap"** butonuna tıklayın
- Otomatik görev oluşturulacak
- Artık bilgisayar her açıldığında otomatik çalışacak! ✅

#### 4️⃣ Kullanmaya Başlayın
- Geçici dosyalarınızı `Desktop\short-term-files` klasörüne atın
- İstediğiniz kadar alt klasör oluşturabilirsiniz
- Uygulama otomatik olarak yönetecek!

---

## 📖 Kullanım Kılavuzu

### Temel Kullanım

1. **Dosyaları Atın**
   - `C:\Users\[KullanıcıAdı]\Desktop\short-term-files` klasörüne geçici dosyalarınızı atın
   - Alt klasörler oluşturabilirsiniz (örn: `projeler`, `indirilenler`, `temp`)

2. **Otomatik Çalışma**
   - Bilgisayar her açıldığında arka planda çalışır
   - Eski dosyaları kontrol eder
   - Gerekirse uyarı penceresi açar

### İki Aşamalı Temizlik Sistemi

#### 📅 Varsayılan Ayarlar
- **Uyarı Süresi**: 7 gün
- **Otomatik Silme**: 14 gün

#### 🔄 Nasıl Çalışır?

| Dosya Yaşı | Ne Olur? |
|-----------|----------|
| 0-6 gün | Hiçbir şey olmaz |
| 7-13 gün | Uyarı penceresi açılır (Sil/Atla/Koru seçenekleri) |
| 14+ gün | Otomatik silinir (korunmadıysa) |

#### 💡 Örnek Senaryo
```
📁 rapor.pdf (5 gün önce) → Beklemede
📁 sunum.pptx (10 gün önce) → Uyarı penceresi açılır
📁 eski_dosya.zip (20 gün önce) → Otomatik silinir
🛡️ önemli.docx (30 gün önce, korumalı) → Silinmez
```

### Uyarı Penceresi Kullanımı

Uyarı penceresi açıldığında 3 seçeneğiniz var:

#### 🗑️ Sil
- Seçili dosyaları hemen siler
- Checkbox'larla hangi dosyaların silineceğini seçin
- Boş kalan klasörler de otomatik silinir

#### ⏭️ Atla
- Hiçbir şey yapmaz
- Dosyalar otomatik silme gününe kadar bekler
- Sonraki çalıştırmada tekrar uyarı alırsınız

#### 🛡️ Koru
- Seçili dosyaları **kalıcı korumaya** alır
- Otomatik silme günü dolsa bile silinmez
- MainApp'ten korumayı kaldırabilirsiniz

### MainApp.ps1 Kullanımı

#### Tab 1: Ana Sayfa
- **Durum Bilgisi**: Kurulum durumu, sonraki çalışma zamanı
- **Hızlı İşlemler**:
  - `Kurulum Yap`: Otomatik görevi oluştur
  - `Kaldır`: Otomatik görevi kaldır
  - `Şimdi Temizle`: Manuel temizlik başlat
  - `Klasörü Aç`: Hedef klasörü Explorer'da aç

#### Tab 2: Ayarlar
- **Uyarı Gün Sayısı**: Kaç gün sonra uyarı verileceği
- **Otomatik Silme Gün Sayısı**: Kaç gün sonra otomatik silineceği
- **Kaydet**: Ayarları kaydet

> ⚠️ **Önemli**: Otomatik silme günü, uyarı gününden büyük olmalıdır!

#### Tab 3: Korunan Dosyalar
- Korumalı dosyaların listesi
- `Korumayı Kaldır`: Seçili dosyanın korumasını kaldır
- `Yenile`: Listeyi güncelle

#### Tab 4: Log
- Tüm işlemlerin geçmişi
- `Yenile`: Log'u güncelle
- `Dosyayı Aç`: Log dosyasını Notepad'de aç

#### Tab 5: Hakkında
- Versiyon bilgisi
- GitHub linki
- Lisans bilgisi

---

## ⚙️ Gelişmiş Yapılandırma

### Ayarları Değiştirme

#### GUI ile (Önerilen)
1. `MainApp.ps1`'i çalıştırın
2. **Ayarlar** tab'ine gidin
3. Gün sayılarını değiştirin
4. **Kaydet** butonuna tıklayın

#### Manuel (config.json)
```json
{
  "warningDays": 7,
  "deletionDays": 14,
  "lastModified": "2026-02-04T20:00:00+03:00"
}
```

Dosya konumu: `Desktop\short-term-files\.system\config.json`

### Dosya Koruma Sistemi

#### Korumaya Alma
1. Temizlik penceresinde dosyayı seçin
2. **Koru** butonuna tıklayın
3. Dosya `protected-files.json`'a eklenir

#### Korumayı Kaldırma
1. `MainApp.ps1` → **Korunan Dosyalar** tab'i
2. Dosyayı seçin
3. **Korumayı Kaldır** butonuna tıklayın

---

## 🗂️ Klasör Yapısı

```
Desktop\short-term-files\
│
├── MainApp.ps1              # 🎯 ANA UYGULAMA (BU DOSYAYI ÇALIŞTIRIN)
├── README.md
├── LICENSE
├── CHANGELOG.md
├── .gitignore
│
├── .system\                 # ⚙️ Sistem klasörü (DOKUNMAYIN)
│   ├── ShortTermFileCleaner.ps1    # Temizlik betiği
│   ├── ConfigEditor.ps1            # Ayar editörü
│   ├── Install.ps1                 # Kurulum betiği
│   ├── Uninstall.ps1               # Kaldırma betiği
│   ├── config.json                 # Yapılandırma
│   ├── protected-files.json        # Korunan dosyalar
│   └── cleanup.log                 # İşlem geçmişi
│
└── [Kullanıcı Klasörleri]   # 📁 Geçici dosyalarınızı buraya atın
    ├── projeler\
    ├── indirilenler\
    └── temp\
```

---

## 🔧 Teknik Detaylar

| Özellik | Detay |
|---------|-------|
| **Dil** | PowerShell 5.1+ |
| **GUI Framework** | Windows Forms (.NET Framework) |
| **Zamanlama** | Windows Task Scheduler |
| **Bellek Kullanımı** | ~5-10MB |
| **Tarama Modu** | Recursive (tüm alt klasörler) |
| **Hariç Tutulan** | `.system` klasörü, `.ps1` dosyaları, `README.md` |
| **Encoding** | UTF-8 |

### Çalışma Prensibi

1. **Başlangıç**: Bilgisayar açıldığında Task Scheduler tetiklenir
2. **Tarama**: Tüm alt klasörler recursive olarak taranır
3. **Kontrol**: Dosya yaşları config'e göre kontrol edilir
4. **Otomatik Silme**: Çok eski dosyalar (14+ gün) otomatik silinir
5. **Uyarı**: Eski dosyalar (7-13 gün) için GUI açılır
6. **Kullanıcı Seçimi**: Sil/Atla/Koru seçenekleri sunulur
7. **Temizlik**: Boş klasörler otomatik silinir
8. **Log**: Tüm işlemler log'a kaydedilir

---

## 🐛 Sorun Giderme

### Uygulama çalışmıyor

**PowerShell Execution Policy Hatası**
```powershell
# Çözüm:
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
```

**Görev çalışmıyor**
1. Task Scheduler'ı açın (`Win + R` → `taskschd.msc`)
2. "ShortTermFileCleaner" görevini bulun
3. Sağ tıklayıp "Çalıştır" seçin
4. Hata varsa "Geçmiş" tab'inde kontrol edin

### Manuel test

```powershell
# Temizlik betiğini manuel çalıştır
cd "$env:USERPROFILE\Desktop\short-term-files\.system"
.\ShortTermFileCleaner.ps1
```

### Log kontrolü

```powershell
# Log dosyasını görüntüle
notepad "$env:USERPROFILE\Desktop\short-term-files\.system\cleanup.log"
```

### Sık Karşılaşılan Sorunlar

| Sorun | Çözüm |
|-------|-------|
| MainApp açılmıyor | PowerShell execution policy ayarlayın |
| Görev çalışmıyor | Task Scheduler'da kontrol edin |
| Dosyalar silinmiyor | Log dosyasını kontrol edin |
| Uyarı penceresi açılmıyor | Dosya yaşlarını kontrol edin |

---

## 🤝 Katkıda Bulunma

Katkılarınızı bekliyoruz! Lütfen:

1. Fork edin
2. Feature branch oluşturun (`git checkout -b feature/harika-ozellik`)
3. Commit edin (`git commit -m 'Harika özellik eklendi'`)
4. Push edin (`git push origin feature/harika-ozellik`)
5. Pull Request açın

### Geliştirme Fikirleri
- [ ] Farklı klasörler için farklı süreler
- [ ] E-posta bildirimleri
- [ ] Dosya türüne göre filtreleme
- [ ] İstatistik ve raporlama
- [ ] Sistem tray ikonu

---

## 📝 Lisans

Bu proje MIT lisansı altında lisanslanmıştır. Detaylar için [LICENSE](LICENSE) dosyasına bakın.

**Özet**: Kişisel ve ticari kullanım için özgürce kullanabilir, değiştirebilir ve dağıtabilirsiniz.

---

## 🙏 Teşekkürler

- Windows Forms ve PowerShell topluluğuna
- Tüm katkıda bulunanlara
- Geri bildirim sağlayan kullanıcılara

---

## 📞 İletişim

- **GitHub**: [@umutzaif](https://github.com/umutzaif)
- **Issues**: [Sorun bildirin](https://github.com/umutzaif/short-term-file-cleaner/issues)
- **Discussions**: [Tartışmalara katılın](https://github.com/umutzaif/short-term-file-cleaner/discussions)

---

## 📊 Sürüm Geçmişi

### v2.0.0 (2026-02-04)
- ✨ Ana GUI uygulaması (MainApp.ps1)
- ✨ Gelişmiş yapılandırma sistemi
- ✨ Dosya koruma sistemi
- ✨ İki aşamalı silme
- ✨ Boş klasör temizliği
- ✨ Checkbox'lı dosya seçimi
- 🎨 Modern profesyonel tasarım
- 🐛 Türkçe karakter düzeltmeleri

### v1.0.0 (2026-02-03)
- 🎉 İlk sürüm
- ⚡ Temel temizlik özelliği
- 📁 Recursive tarama
- ⏰ Task Scheduler entegrasyonu

---

## ⭐ Yıldız Verin!

Bu projeyi beğendiyseniz, lütfen GitHub'da ⭐ vererek destek olun!

---

**Not**: Sadece Windows işletim sisteminde çalışır. macOS ve Linux desteği planlanmamaktadır.

---

<div align="center">

**Geçici dosyalarınızı akıllıca yönetin! 🚀**

Made with ❤️ by [Umut Zaif](https://github.com/umutzaif)

</div>
