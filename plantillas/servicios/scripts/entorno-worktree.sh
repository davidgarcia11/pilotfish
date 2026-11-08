#!/usr/bin/env bash
# Da a cada worktree sus propias bases de datos y puertos, para trabajar en varias tareas a la vez sin pisarse.
# Escribe .env.worktree, que mise carga después de .env. La copia principal conserva sus bases y sus puertos.
#
# Uso: scripts/entorno-worktree.sh            prepara esta copia (la principal o un worktree)
#      scripts/entorno-worktree.sh --borrar   borra las bases de este worktree (nunca las de la copia principal)
#
# Bases: la principal usa <POSTGRES_DB> y <POSTGRES_DB>_test; cada worktree, <POSTGRES_DB>_<worktree> y
# <POSTGRES_DB>_<worktree>_test (el nombre de las de tests siempre acaba en _test). Las bases de tests son del rol
# <POSTGRES_DB>_test, con contraseña igual a su nombre, que el script crea si no existe.
set -euo pipefail
cd "$(git rev-parse --show-toplevel)"

# Variables del proyecto que dependen del puerto de la app en un worktree: URL pública, de autenticación,
# de callback… Usa el mismo host que en .env (normalmente localhost: localhost y 127.0.0.1 son orígenes distintos).
# Ejemplo: echo "BETTER_AUTH_URL=http://localhost:$1"
variables_del_puerto() {
  :
}

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
bd_test="${base}${sufijo}_test"
rol_test="${base}_test"

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

if [ -z "$(psql_admin "SELECT 1 FROM pg_roles WHERE rolname = '$rol_test'")" ]; then
  psql_admin "CREATE ROLE \"$rol_test\" LOGIN PASSWORD '$rol_test'"
fi
crear_bd() {
  if [ -z "$(psql_admin "SELECT 1 FROM pg_database WHERE datname = '$1'")" ]; then
    psql_admin "CREATE DATABASE \"$1\" OWNER \"$2\""
  fi
}
crear_bd "$bd_dev" "$usuario"
crear_bd "$bd_test" "$rol_test"

# La contraseña va en la URL tal cual: usa en .env una sin caracteres especiales de URL (@ : / ? #).
url() { printf 'postgres://%s:%s@127.0.0.1:%s/%s' "$2" "$3" "$puerto_bd" "$1"; }
cat > .env.worktree <<FIN
# Generado por scripts/entorno-worktree.sh. No editar ni subir a git.
WORKTREE=$slug
DATABASE_URL=$(url "$bd_dev" "$usuario" "$clave")
TEST_DATABASE_URL=$(url "$bd_test" "$rol_test" "$rol_test")
FIN

if [ "$slug" = principal ]; then
  echo "Copia principal: bases $bd_dev y $bd_test; puertos y URLs de .env."
  exit 0
fi
puerto_app=$((3000 + desplazamiento))
puerto_e2e=$((4000 + desplazamiento))
{
  echo "PORT=$puerto_app"
  echo "E2E_PORT=$puerto_e2e"
  variables_del_puerto "$puerto_app"
} >> .env.worktree
echo "Worktree $slug: bases $bd_dev y $bd_test, app en el puerto $puerto_app, e2e en el $puerto_e2e."
