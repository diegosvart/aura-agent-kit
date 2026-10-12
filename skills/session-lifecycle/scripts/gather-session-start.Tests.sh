#!/usr/bin/env bash
# gather-session-start.Tests.sh — Issue #345
# Cubre los 4 bugs: contrato JSON con claves vacías, ideas_count, staleness de develop local.
set -uo pipefail

RED='\033[0;31m'; GREEN='\033[0;32m'; NC='\033[0m'
test_count=0; pass_count=0; fail_count=0

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPT="$SCRIPT_DIR/gather-session-start.sh"
FIXTURE="$(mktemp -d)"
trap 'rm -rf "$FIXTURE"' EXIT

mkdir -p "$FIXTURE/bin"
printf '#!/usr/bin/env bash\nexit 1\n' > "$FIXTURE/bin/gh"
chmod +x "$FIXTURE/bin/gh"

check() {
    test_count=$((test_count + 1))
    if [ "$2" = "0" ]; then
        echo -e "${GREEN}✓ PASS${NC} — $1"; pass_count=$((pass_count + 1))
    else
        echo -e "${RED}✗ FAIL${NC} — $1"; fail_count=$((fail_count + 1))
    fi
}

setup_repo() {
    local name="$1"
    local base="$FIXTURE/$name"
    git init -q --bare "$base/origin.git"
    git init -q "$base/work"
    (
        cd "$base/work"
        git config user.email t@t; git config user.name t; git config commit.gpgsign false
        git checkout -q -b develop
        git remote add origin "$base/origin.git"
        git commit -q --allow-empty -m "c1"
        git push -q origin develop
    )
    echo "$base/work"
}

run_script() {
    (cd "$1" && PATH="$FIXTURE/bin:$PATH" bash "$SCRIPT" fake/repo 2>/dev/null)
}

EXPECTED_KEYS="aura_submodule_initialized branch branches_gone branches_merged_local branches_merged_remote detected_stack gh_active_account gh_authenticated git_diff_stat git_log_latest git_log_recent git_status_short harness_current_version harness_latest_version harness_update_available hooks_status ideas_count issues_ready open_prs repo_classification repo_integrity_messages repo_name repo_topics repo_visibility session_stack session_stack_exists stash_count stash_list stranded_candidates"

# --- Punto 5: contrato JSON — todas las claves presentes aunque el valor sea vacío
work=$(setup_repo contrato)
out=$(run_script "$work")
missing=""
for k in $EXPECTED_KEYS; do
    printf '%s' "$out" | grep -q "\"$k\":" || missing="$missing $k"
done
[ -z "$missing" ]; check "JSON incluye todas las claves del schema (faltan:${missing:- ninguna})" "$?"

# --- Punto 4: ideas_count lee .agent/memory/ideas.md
work=$(setup_repo ideas)
mkdir -p "$work/.agent/memory"
printf '## [001] a\n\n## [002] b\n' > "$work/.agent/memory/ideas.md"
out=$(run_script "$work")
printf '%s' "$out" | grep -q '"ideas_count": "2"'; check "ideas_count cuenta las ideas de .agent/memory/ideas.md" "$?"

work=$(setup_repo ideas-cero)
mkdir -p "$work/.agent/memory"
printf '# Ideas\n' > "$work/.agent/memory/ideas.md"
out=$(run_script "$work")
printf '%s' "$out" | grep -q '"ideas_count": "0"'; check "ideas_count es 0 (sin duplicar) con ideas.md sin entradas" "$?"

# --- Punto 2: develop local desactualizado respecto de origin/develop
work=$(setup_repo stale)
(
    cd "$work"
    c1=$(git rev-parse develop)
    git checkout -q -b feat-x
    git commit -q --allow-empty -m "c2"
    git push -q origin feat-x:develop
    git update-ref refs/remotes/origin/develop "$c1"
    git checkout -q develop
)
out=$(run_script "$work")
printf '%s' "$out" | grep -q '"branches_merged_local": "feat-x"'; check "branches_merged_local usa origin/develop actualizado por fetch" "$?"

# --- Punto 2: sin origin/develop, cae al develop local
work="$FIXTURE/sin-origin"
git init -q "$work"
(
    cd "$work"
    git config user.email t@t; git config user.name t; git config commit.gpgsign false
    git checkout -q -b develop
    git commit -q --allow-empty -m "c1"
    git branch feat-y
)
out=$(run_script "$work")
printf '%s' "$out" | grep -q '"branches_merged_local": "feat-y"'; check "sin origin/develop, branches_merged_local usa develop local" "$?"

echo ""
echo "Total: $test_count  Pass: $pass_count  Fail: $fail_count"
[ $fail_count -eq 0 ]
