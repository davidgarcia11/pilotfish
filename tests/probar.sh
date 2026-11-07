#!/usr/bin/env bash
# Pruebas del taller: base del estándar, hooks, comprobación de commits y elección de modelos.
set -euo pipefail

raiz="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

fallos=0
ok()    { printf '  \033[32m✓\033[0m %s\n' "$1"; }
falla() { printf '  \033[31m✗\033[0m %s\n' "$1"; fallos=$((fallos + 1)); }
comprueba() { if eval "$2"; then ok "$1"; else falla "$1"; fi; }

# mise falso: el hook pre-commit lo invoca para gitleaks.
mkdir -p "$tmp/bin"
printf '#!/bin/sh\nexit 0\n' > "$tmp/bin/mise"
chmod +x "$tmp/bin/mise"
export PATH="$tmp/bin:$PATH"

repo="$tmp/repo"
git init -q -b main "$repo"
cd "$repo"
git config user.email prueba@example.com
git config user.name Prueba

echo "taller base"
"$raiz/bin/taller" base --forja github --servicios --runbook > "$tmp/salida.txt"
comprueba "crea los hooks de git" "[ -x .githooks/pre-commit ] && [ -x .githooks/commit-msg ]"
comprueba "configura core.hooksPath" "[ \"\$(git config core.hooksPath)\" = .githooks ]"
comprueba "crea CI, docs, compose, runbook y cliff.toml" "[ -f .github/workflows/ci.yml ] && [ -f docs/ARCHITECTURE.md ] && [ -f compose.yaml ] && [ -f docs/RUNBOOK.md ] && [ -f cliff.toml ]"
comprueba "crea los scripts de commits y de entorno por worktree" "[ -x scripts/comprobar-commits.sh ] && [ -x scripts/entorno-worktree.sh ]"
comprueba "el CI comprueba los commits de la PR" "grep -q comprobar-commits.sh .github/workflows/ci.yml"
comprueba "crea AGENTS.md y CLAUDE.md que lo importa" "[ -f AGENTS.md ] && grep -qx '@AGENTS.md' CLAUDE.md"
comprueba "excluye los archivos de los agentes" "git check-ignore -q AGENTS.md && git check-ignore -q CLAUDE.md && git check-ignore -q .claude/settings.json && git check-ignore -q .worktreeinclude"
comprueba "ignora .env.worktree" "git check-ignore -q .env.worktree && ! git check-ignore -q .env.example"
comprueba "copia lo local a los worktrees" "grep -qxF AGENTS.md .worktreeinclude && grep -qxF CLAUDE.md .worktreeinclude && grep -qxF .env .worktreeinclude"
comprueba "no muestra archivos de los agentes en git status" "! git status --porcelain | grep -qiE 'claude|agents|worktreeinclude'"
"$raiz/bin/taller" base --forja github > "$tmp/salida2.txt"
comprueba "es idempotente" "! grep -q Creados \"$tmp/salida2.txt\" && [ \"\$(grep -cxF AGENTS.md .git/info/exclude)\" = 1 ]"

echo "commit-msg"
intenta() { git commit -q --allow-empty -m "$1" 2>/dev/null; }
comprueba "rechaza un mensaje sin formato" "! intenta 'mensaje sin formato'"
comprueba "rechaza un tipo en mayúscula" "! intenta 'Feat: algo'"
comprueba "acepta conventional commits" "intenta 'feat(api): añade endpoint'"
comprueba "acepta cambios incompatibles" "intenta 'fix(auth)!: corrige sesión'"
printf 'feat: con autoría\n\nCuerpo.\n\nCo-Authored-By: Asistente <a@example.com>\nAlgo-Session: https://example.com/x\n\nGenerated with [Herramienta](https://example.com)\n' |
  git commit -q --allow-empty -F -
comprueba "elimina trailers de autoría" "! git log -1 --format=%B | grep -qiE 'co-authored|session:|generated with'"

echo "comprobar-commits"
inicio=$(git rev-list --max-parents=0 HEAD)
comprueba "acepta un historial correcto" "bash scripts/comprobar-commits.sh $inicio..HEAD > /dev/null"
printf 'feat: saltándose el hook\n\nCo-authored-by: Claude <noreply@anthropic.com>\n' | git commit -q --allow-empty --no-verify -F -
comprueba "rechaza una firma de IA colada con --no-verify" "! bash scripts/comprobar-commits.sh $inicio..HEAD > /dev/null 2>&1"
git reset -q --hard HEAD~1
git commit -q --allow-empty --no-verify -m "cambios varios"
comprueba "rechaza un formato no válido colado con --no-verify" "! bash scripts/comprobar-commits.sh $inicio..HEAD > /dev/null 2>&1"
git reset -q --hard HEAD~1

echo "no-commit-main"
comprueba "bloquea commits en main con historial" "! echo '{\"cwd\":\"$repo\"}' | bash .claude/hooks/no-commit-main.sh 2>/dev/null"
git switch -q -c feat/prueba
comprueba "permite commits en una rama" "echo '{\"cwd\":\"$repo\"}' | bash .claude/hooks/no-commit-main.sh"

echo "elección de modelos"
casa="$tmp/casa"; mkdir -p "$casa/.claude" "$casa/agentes"
for a in claude opencode; do printf '#!/bin/sh\nexit 0\n' > "$casa/agentes/$a"; chmod +x "$casa/agentes/$a"; done
eleccion() {  # eleccion <papel> [args…] → agente:modelo, o «pausar»
  local papel="$1"; shift
  HOME="$casa" PATH="$casa/agentes:/usr/bin:/bin" TALLER_CONFIG="$casa/equipo.toml" \
    python3 -I "$raiz/lib/equipo.py" --raiz "$raiz" --json "$@" |
    python3 -c "import json,sys; d=json.load(sys.stdin)['papeles']['$papel']; print('pausar' if d['estado']=='pausar' else d['agente']+':'+d['modelo'])"
}
touch "$casa/.claude/.credentials.json"
comprueba "solo Claude: el desarrollador usa Sonnet" "[ \"\$(eleccion desarrollador)\" = claude:sonnet ]"
comprueba "solo Claude: planificar usa Opus" "[ \"\$(eleccion planificar)\" = claude:opus ]"
mkdir -p "$casa/.local/share/opencode"; echo '{"deepseek":{"type":"api","key":"x"}}' > "$casa/.local/share/opencode/auth.json"
comprueba "con DeepSeek: el desarrollador usa DeepSeek" "[ \"\$(eleccion desarrollador)\" = opencode:deepseek/deepseek-chat ]"
comprueba "con DeepSeek: el revisor es de otro proveedor" "[ \"\$(eleccion revisor)\" = claude:sonnet ]"
comprueba "Claude sin uso: seguridad se pausa" "[ \"\$(eleccion seguridad --sin claude)\" = pausar ]"
printf '[reglas]\nsi_no_queda_nivel = "bajar"\n' > "$casa/equipo.toml"
comprueba "Claude sin uso y «bajar»: seguridad baja a DeepSeek" "[ \"\$(eleccion seguridad --sin claude)\" = opencode:deepseek/deepseek-chat ]"
printf '[papeles]\nseguridad = ["claude:opus"]\n' > "$casa/equipo.toml"
comprueba "un papel con lista propia la respeta" "[ \"\$(eleccion seguridad --sin claude)\" = pausar ]"

echo
if [ "$fallos" -eq 0 ]; then echo "Todo correcto."; else echo "$fallos comprobaciones fallidas."; exit 1; fi
