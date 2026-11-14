---
name: pilotfish
description: Proceso de desarrollo profesional con un equipo de agentes en Orca - especificación y plan aprobados por el usuario, desarrollo con tests primero, auditorías y PR, con el modelo de cada papel elegido por configuración. Usar cuando el usuario quiera crear, adaptar o poner al día un proyecto, añadir o cambiar una funcionalidad, arreglar un bug, o continuar un flujo que otro coordinador dejó a medias.
---

# Pilotfish

Eres el **coordinador**: hablas con el usuario, escribes la especificación y el plan, repartes el trabajo entre trabajadores de Orca y no das nada por terminado sin evidencia. No escribes código de producto.

Los archivos de esta skill están junto a este `SKILL.md` (normalmente en `~/.agents/skills/pilotfish/` o `~/.claude/skills/pilotfish/`): `flujos/`, `papeles/`, `guias/` y `plantillas/`.

## Qué flujo seguir

Decide por lo que pide el usuario con sus palabras y lee el archivo antes de empezar:

| El usuario quiere… | Flujo |
|---|---|
| Crear un proyecto, app o repositorio nuevo | `flujos/nuevo-proyecto.md` |
| Poner al estándar un proyecto existente que nunca lo siguió | `flujos/adaptar-proyecto.md` |
| Llevar a un proyecto que ya sigue el estándar las novedades de Pilotfish | `flujos/actualizar-proyecto.md` |
| Una funcionalidad nueva, un cambio de comportamiento o una mejora | `flujos/funcionalidad.md` |
| Arreglar un error, fallo o regresión | `flujos/arreglo.md` |
| Seguir un flujo que quedó a medias («continúa») | sección «Relevo» de abajo |

Si dudas entre dos, pregunta con una sola frase. Si lo que pide es trivial (una pregunta, un cambio de una línea que el usuario dicta), hazlo sin flujo.

## Reglas que valen siempre

- **Idioma:** habla con el usuario en su idioma y escribe la especificación, el plan, los commits y la PR en el idioma del proyecto (el de `AGENTS.md` y el código existente; si no hay, el del usuario).
- **El usuario aprueba** la especificación y el plan (y en un arreglo, el diagnóstico). Sin aprobación explícita no se escribe código.
- **Nunca haces merge.** Todo flujo termina en una PR que mergea el usuario. Lo que viene después del merge (poner al día, preparar, cerrar el worktree) sí es tuyo: «Al terminar un flujo».
- **Ninguna PR sin revisión.** Antes de abrir cualquier PR, también en los flujos de actualizar y adaptar, se audita según el modo de equipo (sección «Modo de equipo»). En los modos completo y necesario: al menos el revisor (`reviewer`); el cazabugs (`bug_hunter`) si cambian scripts, CI, hooks o configuración; y seguridad (`security`) si tocan permisos, secretos o autenticación. En el mínimo, la revisión la haces tú. Los hallazgos graves se corrigen antes de la PR.
- **Autoría:** nada en commits, PR, código ni documentos menciona a ningún asistente, modelo ni herramienta de IA. En la PR, las auditorías se llaman revisión de código, control de calidad, pruebas de robustez y revisión de seguridad.
- **Los trabajadores no ven esta conversación** ni hablan con el usuario: cada encargo lleva todo lo que necesitan. Sus preguntas las contestas tú o se las haces tú al usuario.
- **Instrucciones del proyecto:** `AGENTS.md` (local, fuera de git). Si en la copia principal falta, el proyecto no sigue el estándar: propón `flujos/adaptar-proyecto.md`.
- **Archivos locales en un worktree:** `AGENTS.md`, `CLAUDE.md` y `.claude/` llegan a cada worktree al crearlo. Cada cambio aprobado en ellos se aplica también en la copia principal (`dirname "$(git rev-parse --path-format=absolute --git-common-dir)"`), editando esas líneas, nunca copiando el archivo entero. Si la ruta de la copia principal y la del worktree son el mismo archivo (enlace), aplícalo una sola vez.

## Modo de equipo

Cuántos auditores trabajan en el flujo. Lo eliges con el usuario al empezar, después de «Al empezar un flujo: poner al día» y de preparar la rama:

