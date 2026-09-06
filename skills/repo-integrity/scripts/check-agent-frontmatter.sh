#!/usr/bin/env bash
# Gate del PR de Issue #231: valida que un agents/*.md tenga frontmatter YAML mínimo
# (name/description/tools) y que description matchee el patrón "use proactively"/"use after"
# que Claude Code usa para auto-delegar subagentes. No requiere un parser YAML completo —
# mismo criterio de simplicidad que el resto de scripts de skills/repo-integrity (grep/awk
# sobre texto, no una dependencia nueva).
set -euo pipefail

if [ "$#" -eq 0 ]; then
  echo "Uso: check-agent-frontmatter.sh <archivo.md> [<archivo.md> ...]" >&2
  exit 1
fi

overall_fail=0

for f in "$@"; do
  if [ ! -f "$f" ]; then
    echo "MISSING-FILE: $f"
    overall_fail=1
    continue
  fi

  file_fail=0

  if [ "$(head -n1 "$f")" != "---" ]; then
    echo "NO-FRONTMATTER: $f"
    overall_fail=1
    continue
  fi

  frontmatter=$(awk '/^---$/{c++; next} c==1' "$f")

  name=$(echo "$frontmatter" | grep -E "^name:" || true)
  description=$(echo "$frontmatter" | grep -E "^description:" || true)
  tools=$(echo "$frontmatter" | grep -E "^tools:" || true)

  if [ -z "$name" ]; then
    echo "MISSING-FIELD: $f: name"
    file_fail=1
  fi

  if [ -z "$description" ]; then
    echo "MISSING-FIELD: $f: description"
    file_fail=1
  elif ! echo "$description" | grep -qiE "use (proactively|after)"; then
    echo "BAD-DESCRIPTION-PATTERN: $f: description debe incluir 'use proactively' o 'use after'"
    file_fail=1
  fi

  if [ -z "$tools" ]; then
    echo "MISSING-FIELD: $f: tools"
    file_fail=1
  fi

  if [ "$file_fail" -eq 0 ]; then
    echo "OK: $f"
  else
    overall_fail=1
  fi
done

exit "$overall_fail"
