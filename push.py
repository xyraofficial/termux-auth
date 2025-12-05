import os
import subprocess

def get_token():
    if not os.path.exists(".token"):
        print("[!] File .token tidak ditemukan!")
        exit()
    return open(".token").read().strip()

def run(cmd):
    print(f"[CMD] {cmd}")
    p = subprocess.run(cmd, shell=True)
    if p.returncode != 0:
        print("[!] Error:", cmd)
        exit()

def main():
    # Auto tambah .token ke .gitignore
    if not os.path.exists(".gitignore"):
        open(".gitignore", "w").write(".token\n")
    else:
        with open(".gitignore", "r+") as f:
            lines = f.read()
            if ".token" not in lines:
                f.write("\n.token\n")

    token = get_token()
    username = "xyraofficial"
    repo = "termux-auth"

    run("git rm --cached .token 2>/dev/null || true")

    run("git remote remove origin 2>/dev/null || true")
    run(f'git remote add origin https://{token}@github.com/{username}/{repo}.git')

    run("git add .")
    run('git commit -m "Auto commit (safe token)" || true')

    run("git branch -M main")
    run("git push -u origin main --force")

    print("\n[✓] PUSH BERHASIL (token aman).")

if __name__ == "__main__":
    main()