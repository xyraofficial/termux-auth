#!/usr/bin/env python3
import sys
import os
import glob
import platform
import subprocess

REQUIRED_PACKAGES = ["requests", "cryptography", "tqdm", "tabulate", "rich", "simple-term-menu"]

def is_termux():
    return os.path.exists("/data/data/com.termux") or "com.termux" in os.environ.get("PREFIX", "")

def check_and_install_dependencies():
    missing = []
    for pkg in REQUIRED_PACKAGES:
        try:
            __import__(pkg)
        except ImportError:
            missing.append(pkg)
    
    if missing:
        print("\n  \033[93m[*]\033[0m Mengecek dependensi...")
        in_termux = is_termux()
        
        for pkg in missing:
            if pkg == "cryptography" and in_termux:
                print(f"  \033[93m[!]\033[0m Package '{pkg}' tidak ditemukan di Termux!")
                print(f"  \033[96m[i]\033[0m Install dengan: pkg install python-cryptography")
                print(f"  \033[93m[i]\033[0m Jangan gunakan pip untuk cryptography di Termux")
                print()
                return False
            
            print(f"  \033[96m[+]\033[0m Installing {pkg}...")
            try:
                subprocess.check_call(
                    [sys.executable, "-m", "pip", "install", pkg, "-q"],
                    stdout=subprocess.DEVNULL,
                    stderr=subprocess.DEVNULL
                )
                print(f"  \033[92m[✓]\033[0m {pkg} berhasil diinstall!")
            except subprocess.CalledProcessError:
                print(f"  \033[91m[!]\033[0m Gagal install {pkg}")
                if pkg == "cryptography" and in_termux:
                    print(f"  \033[93m[i]\033[0m Di Termux gunakan: pkg install python-cryptography")
                else:
                    print(f"  \033[93m[i]\033[0m Coba manual: pip install {pkg}")
                return False
        print()
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
                    print("\n  \033[91m[!]\033[0m Config butuh library cryptography!")
                    if is_termux():
                        print("  \033[93m[i]\033[0m Di Termux jalankan: pkg install python-cryptography")
                    else:
                        print("  \033[93m[i]\033[0m Jalankan: pip install cryptography")
                    print()
                    return False
        except:
            pass
        return True
    if os.path.exists("config.json"):
        print("\n  \033[91m[!]\033[0m config.json tidak aman!")
        print("  \033[93m[i]\033[0m Gunakan config.enc yang terenkripsi")
        print()
        return False
    print("\n  \033[91m[!]\033[0m File konfigurasi tidak ditemukan!")
    print("  \033[93m[i]\033[0m Butuh file config.enc")
    print()
    return False

def main():
    if not check_and_install_dependencies():
        return
    
    so_file = find_so_file()
    
    if not so_file:
        print("\n  \033[91m[!]\033[0m File .so tidak ditemukan!")
        print("  \033[93m[i]\033[0m Minta file termux_auth_lib*.so dari developer")
        print()
        return
    
    machine = platform.machine().lower()
    is_arm = machine in ["aarch64", "arm", "armv7l", "armv8l"]
    is_x86_so = "x86_64" in so_file or "x86-64" in so_file
    
    if is_arm and is_x86_so:
        print("\n  \033[91m[!]\033[0m File .so tidak cocok dengan device!")
        print(f"  \033[93m[i]\033[0m Device kamu : {machine} (ARM/Android)")
        print(f"  \033[93m[i]\033[0m File .so    : x86_64 (PC/Linux)")
        print()
        print("  \033[96m[*]\033[0m Solusi:")
        print("      Minta file .so versi ARM dari developer,")
        print("      atau kompilasi sendiri dengan folder encrypt/")
        print()
        return
    
    if not check_config():
        return
    
    try:
        from termux_auth_lib import run_main
        run_main()
    except ImportError as e:
        err = str(e).lower()
        if "elf" in err or "architecture" in err or "exec format" in err:
            print("\n  \033[91m[!]\033[0m Arsitektur tidak cocok!")
            print(f"  \033[93m[i]\033[0m Device: {machine}")
            print("  \033[93m[i]\033[0m Minta file .so yang sesuai dari developer")
        else:
            print(f"\n  \033[91m[!]\033[0m Gagal load module!")
            print(f"  \033[93m[i]\033[0m Error: {e}")
        print()

if __name__ == "__main__":
    main()
