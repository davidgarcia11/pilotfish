# Flujo: funcionalidad

Especificación y plan aprobados por el usuario, desarrollo con tests primero, auditorías según el riesgo y PR.

Pasos (márcalos en tu lista de tareas si la tienes, y en el estado del worktree en cada cambio de fase):

```text
1. Preparar rama, equipo y modo
2. Especificación aprobada
3. Plan aprobado
4. Desarrollo
5. Auditorías (incluye la comprobación de los tests)
6. Correcciones
7. Documentación y AGENTS.md
8. PR abierta
```

## 1. Preparar

```bash
git status --porcelain          # si no está vacío, para y pregunta
git fetch origin --prune
test "$(git rev-parse --git-dir)" = "$(git rev-parse --git-common-dir)" && echo principal || echo worktree
ls docs/specs/
git branch -a --list '*feat/[0-9][0-9][0-9]-*'
pilotfish agents --json
```

- `NNN`: siguiente número de tres cifras tras el mayor entre `docs/specs/` y las ramas `feat/NNN-*` locales y remotas, para que dos tareas en paralelo no repitan número. `nombre-corto`: 2-4 palabras en kebab-case.
- **Copia principal:** `git switch main && git pull --ff-only && git switch -c feat/NNN-nombre-corto`.
- **Worktree de Orca:** `main` está ocupada por la copia principal, no cambies a ella. Si la rama actual no tiene commits propios (`git log origin/main..HEAD` vacío), `git reset --hard origin/main` y `git branch -m feat/NNN-nombre-corto`. Si ya tiene commits, para y pregunta.
- **Equipo:** elige con el usuario el modo de equipo («Modo de equipo» en `SKILL.md`).
- **Modo de especificación.** Propón el ligero solo si se cumple todo: sin cambios en el modelo de datos, sin dependencias nuevas, sin tocar autenticación, permisos, pagos ni datos personales, sin cambiar contratos públicos y unas 3 tareas como máximo. En otro caso, completo. El usuario confirma.

| | Completo | Ligero |
|---|---|---|
| Especificación | completa | problema, objetivo, criterios y fuera de alcance |
| Plan | método completo de `guias/diseno-tecnico.md` | breve |
| Aprobaciones | especificación y plan por separado | una sola, conjunta |

## 2. Especificación

1. Lee `AGENTS.md`, los principios de `docs/ARCHITECTURE.md` y el código relacionado lo justo para preguntar bien.
2. Pregunta al usuario solo lo que no puedas deducir, en rondas de hasta 4 preguntas (con la herramienta de preguntas si la tienes).
3. Redacta `docs/specs/NNN-nombre-corto/spec.md` desde `plantillas/spec.md`. Comportamiento observable, nunca implementación. Cada criterio verificable.
4. **Tamaño.** Propón dividirla en funcionalidades que se puedan usar y probar de punta a punta por separado, con su orden, y especifica solo la primera, si pasa de unos 15 criterios de aceptación, si trae más de una integración externa nueva o si prevés más de unas 8 tareas o un diff de más de unas 1 500 líneas. Es la decisión que más tokens ahorra: desarrollo, auditorías y correcciones cuestan en proporción al tamaño del diff.
5. Enseña el objetivo, las historias, los criterios y lo que queda fuera. Itera hasta la aprobación explícita y marca `Estado: Aprobada`.

## 3. Plan

Sigue `guias/diseno-tecnico.md`: `plan.md` corto (solo los casos límite y amenazas que pueden costar dinero, datos, seguridad o disponibilidad, cada fila con su identificador y su prueba; archivos críticos y auditoría), `tasks.md` y ADR si hace falta, desde `plantillas/plan.md` y `plantillas/tasks.md`. En modo ligero, `plan.md` breve.

Si surgen dudas sobre la especificación, pregúntalas y actualiza `spec.md` antes de seguir. Presenta el plan e itera hasta la aprobación explícita. Después:

```bash
git add docs/ && git commit -m "docs(specs): especificación y plan de NNN-nombre-corto"
```

Si `plan` y `coordinate` usan modelos distintos, sugiere ahora al usuario el cambio de modelo.

## 4. Desarrollo

Lanza el `developer` (`--worktree current`, `--keep-open`) con el primer bloque de hasta 5 tareas y mándale los siguientes al mismo trabajador con `send` («Un desarrollador por funcionalidad» en `SKILL.md`). Encargo, además de su papel:

> Rama `feat/NNN-nombre-corto`, en este worktree. Implementa las tareas T1-T5 de `docs/specs/NNN-nombre-corto/tasks.md` según `spec.md` y `plan.md`. Un commit por tarea con su test. Informe en la bitácora: `<ruta>`.

Tras cada bloque comprueba tú, sin repetir lo que ya se ejecutó: `git log --oneline origin/main..HEAD`, tareas marcadas en `tasks.md`, y que el informe trae, por tarea, el motivo del fallo en rojo, y el resultado de `mise run check` completo con el commit en que se ejecutó, que debe ser el último del bloque. Si falta o no corresponde, pídeselo al desarrollador; no lo ejecutes tú. Anota las tareas «sin rojo» para la comprobación de los tests. Lleva al usuario los bloqueos de diseño y las desviaciones del plan que cambien configuración, dependencias o comportamiento; las demás, resúmelas al final del bloque.

**Cada comprobación, una sola vez y en su capa:**

