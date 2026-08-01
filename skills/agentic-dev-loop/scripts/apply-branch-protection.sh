#!/usr/bin/env bash
# Encapsula el heredoc JSON de agents/github.md ("Aplicar protección (si falta)") que hoy el
# agente reconstruye de memoria -- operacion de seguridad real, alto riesgo si se arma mal el
# JSON. PUT es idempotente: correrlo repetido siempre deja la rama en el mismo estado deseado.
set -euo pipefail

REPO="${1:?Uso: apply-branch-protection.sh <owner>/<repo> <branch>}"
BRANCH="${2:?Uso: apply-branch-protection.sh <owner>/<repo> <branch>}"

tmp_json=$(mktemp)
trap 'rm -f "$tmp_json"' EXIT

cat > "$tmp_json" <<'EOF'
{
  "required_status_checks": null,
  "enforce_admins": false,
  "required_pull_request_reviews": {
    "required_approving_review_count": 0,
    "dismiss_stale_reviews": true
  },
  "restrictions": null,
  "allow_force_pushes": false,
  "allow_deletions": false,
  "required_linear_history": false
}
EOF

if ! gh api -X PUT "repos/$REPO/branches/$BRANCH/protection" --input "$tmp_json" >/dev/null; then
  echo "No se pudo aplicar la proteccion a '$BRANCH' en $REPO." >&2
  exit 1
fi

echo "Proteccion aplicada a '$BRANCH' en $REPO: require_pr=true (0 approvals), force_push=false, deletions=false."
