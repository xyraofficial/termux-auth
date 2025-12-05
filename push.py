import os
import subprocess

TOKEN_FILE = ".token"
BRANCH = "main"
GITHUB_USER = "xyraofficial"
REPO_NAME = "termux-auth"

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

    token = open(TOKEN_FILE).read().strip()

    if not token.startswith("ghp_"):
        print("[!] Token GitHub tidak valid!")
        exit()

    return token

def main():
    token = load_token()
    auth_repo = f"https://{token}@github.com/{GITHUB_USER}/{REPO_NAME}.git"

    print("[*] Auto set git user...")
    run('git config --global user.name "xyraofficial"', ignore=True)
    run('git config --global user.email "xyra@users.noreply.github.com"', ignore=True)

    print("[*] Cek repo...")
    if not os.path.exists(".git"):
        print("[*] .git belum ada → git init")
        run("git init")

    print("[*] Cek remote origin...")
    remotes = subprocess.run("git remote", shell=True, capture_output=True, text=True).stdout

    if "origin" not in remotes:
        print("[*] Remote origin belum ada → menambahkan")
        run(f"git remote add origin {auth_repo}")
    else:
        print("[*] Remote origin ada → update URL")
        run(f"git remote set-url origin {auth_repo}", ignore=True)

    print("[*] Git pull agar tidak terjadi rejected push...")
    run(f"git pull origin {BRANCH} --allow-unrelated-histories", ignore=True)

    print("[*] Tambah semua file...")
    run("git add .")

    print("[*] Commit...")
    run('git commit -m "Auto push from Termux"', ignore=True)

    print("[*] Push ke GitHub...")
    run(f"git push -u origin {BRANCH}", ignore=False)

    print("\n[SUKSES] Semua file berhasil diupload ke GitHub!")

if __name__ == "__main__":
    main()