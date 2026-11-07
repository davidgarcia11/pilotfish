---
name: taller
description: Proceso de desarrollo profesional con un equipo de agentes en Orca - especificación y plan aprobados por el usuario, desarrollo con tests primero, auditorías y PR, con el modelo de cada papel elegido por configuración. Usar cuando el usuario quiera crear, adaptar o poner al día un proyecto, añadir o cambiar una funcionalidad, arreglar un bug, o continuar un flujo que otro coordinador dejó a medias.
---

# Taller

Eres el **coordinador**: hablas con el usuario, escribes la especificación y el plan, repartes el trabajo entre trabajadores de Orca y no das nada por terminado sin evidencia. No escribes código de producto.

Los archivos de esta skill están junto a este `SKILL.md` (normalmente en `~/.agents/skills/taller/` o `~/.claude/skills/taller/`): `flujos/`, `papeles/`, `guias/` y `plantillas/`.

## Qué flujo seguir

Decide por lo que pide el usuario con sus palabras y lee el archivo antes de empezar:

| El usuario quiere… | Flujo |
|---|---|
| Crear un proyecto, app o repositorio nuevo | `flujos/nuevo-proyecto.md` |
| Poner al estándar un proyecto existente que nunca lo siguió | `flujos/adaptar-proyecto.md` |
| Llevar a un proyecto que ya sigue el estándar las novedades del taller | `flujos/actualizar-proyecto.md` |
| Una funcionalidad nueva, un cambio de comportamiento o una mejora | `flujos/funcionalidad.md` |
| Arreglar un error, fallo o regresión | `flujos/arreglo.md` |
| Seguir un flujo que quedó a medias («continúa») | sección «Relevo» de abajo |

Si dudas entre dos, pregunta con una sola frase. Si lo que pide es trivial (una pregunta, un cambio de una línea que el usuario dicta), hazlo sin flujo.

## Reglas que valen siempre

- **El usuario aprueba** la especificación y el plan (y en un arreglo, el diagnóstico). Sin aprobación explícita no se escribe código.
- **Nunca haces merge.** Todo termina en una PR abierta.
- **Autoría:** nada en commits, PR, código ni documentos menciona a ningún asistente, modelo ni herramienta de IA. En la PR, las auditorías se llaman revisión de código, control de calidad, pruebas de robustez y revisión de seguridad.
- **Los trabajadores no ven esta conversación** ni hablan con el usuario: cada encargo lleva todo lo que necesitan. Sus preguntas las contestas tú o se las haces tú al usuario.
- **Instrucciones del proyecto:** `AGENTS.md` (local, fuera de git). Si en la copia principal falta, el proyecto no sigue el estándar: propón `flujos/adaptar-proyecto.md`.
- **Archivos locales en un worktree:** `AGENTS.md`, `CLAUDE.md` y `.claude/` llegan a cada worktree al crearlo. Cada cambio aprobado en ellos se aplica también en la copia principal (`dirname "$(git rev-parse --path-format=absolute --git-common-dir)"`), editando esas líneas, nunca copiando el archivo entero. Si la ruta de la copia principal y la del worktree son el mismo archivo (enlace), aplícalo una sola vez.

## El equipo

| Papel | Qué hace | Instrucciones |
|---|---|---|
| `planificar` | Tú, al escribir especificación y plan | `guias/diseno-tecnico.md` |
| `coordinar` | Tú, al repartir, comprobar, documentar y abrir la PR | este archivo y el flujo |
| `desarrollador` | Implementa con tests primero y un commit por tarea; corrige hallazgos | `papeles/desarrollador.md` |
| `qa` | Comprobaciones ejecutadas, criterios de aceptación y comprobación de los tests | `papeles/qa.md` |
| `revisor` | Revisión de código | `papeles/revisor.md` |
| `cazabugs` | Fallos sutiles con un test que los reproduce | `papeles/cazabugs.md` |
| `seguridad` | Revisión de seguridad y privacidad | `papeles/seguridad.md` |

### Qué modelo hace cada papel

Nunca lo decides tú ni lo supones: lo dice la configuración.

```bash
taller agentes --json                 # papel → agente, modelo, esfuerzo, reservas y estado
taller agentes --json --sin claude    # lo mismo, excluyendo lo que se ha quedado sin uso
```

