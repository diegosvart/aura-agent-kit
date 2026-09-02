#!/usr/bin/env bash
# Encapsula el Proceso de Release de agents/github.md (seccion "Proceso de Release (tag) -
# sync-back obligatorio") en pasos idempotentes e invocables por separado, en vez de que el
# agente reconstruya la secuencia razonando cada vez. Nace de 2 incidentes reales: el drift de
# v2.2.0 fuera de la ancestria de develop (paso de sync-back omitido), y el bloqueo repetido de
# git-guard.ps1 al publicar el tag estando parado en main (releases v2.2.0 y v2.2.1). Ver
# Issue #136.
#
# git-guard.ps1 exime la invocacion literal de este script (no la sintaxis de git en si) para
# permitir que el paso "tag" publique el tag estando en main/develop -- la precision real de
# que ese push no mueva commits de la rama protegida sigue siendo .githooks/pre-push, que este
# script no bypasea ni necesita bypasear.
#
# El contenido del CHANGELOG.md (que se agrega, en que lenguaje) es redaccion humana/LLM y no
# lo genera este script -- solo valida que exista antes de continuar.
set -euo pipefail

usage() {
  echo "Uso: cut-release.sh <changelog-pr|promote|tag|sync-back> <owner>/<repo> <version> [args]" >&2
  exit 1
}

SUBCOMMAND="${1:?$(usage)}"
REPO="${2:?$(usage)}"
VERSION="${3:?$(usage)}"

case "$SUBCOMMAND" in

  changelog-pr)
    if ! git branch --show-current | grep -qx "develop"; then
      echo "Debe correrse estando en 'develop'." >&2
      exit 1
    fi
    if ! grep -q "^## \[$VERSION\]" CHANGELOG.md; then
      echo "CHANGELOG.md no tiene una seccion '## [$VERSION]' -- agregala antes de correr este paso." >&2
      exit 1
    fi
    if git diff --quiet CHANGELOG.md && git diff --cached --quiet CHANGELOG.md; then
      echo "CHANGELOG.md no tiene cambios sin commitear -- nada que preparar." >&2
      exit 1
    fi

    branch="docs/changelog-$VERSION"
    if git show-ref --verify --quiet "refs/heads/$branch"; then
      echo "La rama '$branch' ya existe localmente." >&2
      exit 1
    fi

    git checkout -b "$branch"

    # Bump de .claude-plugin/plugin.json (sin el prefijo "v" del tag) -- sin esto el chequeo
    # de actualizacion para consumidores via plugin/marketplace (Issue #181) compara siempre
    # contra un numero de version que nunca cambia, porque el cache del marketplace de un
    # consumidor lee este mismo campo.
    if [ -f ".claude-plugin/plugin.json" ]; then
      plugin_version="${VERSION#v}"
      python3 - "$plugin_version" << 'PYTHON_PLUGIN_BUMP'
import json
import sys

version = sys.argv[1]
path = ".claude-plugin/plugin.json"
try:
    with open(path, "r", encoding="utf-8") as f:
        data = json.load(f)
    data["version"] = version
    with open(path, "w", encoding="utf-8") as f:
        json.dump(data, f, indent=2, ensure_ascii=False)
        f.write("\n")
except Exception as e:
    raise ValueError(f"No se pudo bumpear .claude-plugin/plugin.json: {e}") from e
