# Flujo: adaptar proyecto

Actúa como ingeniero de plataforma y arquitecto que hereda un proyecto en producción: primero entiende, después propone, nunca rompe.

## Reglas

- Las fases 1 y 2 son de solo lectura. La fase 3 empieza solo con aprobación explícita.
- Todo el cambio va en la rama `chore/adaptar-estandar` y termina en una PR/MR, con la sección «Al terminar un flujo» de `SKILL.md`.
- No reescribas historial, no hagas force push y no borres ramas sin una confirmación explícita y separada para esa acción.
- No silencies reglas de lint ni desactives tests para que el check pase. Si algo no se puede arreglar dentro de esta PR, lo decide el usuario.
- Sin refactors de código de producto: esta PR cambia herramientas, configuración y documentación.
- La documentación que ya existe se conserva: se enlaza desde el mapa de `docs/ARCHITECTURE.md`, no se duplica ni se reescribe. Las mejoras que propongas sobre ella van como lista aparte.
- Mismas reglas de instalación y autoría que `flujos/nuevo-proyecto.md`.

## Fase 1. Diagnóstico

Si `git status --porcelain` no está vacío, para y pregunta. Después revisa, sin modificar nada (para mapear un código grande, puedes repartir la lectura entre trabajadores `reviewer` en worktrees hijos):

| Área | Qué mirar |
|---|---|
| Forja y ramas | remoto, rama por defecto, protección de `main` |
| Stack | manifiestos, versiones de runtime y dónde se fijan |
| Herramientas | `mise.toml`, lint, formato, tipos, tests y si pasan hoy |
| Git | hooks, formato de commits recientes |
| CI | qué ejecuta y si coincide con lo local |
| Documentación | README, arquitectura, decisiones, `.env.example`, documentación propia del proyecto |
| Secretos | `.env` rastreado y secretos en todo el historial |
| Dependencias | vulnerabilidades conocidas |
| Archivos de agentes | rastreados en git |
| Autoría | firmas de herramientas de IA en el historial |
| Base de datos | si los tests usan una base separada y si se puede trabajar en varios worktrees a la vez |

```bash
mise exec gitleaks@latest -- gitleaks git --redact --no-banner
mise exec osv-scanner@latest -- osv-scanner scan source -r .
git ls-files | grep -iE 'claude|agents\.md|\.cursor|\.opencode'
git log --format=%B | grep -icE 'co-authored-by:.*(claude|codex|copilot|cursor|deepseek|glm)|generated with \['
```

## Fase 2. Propuesta

1. **Diagnóstico**: tabla área | estado | acción propuesta.
2. **Riesgos inmediatos**: secretos encontrados (primero se rotan; limpiar el historial es una decisión aparte), dependencias vulnerables, tests rotos y carencias frente a `guias/seguridad.md`.
3. **Cambios de esta PR**, en commits lógicos.
4. **Fuera de esta PR**: deuda que no se toca, con su motivo.
5. **Decisiones para el usuario**: qué hacer si el check no pasa con el código actual; si se limpia el historial; si hay hooks o CI previos, si se reemplazan o se integran.

Pide aprobación explícita e itera hasta tenerla.

## Fase 3. Ejecución

1. **Rama**: `git switch -c chore/adaptar-estandar`.
2. **Runtimes**: `mise use --pin` con las versiones que el proyecto usa hoy, más `gitleaks`, `osv-scanner` y `git-cliff`. `mise trust`.
3. **Base**: `pilotfish scaffold --forge <github|gitlab>` (más `--services` y `--runbook` si aplican). Integra a mano lo que omita por existir ya: conserva los jobs de CI existentes y añade `mise run check` y la comprobación de commits.
4. **Archivos de agentes fuera de git**: `git rm -r --cached --quiet` sobre los que avise. Siguen en disco.
5. **Tareas de mise**: `setup`, `check`, `changelog` y `version` envolviendo los scripts existentes del proyecto. Con base de datos: `servicios.toml`, `TEST_DATABASE_URL` para los tests y `mise run entorno` en `setup`, siguiendo «Entorno por worktree» de `flujos/nuevo-proyecto.md`. Si el proyecto ya crea su base de tests a su manera, explica al usuario cómo encaja antes de aplicarlo.
6. **Check en verde**: correcciones automáticas de formato y lint en un commit propio (`style: aplica formato automático`). Lo que no sea automático se resuelve según lo que decidió el usuario.
7. **Documentación**: `docs/ARCHITECTURE.md` describiendo el sistema tal como es hoy, sin inventar intenciones y enlazando la documentación existente; `docs/adr/0001-stack-y-arquitectura.md` con el stack existente como decisión aceptada; `docs/specs/README.md`; README con requisitos, arranque y comandos; `CHANGELOG.md` desde los commits si ya usan conventional commits, o una entrada inicial; `docs/RUNBOOK.md` si hay despliegue, marcando lo que no exista.
8. **`AGENTS.md`** (local) con la realidad del proyecto: vocabulario, reglas, comandos y zonas con sus rutas reales. `CLAUDE.md` con `@AGENTS.md`.
9. **Protecciones**: las dos pruebas de `flujos/nuevo-proyecto.md` (secreto y mensaje sin formato) deben fallar.
10. **Auditorías**: como dice «Ninguna PR sin revisión» en `SKILL.md`: revisor, cazabugs (scripts, CI, hooks, entorno por worktree) y seguridad si toca permisos, secretos o autenticación.
11. **PR**: commits lógicos, `mise run check` en verde, push y PR/MR con la plantilla. Resume diagnóstico, cambios, resultado de las auditorías y deuda pendiente.

### Limpieza del historial (solo si el usuario la pidió en la fase 2)

Antes de nada: secretos rotados, copia completa (`git clone --mirror`) y aviso a quien tenga el repositorio clonado. `git filter-repo` en una copia, enseña el resultado y pide confirmación para el force push. Nunca en la misma PR que la adaptación.

## Cierre

Resume en 8 líneas como máximo: qué tenía, qué cambia, URL de la PR, deuda pendiente y riesgos abiertos. Termina con lo que el usuario tiene que hacer en Orca, como al final de `flujos/nuevo-proyecto.md`, y con la pregunta del merge de «Al terminar un flujo» en `SKILL.md`.
