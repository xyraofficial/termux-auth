#!/usr/bin/env python3
import sys
import os
import glob
import platform
import subprocess
import time

REQUIRED_PACKAGES = ["requests", "cryptography", "tqdm", "tabulate", "rich", "simple-term-menu", "fake-useragent"]

R = '\033[0m'
B = '\033[1m'
D = '\033[2m'
RD = '\033[91m'
GR = '\033[92m'
YL = '\033[93m'
BL = '\033[94m'
MG = '\033[95m'
CY = '\033[96m'

BANNER = f"""{CY}
╭────────────────────────────────────────────────────────────╮
│                                                            │
│     {GR}████████╗███████╗██████╗ ███╗   ███╗██╗   ██╗██╗  ██╗{CY}  │
│     {GR}╚══██╔══╝██╔════╝██╔══██╗████╗ ████║██║   ██║╚██╗██╔╝{CY}  │
│        {GR}██║   █████╗  ██████╔╝██╔████╔██║██║   ██║ ╚███╔╝{CY}   │
│        {GR}██║   ██╔══╝  ██╔══██╗██║╚██╔╝██║██║   ██║ ██╔██╗{CY}   │
│        {GR}██║   ███████╗██║  ██║██║ ╚═╝ ██║╚██████╔╝██╔╝ ██╗{CY}  │
│        {GR}╚═╝   ╚══════╝╚═╝  ╚═╝╚═╝     ╚═╝ ╚═════╝ ╚═╝  ╚═╝{CY}  │
│                                                            │
│            {B}{MG}A U T H   S Y S T E M{R}{CY}                           │
│              {D}by XyraOfficial{R}{CY}                               │
│                                                            │
╰────────────────────────────────────────────────────────────╯{R}
"""

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

def install_package(pkg):
    try:
        subprocess.check_call(
            [sys.executable, "-m", "pip", "install", pkg, "-q"],
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL
        )
        return True
    except:
        return False

def check_missing_packages():
    missing = []
    for pkg in REQUIRED_PACKAGES:
        pkg_import = pkg.replace("-", "_")
        try:
            __import__(pkg_import)
        except ImportError:
            missing.append(pkg)
    return missing

def show_loading_screen():
    clear()
    print(BANNER)
    
    missing_packages = check_missing_packages()
    
    if missing_packages:
        print(f"  {YL}[!]{R} Package yang dibutuhkan tidak lengkap")
        print(f"  {CY}[*]{R} Menginstall: {', '.join(missing_packages)}\n")
        
        in_termux = is_termux()
        for pkg in missing_packages:
            if pkg == "cryptography" and in_termux:
                print(f"\n  {RD}[✗]{R} Package '{pkg}' tidak ditemukan!")
                print(f"  {CY}[i]{R} Install dengan: {CY}pkg install python-cryptography{R}")
                print(f"  {YL}[!]{R} Jangan gunakan pip untuk cryptography di Termux\n")
                return False
            
            print(f"  {CY}[+]{R} Installing {pkg}...", end=" ", flush=True)
            if install_package(pkg):
                print(f"{GR}✓{R}")
            else:
                print(f"{RD}✗{R}")
                print(f"\n  {RD}[!]{R} Gagal install {pkg}")
                if pkg == "cryptography" and in_termux:
                    print(f"  {YL}[i]{R} Di Termux gunakan: {CY}pkg install python-cryptography{R}")
                else:
                    print(f"  {YL}[i]{R} Coba manual: {CY}pip install {pkg}{R}")
                return False
        print()
    
    try:
        from tqdm import tqdm
    except ImportError:
        print(f"  {RD}[!]{R} tqdm tidak tersedia untuk loading bar")
        return False
    
    online = False
    so_exists = False
    config_exists = False
    
    print()
    for i in tqdm(range(40), desc=f"  {CY}Memuat sistem{R}", 
                  bar_format="{desc}: {percentage:3.0f}%|{bar}| {n_fmt}/{total_fmt}",
                  colour="green", ncols=60):
        
        if i == 5:
            pass
        elif i == 15:
            online = check_internet()
        elif i == 25:
            so_exists = find_so_file() is not None
        elif i == 35:
            config_exists = os.path.exists("config.enc")
        
        time.sleep(0.05)
    
    print()
    
    if not online:
        print(f"  {RD}╭─────────────────────────────────────────╮{R}")
        print(f"  {RD}│{R}   {RD}⚠  PERINGATAN: TIDAK ADA INTERNET  ⚠{R}  {RD}│{R}")
        print(f"  {RD}╰─────────────────────────────────────────╯{R}")
        print()
        print(f"  {YL}[!]{R} Koneksi internet tidak tersedia!")
        print(f"  {YL}[!]{R} Fitur yang membutuhkan internet:")
        print(f"      {D}• Login/Signup{R}")
        print(f"      {D}• Pengiriman OTP{R}")
        print(f"      {D}• Verifikasi akun{R}")
        print()
        confirm = input(f"  {YL}[?]{R} Lanjutkan mode offline? (y/n): ").strip().lower()
        if confirm != 'y':
            print(f"\n  {GR}[✓]{R} Sampai jumpa!\n")
            return False
        print()
    else:
        print(f"  {GR}[✓]{R} Koneksi    : {GR}Online{R}")
    
    return True

