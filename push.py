import os
import subprocess

# Ambil token dari file .token
def get_token():
    if not os.path.exists(".token"):
        print("[!] File .token tidak ditemukan!")
        exit()
    with open(".token", "r") as f:
        return f.read().strip()

# Jalankan command
def run(cmd):
    print(f"[CMD] {cmd}")
    proses = subprocess.run(cmd, shell=True)
    if proses.returncode != 0:
        print("[!] Error saat menjalankan command:", cmd)
        exit()

def main():
    token = get_token()

    # Username GitHub kamu
    username = "xyraofficial"
    repo = "termux-auth"

    print("[+] Mengatur remote dengan token...")
    run(f'git remote remove origin 2>/dev/null || true')
    run(f'git remote add origin https://{token}@github.com/{username}/{repo}.git')

    print("[+] Git add .")
    run("git add .")

    print("[+] Commit...")
    run('git commit -m "Auto commit by push.py" || true')

    print("[+] FORCE PUSH ke GitHub...")
    run("git branch -M main")
    run("git push -u origin main --force")

    print("\n[✓] Selesai! Semua file lokal berhasil di-push ke GitHub (FORCE MODE).")

if __name__ == "__main__":
    main()