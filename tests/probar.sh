#!/usr/bin/env bash
# Pruebas de Pilotfish: base del proyecto, hooks, comprobación de commits y elección de modelos.
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

echo "pilotfish help"
ayuda="$("$raiz/bin/pilotfish")"
if grep -q "pilotfish scaffold" <<< "$ayuda"; then ok "la ayuda lista los comandos"; else falla "la ayuda lista los comandos"; fi
if grep -qE "set -|root=|usage" <<< "$ayuda"; then falla "la ayuda no muestra código"; else ok "la ayuda no muestra código"; fi

echo "pilotfish scaffold"
"$raiz/bin/pilotfish" scaffold --forge github --services --runbook > "$tmp/salida.txt"
comprueba "crea los hooks de git" "[ -x .githooks/pre-commit ] && [ -x .githooks/commit-msg ]"
comprueba "configura core.hooksPath" "[ \"\$(git config core.hooksPath)\" = .githooks ]"
comprueba "crea CI, docs, compose, runbook y cliff.toml" "[ -f .github/workflows/ci.yml ] && [ -f docs/ARCHITECTURE.md ] && [ -f compose.yaml ] && [ -f docs/RUNBOOK.md ] && [ -f cliff.toml ]"
comprueba "crea los scripts de commits y de entorno por worktree" "[ -x scripts/comprobar-commits.sh ] && [ -x scripts/entorno-worktree.sh ]"
comprueba "el CI comprueba los commits de la PR" "grep -q comprobar-commits.sh .github/workflows/ci.yml"
comprueba "crea AGENTS.md y CLAUDE.md que lo importa" "[ -f AGENTS.md ] && grep -qx '@AGENTS.md' CLAUDE.md"
comprueba "excluye los archivos de los agentes" "git check-ignore -q AGENTS.md && git check-ignore -q CLAUDE.md && git check-ignore -q .claude/settings.json && git check-ignore -q .worktreeinclude"
comprueba "ignora .env.worktree" "git check-ignore -q .env.worktree && ! git check-ignore -q .env.example"
comprueba "copia lo local a los worktrees" "grep -qxF AGENTS.md .worktreeinclude && grep -qxF CLAUDE.md .worktreeinclude && grep -qxF .env .worktreeinclude"
comprueba "crea orca.yaml con los scripts de preparación y archivado" "grep -q '^scripts:' orca.yaml && grep -q '^  setup:' orca.yaml && grep -q '^  archive:' orca.yaml && grep -q 'mise run setup' orca.yaml && grep -q 'entorno-worktree.sh --borrar' orca.yaml"
comprueba "el merge pide confirmación y no está prohibido" "python3 -c \"import json,sys; p=json.load(open('.claude/settings.json'))['permissions']; sys.exit(0 if 'Bash(gh pr merge *)' in p['ask'] and 'Bash(gh pr merge *)' not in p['deny'] else 1)\""
comprueba "no muestra archivos de los agentes en git status" "! git status --porcelain | grep -qiE 'claude|agents|worktreeinclude'"
"$raiz/bin/pilotfish" scaffold --forge github > "$tmp/salida2.txt"
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

echo "entorno por worktree"
falso="$tmp/falso"; mkdir -p "$falso"; export SQL_LOG="$tmp/sql.log"
cat > "$falso/docker" <<'FIN'
#!/bin/sh
case "$*" in
  *"ps -q"*) echo contenedor ;;
  *psql*) for a; do ultimo=$a; done; echo "$ultimo" >> "$SQL_LOG" ;;