def find_so_file():
    files = glob.glob("termux_auth_lib*.so")
    return files[0] if files else None

def check_so_file():
    so_file = find_so_file()
    
    if not so_file:
        print(f"  {RD}[✗]{R} Module     : {RD}Tidak ditemukan{R}")
        print(f"\n  {YL}[i]{R} Minta file termux_auth_lib*.so dari developer\n")
        return None
    
    machine = platform.machine().lower()
    is_arm = machine in ["aarch64", "arm", "armv7l", "armv8l"]
    is_x86_so = "x86_64" in so_file or "x86-64" in so_file
    
    if is_arm and is_x86_so:
        print(f"  {RD}[✗]{R} Module     : {RD}Arsitektur tidak cocok{R}")
        print(f"\n  {YL}[i]{R} Device kamu : {CY}{machine}{R} (ARM/Android)")
        print(f"  {YL}[i]{R} File .so    : {CY}x86_64{R} (PC/Linux)")
        print(f"\n  {CY}[*]{R} Solusi: Minta file .so versi ARM dari developer\n")
        return None
    
    print(f"  {GR}[✓]{R} Module     : {GR}Tersedia{R}")
    return so_file

def check_config():
    if os.path.exists("config.enc"):
        try:
            with open("config.enc", "rb") as f:
                header = f.read(8)
            if header == b"TXAUTH02":
                try:
                    import cryptography
                except ImportError:
                    print(f"  {RD}[✗]{R} Config     : {RD}Butuh cryptography{R}")
                    if is_termux():
                        print(f"\n  {YL}[i]{R} Jalankan: {CY}pkg install python-cryptography{R}\n")
                    else:
                        print(f"\n  {YL}[i]{R} Jalankan: {CY}pip install cryptography{R}\n")
                    return False
            print(f"  {GR}[✓]{R} Config     : {GR}Terenkripsi{R}")
        except:
            pass
        return True
    
    if os.path.exists("config.json"):
        print(f"  {RD}[✗]{R} Config     : {RD}Tidak aman (config.json){R}")
        print(f"\n  {YL}[i]{R} Gunakan config.enc yang terenkripsi\n")
        return False
    
    print(f"  {RD}[✗]{R} Config     : {RD}Tidak ditemukan{R}")
    print(f"\n  {YL}[i]{R} Butuh file config.enc\n")
    return False

def main():
    if not show_loading_screen():
        return
    
    so_file = check_so_file()
    if not so_file:
        return
    
    if not check_config():
        return
    
    print()
    print(f"  {GR}╭─────────────────────────────────────────╮{R}")
    print(f"  {GR}│{R}    {GR}✓{R} {B}System Ready - Memulai...{R}        {GR}│{R}")
    print(f"  {GR}╰─────────────────────────────────────────╯{R}")
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