PYTHON_PLUGIN_BUMP
      if [ $? -ne 0 ]; then
        echo "ERROR: Bump de .claude-plugin/plugin.json fallo" >&2
        exit 1
      fi
      git add .claude-plugin/plugin.json
    fi

    git add CHANGELOG.md
    git commit -m "docs(changelog): preparar $VERSION"
    git push -u origin "$branch"

    pr_output=$(gh pr create --repo "$REPO" --base develop --head "$branch" \
      --title "docs(changelog): preparar $VERSION" \
      --body "Prepara CHANGELOG.md para el release $VERSION. Parte del release completo (ver cut-release.sh promote/tag/sync-back)." 2>&1) || {
      echo "$pr_output" >&2
      exit 1
    }
    pr_number=$(echo "$pr_output" | grep -oE '/pull/[0-9]+' | grep -oE '[0-9]+' | tail -1)
    if [ -z "$pr_number" ]; then
      echo "gh pr create no devolvio un numero de PR reconocible. Output: $pr_output" >&2
      exit 1
    fi
    echo "$pr_number"
    ;;

  promote)
    CHANGELOG_PR="${4:?Uso: cut-release.sh promote <owner>/<repo> <version> <changelog_pr_n>}"

    pr_state=$(gh pr view "$CHANGELOG_PR" --repo "$REPO" --json state --jq '.state') || {
      echo "No se pudo consultar el PR #$CHANGELOG_PR en $REPO." >&2
      exit 1
    }
    if [ "$pr_state" != "MERGED" ]; then
      echo "PR #$CHANGELOG_PR (changelog) no esta mergeado (state=$pr_state) -- mergealo antes de promover." >&2
      exit 1
    fi

    git checkout develop
    git pull origin develop --ff-only

    pr_output=$(gh pr create --repo "$REPO" --base main --head develop \
      --title "chore(release): $VERSION" \
      --body "Ver CHANGELOG.md para el detalle. Proximo paso tras mergear: cut-release.sh tag $REPO $VERSION." 2>&1) || {
      echo "$pr_output" >&2
      exit 1
    }
    pr_number=$(echo "$pr_output" | grep -oE '/pull/[0-9]+' | grep -oE '[0-9]+' | tail -1)
    if [ -z "$pr_number" ]; then
      echo "gh pr create no devolvio un numero de PR reconocible. Output: $pr_output" >&2
      exit 1
    fi
    echo "$pr_number"
    ;;

  tag)
    RELEASE_PR="${4:?Uso: cut-release.sh tag <owner>/<repo> <version> <release_pr_n>}"

    pr_state=$(gh pr view "$RELEASE_PR" --repo "$REPO" --json state --jq '.state') || {
      echo "No se pudo consultar el PR #$RELEASE_PR en $REPO." >&2
      exit 1
    }
    if [ "$pr_state" != "MERGED" ]; then
      echo "PR #$RELEASE_PR (release) no esta mergeado (state=$pr_state) -- mergealo antes de taguear." >&2
      exit 1
    fi
    merge_commit=$(gh pr view "$RELEASE_PR" --repo "$REPO" --json mergeCommit --jq '.mergeCommit.oid')
    if [ -z "$merge_commit" ] || [ "$merge_commit" == "null" ]; then
      echo "No se pudo resolver el merge commit del PR #$RELEASE_PR." >&2
      exit 1
    fi

    if git rev-parse -q --verify "refs/tags/$VERSION" >/dev/null; then
      echo "El tag '$VERSION' ya existe localmente -- nada que hacer." >&2
      exit 1
    fi

    git checkout main
    git pull origin main --ff-only
    git tag -a "$VERSION" -m "$VERSION" "$merge_commit"
    git push origin "refs/tags/$VERSION"
    echo "$merge_commit"
    ;;

  sync-back)
    if ! git rev-parse -q --verify "refs/tags/$VERSION" >/dev/null; then
      echo "El tag '$VERSION' no existe localmente -- correr el paso 'tag' primero." >&2
      exit 1
    fi

    branch="chore/sync-back-$VERSION"
    if git show-ref --verify --quiet "refs/heads/$branch"; then
      echo "La rama '$branch' ya existe localmente." >&2
      exit 1
    fi

    git checkout develop
    git pull origin develop --ff-only
    git checkout -b "$branch"
    git merge main --no-edit
    git push -u origin "$branch"

    pr_output=$(gh pr create --repo "$REPO" --base develop --head "$branch" \
      --title "fix(release): sync-back main a develop tras $VERSION" \
      --body "Sync-back obligatorio tras cortar el tag $VERSION (ver agents/github.md -> Proceso de Release)." 2>&1) || {
      echo "$pr_output" >&2
      exit 1
    }
    pr_number=$(echo "$pr_output" | grep -oE '/pull/[0-9]+' | grep -oE '[0-9]+' | tail -1)
    if [ -z "$pr_number" ]; then
      echo "gh pr create no devolvio un numero de PR reconocible. Output: $pr_output" >&2
      exit 1
    fi
    echo "$pr_number"
    ;;

  *)
    usage
    ;;
esac