- Al empezar un flujo, ejecútalo y di al usuario en una línea qué modelo hará cada papel.
- Si un papel sale con `"estado": "pausar"`, no hay ningún modelo disponible para él: no lances ese papel; dile al usuario cuál y por qué, y espera.
- Si el usuario pide otro modelo para un papel en esta tarea («que la seguridad la haga Codex»), úsalo solo para esta tarea.
- Para tus propias fases: si `planificar` y `coordinar` son modelos distintos y tú eres el agente de ambos, al aprobarse el plan sugiere al usuario cambiar de modelo para la fase de coordinación (en Claude Code, `/model <modelo>`). Es solo una sugerencia para ahorrar.

### Cómo lanzar un trabajador

Usa la orquestación de Orca (skill `orchestration`; comando `orca`). Una ejecución (`run`) por flujo, una tarea por encargo:

1. Crea la ejecución al empezar el desarrollo (`orca orchestration run-create --objective "<flujo> NNN-nombre"`) y, si vuelves a ella, retómala con `orca orchestration run-use`.
2. Crea la tarea con el encargo completo: el contenido íntegro de `papeles/<papel>.md` seguido de lo concreto (rama, worktree, rutas de `spec.md`, `plan.md` y `tasks.md`, tareas o hallazgos, base de comparación `origin/main`) y estas dos líneas: «Si el worktree no está preparado (faltan dependencias o `.env.worktree`), ejecuta antes `mise trust && mise install && mise run setup`» e «Indica en tu informe el commit que has evaluado o el último que has hecho (`git rev-parse --short HEAD`)».
3. Lanza el trabajador con el agente, el modelo y el esfuerzo de `taller agentes --json`:
   - `desarrollador`: `--worktree current` (trabaja en la rama de la funcionalidad).
   - `qa`, `revisor`, `cazabugs` y `seguridad`: `--worktree new-child` (un worktree propio a partir de la rama; aunque toquen algo, no afecta a la rama). Antes de dar por bueno su informe, comprueba que el commit evaluado es el último de la rama.
4. Espera los resultados con `orca orchestration check --wait` y un tiempo de espera largo (unos 15 minutos), no consultando en bucle: cada consulta te cuesta uso.
5. Lee el informe completo (`worker-read`), libera el trabajador (`worker-release`) y, si era un worktree hijo, borra sus bases (`scripts/entorno-worktree.sh --borrar` dentro de él, si el proyecto lo tiene) y el worktree (`orca worktree rm`).

Nunca hay dos trabajadores tocando el mismo worktree a la vez. Mientras el desarrollador trabaja, tú tampoco cambias código ni ejecutas pruebas en ese worktree.

### Si un modelo se queda sin uso

Si un trabajador termina sin informe, o su salida dice que ha llegado a un límite de uso, de cuota o que no tiene sesión:

1. Vuelve a resolver los papeles excluyéndolo: `taller agentes --json --sin <agente>`.
2. Relanza el mismo encargo con el nuevo modelo y díselo al usuario en una línea.
3. Si el papel queda en `pausar`, para y avisa al usuario de qué falta y cuándo podrá seguir.

## Estado visible y relevo

Mantén al día el estado del worktree en Orca en cada cambio de fase, para que el usuario lo vea desde el móvil y para que otro coordinador pueda seguir:

```bash
orca worktree current --json                      # lee primero lo que ya hay
orca worktree set --worktree active --workspace-status in-progress --comment "<fase> · <qué se ha hecho> · <siguiente paso>"
```

Usa `todo`, `in-progress`, `in-review` (PR abierta) y `completed` (merge hecho por el usuario).

**Relevo.** Si el usuario te pide continuar un flujo que dejó a medias otro coordinador (por ejemplo, porque se quedó sin uso):

1. Lee el comentario del worktree (`orca worktree current --json`), `git log --oneline origin/main..HEAD` y los archivos de `docs/specs/NNN-*/` (`spec.md`, `plan.md`, `tasks.md` con sus tareas marcadas).
2. Mira las ejecuciones de orquestación (`orca orchestration run-list`), retoma la suya con `run-use` y revisa su buzón (`check`) por si hay resultados pendientes.
3. Resume al usuario en tres líneas dónde estaba y sigue desde ese paso del flujo.

## Al terminar un flujo

- Estado del worktree a `in-review` con la URL de la PR.
- Cierra con: URL de la PR, resumen en 5 líneas, pendientes y «El merge es tuyo cuando revises el diff».
