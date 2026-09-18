#!/usr/bin/env bash
# Extrae la sección de CHANGELOG.md correspondiente a un tag de versión.
# VERSION_TAG llega con prefijo 'v' (ej. v2.7.0, siempre así desde check-update.sh),
# pero los headers de CHANGELOG.md no lo llevan (## [2.7.0]) — se normaliza antes de
# comparar (Issue #285, bug #1).
# Uso: extract-changelog-section.sh <version_tag> <changelog_path>
set -uo pipefail

if [ $# -lt 2 ]; then
  echo "Uso: extract-changelog-section.sh <version_tag> <changelog_path>" >&2
  exit 1
fi

VERSION_TAG="$1"
CHANGELOG_PATH="$2"

python3 - "$VERSION_TAG" "$CHANGELOG_PATH" << 'PYTHON_CHANGELOG' | tr -d '\r'
import re
import sys

try:
    tag = sys.argv[1]
    changelog_path = sys.argv[2]
    normalized_tag = tag[1:] if tag.startswith('v') else tag

    with open(changelog_path, 'r', encoding='utf-8') as f:
        lines = f.readlines()

    in_section = False
    section_lines = []
    for line in lines:
        if re.match(rf'^## \[?{re.escape(normalized_tag)}', line):
            in_section = True
        elif in_section and re.match(r'^## \[', line):
            break
        elif in_section:
            section_lines.append(line.rstrip())

    if section_lines:
        for line in section_lines[:10]:
            if line.strip():
                print(f"  {line}")
    else:
        print(f"  (No hay entradas para {tag} en CHANGELOG.md)")
except Exception as e:
    raise ValueError(f"No se pudo leer CHANGELOG.md: {e}") from e
PYTHON_CHANGELOG
