# cython: language_level=3
import json
import os
import re
import getpass
import requests
import smtplib
import random
import time
import sys
import base64
import hashlib
import platform
import subprocess
from datetime import datetime
from email.mime.text import MIMEText
from email.mime.multipart import MIMEMultipart
from tqdm import tqdm
from simple_term_menu import TerminalMenu
from rich.table import Table
from rich.console import Console
from rich.panel import Panel
from tabulate import tabulate
from fake_useragent import UserAgent

cdef str CONFIG_FILE = "config.enc"
cdef str CONFIG_FILE_PLAIN = "config.json"
cdef str OTP_FILE = "otp_data.json"
cdef int OTP_EXPIRY = 300

cdef bytes SALT = b"TermuxAuth2024SecureSalt"
cdef bytes PASSPHRASE = b"Tx@uth#Pr0t3ct3d$K3y!2024"

cdef str ADMIN_USERNAME = "xyraofficial"
cdef str ADMIN_PASSWORD = "admin"

cdef bytes derive_key_internal(bytes passphrase, bytes salt):
    cdef bytes key = hashlib.pbkdf2_hmac('sha256', passphrase, salt, 100000)
    return base64.urlsafe_b64encode(key)

cdef bytes xor_decrypt(bytes data, bytes key):
    cdef bytearray result = bytearray()
    cdef bytes key_bytes = base64.urlsafe_b64decode(key)
    cdef int i
    cdef int byte
    for i in range(len(data)):
        byte = data[i] ^ key_bytes[i % len(key_bytes)]
        result.append(byte)
    return bytes(result)

cdef dict decrypt_config(bytes encrypted_data):
    cdef bytes header, enc_data, key, decrypted
    cdef str json_str
    
    if len(encrypted_data) < 8:
        return None
    
    header = encrypted_data[:8]
    enc_data = encrypted_data[8:]
    
    if header == b"TXAUTH02":
        try:
            from cryptography.fernet import Fernet
            from cryptography.hazmat.primitives import hashes
            from cryptography.hazmat.primitives.kdf.pbkdf2 import PBKDF2HMAC
            
            kdf = PBKDF2HMAC(
                algorithm=hashes.SHA256(),
                length=32,
                salt=SALT,
                iterations=100000,
            )
            key = base64.urlsafe_b64encode(kdf.derive(PASSPHRASE))
            f = Fernet(key)
            decrypted = f.decrypt(enc_data)
            json_str = decrypted.decode('utf-8')
            return json.loads(json_str)
        except:
            return None
    
    elif header == b"TXAUTH01":
        try:
            key = derive_key_internal(PASSPHRASE, SALT)
            enc_data = base64.urlsafe_b64decode(enc_data)
            decrypted = xor_decrypt(enc_data, key)
            json_str = decrypted.decode('utf-8')
            return json.loads(json_str)
        except:
            return None
    
    return None

cdef str R = '\033[0m'
cdef str B = '\033[1m'
cdef str D = '\033[2m'
cdef str RD = '\033[91m'
cdef str GR = '\033[92m'
cdef str YL = '\033[93m'
cdef str BL = '\033[94m'
cdef str MG = '\033[95m'
cdef str CY = '\033[96m'
cdef str WH = '\033[97m'
cdef str DRD = '\033[31m'
cdef str DGR = '\033[32m'
cdef str DYL = '\033[33m'

console = Console()

cpdef str get_greeting():
    cdef int hour = datetime.now().hour
    if 5 <= hour < 11:
        return "Selamat Pagi"
    elif 11 <= hour < 15:
        return "Selamat Siang"
    elif 15 <= hour < 18:
        return "Selamat Sore"
    else:
        return "Selamat Malam"

cpdef str getprop(str name):
    try:
        return subprocess.check_output(["getprop", name]).decode().strip()
    except:
        return "Unknown"

cpdef dict get_device_info():
    cdef str brand = getprop("ro.product.brand")
    cdef str model = getprop("ro.product.model")
    cdef str android = getprop("ro.build.version.release")
    cdef str arch = platform.machine()
    cdef str system = platform.system()
    
    if brand == "Unknown":
        return {
            "System": system,
            "Arch": arch,
            "Type": "PC/Server"
        }
    return {
        "Brand": brand,
        "Model": model,
        "Android": android
    }

cpdef str get_ip():
    try:
        return requests.get("https://api.ipify.org", timeout=5).text
    except:
        return "N/A"

cpdef str get_day_name():
    cdef list days = ["Senin", "Selasa", "Rabu", "Kamis", "Jumat", "Sabtu", "Minggu"]
    return days[datetime.now().weekday()]

cpdef str get_month_name():
    cdef list months = ["Januari", "Februari", "Maret", "April", "Mei", "Juni",
                        "Juli", "Agustus", "September", "Oktober", "November", "Desember"]
    return months[datetime.now().month - 1]

cpdef str get_date_str():
    cdef object now = datetime.now()
    return f"{get_day_name()}, {now.day:02d} {get_month_name()} {now.year}"

cpdef str get_time_str():
    cdef object now = datetime.now()
    return f"{now.hour:02d}:{now.minute:02d}:{now.second:02d} WIB"

