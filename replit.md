# Termux Auth System

## Overview

A Termux-based authentication system with email OTP verification. The project uses Cython to compile Python code into protected `.so` binaries, making it harder to reverse-engineer. The system provides user signup and login functionality with Supabase as the backend authentication service and SMTP for email-based OTP delivery.

## User Preferences

Preferred communication style: Simple, everyday language.

## Project Structure

```
encrypt/                    # PRIVATE - Developer only
├── termux_auth_core.pyx    # Source code (Cython)
├── setup.py                # Build configuration
├── setup_termux.sh         # Termux compilation script
├── encrypt_config.py       # Config encryption tool
├── config.json             # Plain config (DO NOT DISTRIBUTE)
└── config.enc              # Encrypted config

run/                        # PUBLIC - For distribution
├── run.py                  # Launcher with auto-dependency install
├── config.enc              # Encrypted config (safe to distribute)
├── termux_auth_lib*.so     # Compiled binary (ARM for Termux)
└── README.txt              # User guide
```

## System Architecture

### Build System
- **Cython Compilation**: Core authentication logic is written in `termux_auth_core.pyx` and compiled to a native `.so` library (`termux_auth_lib`)
- **Purpose**: Code obfuscation and anti-decompilation protection for the authentication system
- **Build Process**: Uses setuptools with Cython extensions, optimized with `-O3` and `-fPIC` compiler flags
- **Distribution Model**: Distributes compiled `.so` files instead of source code to protect intellectual property
- **Architecture**: `.so` files are architecture-specific - must compile on Termux (ARM) for Android distribution

### Application Entry Point
- **Launcher**: `run.py` serves as the main entry point with:
  - Automatic dependency checking and installation
  - Architecture compatibility detection
  - Config encryption validation
- **Fallback Handling**: Provides clear error messages for missing modules, wrong architecture, missing config

### Configuration Management
- **Encrypted Config**: `config.enc` stores encrypted credentials using AES-Fernet (TXAUTH02) or PBKDF2-XOR fallback (TXAUTH01)
- **Encryption Tool**: `encrypt/encrypt_config.py` encrypts `config.json` to `config.enc`
- **Configuration Schema**:
  - `supabase_url`: Supabase project endpoint
  - `supabase_key`: Supabase anonymous key for API access
  - `smtp_email`: Gmail address for sending OTP emails
  - `smtp_app_password`: Gmail app-specific password for SMTP authentication

### Security Notes
- **Obfuscation Level**: Config encryption protects against casual users viewing credentials
- **Limitation**: Encryption keys are embedded in the `.so` binary; skilled attackers with reverse-engineering tools can potentially extract them
- **Best Practice**: This is adequate for casual protection but not suitable for high-security environments

### UI/UX Features
- **Terminal Animations**: Includes animated text, spinner, and progress bar utilities for enhanced user experience
- **Color-Coded Output**: Uses ANSI color codes for visual feedback (errors in red, success in green, info in cyan, etc.)
- **Interactive Input**: Password masking with `getpass` for secure credential entry

### Authentication Flow
- **OTP System**: 
  - Generates time-limited OTP codes (300 second expiry)
  - Stores OTP data in `otp_data.json`
  - Email delivery via SMTP
- **Validation**: Email format validation using regex patterns

### Admin System
- **Admin Login**: Hardcoded credentials (username: xyraofficial, password: admin)
- **Admin Panel Features**:
  - List Users - View all registered users in table format
  - Detail User - View detailed info for specific user by UID
  - Delete User - Remove user from database with confirmation
  - Database Stats - View user statistics (total, verified, unverified)
- **Admin API**: Uses Supabase service_key for admin operations (list_users, delete_user, get_user)

## External Dependencies

### Backend Services
- **Supabase**: Primary authentication backend
  - Project URL: `https://feesaxvfbgsgbrncbgpd.supabase.co`
  - Handles user account management and authentication state

### Email Service
- **SMTP (Gmail)**: Used for OTP email delivery
  - Server: Gmail SMTP (implicit from app password usage)
  - Requires app-specific password for authentication
  - Sends OTP codes via MIMEText/MIMEMultipart email formatting

### Python Packages
- **Cython**: Compiles Python code to C extensions for obfuscation
- **setuptools**: Build system for creating distributable packages
- **requests**: HTTP client for Supabase API communication
- **cryptography**: AES-Fernet encryption for config protection
- **smtplib**: Standard library for SMTP email sending
- **email.mime**: Email composition utilities
- **tabulate**: Table formatting for developer info display
- **rich**: Rich text and beautiful formatting in terminal
- **simple-term-menu**: Interactive terminal menu selection
- **tqdm**: Progress bar animations

### Platform
- **Termux**: Android terminal emulator and Linux environment
  - Setup automation via `setup_termux.sh`
  - Native compilation toolchain for ARM/ARM64 architectures

## Distribution Workflow

1. **Developer (encrypt/ folder)**:
   - Edit `config.json` with credentials
   - Run `python encrypt_config.py` to create `config.enc`
   - Compile on Termux: `bash setup_termux.sh`
   - Copy `.so` and `config.enc` to `run/` folder

2. **User (run/ folder)**:
   - Install Python in Termux
   - Run `python run.py` (dependencies auto-install)
