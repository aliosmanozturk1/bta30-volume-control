# BTA30 Volume

**FiiO BTA30 Pro** USB DAC olarak çalışırken Mac'ten gerçek ses kontrolü sağlayan menü çubuğu uygulaması — ses tuşları, scroll ile ayar, sistem tarzı HUD ve tüm cihaz ayarları menü çubuğunda.

*English version: [README.md](README.md)*

## Neden var?

BTA30 Pro, USB DAC modunda macOS'e **ses seviyesi birimi ve HID arayüzü olmayan** bir USB Audio Class 2 aygıtı olarak görünür — bu yüzden Mac'in ses tuşları çalışmaz, sistem kaydıracı devre dışıdır. Cihazın gerçek kontrol kanalı Bluetooth LE'dir: FiiO Control mobil uygulamasının kullandığı GAIA protokolü, FiiO'nun kendi dokümantasyonuna göre USB DAC modunda da aktiftir.

Bu uygulama iki dünyayı birleştirir: **ses USB'den akmaya devam eder, kontrol Mac'in kendi Bluetooth'u üzerinden BLE ile yapılır.** Sürücü yok, kernel extension yok.

## Özellikler

- Menü çubuğunda kaydıraç ve anlık seviye göstergesi (cihazın kendi ölçeği olan 0–60)
- Menü çubuğu simgesinin üzerinde scroll ile ses ayarı (isteğe bağlı,
  varsayılan kapalı — yanlışlıkla sesi fullemek çok kolay)
- **Medya tuşları desteği** — F10/F11/F12 BTA30'u kontrol eder, ama yalnızca FiiO aktif ses çıkışıyken; başka aygıt seçiliyken sistem sesi normal çalışır (Erişilebilirlik izni gerekir, adım ±1/±2/±3 seçilebilir)
- **Düzenlenebilir global kısayollar** (varsayılan ⌥⌘↑ / ⌥⌘↓ / ⌥⌘0) — her uygulamada çalışır, izin gerektirmez
- Menü çubuğu simgesinin altına hizalanan, sistem tarzı ses HUD'u
- **Preset'ler** — ses + filtre + denge + LED + upsampling kombinasyonlarını kaydet; tek tıkla, sağ tık menüsünden veya URL ile uygula
- Cihaz ayarları: DAC lowpass filtresi, kanal dengesi (L12–R12), 384 kHz upsampling, LED açma/kapama, otomatik açılış, uzaktan kapatma
- **Ses limiti** — hiçbir kaynağın (cihazın kumandası dahil) aşamayacağı tavan
- Canlı senkron: kumandayla yapılan değişiklikler anında yansır
- Anlık USB ses formatı (örnekleme hızı / bit derinliği) ve firmware sürümü gösterimi
- Girişte başlatma, otomatik yeniden bağlanma, sağ tık hızlı menüsü
- Otomasyon için URL şeması (aşağıda)
- Yerelleştirme: İngilizce, Türkçe (katkıya açık — tek bir [string catalog](Sources/BTA30Volume/Resources/Localizable.xcstrings))

## Uyumluluk

**BTA30 Pro** üzerinde test edildi. Pro olmayan **BTA30** aynı Qualcomm CSR8675 çipini ve aynı GAIA protokolünü kullanır (uygulamanın dayandığı protokol dokümantasyonu zaten Pro olmayan model için yazılmıştı), yani büyük ihtimalle çalışır — ama test edilmedi. Denerseniz sonucu (olumlu ya da olumsuz) bir issue ile paylaşın.

## Gizlilik

Bu uygulama **internete hiç çıkmaz.** Yalnızca BTA30 ile Bluetooth LE üzerinden konuşur — analitik yok, telemetri yok, güncelleme kontrolü yok. Hiçbir veri makinenizden dışarı çıkmaz.

## Kurulum

Gereksinimler: macOS 13+, Xcode, [Tuist](https://tuist.dev) (`brew install tuist`).

```bash
./build.sh
open "dist/BTA30 Volume.app"   # veya /Applications'a kopyalayın
```

Geliştirme için `tuist generate` Xcode workspace'ini oluşturup açar.

İlk açılışta macOS **Bluetooth** izni ister — zorunludur. Medya tuşlarını açarsanız **Erişilebilirlik** izni için yönlendirilirsiniz (izni verdiğiniz anda tuşlar kendiliğinden devreye girer).

> **İmza notu:** `build.sh`, keychain'de Apple Development sertifikası bulursa onunla imzalar; böylece TCC izinleri yeniden derlemelerde korunur. Sertifika yoksa ad-hoc imzalanır — o durumda her derleme yeni uygulama sayılır ve izinlerin yeniden verilmesi gerekir (`tccutil reset Accessibility com.aliosmanozturk.bta30volume` işi kolaylaştırır).

## URL şeması (otomasyon)

Kısayollar (Shortcuts), Raycast, Alfred veya terminalden:

```bash
open "bta30://volume/25"      # ses seviyesini ayarla (0-60)
open "bta30://volume/up"      # sesi artır (tuş adımı kadar)
open "bta30://volume/down"    # sesi azalt
open "bta30://mute"           # sessize al / geri aç
open "bta30://balance/-3"     # denge: L3 (-12 … 12)
open "bta30://filter/2"       # DAC filtresi (0-3)
open "bta30://led/off"        # LED'ler (on/off)
open "bta30://upsampling/on"  # upsampling (on/off)
open "bta30://power/off"      # cihazı kapat
open "bta30://preset/gece"    # kayıtlı preset'i adıyla uygula
```

## Notlar

- Cihaz aynı anda tek BLE bağlantısı kabul eder: telefondaki FiiO Control bağlıyken bu uygulama bağlanamaz (ve tersi).
- FiiO'nun SSS'ine göre uygulama kontrolü yalnızca RX ve DAC modlarında çalışır; TX modunda çalışmaz.
- DAC modunda ses kontrolü, cihazın "Volume Mode: Adjustable" ayarını gerektirir (fabrika ayarı budur).

## Protokol

BTA30, CSR8675 üzerindeki Qualcomm GAIA servisini kullanır (`00001100-d102-11e1-9b23-00025b00a5a5`):

| Karakteristik | Görev |
|---|---|
| `...1101...` | Komut yazma |
| `...1102...` | Yanıt bildirimleri (önce abone olunur) |

Çerçeve biçimi: `00 0a 0X XX [payload]` (istek), `00 0a 8X XX 00 [payload]` (yanıt).
Ses: GET `0x412`, SET `0x402`, 1 bayt payload (0–60). Cihaz, ses yerel olarak değişince kendiliğinden bildirim gönderir — kumandayla senkron böyle sağlanır.

Bilinmesi gereken iki tuhaflık:
- Cihaz GAIA servis UUID'sini advertise **etmez**; keşif, tüm cihazları tarayıp isme göre eşleştirir.
- BTA30 Pro'da LED bayrağı (`0x43D`/`0x43E`) protokol dokümanının tersine çalışır: `0x01` = LED **yanıyor** (donanımda doğrulandı). Pro olmayan BTA30'da LED anahtarı ters çalışırsa issue açın.

## Teşekkür

- BLE protokolünün reverse engineering'i: [Hypfer/fiio-bta30-protocol](https://github.com/Hypfer/fiio-bta30-protocol) — bu proje protokolü BTA30 Pro üzerinde bayt bayt doğruladı.

## Lisans

[MIT](LICENSE)
