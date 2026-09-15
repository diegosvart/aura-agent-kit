#!/usr/bin/env bash
# classify-branch.Tests.sh — Tests para classify-branch.sh (Issue #285, bug #2)
# Bug: el Paso B solo miraba el primer match de Closes/Fixes/Resolves #N de los commits
# exclusivos de la rama, pudiendo clasificar una rama como CLEAN sin ver un issue mas viejo
# cerrado sin PR mergeada (STRANDED).

set -uo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'

test_count=0
pass_count=0
fail_count=0

SCRIPT_PATH="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/classify-branch.sh"

# gh fake: lee ISSUE_STATES y MERGED_PRS (formato "N:STATE N:STATE") desde variables de
# entorno para simular respuestas de gh issue view / gh pr list sin red real.
setup_fake_gh() {
    local bin_dir=$1
    cat > "$bin_dir/gh" << 'FAKE_GH'
#!/usr/bin/env bash
if [ "$1" = "issue" ] && [ "$2" = "view" ]; then
    issue_n="$3"
    for pair in $ISSUE_STATES; do
        n="${pair%%:*}"
        state="${pair##*:}"
        if [ "$n" = "$issue_n" ]; then
            echo "$state"
            exit 0
        fi
    done
    exit 1
fi
if [ "$1" = "pr" ] && [ "$2" = "list" ]; then
    for pair in $MERGED_PRS; do
        n="${pair%%:*}"
        pr="${pair##*:}"
        echo "$pr"
    done
    exit 0
fi
exit 1
FAKE_GH
    chmod +x "$bin_dir/gh"
}

run_test() {
    local test_name=$1
    local commit_messages=$2
    local issue_states=$3
    local merged_prs=$4
    local expected_output=$5

    test_count=$((test_count + 1))

    local fixture_dir
    fixture_dir="$(dirname "$SCRIPT_PATH")/.tmp-test-fixture-$$-$test_count"
    mkdir -p "$fixture_dir/bin"
    setup_fake_gh "$fixture_dir/bin"

    (
        cd "$fixture_dir"
        git init -q
        git config user.email "test@example.com"
        git config user.name "Test User"
        git config core.autocrlf false
        echo base > base.txt
        git add base.txt
        git commit -q -m "base"
        git branch -q develop

        git checkout -q -b feature-branch
        local i=0
        while IFS= read -r msg; do
            i=$((i + 1))
            echo "change $i" > "file$i.txt"
            git add "file$i.txt"
            git commit -q -m "commit $i" -m "$msg"
        done <<< "$commit_messages"

        PATH="$fixture_dir/bin:$PATH" ISSUE_STATES="$issue_states" MERGED_PRS="$merged_prs" \
            "$SCRIPT_PATH" "fake/repo" "feature-branch"
    ) > "$fixture_dir/output.txt" 2>&1
    output=$(cat "$fixture_dir/output.txt")
    rm -rf "$fixture_dir"

    if [ "$output" = "$expected_output" ]; then
        echo -e "${GREEN}✓ PASS${NC} — $test_name"
        pass_count=$((pass_count + 1))
    else
        echo -e "${RED}✗ FAIL${NC} — $test_name"
        echo "  Expected: $expected_output"
        echo "  Got:      $output"
        fail_count=$((fail_count + 1))
    fi
}

run_test "issue mas viejo (no el mas reciente) cerrado sin PR debe reportar STRANDED" \
"Closes #20
Closes #10" \
"10:OPEN 20:CLOSED" \
"" \
"STRANDED:20"

run_test "unico issue referenciado, abierto, sigue CLEAN:issue-open" \
"Closes #10" \
"10:OPEN" \
"" \
"CLEAN:issue-open:10"

run_test "unico issue referenciado, cerrado con PR mergeada, sigue CLEAN:merged" \
"Closes #10" \
"10:CLOSED" \
"10:42" \
"CLEAN:merged:10:42"

run_test "multiples issues, todos cerrados con PR mergeada, CLEAN:merged" \
"Closes #10
Fixes #20" \
"10:CLOSED 20:CLOSED" \
"10:42 20:43" \
"CLEAN:merged:20:42"

echo ""
echo "=== Resumen de tests ==="
echo "Total: $test_count"
echo -e "${GREEN}Pass: $pass_count${NC}"
echo -e "${RED}Fail: $fail_count${NC}"

if [ $fail_count -ne 0 ]; then
    exit 1
fi
exit 0
