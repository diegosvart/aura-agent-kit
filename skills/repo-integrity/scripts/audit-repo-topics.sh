#!/usr/bin/env bash
# audit-repo-topics.sh
# Audita los repos del usuario contra la convencion de topics de GitHub documentada en
# agents/github.md -> "Convencion de Topics de GitHub" (Issue #201): senala repos personales
# sin topic de ownership, repos bajo una org corporativa cuyo nombre no sigue
# <empresa>-<proyecto>, y repos sin ningun topic de dominio/stack.
#
# Requiere gh autenticado (usa el motor --jq embebido de gh, no depende del binario jq del
# sistema — mismo patron que check-base-branch.sh).
#
# NO modifica nada -- solo informa (mismo patron que check-orphaned-worktrees.sh). La
# aplicacion real de topics (gh repo edit --add-topic) o el ajuste de nombre la decide el
# usuario. Exit code: 0 siempre (informativo, nunca bloqueante).
set -uo pipefail

DOMAIN_TOPICS="frontend backend automation ml mobile infra fullstack cli data"

command -v gh >/dev/null 2>&1 || { echo "gh no disponible — abortando auditoria"; exit 0; }
gh auth status >/dev/null 2>&1 || { echo "gh no autenticado — abortando auditoria"; exit 0; }

rows=$(gh repo list --json name,owner,repositoryTopics,isInOrganization --limit 200 \
  --jq '.[] | [.owner.login, .name, .isInOrganization, ((.repositoryTopics // []) | [.[].name] | join(","))] | @tsv' \
  2>/dev/null)

[ -z "$rows" ] && { echo "sin repos listados (o gh repo list fallo)"; exit 0; }

while IFS=$'\t' read -r owner name inOrg topicsCsv; do
    [ -z "$name" ] && continue

    hasOwnershipTopic=false
    hasDomainTopic=false
    IFS=',' read -ra topicsArr <<< "$topicsCsv"
    for t in "${topicsArr[@]}"; do
        [ -z "$t" ] && continue
        if [ "$t" = "personal" ] || [[ "$t" == *-copropiedad ]]; then
            hasOwnershipTopic=true
        fi
        for d in $DOMAIN_TOPICS; do
            [ "$t" = "$d" ] && hasDomainTopic=true
        done
    done

    if [ "$inOrg" != "true" ] && [ "$hasOwnershipTopic" = "false" ]; then
        echo "MISSING-OWNERSHIP-TOPIC: $owner/$name — sin topic personal|<empresa>-copropiedad"
    fi

    ownerLower=$(echo "$owner" | tr '[:upper:]' '[:lower:]')
    if [ "$inOrg" = "true" ] && [[ "$name" != "$ownerLower-"* ]]; then
        echo "NAMING-CONVENTION: $owner/$name — no sigue el patron <empresa>-<proyecto> (solo reporte, no se renombra)"
    fi

    if [ "$hasDomainTopic" = "false" ]; then
        echo "MISSING-DOMAIN-TOPIC: $owner/$name — sin topic de dominio/stack (frontend|backend|automation|ml|...)"
    fi
done <<< "$rows"
