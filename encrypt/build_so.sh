#!/bin/bash

R='\033[0m'
G='\033[92m'
C='\033[96m'
Y='\033[93m'
B='\033[1m'

echo ""
echo -e "  ${C}╭──────────────────────────────────────╮${R}"
echo -e "  ${C}│${R}  ${B}KOMPILASI .SO ANTI-DECRYPT${R}          ${C}│${R}"
echo -e "  ${C}╰──────────────────────────────────────╯${R}"
echo ""

echo -e "  ${Y}[1/2]${R} Kompilasi Cython ke .so..."
python setup.py build_ext --inplace

if [ $? -eq 0 ]; then
    echo ""
    echo -e "  ${Y}[2/2]${R} Cleanup..."
    rm -f termux_auth_core.c
    rm -rf build/
    
    echo ""
    echo -e "  ${G}✓${R} Kompilasi berhasil!"
    echo ""
    echo -e "  ${B}File .so:${R}"
    ls -la termux_auth_lib*.so 2>/dev/null || echo "    (cek manual dengan: ls *.so)"
    echo ""
    echo -e "  ${B}Cara menjalankan:${R}"
    echo -e "    python run.py"
    echo ""
else
    echo ""
    echo -e "  ${R}✗${R} Kompilasi gagal!"
    echo ""
fi
