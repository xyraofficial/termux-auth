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

def install_missing_packages():
    missing = []
    for pkg in REQUIRED_PACKAGES:
        pkg_import = pkg.replace("-", "_")
        try:
            __import__(pkg_import)
        except ImportError:
            missing.append(pkg)
    
    if not missing:
        return True
    
    in_termux = is_termux()
    for pkg in missing:
        if pkg == "cryptography" and in_termux:
            return False
        try:
            subprocess.check_call(
                [sys.executable, "-m", "pip", "install", pkg, "-q"],
                stdout=subprocess.DEVNULL,
                stderr=subprocess.DEVNULL
            )
        except:
            return False
    return True

def find_so_file():
    files = glob.glob("termux_auth_lib*.so")
    return files[0] if files else None

def show_loading_screen():
    clear()
    print(BANNER)
    
    if not install_missing_packages():
        print(f"\n  {RD}[!]{R} Gagal install dependensi!")
        if is_termux():
            print(f"  {YL}[i]{R} Jalankan: {CY}pkg install python-cryptography{R}\n")
        return False
    
    try:
        from tqdm import tqdm
    except ImportError:
        print(f"  {RD}[!]{R} tqdm tidak tersedia\n")
        return False
    
    online = False
    so_file = None
    config_ok = False
    
    for _ in tqdm(range(40), desc=f"  Cek Koneksi", 
                  bar_format="{desc}: {percentage:3.0f}%|{bar}| {n}/{total}",
                  ncols=50, leave=True):
        time.sleep(0.02)
    online = check_internet()
    print(f"  {GR}[OK]{R}" if online else f"  {RD}[OFFLINE]{R}")
    
    for _ in tqdm(range(40), desc=f"  Cek Module", 
                  bar_format="{desc}: {percentage:3.0f}%|{bar}| {n}/{total}",
                  ncols=50, leave=True):
        time.sleep(0.02)
    so_file = find_so_file()
    print(f"  {GR}[OK]{R}" if so_file else f"  {RD}[NOT FOUND]{R}")
    
    for _ in tqdm(range(40), desc=f"  Cek Config", 
                  bar_format="{desc}: {percentage:3.0f}%|{bar}| {n}/{total}",
                  ncols=50, leave=True):
        time.sleep(0.02)
    config_ok = os.path.exists("config.enc")
    print(f"  {GR}[OK]{R}" if config_ok else f"  {RD}[NOT FOUND]{R}")
    
    for _ in tqdm(range(40), desc=f"  Memuat Config", 
                  bar_format="{desc}: {percentage:3.0f}%|{bar}| {n}/{total}",
                  ncols=50, leave=True):
        time.sleep(0.02)
    print(f"  {GR}[OK]{R}")
    
    for _ in tqdm(range(40), desc=f"  Mengambil IP", 
                  bar_format="{desc}: {percentage:3.0f}%|{bar}| {n}/{total}",
                  ncols=50, leave=True):
        time.sleep(0.02)
    print(f"  {GR}[OK]{R}")
    
    print()
    
    if not online:
        print(f"\n  {RD}╭─────────────────────────────────────────╮{R}")
        print(f"  {RD}│{R}   {RD}  PERINGATAN: TIDAK ADA INTERNET    {R}  {RD}│{R}")
        print(f"  {RD}╰─────────────────────────────────────────╯{R}")
        print(f"\n  {YL}[!]{R} Beberapa fitur tidak akan berfungsi")
        print(f"      {D}* Login/Signup * Kirim OTP * Verifikasi{R}\n")
        confirm = input(f"  {YL}[?]{R} Lanjutkan offline? (y/n): ").strip().lower()
        if confirm != 'y':
            print(f"\n  {GR}[v]{R} Sampai jumpa!\n")
            return False
        print()
    
    if not so_file:
        print(f"  {RD}[x]{R} Module tidak ditemukan!")
        print(f"  {YL}[i]{R} Minta file termux_auth_lib*.so dari developer\n")
        return False
    
    machine = platform.machine().lower()
    is_arm = machine in ["aarch64", "arm", "armv7l", "armv8l"]
    is_x86_so = "x86_64" in so_file or "x86-64" in so_file
    
    if is_arm and is_x86_so:
        print(f"  {RD}[x]{R} Arsitektur tidak cocok!")
        print(f"  {YL}[i]{R} Device: {CY}{machine}{R} | File: {CY}x86_64{R}\n")
        return False
    
    if not config_ok:
        print(f"  {RD}[x]{R} Config tidak ditemukan!")
        print(f"  {YL}[i]{R} Butuh file config.enc\n")
        return False
    
    print(f"  {GR}╭─────────────────────────────────────────╮{R}")
    print(f"  {GR}│{R}      {GR}v{R} {B}System Ready{R}                      {GR}│{R}")
    print(f"  {GR}╰─────────────────────────────────────────╯{R}")
    time.sleep(0.8)
    
    return True

def main():
    if not show_loading_screen():
        return
    
    try:
        from termux_auth_lib import run_main
        run_main()
    except ImportError as e:
        err = str(e).lower()
        if "elf" in err or "architecture" in err or "exec format" in err:
            print(f"\n  {RD}[!]{R} Arsitektur tidak cocok!")
            print(f"  {YL}[i]{R} Device: {CY}{platform.machine()}{R}")
        else:
            print(f"\n  {RD}[!]{R} Error: {e}")
        print()

if __name__ == "__main__":
    main()
