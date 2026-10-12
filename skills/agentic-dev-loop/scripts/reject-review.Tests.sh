#!/usr/bin/env bash
# reject-review.Tests.sh — Issue #352
# Contrato entre reject-review.sh y resolve-tier.sh: el rechazo deja un marcador legible por
# maquina en un comentario, y es el mismo literal que resolve-tier.sh cuenta.
set -uo pipefail

RED='\033[0;31m'; GREEN='\033[0;32m'; NC='\033[0m'
test_count=0; pass_count=0; fail_count=0

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FIXTURE="$SCRIPT_DIR/.tmp-test-rejectreview-$$"
trap 'rm -rf "$FIXTURE"' EXIT
mkdir -p "$FIXTURE/bin"

cat > "$FIXTURE/bin/gh" << 'FAKE'
#!/usr/bin/env bash
printf '%s\n' "ARGS: $*" >> "$GH_LOG_FILE"
if [ "$1" = "issue" ] && [ "$2" = "view" ]; then echo "OPEN"; fi
exit 0
FAKE
chmod +x "$FIXTURE/bin/gh"
export GH_LOG_FILE="$FIXTURE/gh.log"; : > "$GH_LOG_FILE"

PATH="$FIXTURE/bin:$PATH" bash "$SCRIPT_DIR/reject-review.sh" fake/repo 42 >/dev/null 2>&1
rc=$?

check() {
    test_count=$((test_count + 1))
    if [ "$2" = "0" ]; then
        echo -e "${GREEN}✓ PASS${NC} — $1"; pass_count=$((pass_count + 1))
    else
        echo -e "${RED}✗ FAIL${NC} — $1"; fail_count=$((fail_count + 1))
    fi
}

check "reject-review.sh termina con exit 0" "$rc"
grep -q 'issue edit 42 .*--add-label changes-requested' "$GH_LOG_FILE"; check "sigue marcando changes-requested" "$?"
grep -q 'issue comment 42 --repo fake/repo --body <!-- aura:verifier-reject -->' "$GH_LOG_FILE"; check "publica un comentario con el marcador" "$?"
marker='<!-- aura:verifier-reject -->'
grep -qF "REJECT_MARKER='$marker'" "$SCRIPT_DIR/resolve-tier.sh"; check "resolve-tier.sh cuenta el mismo marcador" "$?"

echo ""
echo "Total: $test_count  Pass: $pass_count  Fail: $fail_count"
[ $fail_count -eq 0 ]
