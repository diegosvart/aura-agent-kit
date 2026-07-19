#!/usr/bin/env bash
# Fase 2, Paso 1 del skill agentic-dev-loop: lista issues en review sin razonamiento de agente.
set -euo pipefail

REPO="${1:?Uso: find-review-candidates.sh <owner>/<repo>}"

gh issue list --repo "$REPO" --label review --state open --json number,title
