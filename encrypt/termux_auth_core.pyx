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
from datetime import datetime
from email.mime.text import MIMEText
from email.mime.multipart import MIMEMultipart
from tqdm import tqdm

cdef str CONFIG_FILE = "config.enc"
cdef str CONFIG_FILE_PLAIN = "config.json"
cdef str OTP_FILE = "otp_data.json"
cdef int OTP_EXPIRY = 300

cdef bytes SALT = b"TermuxAuth2024SecureSalt"
cdef bytes PASSPHRASE = b"Tx@uth#Pr0t3ct3d$K3y!2024"

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

cpdef str get_device_info():
    cdef str arch = platform.machine()
    cdef str system = platform.system()
    if os.path.exists("/data/data/com.termux"):
        return f"Android {arch}"
    return f"{system} {arch}"

cpdef void loading_tqdm(str desc, int steps=30):
    for i in tqdm(range(steps), desc=f"  {desc}", colour="green", 
                  bar_format="{l_bar}{bar}| {n_fmt}/{total_fmt}", ncols=40):
        time.sleep(0.03)
    print()

cpdef void clear():
    os.system('clear' if os.name == 'posix' else 'cls')

cpdef void show_banner():
    cdef str greeting = get_greeting()
    cdef int pad = (40 - len(greeting) - 2) // 2
    print(f"\n{' ' * pad}{DRD}•{R} {WH}{greeting}{R} {DRD}•{R}")
    print()
    print(f" {DRD}┌──────────────────────────────────────┐{R}")
    print(f" {DRD}│{R} {RD}●{R} {YL}●{R} {GR}●{R}                                 {DRD}│{R}")
    print(f" {DRD}│{R}                                      {DRD}│{R}")
    print(f" {DRD}│{R}  {DRD}▀▀▀▀▀▀▀  █   █  {RD}▄▀▄  █  █ ▀▀█▀▀ █  █{R}  {DRD}│{R}")
    print(f" {DRD}│{R}     █     ▀▄▀   {RD}█▀█  █  █   █   █▀▀█{R}  {DRD}│{R}")
    print(f" {DRD}│{R}     █     █ █   {RD}█ █  ▀▄▄▀   █   █  █{R}  {DRD}│{R}")
    print(f" {DRD}│{R}                              {D}v1.0{R}    {DRD}│{R}")
    print(f" {DRD}│{R} {DGR}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━{R} {DRD}│{R}")
    print(f" {DRD}│{R}  {GR}♦{R} Creator  : {WH}XyraOfficial{R}          {DRD}│{R}")
    print(f" {DRD}│{R}  {GR}▶{R} Youtube  : {WH}@Kz.tutorial{R}          {DRD}│{R}")
    print(f" {DRD}│{R}                                      {DRD}│{R}")
    print(f" {DRD}└──────────────────────────────────────┘{R}")

cpdef void show_info_box():
    cdef str device = get_device_info()
    cdef str date_str = get_date_str()
    cdef str time_str = get_time_str()
    print()
    print(f" {DYL}┌─────────── {YL}Ingfo{R} {DYL}───────────────────┐{R}")
    print(f" {DYL}│{R} {GR}●{R} Device   : {WH}{device:<24}{R} {DYL}│{R}")
    print(f" {DYL}│{R} {GR}■{R} Tanggal  : {CY}{date_str:<24}{R} {DYL}│{R}")
    print(f" {DYL}│{R} {GR}■{R} Waktu    : {CY}{time_str:<24}{R} {DYL}│{R}")
    print(f" {DYL}└──────────────────────────────────────┘{R}")

cpdef void show_menu():
    print()
    print(f" {D}[{GR}•{R}{D}]{R} Control: {GR}angka{R}, {YL}enter{R}")
    print()
    print(f"   {GR}•{R} {WH}1.{R} Signup      {D}─ Daftar akun baru{R}")
    print(f"   {GR}•{R} {WH}2.{R} Login       {D}─ Masuk ke akun{R}")
    print(f"   {GR}•{R} {WH}3.{R} Resend OTP  {D}─ Kirim ulang kode{R}")
    print(f"   {GR}•{R} {WH}4.{R} Reset Pass  {D}─ Lupa password{R}")
    print(f"   {MG}•{R} {WH}5.{R} About       {D}─ Info developer{R}")
    print(f"   {RD}•{R} {WH}6.{R} Keluar      {D}─ Exit program{R}")
    print()

