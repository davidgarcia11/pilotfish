#!/usr/bin/env bash
# Comprueba un rango de commits: formato de conventional commits y ninguna firma de herramientas de IA.
# Es la segunda barrera por si alguien se salta los hooks con --no-verify. La usa el CI en cada PR.
#
# Uso: scripts/comprobar-commits.sh origin/main..HEAD
set -euo pipefail
rango="${1:?Indica un rango, por ejemplo origin/main..HEAD}"
tipos='feat|fix|docs|style|refactor|perf|test|build|ci|chore|revert'
firmas='(co-authored-by|generated with|-session:).*(claude|anthropic|openai|chatgpt|codex|copilot|cursor|gemini|deepseek|glm|z\.ai|kimi|moonshot|opencode|aider|devin)|generated with \[|noreply@anthropic\.com'
errores=0
for c in $(git rev-list --no-merges "$rango"); do
  cabecera=$(git log -1 --format=%s "$c")
  case "$cabecera" in Revert\ *|fixup!\ *|squash!\ *|amend!\ *) ;; *)
    if ! printf '%s\n' "$cabecera" | grep -Eq "^($tipos)(\([a-z0-9._/-]+\))?!?: .+"; then
      echo "${c:0:9}: formato no válido: $cabecera" >&2; errores=1
    fi
    if [ "${#cabecera}" -gt 100 ]; then echo "${c:0:9}: primera línea de más de 100 caracteres" >&2; errores=1; fi
  esac
  if git log -1 --format=%B "$c" | grep -Eiq "$firmas"; then
    echo "${c:0:9}: lleva una firma de herramienta de IA: $cabecera" >&2; errores=1
  fi
done
[ "$errores" -eq 0 ] && echo "Commits correctos en $rango."
exit "$errores"