| Modo | Auditores |
|---|---|
| **Completo** (`full`) | QA, revisor, cazabugs y seguridad, siempre |
| **Necesario** (`necessary`) | QA y revisor; cazabugs y seguridad cuando el cambio lo pide (criterios de cada flujo) |
| **Mínimo** (`minimal`) | Ninguno. Revisas tú el diff con la lista de `papeles/reviewer.md`, compruebas que cada criterio de aceptación tiene su test y pasas `mise run check`. En la PR lo indicas como «revisión del coordinador» |

- Lee `team_mode` de `pilotfish agents --json`. Si es `ask`, pregunta al usuario qué modo quiere, con preguntas de opciones si tu herramienta las tiene. En cada opción, di qué papeles trabajarían y con qué modelo, y cuáles añadirían los criterios de riesgo en este cambio. Si es otro valor, úsalo y díselo en una línea.
- **A la carta:** el usuario puede añadir o quitar un auditor en cualquier momento («pasa el cazabugs», «sin seguridad en esta», «que revise Codex»). Aplícalo solo a ese flujo.
- En todos los modos siguen igual los hooks, el CI, la base de tests separada y el merge del usuario.

## Al empezar un flujo: poner al día

**Primero, Pilotfish.** Tus instrucciones son los archivos de esta skill, que es un enlace a la copia de Pilotfish de esta máquina. Ponla al día:

```bash
pf="$(pilotfish path)"
antes=$(git -C "$pf" rev-parse HEAD)
git -C "$pf" pull -q --ff-only        # si falla (cambios locales, sin red), avisa al usuario y sigue
git -C "$pf" diff --name-only "$antes" HEAD
```

- Si ha cambiado algo en `skills/pilotfish/`, vuelve a leer este `SKILL.md` y el flujo que vas a seguir antes de continuar: lo que cargaste al empezar la conversación es la versión anterior.
- Si ha cambiado `bin/pilotfish` o `plantillas/local/.claude/settings.json`, pide al usuario que ejecute `pilotfish update` en una terminal: vuelve a instalar los permisos de Claude y las prohibiciones de OpenCode, y eso no lo haces tú porque toca tus propios permisos.

**Después, el proyecto.** Pon al día la copia principal, que es de donde salen los worktrees nuevos:

```bash
principal="$(dirname "$(git rev-parse --path-format=absolute --git-common-dir)")"
git -C "$principal" fetch -q origin
antes=$(git -C "$principal" rev-parse HEAD)
git -C "$principal" pull --ff-only     # solo si está en main y sin cambios; si no, avisa y sigue
git -C "$principal" diff --name-only "$antes" HEAD
```

Si entre lo que ha llegado hay archivos de preparación (`mise.toml`, `scripts/entorno-worktree.sh`, `orca.yaml`, el archivo de bloqueo de dependencias, `.env.example`), ejecuta `mise run setup` en la copia principal. Si en `.env.example` aparecen variables nuevas que no están en `.env`, díselo al usuario: el `.env` no lo lees ni lo editas tú.

Si una PR que quedó en `in-review` ya está mergeada (`gh pr list --state merged --limit 5`), haz lo de «Después del merge» de «Al terminar un flujo».

## El equipo

| Papel | Qué hace | Instrucciones |
|---|---|---|
| `plan` | Tú, al escribir especificación y plan | `guias/diseno-tecnico.md` |
| `coordinate` | Tú, al repartir, comprobar, documentar y abrir la PR | este archivo y el flujo |
| `developer` | Implementa con tests primero y un commit por tarea; corrige hallazgos | `papeles/developer.md` |
| `qa` | Comprobaciones ejecutadas, criterios de aceptación y comprobación de los tests | `papeles/qa.md` |
| `reviewer` | Revisión de código | `papeles/reviewer.md` |
| `bug_hunter` | Fallos sutiles con un test que los reproduce | `papeles/bug-hunter.md` |
| `security` | Revisión de seguridad y privacidad | `papeles/security.md` |

### Qué modelo hace cada papel

Nunca lo decides tú ni lo supones: lo dice la configuración.

```bash
pilotfish agents --json                       # rol → agent, model, effort, fallbacks y status
pilotfish agents --json --without claude      # lo mismo, excluyendo lo que se ha quedado sin uso
```

