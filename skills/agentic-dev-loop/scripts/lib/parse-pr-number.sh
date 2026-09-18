#!/usr/bin/env bash
# Extrae el numero de PR de la salida de "gh pr create" (URL con /pull/<N> al final),
# copy-pasteado antes en 4 lugares (open-pr.sh, cut-release.sh x3) -- Issue #285, bug #8.

parse_pr_number() {
  grep -oE '/pull/[0-9]+' | grep -oE '[0-9]+' | tail -1
}