| Capa | Qué |
|---|---|
| Hook `pre-commit` | formato, lint y secretos de lo preparado; mensaje del commit |
| Desarrollador, por tarea | tipos y **solo los tests relacionados** con lo cambiado |
| Desarrollador, por bloque | `mise run check` completo, una vez |
| Coordinador | revisa la evidencia; no repite el check |
| CI de la PR | la autoridad: check, `mise run calidad` si existe y e2e |

## 5. Auditorías

Según el modo de equipo: en el **completo**, los cuatro; en el **mínimo**, ninguno (haz tú la revisión que describe `SKILL.md` y salta a «6. Correcciones» con tus hallazgos); en el **necesario**, elige con la especificación, el plan y el diff (`git diff --stat origin/main...HEAD`):

| Papel | Cuándo |
|---|---|
| `reviewer` | Siempre, de otro proveedor que el desarrollador si es posible |
| `qa` | Si el proyecto no tiene `mise run calidad` en la CI; si la tiene, solo para la comprobación de los tests cuando no hay `mise run mutacion` |
| `security` | Si toca autenticación, sesiones, permisos, datos personales, pagos, secretos o configuración, dependencias nuevas, subida de archivos, servicios externos, o entradas de usuario nuevas que llegan a base de datos, HTML, shell o archivos. En caso de duda, lánzalo, acotado a esos archivos |
| `bug_hunter` | Si hay reglas de negocio con estados, cálculos (importes, fechas, zonas horarias), concurrencia o tareas asíncronas, integraciones externas, migraciones de datos o parseo de formatos; acotado a esos archivos |

Di al usuario en una línea cuáles van y por qué los que no; si pide alguno más, añádelo.

Lánzalos escalonados y repartidos entre proveedores («Auditoría proporcional» en `SKILL.md`), cada uno en su worktree hijo (`--worktree new-child`). Encargo común, además de su papel:

> Rama `feat/NNN-nombre-corto`, comparada con `origin/main`. Especificación: `docs/specs/NNN-nombre-corto/spec.md`. Plan: `docs/specs/NNN-nombre-corto/plan.md`. Revisa, por este orden, solo: <archivos críticos del plan o lista de puntos>. Ya revisado (no lo repitas): <lo que haya>. Escribe tus hallazgos en la bitácora `<ruta>` según los confirmes y entrega el informe en su formato.

La comprobación de los tests (rompen a propósito y se mira si algún test falla) la hace `mise run mutacion` si el proyecto la tiene; si no, encárgasela a quien audite: qué romper (las tareas «sin rojo», las amenazas del plan y las reglas críticas: permisos, importes, restricciones de datos, validaciones), entre 5 y 8 cambios; en modo ligero, solo las tareas «sin rojo».

Consolida los informes: une duplicados, conserva el texto completo de cada hallazgo (con el test propuesto si lo hay) y clasifícalos por gravedad.

## 6. Correcciones

- CRÍTICO y ALTO: siempre se corrigen. Un cambio de la comprobación de los tests que no hizo fallar nada cuenta como ALTO: falta ese test.
- MEDIO: se corrigen salvo que sean muchos o costosos; en ese caso pregunta al usuario cuáles aplazar.
- BAJO: van a la PR como pendientes.

Manda al mismo `developer` (con `send`; uno nuevo solo si el anterior ya no está) todos los hallazgos a corregir en un solo encargo, completos. Si discute un hallazgo, decide tú cuando sea evidente y pregunta al usuario cuando no.

Verificación:

- Solo los CRÍTICO y ALTO hacen relanzar auditores: relanza solo los que los encontraron, indicándoles qué hallazgos deben verificar y que no repitan la auditoría entera.
- Los MEDIO los verificas tú con la evidencia del informe: el test nuevo existe, el desarrollador lo vio fallar sin la corrección y su `mise run check` del último commit está en verde.

Máximo 2 rondas. Si tras la segunda queda algún CRÍTICO o ALTO, para y presenta al usuario cada hallazgo con su coste estimado para que decida qué se corrige ya y qué va a pendientes.

## 7. Documentación y AGENTS.md

- `spec.md`: `Estado: Implementada`. Si el alcance cambió, la especificación refleja lo construido.
- Comprueba que está al día lo que el plan marcó en «Documentación que cambia»: `docs/ARCHITECTURE.md`, ADR, README, `docs/RUNBOOK.md` y la referencia OpenAPI si existe. Lo que falte, commit `docs: ...`.
- `CHANGELOG.md` no se toca: sale de los commits al preparar una versión (`mise run version`).
- `AGENTS.md` (local): si surgió una regla, un término del dominio, un comando o un cambio de alcance duradero, enseña al usuario solo esas líneas y aplícalas con su aprobación, también en la copia principal (ver «Reglas que valen siempre»).

## 8. PR

Comprueba que el último `mise run check` del informe corresponde a `HEAD` (si después hubo commits, aunque sean de documentación, pide o ejecuta uno solo) y empuja; la CI de la PR es la comprobación final:

```bash
git push -u origin feat/NNN-nombre-corto
```

Escribe el cuerpo fuera del repositorio con la plantilla de PR del proyecto: qué cambia, por qué (enlace a la especificación), cómo probarlo, comprobaciones marcadas, resultado de la revisión de código, el control de calidad (con la comprobación de los tests), las pruebas de robustez y la revisión de seguridad (las que no se hicieron, con su motivo), y pendientes con su motivo.

```bash
gh pr create --title "feat(ámbito): descripción" --body-file <archivo>
# GitLab: glab mr create --title "..." --description "$(cat <archivo>)" --remove-source-branch --yes
```

Después, la sección «Al terminar un flujo» de `SKILL.md`: CI, cierre y, tras el merge del usuario, puesta al día.
