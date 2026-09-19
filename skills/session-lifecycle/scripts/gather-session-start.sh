#!/usr/bin/env bash
# Session Start — Gathering determinístico (Paso 2 de protocols/session_start.md)
# Ejecuta todos los comandos de git/gh/filesystem en la tabla y emite UN único JSON.
# Patrón: lógica determinística en script (P1: CLI > MCP), output consumible por orquestador.
# Uso: gather-session-start.sh [<owner>/<repo>]
# Si no se proporciona <owner>/<repo>, se intenta detectar automáticamente.

set -euo pipefail

# Helper: escapar string para JSON (sin jq)
json_escape() {
  local s="$1"
  # Escapar comillas, backslash, newlines, tabs, etc.
  s="${s//\\/\\\\}"      # backslash first
  s="${s//\"/\\\"}"      # double quote
  s="${s//$'\n'/\\n}"    # newline
  s="${s//$'\r'/\\r}"    # carriage return
  s="${s//$'\t'/\\t}"    # tab
  printf '%s' "$s"
}

json_string() {
  printf '"%s"' "$(json_escape "$1")"
}

json_object_start() {
  printf '{'
}

json_object_end() {
  printf '}'
}

json_field() {
  local key="$1"
  local value="$2"
  local separator="${3:-,}"
  printf '"%s":%s%s' "$key" "$value" "$separator"
}

# Detectar <owner>/<repo> si no se proporciona
REPO="${1:-}"
if [ -z "$REPO" ]; then
  if git rev-parse --git-dir >/dev/null 2>&1; then
    # Intentar extraer del remoto 'origin'
    REPO=$(git remote get-url origin | sed -n 's/.*github\.com[:/]\([^/]*\/[^/]*\)\.git$/\1/p')
    if [ -z "$REPO" ]; then
      REPO=$(git remote get-url origin | sed -n 's/.*\/\([^/]*\/[^/]*\)$/\1/p')
    fi
  fi
  if [ -z "$REPO" ]; then
    echo '{"error": "Cannot detect repo. Provide <owner>/<repo> as argument."}' >&2
    exit 1
  fi
fi

# Detener acá si no estamos en un git repo
if ! git rev-parse --git-dir >/dev/null 2>&1; then
  echo '{"error": "Not a git repository."}' >&2
  exit 1
fi

PROJECT_ROOT=$(git rev-parse --show-toplevel)
cd "$PROJECT_ROOT"

# Iniciar recolección JSON
declare -A data

# 1. Rama y estado de git
current_branch=$(git branch --show-current)
git_status_output=$(git status --short)
git_diff_stat=$(git diff --stat 2>/dev/null || echo "")
git_log_oneline=$(git log --oneline -1 2>/dev/null || echo "")
git_log_3=$(git log --oneline -3 2>/dev/null || echo "")

data[branch]="$current_branch"
data[git_status_short]="$git_status_output"
data[git_diff_stat]="$git_diff_stat"
data[git_log_latest]="$git_log_oneline"
data[git_log_recent]="$git_log_3"

# 2. Config de hooks nativos
hooks_path=$(git config --get core.hooksPath 2>/dev/null || echo "")
if [ -d .githooks ]; then
  if [ -z "$hooks_path" ]; then
    hooks_status="detected_not_configured"
  else
    hooks_status="configured"
  fi
else
  hooks_status="not_found"
fi
data[hooks_status]="$hooks_status"

# 3. Init de submódulo .aura si quedó vacío
aura_submodule_initialized="false"
if [ -d .aura ] && [ -z "$(ls -A .aura 2>/dev/null || echo)" ]; then
  git submodule update --init .aura >/dev/null 2>&1 || true
  aura_submodule_initialized="true"
fi
data[aura_submodule_initialized]="$aura_submodule_initialized"

# 4. Autenticación de GitHub
gh_auth_status="false"
gh_active_account=""
if gh auth status --hostname github.com >/dev/null 2>&1; then
  gh_auth_status="true"
  gh_active_account=$(gh auth status --active 2>/dev/null | grep 'Logged in to github.com' | awk '{print $NF}' || echo "unknown")
fi
data[gh_authenticated]="$gh_auth_status"
data[gh_active_account]="$gh_active_account"