cpdef void show_user_menu():
    print()
    print(f" {D}[{GR}•{R}{D}]{R} Menu User:")
    print()
    print(f"   {GR}•{R} {WH}1.{R} Profile  {D}─ Lihat info akun{R}")
    print(f"   {RD}•{R} {WH}2.{R} Logout   {D}─ Keluar akun{R}")
    print()

cpdef void show_developer_info():
    print()
    print(f" {CY}┌──────────────────────────────────────┐{R}")
    print(f" {CY}│{R}       {MG}★{R} {B}{WH}DEVELOPER INFO{R} {MG}★{R}            {CY}│{R}")
    print(f" {CY}├──────────────────────────────────────┤{R}")
    print(f" {CY}│{R}                                      {CY}│{R}")
    print(f" {CY}│{R}  {YL}[♦]{R} Developer : {WH}XyraOfficial{R}         {CY}│{R}")
    print(f" {CY}│{R}                                      {CY}│{R}")
    print(f" {CY}│{R}  {GR}[■]{R} WhatsApp  :                      {CY}│{R}")
    print(f" {CY}│{R}      {CY}wa.me/62895325844493{R}            {CY}│{R}")
    print(f" {CY}│{R}                                      {CY}│{R}")
    print(f" {CY}│{R}  {RD}[▶]{R} YouTube   :                      {CY}│{R}")
    print(f" {CY}│{R}      {CY}youtube.com/@Kz.tutorial{R}        {CY}│{R}")
    print(f" {CY}│{R}                                      {CY}│{R}")
    print(f" {CY}│{R}  {BL}[✉]{R} Email     :                      {CY}│{R}")
    print(f" {CY}│{R}      {CY}xyraofficialsup@gmail.com{R}       {CY}│{R}")
    print(f" {CY}│{R}                                      {CY}│{R}")
    print(f" {CY}└──────────────────────────────────────┘{R}")

cpdef void section(str title):
    print()
    print(f" {DGR}┌─ {GR}{title}{R} {DGR}{'─' * (34 - len(title))}┐{R}")
    print()

cpdef void success(str msg):
    print(f" {GR}[✓]{R} {msg}")

cpdef void error(str msg):
    print(f" {RD}[✗]{R} {msg}")

cpdef void info(str msg):
    print(f" {YL}[!]{R} {msg}")

cpdef void box(list lines):
    cdef int w = 36
    cdef str l
    cdef int padding
    print()
    print(f" {D}╭{'─' * w}╮{R}")
    for l in lines:
        padding = w - len(l) - 2
        if padding < 0:
            padding = 0
        print(f" {D}│{R}  {l}{' ' * padding}{D}│{R}")
    print(f" {D}╰{'─' * w}╯{R}")

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

cdef class Auth:
    cdef str url
    cdef dict h
    
    def __init__(self, str url, str key):
        self.url = url
        self.h = {"apikey": key, "Content-Type": "application/json"}
    
    cpdef tuple signup(self, str email, str pw):
        try:
            r = requests.post(f"{self.url}/auth/v1/signup", 
                json={"email": email, "password": pw}, headers=self.h)
            d = r.json()
            if r.status_code == 200:
                uid = d.get("id") or d.get("user", {}).get("id")
                return (True, {"uid": uid, "email": email})
            elif r.status_code == 422:
                return (False, "Email sudah terdaftar")
            return (False, d.get("error_description", "Gagal"))
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
    cdef str email, pw, otp, msg
    cdef bint ok, sent
    cdef object res
    
    section("SIGNUP")
    email = get_email()
    pw = get_pass(True)
    print()
    loading_tqdm("Membuat akun", 25)
    ok, res = auth.signup(email, pw)
    if ok:
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
                success("Email terverifikasi!")
                info("Silakan login")
        else:
            error(msg)
    else:
        error(res)