esac
FIN
chmod +x "$falso/docker"
printf 'POSTGRES_USER=app\nPOSTGRES_PASSWORD=clave\nPOSTGRES_DB=app\nPOSTGRES_PORT=5432\n' > .env
PATH="$falso:$PATH" bash scripts/entorno-worktree.sh > /dev/null
comprueba "la copia principal usa sus bases de siempre" "grep -q '/app\$' .env.worktree && grep -q 'app_test:app_test@127.0.0.1:5432/app_test\$' .env.worktree"
comprueba "la copia principal conserva los puertos de .env" "! grep -qE '^(PORT|E2E_PORT)=' .env.worktree"
comprueba "la copia principal no se puede borrar" "! PATH=\"$falso:\$PATH\" bash scripts/entorno-worktree.sh --borrar 2>/dev/null"
git worktree add -q "$tmp/Tarea-Uno" -b tarea-uno
cp .env "$tmp/Tarea-Uno/.env"
(cd "$tmp/Tarea-Uno" && PATH="$falso:$PATH" bash "$repo/scripts/entorno-worktree.sh" > /dev/null)
comprueba "un worktree tiene bases propias acabadas en _test" "grep -q '/app_tarea_uno\$' '$tmp/Tarea-Uno/.env.worktree' && grep -q '/app_tarea_uno_test\$' '$tmp/Tarea-Uno/.env.worktree'"
comprueba "las bases de tests son del rol de tests" "grep -q 'CREATE DATABASE \"app_tarea_uno_test\" OWNER \"app_test\"' \"\$SQL_LOG\""
comprueba "un worktree tiene puertos propios" "grep -qE '^PORT=3[0-9]+\$' '$tmp/Tarea-Uno/.env.worktree' && grep -qE '^E2E_PORT=4[0-9]+\$' '$tmp/Tarea-Uno/.env.worktree'"
(cd "$tmp/Tarea-Uno" && PATH="$falso:$PATH" bash "$repo/scripts/entorno-worktree.sh" --borrar > /dev/null)
comprueba "al borrar un worktree se borran solo sus bases" "grep -q 'DROP DATABASE IF EXISTS \"app_tarea_uno_test\"' \"\$SQL_LOG\" && ! grep -qE 'DROP DATABASE IF EXISTS \"app(_test)?\"' \"\$SQL_LOG\" && [ ! -f '$tmp/Tarea-Uno/.env.worktree' ]"
git worktree remove --force "$tmp/Tarea-Uno"

echo "elección de modelos"
casa="$tmp/casa"; mkdir -p "$casa/.claude" "$casa/agentes"
printf '#!/bin/sh\nexit 0\n' > "$casa/agentes/claude"
cat > "$casa/agentes/opencode" <<'FIN'
#!/bin/sh
[ "$1 $2" = "models deepseek" ] && printf 'deepseek/deepseek-flash\ndeepseek/deepseek-v4-pro\n'
exit 0
FIN
chmod +x "$casa/agentes/claude" "$casa/agentes/opencode"
eleccion() {  # eleccion <rol> [args…] → agente:modelo, o «paused»
  local papel="$1"; shift
  HOME="$casa" PATH="$casa/agentes:/usr/bin:/bin" PILOTFISH_CONFIG="$casa/team.toml" \
    python3 -I "$raiz/lib/team.py" --root "$raiz" --json "$@" |
    python3 -c "import json,sys; d=json.load(sys.stdin)['roles']['$papel']; print('paused' if d['status']=='paused' else d['agent']+':'+d['model'])"
}
touch "$casa/.claude/.credentials.json"
comprueba "solo Claude: el desarrollador usa Sonnet" "[ \"\$(eleccion developer)\" = claude:sonnet ]"
comprueba "solo Claude: planificar usa Opus" "[ \"\$(eleccion plan)\" = claude:opus ]"
mkdir -p "$casa/.local/share/opencode"; echo '{"deepseek":{"type":"api","key":"x"}}' > "$casa/.local/share/opencode/auth.json"
comprueba "con DeepSeek: el desarrollador usa DeepSeek Flash" "[ \"\$(eleccion developer)\" = opencode:deepseek/deepseek-flash ]"
comprueba "con DeepSeek: el revisor es de otro proveedor" "[ \"\$(eleccion reviewer)\" = claude:sonnet ]"
comprueba "Claude sin uso: seguridad pasa a DeepSeek Pro" "[ \"\$(eleccion security --without claude)\" = opencode:deepseek/deepseek-v4-pro ]"
comprueba "Claude y DeepSeek sin uso: seguridad se pausa" "[ \"\$(eleccion security --without claude,deepseek)\" = paused ]"
printf '[tiers]\nstrong = ["claude:opus"]\n[rules]\nwhen_tier_exhausted = "downgrade"\n' > "$casa/team.toml"
comprueba "Claude sin uso y «downgrade»: seguridad baja al nivel estándar" "[ \"\$(eleccion security --without claude)\" = opencode:deepseek/deepseek-v4-pro ]"
printf '[tiers]\nbudget = ["opencode:deepseek/deepseek-chat", "claude:sonnet"]\n' > "$casa/team.toml"
comprueba "salta un modelo que OpenCode no ofrece" "[ \"\$(eleccion developer)\" = claude:sonnet ]"
printf '[roles]\nsecurity = ["claude:opus"]\n' > "$casa/team.toml"
comprueba "un papel con lista propia la respeta" "[ \"\$(eleccion security --without claude)\" = paused ]"

echo
if [ "$fallos" -eq 0 ]; then echo "Todo correcto."; else echo "$fallos comprobaciones fallidas."; exit 1; fi