# 5-6. Nombre, topics y visibilidad del repo
repo_name=""
repo_topics=""
repo_visibility=""
if [ "$gh_auth_status" = "true" ]; then
  repo_name=$(gh repo view --repo "$REPO" --json name --jq '.name' 2>/dev/null || echo "")
  repo_topics_json=$(gh repo view --repo "$REPO" --json repositoryTopics --jq '.repositoryTopics | map(.name) | @csv' 2>/dev/null || echo "")
  repo_topics="${repo_topics_json//\"/}"  # Remover comillas
  repo_visibility=$(gh repo view --repo "$REPO" --json visibility --jq '.visibility' 2>/dev/null || echo "")
fi
data[repo_name]="$repo_name"
data[repo_topics]="$repo_topics"
data[repo_visibility]="$repo_visibility"

# 7. Stash pendiente
stash_list=$(git stash list)
stash_count=$(echo "$stash_list" | wc -l | xargs)
if [ "$stash_count" -eq 0 ] || [ -z "$stash_list" ]; then
  data[stash_count]="0"
  data[stash_list]=""
else
  data[stash_count]="$stash_count"
  data[stash_list]="$stash_list"
fi

# 8. Salud de ramas
merged_local=$(git branch --merged develop --format='%(refname:short)' 2>/dev/null | grep -v '^\*\|main\|develop' | xargs || echo "")
merged_remote=$(git branch -r --merged origin/develop --format='%(refname:short)' 2>/dev/null | grep -v 'origin/HEAD\|origin/main\|origin/develop' | xargs || echo "")
gone_branches=$(git branch -vv 2>/dev/null | grep ': gone]' | awk '{print $1}' | xargs || echo "")

data[branches_merged_local]="$merged_local"
data[branches_merged_remote]="$merged_remote"
data[branches_gone]="$gone_branches"

# 9. PRs abiertas
open_prs_json="[]"
if [ "$gh_auth_status" = "true" ]; then
  open_prs_json=$(gh pr list --repo "$REPO" --state open --json number,title,headRefName,baseRefName,mergeable --limit 20 2>/dev/null || echo "[]")
fi
data[open_prs]="$open_prs_json"

# 10. Issues ready
issues_ready_json="[]"
if [ "$gh_auth_status" = "true" ]; then
  issues_ready_json=$(gh issue list --repo "$REPO" --label ready --state open --json number,title --limit 20 2>/dev/null || echo "[]")
fi
data[issues_ready]="$issues_ready_json"

# 11-12. Detección de stack y session-stack.json
detected_stack="null"
if [ -f pyproject.toml ] || [ -f setup.py ]; then
  detected_stack="python"
elif [ -f package.json ]; then
  detected_stack="node"
elif [ -f Cargo.toml ]; then
  detected_stack="rust"
elif [ -f go.mod ]; then
  detected_stack="go"
fi
data[detected_stack]="$detected_stack"

session_stack_exists="false"
session_stack_content=""
if [ -f .agent/memory/session-stack.json ]; then
  session_stack_exists="true"
  session_stack_content=$(cat .agent/memory/session-stack.json 2>/dev/null || echo "")
fi
data[session_stack_exists]="$session_stack_exists"
data[session_stack]="$session_stack_content"

# 13. 5 scripts de repo-integrity (fail-silent si no imprimen nada)
repo_integrity_messages=()
for script in \
  "skills/repo-integrity/scripts/check-release-drift.sh" \
  "skills/repo-integrity/scripts/check-repo-manifest.sh" \
  "skills/repo-integrity/scripts/check-base-branch.sh" \
  "skills/repo-integrity/scripts/check-orphaned-worktrees.sh"; do
  if [ -f "$script" ]; then
    msg=$(bash "$script" 2>/dev/null || true)
    if [ -n "$msg" ]; then
      repo_integrity_messages+=("$msg")
    fi
  fi
done

