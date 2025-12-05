#!/bin/bash

R='\033[0m'
G='\033[92m'
C='\033[96m'
Y='\033[93m'
RD='\033[91m'
B='\033[1m'

echo ""
echo -e "  ${C}╭──────────────────────────────────────╮${R}"
echo -e "  ${C}│${R}  ${B}TERMUX AUTH SYSTEM - SETUP${R}          ${C}│${R}"
echo -e "  ${C}│${R}  ${Y}Kompilasi .so anti-decrypt${R}          ${C}│${R}"
echo -e "  ${C}╰──────────────────────────────────────╯${R}"
echo ""

echo -e "  ${Y}[1/6]${R} Update packages..."
pkg update -y && pkg upgrade -y

echo ""
echo -e "  ${Y}[2/6]${R} Install Python & build tools..."
pkg install python clang make -y

echo ""
echo -e "  ${Y}[3/6]${R} Install Python libraries..."
pip install requests cython setuptools

echo ""
echo -e "  ${Y}[4/6]${R} Kompilasi ke .so (anti-decrypt)..."
python setup.py build_ext --inplace

if [ $? -eq 0 ]; then
    echo ""
    echo -e "  ${Y}[5/6]${R} Pindahkan .so ke folder run..."
    mv termux_auth_lib*.so ../run/ 2>/dev/null || cp termux_auth_lib*.so ../run/
    
    echo ""
    echo -e "  ${Y}[6/6]${R} Cleanup file sumber..."
    rm -f termux_auth_core.c
    rm -rf build/
    
    echo ""
    echo -e "  ${C}╭──────────────────────────────────────╮${R}"
    echo -e "  ${C}│${R}  ${G}✓${R} KOMPILASI BERHASIL!               ${C}│${R}"
    echo -e "  ${C}╰──────────────────────────────────────╯${R}"
    echo ""
    echo -e "  ${B}Cara menjalankan:${R}"
    echo -e "    ${C}cd ../run${R}"
    echo -e "    ${C}python run.py${R}"
    echo ""
    echo -e "  ${B}Folder run berisi:${R}"
    ls -la ../run/
    echo ""
else
    echo ""
    echo -e "  ${C}╭──────────────────────────────────────╮${R}"
    echo -e "  ${C}│${R}  ${RD}✗${R} KOMPILASI GAGAL!                  ${C}│${R}"
    echo -e "  ${C}╰──────────────────────────────────────╯${R}"
    echo ""
    echo "  Pastikan semua dependencies terinstall."
    echo ""
fi
