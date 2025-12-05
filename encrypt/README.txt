╔══════════════════════════════════════════════════════════════╗
║                   FOLDER ENCRYPT                              ║
║           File untuk kompilasi ke .so                         ║
╚══════════════════════════════════════════════════════════════╝

[DESKRIPSI]
  Folder ini berisi source code dan script untuk mengkompilasi
  aplikasi menjadi file .so yang terproteksi.

═══════════════════════════════════════════════════════════════

[FILE DI FOLDER INI]

  ├── termux_auth_core.pyx  # Source code Cython
  ├── setup.py              # Konfigurasi kompilasi
  ├── setup_termux.sh       # Script setup lengkap Termux
  ├── build_so.sh           # Script kompilasi cepat
  ├── run.py                # Launcher (akan dicopy ke run/)
  └── config.json           # Template konfigurasi

═══════════════════════════════════════════════════════════════

[CARA KOMPILASI DI TERMUX]

  1. Copy folder ini ke Termux
  2. Jalankan:
     $ bash setup_termux.sh

  3. File .so akan otomatis dipindahkan ke folder ../run/

═══════════════════════════════════════════════════════════════

[KOMPILASI MANUAL]

  1. Install dependencies:
     $ pkg install python clang make
     $ pip install requests cython setuptools

  2. Kompilasi:
     $ python setup.py build_ext --inplace

  3. Pindahkan hasil ke folder run:
     $ mv termux_auth_lib*.so ../run/

  4. Cleanup:
     $ rm -f termux_auth_core.c
     $ rm -rf build/

═══════════════════════════════════════════════════════════════

[CATATAN]

  - File .pyx adalah source code, JANGAN didistribusikan!
  - Setelah kompilasi, hapus file .pyx untuk keamanan
  - File .so spesifik untuk arsitektur device

═══════════════════════════════════════════════════════════════
