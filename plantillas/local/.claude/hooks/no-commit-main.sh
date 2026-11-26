#!/usr/bin/env bash
# Bloquea commits en main/master cuando ya hay historial (el commit inicial pasa).
#
# Claude Code puede lanzar este hook con comandos compuestos que no son un commit
# (p. ej. `git status && mise run check`); por eso se mira el comando: solo se bloquea
# si alguna de sus partes ejecuta `git ... commit`. Sin comando en la entrada, se
# comprueba igual: más vale bloquear de más que dejar pasar un commit en main.

# ¿Alguna parte del comando ejecuta el subcomando `commit` de git? Salta las opciones
# globales (`-C <ruta>`, `-c <clave=valor>`, `--no-pager`…) hasta el primer argumento,
# que es el subcomando. `git log --grep commit` no cuenta. Las comillas se quitan antes
# de partir el comando, para ver también `bash -c "git commit …"`.
es_commit() {
  local segmento i j subcomando
  local -a palabras
  while IFS= read -r segmento; do
    read -ra palabras <<<"$segmento"
    for ((i = 0; i < ${#palabras[@]}; i++)); do
      [[ ${palabras[i]} == git || ${palabras[i]} == */git ]] || continue
      subcomando=""
      for ((j = i + 1; j < ${#palabras[@]}; j++)); do
        case ${palabras[j]} in
          -C | -c) j=$((j + 1)) ;;
          -*) ;;
          *) subcomando=${palabras[j]}; break ;;
        esac
      done
      [[ $subcomando == commit ]] && return 0
    done
  done < <(printf '%s\n' "$1" | tr -d "\"'" | sed -E 's/(&&|\|\||[;|&()])/\n/g')
  return 1
}

entrada=$(cat)
dir=$(jq -r '.cwd // empty' <<<"$entrada" 2>/dev/null)
dir=${dir:-${CLAUDE_PROJECT_DIR:-.}}
comando=$(jq -r '.tool_input.command // empty' <<<"$entrada" 2>/dev/null)
if [ -n "$comando" ] && ! es_commit "$comando"; then exit 0; fi

git -C "$dir" rev-parse --verify -q HEAD >/dev/null || exit 0
branch=$(git -C "$dir" symbolic-ref --short -q HEAD) || exit 0
case "$branch" in
  main|master)
    echo "Commit bloqueado en '$branch'. Crea una rama: git switch -c feat/<descripcion>" >&2
    exit 2 ;;
esac
exit 0
