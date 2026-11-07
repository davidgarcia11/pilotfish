# Flujo: actualizar proyecto

Lleva a un proyecto que ya sigue el estándar las novedades de las plantillas del taller. Solo añades lo que falta: nunca borras, nunca sustituyes un archivo entero y nunca cambias una línea que el proyecto haya adaptado sin enseñársela al usuario.

Mejor desde la copia principal del proyecto, que es de donde copian los worktrees nuevos.

## 1. Comprobar

```bash
git status --porcelain          # si no está vacío, para y pregunta
test -f AGENTS.md && test -d .githooks && echo estandar || echo sin-estandar
git remote get-url origin       # github o gitlab
```

Si sale `sin-estandar`, el proyecto nunca se adaptó: sigue `flujos/adaptar-proyecto.md`. Si tiene el estándar antiguo (`CLAUDE.md` con reglas y `.claude/rules/`, pero sin `AGENTS.md`), propón pasar su contenido a `AGENTS.md` y dejar `CLAUDE.md` con `@AGENTS.md`.

## 2. Generar la referencia

```bash
ref="$(mktemp -d)" && git -C "$ref" init -q
taller base --forja <github|gitlab> [--servicios] [--runbook] --dir "$ref"
```

`--servicios` si el proyecto tiene `compose.yaml`; `--runbook` si tiene `docs/RUNBOOK.md`. Las tareas de mise de referencia están en `$(taller ruta)/plantillas/tareas/`.

## 3. Comparar

| Caso | Qué propones |
|---|---|
| Falta en el proyecto | Crearlo, rellenando los marcadores con los datos reales |
| `AGENTS.md` | Solo las reglas de la referencia que no estén ya, con estas u otras palabras |
| `.claude/settings.json` | Entradas de `allow` y `deny` y hooks que falten. Nunca quitar una entrada del proyecto |
| `.githooks/*`, `.claude/hooks/*`, `scripts/*` | Si difieren, el diff completo y si el cambio del proyecto parece intencionado |
| CI, plantillas de PR, `cliff.toml`, `dependabot.yml` | Lo que falte (por ejemplo, la comprobación de commits), adaptado al proyecto |
| `docs/` | Solo secciones que falten en los documentos base |
| `mise.toml` | Tareas y `[env]` de la referencia que no existan; sin tocar las versiones fijadas |
| `.worktreeinclude`, `.gitignore`, `.git/info/exclude` | Líneas que falten |

Si el proyecto tiene base de datos y los tests usan la de desarrollo, o no puede trabajar en varios worktrees a la vez, propón `scripts/entorno-worktree.sh`, `TEST_DATABASE_URL` y `mise run entorno` en `setup`.

Comprueba además que `git config core.hooksPath` es `.githooks` y que ningún archivo de agentes está en git.

## 4. Proponer

Una tabla por archivo con qué falta y la propuesta, separando:

- **Local** (`AGENTS.md`, `CLAUDE.md`, `.claude/`, `.worktreeinclude`): no llega a git.
- **Repositorio** (hooks, scripts, CI, docs, `mise.toml`…): irá en una rama con PR.

Pregunta qué se aplica, por archivo. Si no falta nada, dilo y termina.

## 5. Aplicar

1. Lo local aprobado, directamente (si estás en un worktree, también en la copia principal).
2. Lo del repositorio aprobado, en la rama `chore/actualizar-estandar` (en un worktree: renombrando la rama actual si no tiene commits propios, como en `flujos/funcionalidad.md`).
3. Commits lógicos (`chore: …`, `ci: …`, `docs: …`), `mise run check` en verde, push y PR con la plantilla del proyecto. El merge lo hace el usuario.
4. `rm -rf "$ref"`.