# Agent frontmatter check (específico: filtra agents/*.md)
if [ -f "skills/repo-integrity/scripts/check-agent-frontmatter.sh" ]; then
  msg=$(bash "skills/repo-integrity/scripts/check-agent-frontmatter.sh" agents/*.md 2>/dev/null | grep -v '^OK:' || true)
  if [ -n "$msg" ]; then
    repo_integrity_messages+=("$msg")
  fi
fi

repo_integrity_output='[]'
if [ ${#repo_integrity_messages[@]} -gt 0 ]; then
  repo_integrity_output="["
  for i in "${!repo_integrity_messages[@]}"; do
    if [ $i -gt 0 ]; then repo_integrity_output="$repo_integrity_output,"; fi
    repo_integrity_output="$repo_integrity_output$(json_string "${repo_integrity_messages[$i]}")"
  done
  repo_integrity_output="$repo_integrity_output]"
fi
data[repo_integrity_messages]="$repo_integrity_output"

# 14. Candidatos a trabajo stranded (ramas ahead de develop con Closes/Fixes/Resolves)
stranded_candidates=()
if [ "$gh_auth_status" = "true" ]; then
  for branch in $(git branch --format='%(refname:short)' 2>/dev/null | grep -v 'develop\|main'); do
    commits=$(git log develop.."$branch" --format=%B 2>/dev/null || echo "")
    if echo "$commits" | grep -qi 'Closes\|Fixes\|Resolves'; then
      stranded_candidates+=("$branch")
    fi
  done
fi
stranded_json="["
for i in "${!stranded_candidates[@]}"; do
  if [ $i -gt 0 ]; then stranded_json="$stranded_json,"; fi
  stranded_json="$stranded_json$(json_string "${stranded_candidates[$i]}")"
done
stranded_json="$stranded_json]"
data[stranded_candidates]="$stranded_json"

# 15. Ideas en backlog
ideas_count=0
if [ -f ideas.md ]; then
  ideas_count=$(grep -c '^## \[' ideas.md || echo 0)
fi
data[ideas_count]="$ideas_count"

# 16. Update del harness disponible (simplificado — solo .aura tag local vs remoto)
harness_update_available="false"
harness_latest_version=""
harness_current_version=""
if [ -d .aura/.git ]; then
  current_tag=$(cd .aura && git describe --tags 2>/dev/null || echo "unknown")
  latest_tag=$(cd .aura && git fetch --tags >/dev/null 2>&1 && git describe --tags origin/HEAD 2>/dev/null || echo "unknown")
  if [ "$current_tag" != "$latest_tag" ] && [ "$latest_tag" != "unknown" ]; then
    harness_update_available="true"
    harness_latest_version="$latest_tag"
    harness_current_version="$current_tag"
  fi
fi
data[harness_update_available]="$harness_update_available"
data[harness_latest_version]="$harness_latest_version"
data[harness_current_version]="$harness_current_version"

# 17. Clasificación de repo (Issue #303)
repo_classification=""
if [ -f .agent/memory/repo-classification.json ]; then
  repo_classification=$(cat .agent/memory/repo-classification.json 2>/dev/null || echo "")
fi
data[repo_classification]="$repo_classification"

# Construir y emitir JSON final (sin jq, ordenado alfabéticamente por clave)
# Nota: bash associative arrays no mantienen orden, así que sortearemos manualmente
declare -a json_keys=(
  "aura_submodule_initialized"
  "branch"
  "branches_gone"
  "branches_merged_local"
  "branches_merged_remote"
  "detected_stack"
  "gh_active_account"
  "gh_authenticated"
  "git_diff_stat"
  "git_log_latest"
  "git_log_recent"
  "git_status_short"
  "harness_current_version"
  "harness_latest_version"
  "harness_update_available"
  "hooks_status"
  "ideas_count"
  "issues_ready"
  "open_prs"
  "repo_classification"
  "repo_integrity_messages"
  "repo_name"
  "repo_topics"
  "repo_visibility"
  "session_stack"
  "session_stack_exists"
  "stash_count"
  "stash_list"
  "stranded_candidates"
)

printf '{\n'
first=true
for key in "${json_keys[@]}"; do
  if [ -n "${data[$key]:-}" ]; then
    if [ "$first" = true ]; then
      first=false
    else
      printf ',\n'
    fi
    # Detectar si el valor es un JSON object/array (comienza con { o [)
    value="${data[$key]}"
    if [[ "$value" =~ ^[\[\{] ]]; then
      printf '  "%s": %s' "$key" "$value"
    else
      printf '  "%s": %s' "$key" "$(json_string "$value")"
    fi
  fi
done
printf '\n}\n'
