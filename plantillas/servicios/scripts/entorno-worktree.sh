#!/usr/bin/env bash
# Da a esta copia del proyecto (la principal o un worktree) sus propias bases de datos y puertos,
# para trabajar en varias tareas a la vez sin pisarse. Escribe .env.worktree, que mise carga después de .env.
#
# Uso: scripts/entorno-worktree.sh            prepara este worktree
#      scripts/entorno-worktree.sh --borrar   borra las bases de este worktree (nunca las de la copia principal)
set -euo pipefail
cd "$(git rev-parse --show-toplevel)"

[ -f .env ] || { echo "Falta .env: cópialo de .env.example y rellénalo." >&2; exit 1; }
leer() { grep -E "^$1=" .env | tail -1 | cut -d= -f2- | sed -E 's/^["'\'']//; s/["'\'']$//'; }
usuario=$(leer POSTGRES_USER); clave=$(leer POSTGRES_PASSWORD); base=$(leer POSTGRES_DB)
puerto_bd=$(leer POSTGRES_PORT); puerto_bd=${puerto_bd:-5432}
: "${usuario:?Define POSTGRES_USER en .env}" "${clave:?Define POSTGRES_PASSWORD en .env}" "${base:?Define POSTGRES_DB en .env}"

if [ "$(git rev-parse --git-dir)" = "$(git rev-parse --git-common-dir)" ]; then
  slug=principal; sufijo=""; desplazamiento=0
else
  slug=$(basename "$PWD" | tr '[:upper:]' '[:lower:]' | tr -c 'a-z0-9\n' '_' | cut -c1-30)
  sufijo="_$slug"
  desplazamiento=$(( $(printf '%s' "$PWD" | cksum | cut -d' ' -f1) % 899 + 1 ))
fi
bd_dev="${base}${sufijo}"
bd_test="${base}_test${sufijo}"

psql_admin() { docker compose exec -T db psql -v ON_ERROR_STOP=1 -U "$usuario" -d "$base" -tAc "$1"; }

if [ -z "$(docker compose ps -q --status running db 2>/dev/null)" ]; then
  docker compose up -d --wait db
fi

if [ "${1:-}" = "--borrar" ]; then
  [ "$slug" = principal ] && { echo "No se borran las bases de la copia principal." >&2; exit 1; }
  for bd in "$bd_dev" "$bd_test"; do psql_admin "DROP DATABASE IF EXISTS \"$bd\" WITH (FORCE)"; done
  rm -f .env.worktree
  echo "Bases de $slug borradas."
  exit 0
fi

for bd in "$bd_dev" "$bd_test"; do
  if [ -z "$(psql_admin "SELECT 1 FROM pg_database WHERE datname = '$bd'")" ]; then
    psql_admin "CREATE DATABASE \"$bd\" OWNER \"$usuario\""
  fi
done

# La contraseña va en la URL tal cual: usa en .env una sin caracteres especiales de URL (@ : / ? #).
url() { printf 'postgres://%s:%s@127.0.0.1:%s/%s' "$usuario" "$clave" "$puerto_bd" "$1"; }
cat > .env.worktree <<FIN
# Generado por scripts/entorno-worktree.sh. No editar ni subir a git.
WORKTREE=$slug
DATABASE_URL=$(url "$bd_dev")
TEST_DATABASE_URL=$(url "$bd_test")
PORT=$((3000 + desplazamiento))
E2E_PORT=$((4000 + desplazamiento))
FIN
echo "Worktree $slug: bases $bd_dev y $bd_test, app en el puerto $((3000 + desplazamiento)), e2e en el $((4000 + desplazamiento))."
