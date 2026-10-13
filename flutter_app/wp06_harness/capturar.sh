#!/bin/zsh
# Uso: capturar.sh <nome> <perfil> <cenario> <w> <h> [auto]
CHROME="/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"
OUT="${WP06_EVIDENCE_DIR:-/Users/usuario/eqp_maanaim/_bmad-output/planning-artifacts/ux/UX-REF-001-evidence}"
mkdir -p "$OUT"
nome=$1; p=$2; c=$3; w=$4; h=$5; auto=$6
tmp="$OUT/_tmp_$nome.png"
url="http://127.0.0.1:7357/?p=$p&c=$c&w=$w&h=$h"
[ -n "$auto" ] && url="$url&auto=$auto"
"$CHROME" --headless=new --disable-gpu --hide-scrollbars --window-size=$w,$h \
  --virtual-time-budget=60000 --enable-logging=stderr --v=0 \
  --screenshot="$tmp" "$url" 2>"$OUT/_log_$nome.txt" >/dev/null
mv "$tmp" "$OUT/${nome}_${w}x${h}.png"
grep -h "WP06 passo" "$OUT/_log_$nome.txt" | sed 's/.*WP06/WP06/' | tr '\n' ' '
echo "-> ${nome}_${w}x${h}.png"