cpdef void do_login(Auth auth, dict cfg):
    cdef str email, pw, otp, msg, c
    cdef bint ok, sent
    cdef object res
    
    section("LOGIN")
    email = get_email()
    pw = get_pass(False)
    print()
    loading_tqdm("Memverifikasi", 25)
    ok, res = auth.login(email, pw)
    if ok:
        success("Login berhasil!")
        box([f"Email : {res['email']}", f"UID   : {res['uid'][:20]}..."])
        while True:
            show_user_menu()
            c = input(f" {GR}[?]{R} Pilih : {CY}").strip()
            print(R, end="")
            if c == "1":
                section("PROFILE")
                box([f"Email : {res['email']}", f"UID   : {res['uid']}"])
            elif c == "2":
                loading_tqdm("Logout", 20)
                success("Logout berhasil!")
                print()
                input(f" {D}Tekan Enter...{R}")
                break
            else:
                error("Pilihan salah")
    elif res == "UNVERIFIED":
        info("Email belum diverifikasi")
        loading_tqdm("Mengirim OTP", 30)
        otp = gen_otp()
        save_otp(email, otp)
        sent, msg = send_email(cfg, email, otp)
        if sent:
            success(msg)
            print()
            if otp_input(email, cfg):
                print()
                success("Terverifikasi! Silakan login lagi")
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

cpdef void intro_loading():
    clear()
    print(f"\n\n")
    print(f" {DRD}┌──────────────────────────────────────┐{R}")
    print(f" {DRD}│{R}       {MG}★{R} {B}{WH}TERMUX AUTH SYSTEM{R} {MG}★{R}        {DRD}│{R}")
    print(f" {DRD}│{R}          {D}by XyraOfficial{R}            {DRD}│{R}")
    print(f" {DRD}└──────────────────────────────────────┘{R}")
    print()
    loading_tqdm("Memuat sistem", 40)
    time.sleep(0.3)

cpdef void run_main():
    cdef dict cfg
    cdef str url, key, c
    cdef Auth auth
    
    intro_loading()
    
    cfg = load_config()
    if cfg is None:
        input(f"\n {D}Tekan Enter...{R}")
        return
    
    url = cfg.get("supabase_url", "")
    key = cfg.get("supabase_key", "")
    if not url or not key:
        error("Konfigurasi Supabase tidak lengkap")
        input(f"\n {D}Tekan Enter...{R}")
        return
    if not cfg.get("smtp_email") or not cfg.get("smtp_app_password"):
        error("Konfigurasi SMTP tidak lengkap")
        input(f"\n {D}Tekan Enter...{R}")
        return
    
    auth = Auth(url, key)
    
    while True:
        clear()
        show_banner()
        show_info_box()
        show_menu()
        
        c = input(f" {GR}[?]{R} Pilih : {CY}").strip()
        print(R, end="")
        
        if c == "1":
            do_signup(auth, cfg)
        elif c == "2":
            do_login(auth, cfg)
        elif c == "3":
            do_resend(cfg)
        elif c == "4":
            do_reset(cfg)
        elif c == "5":
            clear()
            show_developer_info()
        elif c == "6":
            clear()
            print()
            print(f" {DGR}┌──────────────────────────────────────┐{R}")
            print(f" {DGR}│{R}  {GR}✓{R} {WH}Terima kasih!{R}                      {DGR}│{R}")
            print(f" {DGR}│{R}    {D}Sampai jumpa lagi{R}                  {DGR}│{R}")
            print(f" {DGR}│{R}    {MG}~ XyraOfficial ~{R}                   {DGR}│{R}")
            print(f" {DGR}└──────────────────────────────────────┘{R}")
            print()
            break
        else:
            error("Pilihan tidak valid")
        
        print()
        input(f" {D}Tekan Enter...{R}")