cpdef void loading_tqdm(str desc, int steps=30):
    for i in tqdm(range(steps), desc=f"  {desc}", colour="green", 
                  bar_format="{l_bar}{bar}| {n_fmt}/{total_fmt}", ncols=40):
        time.sleep(0.03)
    print()

cpdef void clear():
    os.system('clear' if os.name == 'posix' else 'cls')

cpdef void print_info_table(dict dev_info, str user_ip):
    table = Table(
        title=f"[bold magenta]★[/bold magenta] [bold white]TERMUX AUTH SYSTEM[/bold white] [bold magenta]★[/bold magenta]",
        show_header=False,
        title_style="bold cyan",
        box=None
    )
    
    if "Brand" in dev_info:
        dev_content = (
            f"[bold cyan]Brand[/bold cyan]   : {dev_info['Brand']}\n"
            f"[bold cyan]Model[/bold cyan]   : {dev_info['Model']}\n"
            f"[bold cyan]Android[/bold cyan] : {dev_info['Android']}"
        )
    else:
        dev_content = (
            f"[bold cyan]System[/bold cyan] : {dev_info['System']}\n"
            f"[bold cyan]Arch[/bold cyan]   : {dev_info['Arch']}\n"
            f"[bold cyan]Type[/bold cyan]   : {dev_info['Type']}"
        )
    
    left_panel = Panel(
        dev_content,
        title="[bold cyan]DEVICE INFO[/bold cyan]",
        border_style="cyan"
    )
    
    user_content = (
        f"[bold green]IP[/bold green]      : {user_ip}\n"
        f"[bold green]Tanggal[/bold green] : {get_date_str()}\n"
        f"[bold green]Waktu[/bold green]   : {get_time_str()}"
    )
    
    right_panel = Panel(
        user_content,
        title="[bold green]USER INFO[/bold green]",
        border_style="green"
    )
    
    table.add_row(left_panel, right_panel)
    console.print(table)

cpdef void open_url(str url):
    try:
        if os.path.exists("/data/data/com.termux"):
            subprocess.run(["termux-open-url", url], check=False)
        else:
            subprocess.run(["xdg-open", url], check=False)
    except:
        info(f"Buka manual: {url}")

cpdef void show_developer_info():
    cdef int sel
    cdef list dev_links = [
        ("WhatsApp", "https://wa.me/62895325844493"),
        ("YouTube", "https://youtube.com/@Kz.tutorial"),
        ("Email", "mailto:xyraofficialsup@gmail.com"),
        ("GitHub", "https://github.com/XyraOfficial"),
    ]
    
    while True:
        clear()
        print()
        
        title_box = (
            f"\n{GR}{B}"
            f"╭───────────────────────────────╮\n"
            f"│       DEVELOPER INFO          │\n"
            f"│      by XyraOfficial          │\n"
            f"╰───────────────────────────────╯"
            f"{R}"
        )
        
        options = [
            f"{B}WhatsApp  - Hubungi via WA{R}",
            f"{B}YouTube   - Channel Tutorial{R}",
            f"{B}Email     - Kirim Email{R}",
            f"{B}GitHub    - Source Code{R}",
            f"{B}Kembali   - Menu Utama{R}",
        ]
        
        dev_menu = TerminalMenu(
            menu_entries=options,
            title=title_box,
            menu_cursor="▶ ",
            menu_cursor_style=("fg_red",),
            menu_highlight_style=("fg_yellow", "bold"),
        )
        
        sel = dev_menu.show()
        
        if sel is None or sel == 4:
            break
        elif sel >= 0 and sel < 4:
            name, url = dev_links[sel]
            loading_tqdm(f"Membuka {name}", 20)
            open_url(url)
            success(f"{name} dibuka!")
            print()
            input(f" {D}Tekan Enter...{R}")

cpdef void section(str title):
    print()
    console.print(f"[bold green]┌─ {title} {'─' * (30 - len(title))}┐[/bold green]")
    print()

cpdef void success(str msg):
    console.print(f" [bold green][✓][/bold green] {msg}")

cpdef void error(str msg):
    console.print(f" [bold red][✗][/bold red] {msg}")

cpdef void info(str msg):
    console.print(f" [bold yellow][!][/bold yellow] {msg}")

cpdef void box_info(list lines):
    content = "\n".join(lines)
    panel = Panel(content, border_style="dim")
    console.print(panel)

cpdef dict load_config():
    cdef bytes enc_data
    cdef dict cfg
    
    if os.path.exists(CONFIG_FILE):
        with open(CONFIG_FILE, 'rb') as f:
            enc_data = f.read()
        cfg = decrypt_config(enc_data)
        if cfg is not None:
            return cfg
        error("Gagal dekripsi config!")
        return None
    
    if os.path.exists(CONFIG_FILE_PLAIN):
        info("Menggunakan config.json (tidak aman)")
        info("Gunakan encrypt_config.py untuk enkripsi")
        with open(CONFIG_FILE_PLAIN, 'r') as f:
            return json.load(f)
    
    error("File config tidak ditemukan!")
    error("Butuh config.enc atau config.json")
    return None

