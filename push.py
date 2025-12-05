import os
import subprocess

TOKEN_FILE = ".token"
BRANCH = "main"
USER = "xyraofficial"
REPO = "termux-auth"

def run(cmd, ignore=False):
    print(f"[CMD] {cmd}")
    try:
        subprocess.run(cmd, shell=True, check=True)
    except:
        if not ignore:
            raise

def load_token():
    if not os.path.exists(TOKEN_FILE):
        print("[!] File .token tidak ditemukan!")
        exit()
    return open(TOKEN_FILE).read().strip()

def main():
    token = load_token()
    auth_repo = f"https://{token}@github.com/{USER}/{REPO}.git"

    # git identity
    run('git config --global user.name "xyraofficial"', ignore=True)
    run('git config --global user.email "xyra@users.noreply.github.com"', ignore=True)

    # init repo
    if not os.path.exists(".git"):
        run("git init")

    # remote origin
    remotes = subprocess.run("git remote", shell=True, capture_output=True, text=True).stdout
    if "origin" not in remotes:
        run(f"git remote add origin {auth_repo}")
    else:
        run(f"git remote set-url origin {auth_repo}", ignore=True)

    print("[*] Tarik update dari GitHub (auto merge)...")

    # pull pertama
    run(f"git pull origin {BRANCH} --allow-unrelated-histories", ignore=True)

    # merge otomatis dengan origin/main
    run(f"git merge origin/{BRANCH}", ignore=True)

    # rebase off (biar aman)
    run("git config pull.rebase false", ignore=True)

    # tambah semua file
    run("git add .")

    # commit
    run('git commit -m "Auto push from Termux"', ignore=True)

    print("[*] Push ke GitHub...")
    # coba push normal
    try:
        run(f"git push -u origin {BRANCH}", ignore=False)
    except:
        print("[!] Push gagal (non-fast-forward). Auto attempt merge fix...")
        
        # AUTO FIX
        run(f"git pull origin {BRANCH} --allow-unrelated-histories", ignore=True)
        run(f"git merge origin/{BRANCH}", ignore=True)

        print("[*] Mencoba push lagi...")
        try:
            run(f"git push -u origin {BRANCH}", ignore=False)
        except:
            print("[!] Masih gagal.")
            print(">>> Solusi: FORCE PUSH")
            print(">>> Kamu mau aku buat versi FORCE PUSH otomatis? (y/n)")
            return

    print("\n[SUKSES] Semua file berhasil diupload ke GitHub!")

if __name__ == "__main__":
    main()