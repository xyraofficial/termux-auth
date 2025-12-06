#!/usr/bin/env python3
import sys
import os
import glob
import platform
import subprocess
import time

REQUIRED_PACKAGES = ["requests", "cryptography", "tqdm", "tabulate", "rich", "simple-term-menu"]

R = '\033[0m'
B = '\033[1m'
D = '\033[2m'
RD = '\033[91m'
GR = '\033[92m'
YL = '\033[93m'
BL = '\033[94m'
MG = '\033[95m'
CY = '\033[96m'

def clear():
    os.system('clear' if os.name == 'posix' else 'cls')

def is_termux():
    return os.path.exists("/data/data/com.termux") or "com.termux" in os.environ.get("PREFIX", "")

def check_internet():
    try:
        import socket
        socket.setdefaulttimeout(5)
        socket.socket(socket.AF_INET, socket.SOCK_STREAM).connect(("8.8.8.8", 53))
        return True
    except:
        return False

def show_loading_bar(text, steps=20, delay=0.05):
    bar_chars = "░▒▓█"
    for i in range(steps + 1):
        progress = int((i / steps) * 30)
        bar = "█" * progress + "░" * (30 - progress)
        percent = int((i / steps) * 100)
        print(f"\r  {CY}[{bar}]{R} {percent}% - {text}", end="", flush=True)
        time.sleep(delay)
    print()

def show_system_loading():
    clear()
    print()
    print(f"  {MG}{B}╭─────────────────────────────────────╮{R}")
    print(f"  {MG}{B}│{R}     {CY}★{R} {B}TERMUX AUTH SYSTEM{R} {CY}★{R}        {MG}{B}│{R}")
    print(f"  {MG}{B}│{R}         {D}by XyraOfficial{R}           {MG}{B}│{R}")
    print(f"  {MG}{B}╰─────────────────────────────────────╯{R}")
    print()
    
    print(f"  {YL}[•]{R} Memuat System...")
    time.sleep(0.3)
    
    print(f"  {CY}[•]{R} Mengecek koneksi internet...")
    time.sleep(0.5)
    
    if not check_internet():
        print()
        print(f"  {RD}╭─────────────────────────────────────╮{R}")
        print(f"  {RD}│{R}  {RD}⚠  PERINGATAN: OFFLINE MODE  ⚠{R}   {RD}│{R}")
        print(f"  {RD}╰─────────────────────────────────────╯{R}")
        print()
        print(f"  {YL}[!]{R} Tidak ada koneksi internet!")
        print(f"  {YL}[!]{R} Beberapa fitur mungkin tidak berfungsi:")
        print(f"      {D}• Login/Signup membutuhkan internet{R}")
        print(f"      {D}• Pengiriman OTP membutuhkan internet{R}")
        print(f"      {D}• Verifikasi akun membutuhkan internet{R}")
        print()
        print(f"  {CY}[?]{R} Hubungkan ke internet dan coba lagi")
        print()
        confirm = input(f"  {YL}[?]{R} Lanjutkan offline? (y/n): ").strip().lower()
        if confirm != 'y':
            print(f"\n  {GR}[✓]{R} Sampai jumpa!\n")
            return False
        print()
    else:
        print(f"  {GR}[✓]{R} Koneksi internet: {GR}Online{R}")
    
    print(f"  {CY}[•]{R} Memuat modul...")
    time.sleep(0.3)
    
    return True

def check_and_install_dependencies():
    missing = []
    for pkg in REQUIRED_PACKAGES:
        pkg_import = pkg.replace("-", "_")
        try:
            __import__(pkg_import)
        except ImportError:
            missing.append(pkg)
    
    if missing:
        print(f"\n  {YL}[•]{R} Menginstall dependensi...")
        in_termux = is_termux()
        
        for pkg in missing:
            if pkg == "cryptography" and in_termux:
                print(f"\n  {RD}[✗]{R} Package '{pkg}' tidak ditemukan!")
                print(f"  {CY}[i]{R} Install dengan: {CY}pkg install python-cryptography{R}")
                print(f"  {YL}[!]{R} Jangan gunakan pip untuk cryptography di Termux")
                print()
                return False
            
            print(f"  {CY}[+]{R} Installing {pkg}...", end=" ", flush=True)
            try:
                subprocess.check_call(
                    [sys.executable, "-m", "pip", "install", pkg, "-q"],
                    stdout=subprocess.DEVNULL,
                    stderr=subprocess.DEVNULL
                )
                print(f"{GR}✓{R}")
            except subprocess.CalledProcessError:
                print(f"{RD}✗{R}")
                print(f"\n  {RD}[!]{R} Gagal install {pkg}")
                if pkg == "cryptography" and in_termux:
                    print(f"  {YL}[i]{R} Di Termux gunakan: {CY}pkg install python-cryptography{R}")
                else:
                    print(f"  {YL}[i]{R} Coba manual: {CY}pip install {pkg}{R}")
                return False
        
        print(f"\n  {GR}[✓]{R} Semua dependensi terinstall!")
        print()
    else:
        print(f"  {GR}[✓]{R} Dependensi: {GR}Lengkap{R}")
    
    return True