cpdef bint valid_email(str e):
    return bool(re.match(r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$', e))

cpdef tuple valid_pass(str p):
    if len(p) >= 6:
        return (True, "")
    return (False, "Min 6 karakter")

cpdef str gen_otp():
    return str(random.randint(100000, 999999))

cpdef void save_otp(str email, str otp):
    cdef dict data = {}
    if os.path.exists(OTP_FILE):
        with open(OTP_FILE, 'r') as f:
            data = json.load(f)
    data[email] = {"otp": otp, "time": time.time()}
    with open(OTP_FILE, 'w') as f:
        json.dump(data, f)

cpdef tuple check_otp(str email, str code):
    cdef dict data
    if not os.path.exists(OTP_FILE):
        return (False, "OTP tidak ada")
    with open(OTP_FILE, 'r') as f:
        data = json.load(f)
    if email not in data:
        return (False, "OTP tidak ditemukan")
    if time.time() - data[email]["time"] > OTP_EXPIRY:
        del data[email]
        with open(OTP_FILE, 'w') as f:
            json.dump(data, f)
        return (False, "OTP expired")
    if data[email]["otp"] != code:
        return (False, "Kode salah")
    del data[email]
    with open(OTP_FILE, 'w') as f:
        json.dump(data, f)
    return (True, "Valid")

cpdef str email_template(str otp, str to):
    return f'''<!DOCTYPE html><html><body style="margin:0;padding:0;font-family:Arial;background:#0f0f23">
<table style="width:100%"><tr><td align="center" style="padding:40px 0">
<table style="max-width:500px;background:linear-gradient(135deg,#1a1a2e,#16213e);border-radius:20px;overflow:hidden">
<tr><td style="padding:40px;text-align:center">
<div style="font-size:50px;margin-bottom:20px">🔐</div>
<h1 style="color:#fff;margin:0">Kode Verifikasi</h1>
<p style="color:#888;margin:10px 0 30px">Termux Auth System</p>
<div style="background:linear-gradient(135deg,#667eea,#764ba2);border-radius:16px;padding:30px">
<p style="color:rgba(255,255,255,0.8);margin:0 0 10px;font-size:12px">KODE OTP</p>
<h2 style="color:#fff;font-size:48px;margin:0;letter-spacing:10px;font-family:monospace">{otp}</h2>
</div>
<p style="color:#f6ad55;margin:30px 0">⏱️ Berlaku 5 menit</p>
<div style="background:rgba(255,100,100,0.1);border:1px solid rgba(255,100,100,0.3);border-radius:10px;padding:15px">
<p style="color:#fc8181;margin:0;font-size:13px">⚠️ Jangan bagikan kode ini!</p>
</div>
</td></tr>
<tr><td style="padding:20px;background:rgba(0,0,0,0.2);text-align:center">
<p style="color:#666;font-size:12px;margin:0">Dikirim ke: {to}</p>
</td></tr></table></td></tr></table></body></html>'''

cpdef tuple send_email(dict cfg, str to, str otp):
    cdef str smtp_email = cfg.get("smtp_email", "")
    cdef str smtp_pass = cfg.get("smtp_app_password", "")
    if not smtp_email or not smtp_pass:
        return (False, "SMTP tidak dikonfigurasi")
    try:
        msg = MIMEMultipart('alternative')
        msg['Subject'] = f'🔐 Kode OTP: {otp}'
        msg['From'] = f'Termux Auth <{smtp_email}>'
        msg['To'] = to
        msg.attach(MIMEText(f'Kode OTP Anda: {otp}\nBerlaku 5 menit.', 'plain'))
        msg.attach(MIMEText(email_template(otp, to), 'html'))
        srv = smtplib.SMTP('smtp.gmail.com', 587)
        srv.starttls()
        srv.login(smtp_email, smtp_pass)
        srv.sendmail(smtp_email, to, msg.as_string())
        srv.quit()
        return (True, "OTP terkirim!")
    except smtplib.SMTPAuthenticationError:
        return (False, "Login SMTP gagal")
    except Exception as e:
        return (False, str(e))

cpdef tuple valid_phone(str phone):
    cdef str cleaned = phone.strip()
    if cleaned.startswith("+62"):
        cleaned = cleaned[3:]
    elif cleaned.startswith("62"):
        cleaned = cleaned[2:]
    elif cleaned.startswith("0"):
        cleaned = cleaned[1:]
    
    if not cleaned.startswith("8"):
        return (False, "", "Nomor harus diawali 8 (contoh: 895325844493)")
    
    if not cleaned.isdigit():
        return (False, "", "Nomor harus angka saja")
    
    if len(cleaned) < 9 or len(cleaned) > 13:
        return (False, "", "Panjang nomor tidak valid (9-13 digit)")
    
    return (True, cleaned, "")

cpdef str get_random_ua():
    try:
        ua = UserAgent()
        return ua.random
    except:
        return "Mozilla/5.0 (Linux; Android 14; SM-G991B) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/142.0.0.0 Mobile Safari/537.36"

cpdef tuple send_sms_authkey(str phone):
    cdef str ua = get_random_ua()
    cdef str url = "https://napi3.authkey.io/api/login"
    cdef dict payload = {
        "method": "otp_mobile_verification",
        "user_id": 16738,
        "token": "19ee5f415a57c113ad51f2eb92995292",
        "mobile": phone,
        "country_code": "62"
    }
    cdef dict headers = {
        'User-Agent': ua,
        'Accept': "application/json, text/plain, */*",
        'Accept-Encoding': "gzip, deflate, br, zstd",
        'Content-Type': "application/json",
        'sec-ch-ua-platform': '"Android"',
        'sec-ch-ua': '"Chromium";v="142", "Android WebView";v="142", "Not_A Brand";v="99"',
        'sec-ch-ua-mobile': "?1",
        'Origin': "https://console.authkey.io",
        'X-Requested-With': "mark.via.gp",
        'Sec-Fetch-Site': "same-site",
        'Sec-Fetch-Mode': "cors",
        'Sec-Fetch-Dest': "empty",
        'Referer': "https://console.authkey.io/",
        'Accept-Language': "id-ID,id;q=0.9,en-US;q=0.8,en;q=0.7"
    }
    try:
        r = requests.post(url, data=json.dumps(payload), headers=headers, timeout=30)
        return (True, f"AuthKey: {r.text[:100]}")
    except Exception as e:
        return (False, f"AuthKey Error: {str(e)}")

cpdef tuple send_sms_dexatel(str phone):
    cdef str ua = get_random_ua()
    cdef str url = "https://api.dexatel.com/v1/phone_verifications"
    cdef str phone_with_code = "62" + phone
    cdef dict payload = {
        "data": {
            "phone": phone_with_code
        }
    }
    cdef dict headers = {
        'User-Agent': ua,
        'Accept': "application/json, text/plain, */*",
        'Accept-Encoding': "gzip, deflate, br, zstd",
        'Content-Type': "application/json",
        'sec-ch-ua-platform': '"Android"',
        'authorization': "Bearer eyJhbGciOiJIUzI1NiJ9.eyJzdWIiOiJwYW5na2V5anVsaW8yQGdtYWlsLmNvbSIsInJvbGUiOiJVU0VSIiwiYWNjb3VudF9pZCI6IjQ3MTg2OTk0LTBlNTUtNDYxYS04NDA5LTUxOTUzNGQwYmM2MCIsImFjY291bnRfdHlwZSI6IkFDQ09VTlQiLCJpbXBlcnNvbmF0ZWQiOmZhbHNlLCJhZG1pbl9pbXBlcnNvbmF0ZWQiOmZhbHNlLCJpYXQiOjE3NjQ5OTE0ODgsImV4cCI6MTc2NTAyMTQ4OH0.qN_x8FcybHUpsxVTdChm3O3WoQ4HNfWnZdh8WJJo0vM",
        'sec-ch-ua': '"Chromium";v="142", "Android WebView";v="142", "Not_A Brand";v="99"',
        'sec-ch-ua-mobile': "?1",
        'origin': "https://dashboard.dexatel.com",
        'x-requested-with': "mark.via.gp",
        'sec-fetch-site': "same-site",
        'sec-fetch-mode': "cors",
        'sec-fetch-dest': "empty",
        'referer': "https://dashboard.dexatel.com/",
        'accept-language': "id-ID,id;q=0.9,en-US;q=0.8,en;q=0.7",
        'priority': "u=1, i"
    }
    try:
        r = requests.post(url, data=json.dumps(payload), headers=headers, timeout=30)
        return (True, f"Dexatel: {r.text[:100]}")
    except Exception as e:
        return (False, f"Dexatel Error: {str(e)}")

cpdef void do_sms_config():
    cdef str phone_input, phone_clean, msg
    cdef bint valid, ok1, ok2
    cdef int i
    
    section("RUN KONFIGURASI SMS")
    
    print(f" {YL}[!]{R} Format nomor: 8xxxxxxxxx (tanpa +62/0)")
    print(f" {YL}[!]{R} Contoh: 895325844493")
    print()
    
    phone_input = input(f" {GR}[?]{R} Nomor Target : {CY}").strip()
    print(R, end="")
    
    valid, phone_clean, msg = valid_phone(phone_input)
    if not valid:
        error(msg)
        return
    
    success(f"Nomor valid: +62{phone_clean}")
    print()
    
    info("Delay 60 detik sebelum mengirim SMS...")
    for i in tqdm(range(60), desc=f" {YL}[~]{R} Menunggu", ncols=60, bar_format='{l_bar}{bar}| {n_fmt}/{total_fmt}'):
        time.sleep(1)
    print()
    
    loading_tqdm("Mengirim via AuthKey", 20)
    ok1, msg = send_sms_authkey(phone_clean)
    if ok1:
        success(msg)
    else:
        error(msg)
    
    time.sleep(2)
    
    loading_tqdm("Mengirim via Dexatel", 20)
    ok2, msg = send_sms_dexatel(phone_clean)
    if ok2:
        success(msg)
    else:
        error(msg)
    
    print()
    if ok1 or ok2:
        success("SMS Konfigurasi selesai!")
    else:
        error("Semua pengiriman gagal")

cdef class Auth:
    cdef str url
    cdef dict h
    cdef str service_key
    
    def __init__(self, str url, str key, str svc_key=""):
        self.url = url
        self.h = {"apikey": key, "Content-Type": "application/json"}
        self.service_key = svc_key
    
    cpdef tuple signup(self, str email, str pw):
        try:
            admin_h = {"apikey": self.service_key, "Authorization": f"Bearer {self.service_key}", "Content-Type": "application/json"}
            r = requests.post(f"{self.url}/auth/v1/admin/users", 
                json={
                    "email": email, 
                    "password": pw,
                    "email_confirm": False
                }, headers=admin_h)
            d = r.json()
            if r.status_code == 200:
                uid = d.get("id", "")
                return (True, {"uid": uid, "email": email})
            elif r.status_code == 422 or "already been registered" in str(d):
                return (False, "Email sudah terdaftar")
            return (False, d.get("msg", d.get("error_description", "Gagal")))
        except Exception as e:
            return (False, str(e))
    
    cpdef tuple login(self, str email, str pw):
        try:
            r = requests.post(f"{self.url}/auth/v1/token?grant_type=password",
                json={"email": email, "password": pw}, headers=self.h)
            d = r.json()
            if r.status_code == 200:
                return (True, {"uid": d.get("user", {}).get("id"), 
                    "email": d.get("user", {}).get("email"),
                    "token": d.get("access_token")})
            err = d.get("error_description", "")
            if "not confirmed" in err.lower():
                return (False, "UNVERIFIED")
            return (False, err or "Login gagal")
        except Exception as e:
            return (False, str(e))
    
    cpdef tuple list_users(self):
        try:
            admin_h = {"apikey": self.service_key, "Authorization": f"Bearer {self.service_key}", "Content-Type": "application/json"}
            r = requests.get(f"{self.url}/auth/v1/admin/users", headers=admin_h)
            if r.status_code == 200:
                data = r.json()
                users = data.get("users", [])
                return (True, users)
            return (False, f"Error: {r.status_code}")
        except Exception as e:
            return (False, str(e))
    
    cpdef tuple delete_user(self, str uid):
        try:
            admin_h = {"apikey": self.service_key, "Authorization": f"Bearer {self.service_key}", "Content-Type": "application/json"}
            r = requests.delete(f"{self.url}/auth/v1/admin/users/{uid}", headers=admin_h)
            if r.status_code == 200:
                return (True, "User dihapus!")
            return (False, f"Error: {r.status_code}")
        except Exception as e:
            return (False, str(e))
    
    cpdef tuple get_user(self, str uid):
        try:
            admin_h = {"apikey": self.service_key, "Authorization": f"Bearer {self.service_key}", "Content-Type": "application/json"}
            r = requests.get(f"{self.url}/auth/v1/admin/users/{uid}", headers=admin_h)
            if r.status_code == 200:
                return (True, r.json())
            return (False, f"Error: {r.status_code}")
        except Exception as e:
            return (False, str(e))
    
    cpdef tuple confirm_email(self, str uid):
        try:
            admin_h = {"apikey": self.service_key, "Authorization": f"Bearer {self.service_key}", "Content-Type": "application/json"}
            r = requests.put(f"{self.url}/auth/v1/admin/users/{uid}", 
                json={"email_confirm": True}, headers=admin_h)
            if r.status_code == 200:
                return (True, "Email terverifikasi!")
            return (False, f"Error: {r.status_code}")
        except Exception as e:
            return (False, str(e))
    
    cpdef tuple get_user_by_email(self, str email):
        try:
            admin_h = {"apikey": self.service_key, "Authorization": f"Bearer {self.service_key}", "Content-Type": "application/json"}
            r = requests.get(f"{self.url}/auth/v1/admin/users", headers=admin_h)
            if r.status_code == 200:
                data = r.json()
                users = data.get("users", [])
                for u in users:
                    if u.get("email", "").lower() == email.lower():
                        return (True, u)
                return (False, "User tidak ditemukan")
            return (False, f"Error: {r.status_code}")
        except Exception as e:
            return (False, str(e))

cpdef str get_email():
    cdef str e
    while True:
        e = input(f" {GR}[?]{R} Email    : {CY}").strip()
        print(R, end="")
        if valid_email(e):
            return e
        error("Email tidak valid")

cpdef str get_pass(bint confirm=False):
    cdef str p, p2, msg
    cdef bint ok
    while True:
        p = getpass.getpass(f" {GR}[?]{R} Password : {CY}")
        print(R, end="")
        ok, msg = valid_pass(p)
        if not ok:
            error(msg)
            continue
        if confirm:
            p2 = getpass.getpass(f" {GR}[?]{R} Konfirm  : {CY}")
            print(R, end="")
            if p != p2:
                error("Password tidak cocok")
                continue
        return p

cpdef bint otp_input(str email, dict cfg, int tries=3):
    cdef str code, msg
    cdef bint ok
    while tries > 0:
        code = input(f" {YL}[?]{R} OTP [{GR}{tries}x{R}] : {CY}").strip()
        print(R, end="")
        ok, msg = check_otp(email, code)
        if ok:
            return True
        tries -= 1
        error(msg)
    return False

cpdef void do_signup(Auth auth, dict cfg):
    cdef str email, pw, otp, msg, uid
    cdef bint ok, sent, confirmed
    cdef object res
    
    section("SIGNUP")
    email = get_email()
    pw = get_pass(True)
    print()
    loading_tqdm("Membuat akun", 25)
    ok, res = auth.signup(email, pw)
    if ok:
        uid = res.get("uid", "")
        success("Akun dibuat!")
        loading_tqdm("Mengirim OTP", 30)
        otp = gen_otp()
        save_otp(email, otp)
        sent, msg = send_email(cfg, email, otp)
        if sent:
            success(msg)
            print()
            if otp_input(email, cfg):
                print()
                loading_tqdm("Verifikasi email", 20)
                confirmed, msg = auth.confirm_email(uid)
                if confirmed:
                    success("Email terverifikasi!")
                    info("Silakan login")
                else:
                    error(f"Gagal verifikasi: {msg}")
        else:
            error(msg)
    else:
        error(res)

cpdef void do_login(Auth auth, dict cfg):
    cdef str email, pw, otp, msg, uid
    cdef bint ok, sent, found, confirmed
    cdef object res, user_data
    cdef int sel
    
    section("LOGIN")
    email = get_email()
    pw = get_pass(False)
    print()
    loading_tqdm("Memverifikasi", 25)
    ok, res = auth.login(email, pw)
    if ok:
        success("Login berhasil!")
        box_info([f"Email : {res['email']}", f"UID   : {res['uid'][:20]}..."])
        
        while True:
            print()
            user_options = [
                f"{B}Profile - Lihat info akun{R}",
                f"{B}Run Konfigurasi SMS - Kirim SMS OTP{R}",
                f"{B}Logout - Keluar akun{R}",
            ]
            user_menu = TerminalMenu(
                menu_entries=user_options,
                title=f"\n{GR}{B}╭─────────────────────────────╮\n│       USER MENU             │\n╰─────────────────────────────╯{R}",
                menu_cursor="▶ ",
                menu_cursor_style=("fg_red",),
                menu_highlight_style=("fg_yellow", "bold"),
            )
            sel = user_menu.show()
            
            if sel == 0:
                section("PROFILE")
                box_info([f"Email : {res['email']}", f"UID   : {res['uid']}"])
            elif sel == 1:
                do_sms_config()
            elif sel == 2:
                loading_tqdm("Logout", 20)
                success("Logout berhasil!")
                break
            else:
                break
    elif res == "UNVERIFIED":
        info("Email belum diverifikasi")
        loading_tqdm("Mencari data user", 20)
        found, user_data = auth.get_user_by_email(email)
        if not found:
            error("User tidak ditemukan di database")
            return
        uid = user_data.get("id", "")
        loading_tqdm("Mengirim OTP", 30)
        otp = gen_otp()
        save_otp(email, otp)
        sent, msg = send_email(cfg, email, otp)
        if sent:
            success(msg)
            print()
            if otp_input(email, cfg):
                print()
                loading_tqdm("Verifikasi email", 20)
                confirmed, msg = auth.confirm_email(uid)
                if confirmed:
                    success("Email terverifikasi!")
                    info("Silakan login lagi")
                else:
                    error(f"Gagal verifikasi: {msg}")
        else:
            error(msg)
    else:
        error(res)

cpdef void do_resend(dict cfg):
    cdef str email, otp, msg
    cdef bint ok
    
    section("KIRIM ULANG OTP")
    email = get_email()
    print()
    loading_tqdm("Mengirim OTP", 30)
    otp = gen_otp()
    save_otp(email, otp)
    ok, msg = send_email(cfg, email, otp)
    if ok:
        success(msg)
        print()
        if otp_input(email, cfg):
            print()
            success("OTP Valid!")
    else:
        error(msg)

cpdef void do_reset(dict cfg):
    cdef str email, otp, msg
    cdef bint ok
    
    section("RESET PASSWORD")
    email = get_email()
    print()
    loading_tqdm("Mengirim OTP", 30)
    otp = gen_otp()
    save_otp(email, otp)
    ok, msg = send_email(cfg, email, otp)
    if ok:
        success(msg)
        print()
        if otp_input(email, cfg):
            print()
            success("Verifikasi OK!")
            info("Hubungi admin untuk reset password")
    else:
        error(msg)

cpdef bint admin_login():
    cdef str username, password
    cdef int tries = 3
    
    section("ADMIN LOGIN")
    
    while tries > 0:
        username = input(f" {GR}[?]{R} Username : {CY}").strip()
        print(R, end="")
        password = getpass.getpass(f" {GR}[?]{R} Password : {CY}")
        print(R, end="")
        
        if username == ADMIN_USERNAME and password == ADMIN_PASSWORD:
            print()
            loading_tqdm("Verifikasi admin", 25)
            success("Login admin berhasil!")
            return True
        
        tries -= 1
        error(f"Kredensial salah! Sisa {tries} percobaan")
        print()
    
    error("Terlalu banyak percobaan gagal!")
    return False

cpdef void admin_list_users(Auth auth):
    cdef bint ok
    cdef object users, selected_user
    cdef int sel
    cdef list menu_options
    cdef str email, uid, verified_status
    
    section("DAFTAR USER")
    loading_tqdm("Mengambil data", 25)
    
    ok, users = auth.list_users()
    if ok:
        if len(users) == 0:
            info("Belum ada user terdaftar")
            return
        
        success(f"Total: {len(users)} user")
        
        while True:
            print()
            menu_options = []
            for i, u in enumerate(users):
                email = u.get("email", "N/A")
                verified_status = "✓" if u.get("email_confirmed_at") else "✗"
                menu_options.append(f"{B}{i+1}. {email} [{verified_status}]{R}")
            
            menu_options.append(f"{B}← Kembali{R}")
            
            title_box = (
                f"\n{CY}{B}"
                f"╭───────────────────────────────╮\n"
                f"│      PILIH USER               │\n"
                f"│   Tekan Enter untuk detail    │\n"
                f"╰───────────────────────────────╯"
                f"{R}"
            )
            
            user_menu = TerminalMenu(
                menu_entries=menu_options,
                title=title_box,
                menu_cursor="▶ ",
                menu_cursor_style=("fg_red",),
                menu_highlight_style=("fg_yellow", "bold"),
            )
            
            sel = user_menu.show()
            
            if sel is None or sel == len(users):
                break
            
            selected_user = users[sel]
            clear()
            print()
            section("DETAIL USER")
            
            box_info([
                f"UID      : {selected_user.get('id', 'N/A')}",
                f"Email    : {selected_user.get('email', 'N/A')}",
                f"Dibuat   : {selected_user.get('created_at', 'N/A')[:19]}",
                f"Verified : {'Ya' if selected_user.get('email_confirmed_at') else 'Tidak'}",
                f"Provider : {selected_user.get('app_metadata', {}).get('provider', 'email')}",
                f"Last Sign: {selected_user.get('last_sign_in_at', 'Belum pernah')[:19] if selected_user.get('last_sign_in_at') else 'Belum pernah'}",
            ])
            
            print()
            input(f" {D}Tekan Enter untuk kembali...{R}")
            clear()
            print()
            section("DAFTAR USER")
            success(f"Total: {len(users)} user")
    else:
        error(f"Gagal mengambil data: {users}")

cpdef void admin_delete_user(Auth auth):
    cdef str uid, confirm, email, verified_status
    cdef bint ok
    cdef object msg, users, selected_user
    cdef int sel
    cdef list menu_options
    
    section("HAPUS USER")
    loading_tqdm("Mengambil data", 25)
    
    ok, users = auth.list_users()
    if not ok:
        error(f"Gagal mengambil data: {users}")
        return
    
    if len(users) == 0:
        info("Belum ada user terdaftar")
        return
    
    info(f"Total: {len(users)} user")
    print()
    
    menu_options = []
    for i, u in enumerate(users):
        email = u.get("email", "N/A")
        verified_status = "✓" if u.get("email_confirmed_at") else "✗"
        menu_options.append(f"{B}{i+1}. {email} [{verified_status}]{R}")
    
    menu_options.append(f"{B}← Batal{R}")
    
    title_box = (
        f"\n{RD}{B}"
        f"╭───────────────────────────────╮\n"
        f"│      PILIH USER UNTUK         │\n"
        f"│         DIHAPUS               │\n"
        f"╰───────────────────────────────╯"
        f"{R}"
    )
    
    user_menu = TerminalMenu(
        menu_entries=menu_options,
        title=title_box,
        menu_cursor="▶ ",
        menu_cursor_style=("fg_red",),
        menu_highlight_style=("fg_red", "bold"),
    )
    
    sel = user_menu.show()
    
    if sel is None or sel == len(users):
        info("Dibatalkan")
        return
    
    selected_user = users[sel]
    uid = selected_user.get("id", "")
    email = selected_user.get("email", "N/A")
    
    print()
    console.print(f" [bold red]⚠ PERINGATAN:[/bold red] User [bold]{email}[/bold] akan dihapus!")
    confirm = input(f" {RD}[!]{R} Ketik 'HAPUS' untuk konfirmasi: {CY}").strip()
    print(R, end="")
    
    if confirm != 'HAPUS':
        info("Dibatalkan")
        return
    
    print()
    loading_tqdm("Menghapus user", 25)
    ok, msg = auth.delete_user(uid)
    if ok:
        success(f"User {email} berhasil dihapus!")
    else:
        error(msg)

cpdef void admin_user_detail(Auth auth):
    cdef str uid
    cdef bint ok
    cdef object user
    
    section("DETAIL USER")
    uid = input(f" {GR}[?]{R} UID User : {CY}").strip()
    print(R, end="")
    
    if not uid:
        error("UID tidak boleh kosong!")
        return
    
    print()
    loading_tqdm("Mengambil data", 25)
    ok, user = auth.get_user(uid)
    if ok:
        box_info([
            f"UID      : {user.get('id', 'N/A')}",
            f"Email    : {user.get('email', 'N/A')}",
            f"Dibuat   : {user.get('created_at', 'N/A')[:19]}",
            f"Verified : {'Ya' if user.get('email_confirmed_at') else 'Tidak'}",
            f"Provider : {user.get('app_metadata', {}).get('provider', 'email')}",
        ])
    else:
        error(f"Gagal: {user}")

cpdef void admin_panel(Auth auth, dict cfg):
    cdef int sel
    cdef bint ok
    cdef object users
    cdef int verified
    
    while True:
        clear()
        print()
        
        title_box = (
            f"\n{RD}{B}"
            f"╭───────────────────────────────╮\n"
            f"│       ADMIN PANEL             │\n"
            f"│    Kelola User Database       │\n"
            f"╰───────────────────────────────╯"
            f"{R}"
        )
        
        options = [
            f"{B}List User    - Lihat & pilih user{R}",
            f"{B}Hapus User   - Delete user{R}",
            f"{B}Database     - Lihat statistik{R}",
            f"{B}Logout       - Keluar admin{R}",
        ]
        
        admin_menu = TerminalMenu(
            menu_entries=options,
            title=title_box,
            menu_cursor="▶ ",
            menu_cursor_style=("fg_red",),
            menu_highlight_style=("fg_yellow", "bold"),
        )
        
        sel = admin_menu.show()
        
        if sel == 0:
            admin_list_users(auth)
        elif sel == 1:
            admin_delete_user(auth)
        elif sel == 2:
            section("DATABASE STATS")
            ok, users = auth.list_users()
            if ok:
                verified = 0
                for u in users:
                    if u.get("email_confirmed_at"):
                        verified = verified + 1
                box_info([
                    f"Total User     : {len(users)}",
                    f"Terverifikasi  : {verified}",
                    f"Belum Verified : {len(users) - verified}",
                ])
            else:
                error("Gagal mengambil statistik")
            print()
            input(f" {D}Tekan Enter...{R}")
        elif sel == 3 or sel is None:
            loading_tqdm("Logout admin", 20)
            success("Logout admin berhasil!")
            break

cpdef void do_login_menu(Auth auth, dict cfg):
    cdef int sel
    
    section("LOGIN")
    
    login_options = [
        f"{B}Login User   - Masuk sebagai user{R}",
        f"{B}Login Admin  - Masuk sebagai admin{R}",
        f"{B}Kembali      - Menu utama{R}",
    ]
    
    login_menu = TerminalMenu(
        menu_entries=login_options,
        title=f"\n{GR}{B}╭─────────────────────────────╮\n│     PILIH TIPE LOGIN        │\n╰─────────────────────────────╯{R}",
        menu_cursor="▶ ",
        menu_cursor_style=("fg_red",),
        menu_highlight_style=("fg_yellow", "bold"),
    )
    
    sel = login_menu.show()
    
    if sel == 0:
        do_login(auth, cfg)
    elif sel == 1:
        if admin_login():
            admin_panel(auth, cfg)
    elif sel == 2 or sel is None:
        return

cpdef void intro_loading():
    clear()
    print()
    intro_panel = Panel(
        "[bold magenta]★[/bold magenta] [bold white]TERMUX AUTH SYSTEM[/bold white] [bold magenta]★[/bold magenta]\n[dim]by XyraOfficial[/dim]",
        border_style="red",
        padding=(1, 4)
    )
    console.print(intro_panel)
    print()
    loading_tqdm("Memuat sistem", 40)
    time.sleep(0.3)

cpdef int show_main_menu(dict dev_info, str user_ip):
    clear()
    print()
    print_info_table(dev_info, user_ip)
    
    greeting = get_greeting()
    
    title_box = (
        f"\n{GR}{B}"
        f"╭───────────────────────────────╮\n"
        f"│  {greeting}, Pengguna!     │\n"
        f"│       MENU UTAMA              │\n"
        f"╰───────────────────────────────╯"
        f"{R}"
    )
    
    options = [
        f"{B}Signup   - Daftar akun baru{R}",
        f"{B}Login    - Masuk ke akun{R}",
        f"{B}Resend   - Kirim ulang OTP{R}",
        f"{B}Reset    - Reset password{R}",
        f"{B}About    - Info developer{R}",
        f"{B}Keluar   - Exit program{R}",
    ]
    
    terminal_menu = TerminalMenu(
        menu_entries=options,
        title=title_box,
        menu_cursor="▶ ",
        menu_cursor_style=("fg_red",),
        menu_highlight_style=("fg_yellow", "bold"),
    )
    
    return terminal_menu.show()

cpdef void run_main():
    cdef dict cfg, dev_info
    cdef str url, key, svc_key, user_ip
    cdef Auth auth
    cdef int sel
    
    intro_loading()
    
    cfg = load_config()
    if cfg is None:
        input(f"\n {D}Tekan Enter...{R}")
        return
    
    url = cfg.get("supabase_url", "")
    key = cfg.get("supabase_key", "")
    svc_key = cfg.get("supabase_service_key", key)
    if not url or not key:
        error("Konfigurasi Supabase tidak lengkap")
        input(f"\n {D}Tekan Enter...{R}")
        return
    if not cfg.get("smtp_email") or not cfg.get("smtp_app_password"):
        error("Konfigurasi SMTP tidak lengkap")
        input(f"\n {D}Tekan Enter...{R}")
        return
    
    auth = Auth(url, key, svc_key)
    
    dev_info = get_device_info()
    user_ip = get_ip()
    
    while True:
        sel = show_main_menu(dev_info, user_ip)
        
        clear()
        print()
        print_info_table(dev_info, user_ip)
        
        if sel == 0:
            do_signup(auth, cfg)
        elif sel == 1:
            do_login_menu(auth, cfg)
        elif sel == 2:
            do_resend(cfg)
        elif sel == 3:
            do_reset(cfg)
        elif sel == 4:
            show_developer_info()
        elif sel == 5 or sel is None:
            clear()
            print()
            exit_panel = Panel(
                "[bold green]✓[/bold green] [white]Terima kasih![/white]\n[dim]Sampai jumpa lagi[/dim]\n[bold magenta]~ XyraOfficial ~[/bold magenta]",
                border_style="green",
                padding=(1, 4)
            )
            console.print(exit_panel)
            print()
            break
        else:
            error("Pilihan tidak valid")
        
        print()
        input(f" {D}Tekan Enter...{R}")