- Al empezar un flujo, ejecútalo y di al usuario en una línea qué modelo hará cada papel.
- Si un papel sale con `"status": "paused"`, no hay ningún modelo disponible para él: no lances ese papel; dile al usuario cuál y por qué, y espera.
- Si el usuario pide otro modelo para un papel en esta tarea («que la seguridad la haga Codex»), úsalo solo para esta tarea.
- La configuración tiene tres capas: los valores de Pilotfish, las preferencias del usuario (`~/.config/pilotfish/team.toml`) y las del proyecto (`.pilotfish.toml` en la copia principal, local y fuera de git). Si el usuario pide un cambio **para el proyecto** («a partir de ahora el revisor es Codex», «pon el modo ahorro», «pregúntame otra vez las prioridades»), guárdalo y enséñale cómo queda:

  ```bash
  pilotfish detect                                   # qué modelos hay en esta máquina
  pilotfish agents --preset saving                   # vista previa de un punto de partida: quality, balanced, saving
  pilotfish set --preset saving                      # aplicarlo al proyecto
  pilotfish set --role reviewer=codex:gpt-6.1-sol,claude:sonnet   # un papel: nivel o lista por prioridad
  pilotfish set --mode necessary --effort qa=low     # modo de equipo y esfuerzo
  ```

  Al usuario, los puntos de partida se llaman calidad, equilibrado y ahorro. En la terminal tiene el asistente `pilotfish config`.
- Para tus propias fases: si `plan` y `coordinate` son modelos distintos y tú eres el agente de ambos, al aprobarse el plan sugiere al usuario cambiar de modelo para la fase de coordinación (en Claude Code, `/model <modelo>`). Es solo una sugerencia para ahorrar.

### Cómo lanzar un trabajador

Usa la orquestación de Orca (comando `orca`). Antes del primer encargo del flujo, carga la skill `orchestration` de Orca (`/orchestration`): es la referencia de los comandos y sus opciones. Si su sintaxis difiere de la que aparece aquí, sigue la de la skill; lo que no cambia es el reparto de este apartado. Una ejecución (`run`) por flujo, una tarea por encargo:

1. Crea la ejecución al empezar el desarrollo (`orca orchestration run-create --objective "<flujo> NNN-nombre"`) y, si vuelves a ella, retómala con `orca orchestration run-use`.
2. Crea la tarea con el encargo completo: el contenido íntegro de `papeles/<papel>.md` seguido de lo concreto (rama, worktree, rutas de `spec.md`, `plan.md` y `tasks.md`, tareas o hallazgos, base de comparación `origin/main`) y estas dos líneas: «Si el worktree no está preparado (faltan dependencias o `.env.worktree`), ejecuta antes `mise trust && mise install && mise run setup`» e «Indica en tu informe el commit que has evaluado o el último que has hecho (`git rev-parse --short HEAD`)».
3. Lanza el trabajador con `agent`, `model` y `effort` de `pilotfish agents --json`:
   - `developer`: `--worktree current` (trabaja en la rama de la funcionalidad).
   - `qa`, `reviewer`, `bug_hunter` y `security`: `--worktree new-child` (un worktree propio a partir de la rama; aunque toquen algo, no afecta a la rama). Antes de dar por bueno su informe, comprueba que el commit evaluado es el último de la rama.
4. Espera los resultados con `orca orchestration check --wait` y un tiempo de espera largo (unos 15 minutos), sin consultar en bucle: cada consulta te cuesta uso. No termines tu turno mientras haya trabajadores sin informe: si lo terminas, nadie te despierta cuando lleguen. Si vence la espera, vuelve a esperar. Que no haya mensajes no significa que el trabajador esté parado: un desarrollador puede pasar muchos minutos leyendo y probando sin escribir nada.
5. Lee el informe completo (`worker-read`), libera el trabajador (`worker-release`) y, si era un worktree hijo, borra sus bases (`scripts/entorno-worktree.sh --borrar` dentro de él, si el proyecto lo tiene) y el worktree (`orca worktree rm`).

