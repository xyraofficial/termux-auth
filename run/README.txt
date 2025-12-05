╔══════════════════════════════════════════════════════════════╗
║            TERMUX AUTH SYSTEM v1.0                            ║
║         Sistem Autentikasi dengan OTP Email                   ║
╚══════════════════════════════════════════════════════════════╝

[FITUR]
  - Signup dengan verifikasi OTP email
  - Login dengan Supabase
  - Template email OTP yang keren
  - Kode OTP berlaku 5 menit
  - 3x percobaan input OTP
  - Auto-install dependensi
  - Konfigurasi terenkripsi (aman)

═══════════════════════════════════════════════════════════════

[CARA INSTALL DI TERMUX]

  1. Update Termux:
     $ pkg update && pkg upgrade

  2. Install Python:
     $ pkg install python

  3. Jalankan (dependensi auto-install):
     $ python run.py

═══════════════════════════════════════════════════════════════

[KONFIGURASI]

  Konfigurasi disimpan dalam file terenkripsi:
  config.enc (terenkripsi, aman untuk distribusi)

  File config sudah dikonfigurasi oleh developer.
  Jangan mengedit atau menghapus config.enc!

═══════════════════════════════════════════════════════════════

[CARA PENGGUNAAN]

  MENU UTAMA:
  1. Signup  - Daftar akun baru
  2. Login   - Masuk ke akun
  3. Resend  - Kirim ulang OTP
  4. Reset   - Lupa password
  5. Exit    - Keluar

═══════════════════════════════════════════════════════════════

[TROUBLESHOOTING]

  "File .so tidak cocok dengan device"
  → File .so harus sesuai arsitektur (ARM untuk Termux)
  → Minta file .so versi ARM dari developer

  "File .so tidak ditemukan"
  → Pastikan file termux_auth_lib*.so ada

  "File config tidak ditemukan"
  → Pastikan config.enc ada di folder yang sama

  "OTP expired"
  → Kode hanya berlaku 5 menit, kirim ulang

═══════════════════════════════════════════════════════════════

[FILE YANG DIBUTUHKAN]

  ├── run.py                              (launcher)
  ├── termux_auth_lib*-aarch64*.so        (binary ARM)
  └── config.enc                          (config terenkripsi)

  PENTING: File .so harus versi ARM untuk Termux!

═══════════════════════════════════════════════════════════════

KONTAK: xyraofficialsup@gmail.com

═══════════════════════════════════════════════════════════════
