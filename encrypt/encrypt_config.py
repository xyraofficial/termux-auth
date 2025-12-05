#!/usr/bin/env python3
import json
import base64
import os
import sys
import hashlib

try:
    from cryptography.fernet import Fernet
    from cryptography.hazmat.primitives import hashes
    from cryptography.hazmat.primitives.kdf.pbkdf2 import PBKDF2HMAC
    HAS_CRYPTO = True
except ImportError:
    HAS_CRYPTO = False

SALT = b"TermuxAuth2024SecureSalt"
PASSPHRASE = b"Tx@uth#Pr0t3ct3d$K3y!2024"

def derive_key(passphrase, salt):
    if HAS_CRYPTO:
        kdf = PBKDF2HMAC(
            algorithm=hashes.SHA256(),
            length=32,
            salt=salt,
            iterations=100000,
        )
        key = base64.urlsafe_b64encode(kdf.derive(passphrase))
        return key
    else:
        key = hashlib.pbkdf2_hmac('sha256', passphrase, salt, 100000)
        return base64.urlsafe_b64encode(key)

def encrypt_data(data, key):
    if HAS_CRYPTO:
        f = Fernet(key)
        return f.encrypt(data)
    else:
        key_bytes = base64.urlsafe_b64decode(key)
        result = bytearray()
        for i, byte in enumerate(data):
            result.append(byte ^ key_bytes[i % len(key_bytes)])
        return base64.urlsafe_b64encode(bytes(result))

def encrypt_config(config_path, output_path):
    if not os.path.exists(config_path):
        print(f"\n  \033[91m[!]\033[0m File {config_path} tidak ditemukan!")
        return False
    
    try:
        with open(config_path, 'r') as f:
            config_data = json.load(f)
        
        json_str = json.dumps(config_data, separators=(',', ':'))
        json_bytes = json_str.encode('utf-8')
        
        key = derive_key(PASSPHRASE, SALT)
        encrypted = encrypt_data(json_bytes, key)
        
        header = b"TXAUTH02" if HAS_CRYPTO else b"TXAUTH01"
        final_data = header + encrypted
        
        with open(output_path, 'wb') as f:
            f.write(final_data)
        
        method = "AES-Fernet" if HAS_CRYPTO else "PBKDF2-XOR"
        print(f"\n  \033[92m[✓]\033[0m Config berhasil dienkripsi!")
        print(f"  \033[96m[i]\033[0m Metode: {method}")
        print(f"  \033[96m[i]\033[0m Output: {output_path}")
        print(f"\n  \033[93m[!]\033[0m PENTING:")
        print(f"      1. Copy {output_path} ke folder run/")
        print(f"      2. HAPUS config.json dari folder run/")
        print()
        return True
        
    except json.JSONDecodeError:
        print(f"\n  \033[91m[!]\033[0m File {config_path} bukan JSON valid!")
        return False
    except Exception as e:
        print(f"\n  \033[91m[!]\033[0m Error: {e}")
        return False

def main():
    config_input = "config.json"
    config_output = "config.enc"
    
    if len(sys.argv) > 1:
        config_input = sys.argv[1]
    if len(sys.argv) > 2:
        config_output = sys.argv[2]
    
    print("\n╔════════════════════════════════════════╗")
    print("║     CONFIG ENCRYPTION TOOL v1.0        ║")
    print("╚════════════════════════════════════════╝")
    
    if not HAS_CRYPTO:
        print("\n  \033[93m[!]\033[0m Library 'cryptography' tidak ada")
        if os.path.exists("/data/data/com.termux") or "com.termux" in os.environ.get("PREFIX", ""):
            print("  \033[93m[i]\033[0m Di Termux install: pkg install python-cryptography")
        else:
            print("  \033[93m[i]\033[0m Install: pip install cryptography")
        print("  \033[93m[i]\033[0m Menggunakan fallback encryption...")
    
    encrypt_config(config_input, config_output)

if __name__ == "__main__":
    main()