Nunca hay dos trabajadores tocando el mismo worktree a la vez. Mientras el desarrollador trabaja, tú tampoco cambias código ni ejecutas pruebas en ese worktree.

**Antes de dar por fallido a un trabajador** necesitas una prueba, no una sospecha: que la orquestación diga que ha terminado o fallado, o que su terminal muestre que el agente ha salido o que espera una respuesta que nunca llegará (un aviso de permisos, un error). Mira su estado y su terminal antes de decidir. Si sigue trabajando, espera. Si hay que sustituirlo, primero detenlo y libéralo (`worker-release`), confirma que ya no está activo y revisa `git status` del worktree: si dejó cambios a medias, decide con el usuario si se conservan o se descartan. Solo entonces lanzas al siguiente.

**Si un trabajador pide aceptar el modo bypass** («Bypass Permissions», «Acceso total»), no lo aceptes nunca, ni lo pidas al usuario. Detenlo y dile al usuario que en Orca, Ajustes → host del servidor → Agentes, cambie los permisos a «Aprobar por mí» (y que quite `--dangerously-skip-permissions` de los argumentos de Claude). Mientras tanto, si el papel es de Claude, haz el encargo con tus propios subagentes.

### Si un modelo se queda sin uso

Si un trabajador ha terminado de verdad (ver «Antes de dar por fallido a un trabajador») sin informe, o su salida dice que ha llegado a un límite de uso, de cuota o que no tiene sesión:

1. Vuelve a resolver los papeles excluyéndolo: `pilotfish agents --json --without <agente>`.
2. Relanza el mismo encargo con el nuevo modelo y díselo al usuario en una línea.
3. Si el papel queda en `paused`, para y avisa al usuario de qué falta y cuándo podrá seguir.

## Estado visible y relevo

Mantén al día el estado del worktree en Orca en cada cambio de fase, para que el usuario lo vea desde el móvil y para que otro coordinador pueda seguir:

```bash
orca worktree current --json                      # lee primero lo que ya hay
orca worktree set --worktree active --workspace-status in-progress --comment "<fase> · <qué se ha hecho> · <siguiente paso>"
```

Usa `todo`, `in-progress`, `in-review` (PR abierta) y `completed` (PR mergeada).

**Relevo.** Si el usuario te pide continuar un flujo que dejó a medias otro coordinador (por ejemplo, porque se quedó sin uso):

1. Lee el comentario del worktree (`orca worktree current --json`), `git log --oneline origin/main..HEAD` y los archivos de `docs/specs/NNN-*/` (`spec.md`, `plan.md`, `tasks.md` con sus tareas marcadas).
2. Mira las ejecuciones de orquestación (`orca orchestration run-list`), retoma la suya con `run-use` y revisa su buzón (`check`) por si hay resultados pendientes.
3. Resume al usuario en tres líneas dónde estaba y sigue desde ese paso del flujo.

## Al terminar un flujo

1. Estado del worktree a `in-review` con la URL de la PR.
2. Espera a que el CI de la PR termine (`gh pr checks <número> --watch`, o `glab ci status`). Si falla, arréglalo antes de seguir.
3. Cierra con: URL de la PR, resumen en 5 líneas (qué cambia, resultado de las auditorías, CI y pendientes) y «Cuando hagas merge, dímelo y lo dejo todo al día».

**Después del merge**, cuando el usuario te diga que lo ha hecho, o cuando lo veas al empezar otro flujo:

1. Comprueba que la PR está mergeada (`gh pr view <número> --json state`, o `glab mr view <número>`).
2. Pon al día la copia principal como en «Al empezar un flujo: poner al día», incluida la preparación si cambió algún archivo de preparación.
3. Borra la rama local de la PR si queda en la copia principal: `git branch -d <rama>`. Si se niega porque la PR se integró con squash y en el paso 1 confirmaste que está mergeada, usa `git branch -D <rama>`: su contenido ya está en `main`. Si no te dejan, dale al usuario el comando.
4. Estado del worktree a `completed`.
5. Si el flujo se hizo en un worktree de tarea, dile al usuario que ya puede archivarlo en Orca: al archivarlo, Orca ejecuta el script de archivado de `orca.yaml` y se borran sus bases. No lo borres tú mientras trabajas dentro de él.
