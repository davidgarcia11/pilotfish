# Flujo: arreglo

Primero la causa raíz, después el test que la demuestra, después la corrección mínima. Nunca se corrige un síntoma sin entender la causa.

```text
1. Reproducir
2. Diagnóstico aprobado
3. Test de regresión y corrección
4. Auditorías y correcciones
5. PR abierta
```

## 1. Reproducir

```bash
git status --porcelain          # si no está vacío, para y pregunta
git fetch origin --prune
test "$(git rev-parse --git-dir)" = "$(git rev-parse --git-common-dir)" && echo principal || echo worktree
pilotfish agents --json
```

- **Copia principal:** `git switch main && git pull --ff-only && git switch -c fix/nombre-corto`.
- **Worktree de Orca:** no cambies a `main`. Si la rama actual no tiene commits propios (`git log origin/main..HEAD` vacío), `git reset --hard origin/main` y `git branch -m fix/nombre-corto`. Si ya tiene commits, para y pregunta.

Consigue pasos exactos, entrada, resultado esperado y obtenido. Si faltan, pregunta al usuario. Reprodúcelo en local antes de seguir. Si no se reproduce, dilo y pide más datos: sin reproducción no hay arreglo.

## 2. Diagnóstico

Encuentra la causa raíz (lectura del código, `git log -S` y `git blame` sobre la zona, pruebas acotadas). Busca el mismo patrón en el resto del código. Presenta al usuario:

- Síntoma y causa raíz, con `ruta:línea`.
- Desde cuándo y qué lo introdujo, si se sabe.
- Otros sitios con el mismo patrón.
- Corrección propuesta y su riesgo.
- Si hay datos ya dañados, cómo detectarlos y repararlos (decisión aparte).

Si la corrección cambia el modelo de datos, contratos o varios módulos, sigue `guias/diseno-tecnico.md` y escribe un plan breve en `docs/specs/` antes de pedir la aprobación.

## 3. Test de regresión y corrección

Lanza el `developer` (`--worktree current`). Encargo, además de su papel:

> Rama `fix/nombre-corto`, en este worktree. Bug: <síntoma, pasos y causa raíz con rutas>. Primero escribe un test que reproduzca el bug y confirma que falla. Después aplica la corrección mínima aprobada: <corrección>. `mise run check` y commit `fix(ámbito): ...`. Corrige también estos sitios con el mismo patrón: <lista o «ninguno»>.

Comprueba tú que el test existe y que su motivo de fallo en rojo coincide con el bug.

## 4. Auditorías y correcciones

Lánzalos a la vez, cada uno en su worktree hijo (`--worktree new-child`):

| Papel | Cuándo |
|---|---|
| `qa` | Siempre; con la comprobación de los tests sobre la corrección (revertirla debe hacer fallar el test nuevo) |
| `security` | Si el bug o la corrección tocan permisos, autenticación, entradas o datos personales |
| `reviewer` | Si la corrección supera unas 50 líneas o toca varios módulos |
| `bug_hunter` | Si el tipo de bug sugiere hermanos (límites, concurrencia, formatos) |

Encargo: rama, descripción del bug, causa raíz y corrección. Mismas reglas de gravedad, correcciones y rondas que en `flujos/funcionalidad.md`.

## 5. PR

```bash
mise run check
git push -u origin fix/nombre-corto
```

Cuerpo con la plantilla del proyecto: síntoma, causa raíz, corrección, test de regresión, cómo probarlo y pendientes. Título `fix(ámbito): descripción`. Si hay datos dañados que reparar, indícalo como paso aparte. Si el bug fue grave en producción, propón al usuario un informe en `docs/incidencias/AAAA-MM-DD-titulo.md` (cronología, causa raíz, impacto y acciones).

Después, la sección «Al terminar un flujo» de `SKILL.md`: CI, pregunta del merge y puesta al día.
