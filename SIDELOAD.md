# Cara Install Musicfy ke iPhone (Sideload)

## ❌ Issue: IPA dari GitHub Actions tidak bisa di-install

Kalau download IPA dari GitHub Actions artifact **tidak bisa di-install** via Scarlet/KSign, ini karena IPA yang di-build tanpa signing kadang incompatible.

## ✅ Solusi: Build sendiri di Xcode (Recommended)

### Prerequisites:
- Mac dengan Xcode 15.4+
- Apple ID (gratis)
- iPhone 13 dengan iOS 17+

### Langkah-langkah:

#### 1. Clone repo
```bash
git clone https://github.com/paloskoal-crypto/Musicfy.git
cd Musicfy
open Musicfy.xcodeproj
```

#### 2. Di Xcode:
1. **Select your device**: Pilih iPhone kamu di dropdown (bukan Simulator)
2. **Signing & Capabilities** tab:
   - Team: Pilih Apple ID kamu
   - Bundle Identifier: Ubah jadi unique, misal `com.yourname.musicfy`
3. **Build Settings**:
   - Scroll ke "Signing"
   - Set "Code Signing Identity" = "Apple Development"

#### 3. Build & Install langsung:
```
Cmd + R (atau klik tombol Play)
```
Xcode akan otomatis:
- Build app
- Sign dengan Apple ID kamu
- Install ke iPhone via cable

#### 4. Trust Developer:
Di iPhone: **Settings → General → VPN & Device Management → [Your Apple ID] → Trust**

---

## 🔄 Alternatif: Build IPA Manual lalu Install via Scarlet

#### 1. Archive di Xcode:
```
Product → Archive
```

#### 2. Export for Development:
1. Klik **Distribute App**
2. Pilih **Development**
3. Pilih **Export**
4. Simpan IPA

#### 3. Install via Scarlet:
1. Transfer IPA ke iPhone (AirDrop/iCloud)
2. Buka Scarlet → Import IPA
3. Install

---

## ⚠️ Kenapa IPA dari GHA Tidak Jalan?

GitHub Actions build **tanpa Apple Developer signing** → IPA yang dihasilkan:
- ❌ Tidak punya valid code signature
- ❌ Tidak punya provisioning profile
- ❌ Bundle structure bisa berbeda dari yang di-expect sideloader

**Solusi:** Build di Xcode lokal dengan Apple ID kamu sendiri = **always works**!

---

## 🎯 TL;DR — Fastest Way:

```bash
git clone https://github.com/paloskoal-crypto/Musicfy.git
cd Musicfy
open Musicfy.xcodeproj
```

Di Xcode:
1. Pilih iPhone kamu sebagai target
2. Set Team ke Apple ID kamu
3. Cmd+R

Done! App langsung ke iPhone kamu. 🚀

---

## 💡 Tips:

**Free Apple ID limitation:**
- App expire setelah 7 hari
- Reinstall via Xcode lagi setelah expire

**Paid Apple Developer ($99/tahun):**
- App expire setelah 1 tahun
- Bisa distribute ke device lain

**AltStore/SideStore (gratis selamanya):**
- Auto-refresh sebelum expire
- Butuh PC/Mac yang online di network yang sama
