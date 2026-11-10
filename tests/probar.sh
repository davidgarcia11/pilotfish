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

echo "pilotfish install"
casa_i="$tmp/casa-install"; mkdir -p "$casa_i/.claude"
printf '{\n  "model": "sonnet",\n  "hooks": {"Stop": []}\n}\n' > "$casa_i/.claude/settings.json"
HOME="$casa_i" "$raiz/bin/pilotfish" install > /dev/null
HOME="$casa_i" "$raiz/bin/pilotfish" install > /dev/null
ajustes="$casa_i/.claude/settings.json"
comprobar_ajustes() { python3 -c "import json,sys; d=json.load(open('$ajustes')); p=d['permissions']; sys.exit(0 if $1 else 1)"; }
if comprobar_ajustes "p['additionalDirectories'] == ['$raiz']"; then ok "Claude puede leer Pilotfish"; else falla "Claude puede leer Pilotfish"; fi
if comprobar_ajustes "p['deny'] == ['Edit(/$raiz/**)']"; then ok "Claude no puede editar Pilotfish"; else falla "Claude no puede editar Pilotfish"; fi
if comprobar_ajustes "d['model'] == 'sonnet' and 'Stop' in d['hooks']"; then ok "conserva los ajustes que había"; else falla "conserva los ajustes que había"; fi
if [ -L "$casa_i/.claude/skills/pilotfish" ] && [ -L "$casa_i/.local/bin/pilotfish" ]; then ok "enlaza la skill y el comando"; else falla "enlaza la skill y el comando"; fi

echo "prohibiciones de OpenCode"
casa_o="$tmp/casa-opencode"; mkdir -p "$casa_o/bin" "$casa_o/.config/opencode"
printf '#!/bin/sh\nexit 0\n' > "$casa_o/bin/opencode"; chmod +x "$casa_o/bin/opencode"
printf '{\n  "model": "deepseek/deepseek-flash",\n  "permission": {"bash": "ask"}\n}\n' > "$casa_o/.config/opencode/opencode.json"
HOME="$casa_o" PATH="$casa_o/bin:$PATH" "$raiz/bin/pilotfish" install > /dev/null
HOME="$casa_o" PATH="$casa_o/bin:$PATH" "$raiz/bin/pilotfish" install > /dev/null
oc="$casa_o/.config/opencode/opencode.json"
comprobar_oc() { python3 -c "import json,sys; d=json.load(open('$oc')); p=d['permission']; sys.exit(0 if $1 else 1)"; }
if comprobar_oc "p['bash'].get('git push origin main*') == 'deny' and p['bash'].get('mise run db:reset*') == 'deny' and p['bash'].get('gh pr merge *') == 'deny'"; then ok "OpenCode tiene las prohibiciones de Claude"; else falla "OpenCode tiene las prohibiciones de Claude"; fi
if comprobar_oc "p['read'].get('*.env') == 'deny' and p['read'].get('*.env.example') == 'allow'"; then ok "OpenCode no puede leer .env"; else falla "OpenCode no puede leer .env"; fi
if comprobar_oc "d['model'] == 'deepseek/deepseek-flash' and p['bash'].get('*') == 'ask'"; then ok "conserva la configuración de OpenCode que había"; else falla "conserva la configuración de OpenCode que había"; fi
cat > "$casa_o/bin/opencode" <<'FIN'
#!/bin/sh
[ "$1 $2" = "debug config" ] && exit 1
exit 0
FIN
rm "$oc"; printf '{"model": "x"}\n' > "$oc"
HOME="$casa_o" PATH="$casa_o/bin:$PATH" "$raiz/bin/pilotfish" install > "$tmp/oc-salida.txt"
if [ "$(cat "$oc")" = '{"model": "x"}' ] && grep -q "rejected" "$tmp/oc-salida.txt"; then ok "si OpenCode rechaza las reglas, deja su archivo como estaba"; else falla "si OpenCode rechaza las reglas, deja su archivo como estaba"; fi

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
comprueba "los agentes no pueden hacer merge" "python3 -c \"import json,sys; p=json.load(open('.claude/settings.json'))['permissions']; sys.exit(0 if 'Bash(gh pr merge *)' in p['deny'] and 'Bash(glab mr merge *)' in p['deny'] else 1)\""
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
preparar() { (cd "$1" && cp "$repo/.env" .env && PATH="$falso:$PATH" bash "$repo/scripts/entorno-worktree.sh" "${@:2}" > /dev/null); }
git worktree add -q "$tmp/Tarea-Uno" -b tarea-uno
preparar "$tmp/Tarea-Uno"
wt="$tmp/Tarea-Uno/.env.worktree"
comprueba "un worktree tiene bases propias acabadas en _test" "grep -qE '/app_wt_tarea_uno_[0-9a-f]{6}\$' '$wt' && grep -qE '/app_wt_tarea_uno_[0-9a-f]{6}_test\$' '$wt'"
comprueba "las bases de tests son del rol de tests" "grep -qE 'CREATE DATABASE \"app_wt_tarea_uno_[0-9a-f]{6}_test\" OWNER \"app_test\"' \"\$SQL_LOG\""
comprueba "un worktree tiene puertos propios" "grep -qE '^PORT=3[0-9]+\$' '$wt' && grep -qE '^E2E_PORT=4[0-9]+\$' '$wt'"
preparar "$tmp/Tarea-Uno" --borrar
comprueba "al borrar un worktree se borran solo sus bases" "grep -qE 'DROP DATABASE IF EXISTS \"app_wt_tarea_uno_[0-9a-f]{6}_test\"' \"\$SQL_LOG\" && ! grep -qE 'DROP DATABASE IF EXISTS \"app(_test)?\"' \"\$SQL_LOG\" && [ ! -f '$wt' ]"
git worktree remove --force "$tmp/Tarea-Uno"

: > "$SQL_LOG"
git worktree add -q "$tmp/test" -b rama-test
preparar "$tmp/test"; preparar "$tmp/test" --borrar
comprueba "un worktree llamado test no toca la base de tests principal" "! grep -qE '(CREATE|DROP) DATABASE (IF EXISTS )?\"app(_test)?\"' \"\$SQL_LOG\""
git worktree remove --force "$tmp/test"

mkdir -p "$tmp/a" "$tmp/b"
git worktree add -q "$tmp/a/tarea" -b tarea-a
git worktree add -q "$tmp/b/tarea" -b tarea-b
preparar "$tmp/a/tarea"; preparar "$tmp/b/tarea"
comprueba "dos carpetas con el mismo nombre no comparten bases" "[ \"\$(grep ^DATABASE_URL '$tmp/a/tarea/.env.worktree')\" != \"\$(grep ^DATABASE_URL '$tmp/b/tarea/.env.worktree')\" ]"
git worktree remove --force "$tmp/a/tarea"; git worktree remove --force "$tmp/b/tarea"

: > "$SQL_LOG"
PATH="$falso:$PATH" bash scripts/entorno-worktree.sh > /dev/null
git worktree add -q "$tmp/otro" -b otro
comprueba "con GIT_DIR heredado la copia principal sigue protegida" "! GIT_DIR=\"$repo/.git/worktrees/otro\" PATH=\"$falso:\$PATH\" bash scripts/entorno-worktree.sh --borrar 2>/dev/null && [ -f .env.worktree ] && ! grep -q DROP \"\$SQL_LOG\""
git worktree remove --force "$tmp/otro"

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
