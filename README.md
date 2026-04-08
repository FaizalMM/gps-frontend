# 📱 GPS Tracking App - Frontend (Flutter)

Aplikasi mobile berbasis **Flutter** untuk monitoring lokasi bus secara real-time, dengan role pengguna seperti admin, driver, dan siswa.

---

## 🚀 Tech Stack

* Flutter
* Dart
* REST API (Laravel Backend)

---

## 🔥 Fitur Utama

* 🔐 Login & Authentication
* 📍 Tracking Lokasi Bus Real-time
* 🧾 Scan QR Code
* 👨‍✈️ Dashboard Driver
* 🎓 Dashboard Siswa
* 🗺️ Manajemen Lokasi Halte (Admin)

---

## 📂 Struktur Project

```
lib/
 ├── models/        # Data model
 ├── screens/       # Semua tampilan UI
 │    ├── admin/    # Halaman admin
 │    ├── auth/     # Login & autentikasi
 │    ├── common/   # Halaman umum
 │    ├── driver/   # Halaman driver
 │    └── siswa/    # Halaman siswa
 ├── services/      # API service (GPS, bus, dll)
 ├── utils/         # Helper / utility
 ├── widgets/       # Reusable UI components
 └── main.dart      # Entry point aplikasi
```

---

## 🌐 Backend API

Terhubung dengan:
👉 https://github.com/FaizalMM/GPS_BE

---

## ⚙️ Cara Menjalankan

```bash
flutter pub get
flutter run
```

---

## ⚠️ Konfigurasi API

Sesuaikan base URL:

```dart
const String baseUrl = "https://your-api-url/api";
```


---

## ⭐ Catatan

Project ini dikembangkan sebagai sistem tracking bus berbasis mobile dengan integrasi backend Laravel.
