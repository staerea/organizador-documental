#!/usr/bin/env bash
# Ejecuta todas las pruebas sobre dist/ en un directorio temporal. Requiere pwsh 7 y python3 (reportlab para test_m14).
set -u
REPO="$(cd "$(dirname "$0")/.." && pwd)"; PWSH="${PWSH:-pwsh}"
command -v "$PWSH" >/dev/null || PWSH=/tmp/pwsh/pwsh
W="$(mktemp -d)"; cp "$REPO"/tests/prueba*.ps1 "$W"/; cd "$W"
export OD_DIST="$REPO/dist"; ok=0; fallo=0
for t in prueba prueba2 prueba3 prueba4 prueba5 prueba6 prueba7 prueba8 prueba9 prueba10 prueba11; do
  out="$("$PWSH" -NoProfile -File "$t.ps1" 2>&1)"
  o=$(grep -cE ' OK$' <<<"$out"); f=$(grep -cE 'FALLO$' <<<"$out")
  ok=$((ok+o)); fallo=$((fallo+f)); echo "$t: $o OK, $f FALLO"; grep -E 'FALLO$' <<<"$out"
done
out="$(python3 "$REPO/tests/test_m12.py")"; o=$(grep -cE ' OK$' <<<"$out"); f=$(grep -cE 'FALLO$' <<<"$out")
ok=$((ok+o)); fallo=$((fallo+f)); echo "test_m12: $o OK, $f FALLO"
out="$(python3 "$REPO/tests/test_m14.py")"; o=$(grep -cE ' OK$' <<<"$out"); f=$(grep -cE 'FALLO$' <<<"$out")
ok=$((ok+o)); fallo=$((fallo+f)); echo "test_m14: $o OK, $f FALLO"
echo "TOTAL: $ok OK, $fallo FALLO"; rm -rf "$W"; [ "$fallo" -eq 0 ]