def find_so_file():
    files = glob.glob("termux_auth_lib*.so")
    return files[0] if files else None

def check_config():
    if os.path.exists("config.enc"):
        try:
            with open("config.enc", "rb") as f:
                header = f.read(8)
            if header == b"TXAUTH02":
                try:
                    import cryptography
                except ImportError:
                    print(f"\n  {RD}[!]{R} Config butuh library cryptography!")
                    if is_termux():
                        print(f"  {YL}[i]{R} Di Termux jalankan: {CY}pkg install python-cryptography{R}")
                    else:
                        print(f"  {YL}[i]{R} Jalankan: {CY}pip install cryptography{R}")
                    print()
                    return False
            print(f"  {GR}[✓]{R} Konfigurasi: {GR}Terenkripsi{R}")
        except:
            pass
        return True
    if os.path.exists("config.json"):
        print(f"\n  {RD}[!]{R} config.json tidak aman!")
        print(f"  {YL}[i]{R} Gunakan config.enc yang terenkripsi")
        print()
        return False
    print(f"\n  {RD}[!]{R} File konfigurasi tidak ditemukan!")
    print(f"  {YL}[i]{R} Butuh file config.enc")
    print()
    return False

def check_so_file():
    so_file = find_so_file()
    
    if not so_file:
        print(f"\n  {RD}[!]{R} File .so tidak ditemukan!")
        print(f"  {YL}[i]{R} Minta file termux_auth_lib*.so dari developer")
        print()
        return None
    
    machine = platform.machine().lower()
    is_arm = machine in ["aarch64", "arm", "armv7l", "armv8l"]
    is_x86_so = "x86_64" in so_file or "x86-64" in so_file
    
    if is_arm and is_x86_so:
        print(f"\n  {RD}[!]{R} File .so tidak cocok dengan device!")
        print(f"  {YL}[i]{R} Device kamu : {CY}{machine}{R} (ARM/Android)")
        print(f"  {YL}[i]{R} File .so    : {CY}x86_64{R} (PC/Linux)")
        print()
        print(f"  {CY}[*]{R} Solusi:")
        print(f"      Minta file .so versi ARM dari developer,")
        print(f"      atau kompilasi sendiri dengan folder encrypt/")
        print()
        return None
    
    print(f"  {GR}[✓]{R} Module: {GR}Tersedia{R}")
    return so_file

def main():
    if not show_system_loading():
        return
    
    if not check_and_install_dependencies():
        return
    
    so_file = check_so_file()
    if not so_file:
        return
    
    if not check_config():
        return
    
    print()
    print(f"  {GR}╭─────────────────────────────────────╮{R}")
    print(f"  {GR}│{R}  {GR}✓{R} {B}System Ready - Starting...{R}     {GR}│{R}")
    print(f"  {GR}╰─────────────────────────────────────╯{R}")
    time.sleep(1)
    
    try:
        from termux_auth_lib import run_main
        run_main()
    except ImportError as e:
        err = str(e).lower()
        if "elf" in err or "architecture" in err or "exec format" in err:
            print(f"\n  {RD}[!]{R} Arsitektur tidak cocok!")
            print(f"  {YL}[i]{R} Device: {CY}{platform.machine()}{R}")
            print(f"  {YL}[i]{R} Minta file .so yang sesuai dari developer")
        else:
            print(f"\n  {RD}[!]{R} Gagal load module!")
            print(f"  {YL}[i]{R} Error: {e}")
        print()

if __name__ == "__main__":
    main()
