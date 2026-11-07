#!/usr/bin/env bash
# Bloquea commits en main/master cuando ya hay historial (el commit inicial pasa).
dir=$(jq -r '.cwd // empty' 2>/dev/null)
dir=${dir:-${CLAUDE_PROJECT_DIR:-.}}
git -C "$dir" rev-parse --verify -q HEAD >/dev/null || exit 0
branch=$(git -C "$dir" symbolic-ref --short -q HEAD) || exit 0
case "$branch" in
  main|master)
    echo "Commit bloqueado en '$branch'. Crea una rama: git switch -c feat/<descripcion>" >&2
    exit 2 ;;
esac
exit 0
