# NOMBRE

<!-- Una frase: qué hace y para quién. -->

Estas reglas valen para cualquier agente que trabaje en el proyecto. Archivo local: nunca va a git.

## Contexto

- Stack: <!-- runtime · framework · datos · auth · hosting -->. Versiones en `mise.toml`.
- Arquitectura y principios: `docs/ARCHITECTURE.md`. Decisiones: `docs/adr/`. Especificaciones: `docs/specs/`.
- Léelos antes de diseñar o cambiar estructura.

## Vocabulario del dominio

- <!-- término correcto --> (nunca "<!-- término genérico -->")

## Cómo se trabaja

- Funcionalidad nueva, cambio de comportamiento o bug: siguen el proceso del taller (especificación y plan aprobados por el usuario antes de programar).
- Cambios no triviales fuera del proceso: plan y aprobación del usuario antes de tocar código.

## Reglas generales

- Herramientas y dependencias solo dentro del proyecto (`mise.toml` o gestor del stack). Nada global, nada con `sudo`.
- Comandos del runtime con `mise exec --` o `mise run`.
- Valida entradas en los bordes con <!-- zod/pydantic/... -->.
- <!-- Reglas del dominio: "nunca hagas X" -->
- Si cambia la estructura o el stack, actualiza `docs/ARCHITECTURE.md` o añade un ADR en la misma PR.
- API pública con comentarios de documentación; OpenAPI generado desde el código si hay API; README y runbook al día en el mismo commit que los cambia.
- `CHANGELOG.md` nunca a mano: sale de los commits.
- Datos de referencia (divisas, países, impuestos, zonas horarias…) desde la fuente oficial o una librería mantenida, con la URL y la fecha en el código. Nunca de memoria.
- Autoría: commits, PR, código, comentarios y docs nunca mencionan a ningún asistente, modelo ni herramienta de IA. Sin `Co-Authored-By` de herramientas, enlaces de sesión ni «Generated with».
- Prohibido: commit en `main`, merge, force push, `--no-verify`, borrar la base de desarrollo (`db:reset`, `docker compose down -v`, `dropdb`), `git clean`, leer `.env`, desplegar a producción.

## Reglas por zona

### Tests (RUTAS_DE_TESTS)

- Test primero: se ejecuta y se ve fallar por el motivo esperado antes de implementar.
- Un comportamiento por test; nombre que describe el comportamiento esperado.
- Preparar, actuar, comprobar. Aserciones concretas, nunca solo «no lanza error».
- Deterministas: reloj, aleatoriedad y red inyectados o simulados en los unitarios. Sin `sleep`.
- Integración contra la base de datos real en contenedor, no simulada.
- Los tests usan siempre la base de tests (`TEST_DATABASE_URL`), nunca la de desarrollo. Lo mismo para pruebas que rompen código o meten datos inválidos.
- Datos de prueba con factorías; nunca datos personales reales.
- Ejecutar un archivo: COMANDO_TEST_ARCHIVO

### API (RUTAS_DE_API)

- Toda entrada se valida con el esquema del proyecto antes de usarla; si no valida, error 400 con el formato común.
- Cada operación comprueba en servidor quién la pide y si puede actuar sobre ese recurso concreto (no solo el rol).
- Formato de error único: código estable, mensaje legible, sin trazas internas.
- Listados siempre paginados con límite máximo.
- Nada de datos personales, tokens ni contraseñas en logs.

### Datos y migraciones (RUTAS_DE_ESQUEMA_Y_MIGRACIONES)

- Nunca se edita una migración ya aplicada: se crea otra.
- Migraciones reversibles. Un cambio incompatible va en pasos: ampliar, migrar datos, contraer.
- Restricciones en la base de datos (únicos, no nulos, claves foráneas), no solo en código.
- Índice para cada consulta nueva sobre columnas no indexadas.

### Interfaz (RUTAS_DE_INTERFAZ)

- Accesible: etiquetas en formularios, navegación con teclado, foco visible, contraste AA, textos alternativos.
- Cada vista con datos tiene estados de carga, vacío y error.
- Nada de secretos ni lógica de permisos en el cliente: el servidor decide.
- Sin HTML sin sanear (`dangerouslySetInnerHTML`, `v-html`, `innerHTML`).

### Zonas sensibles (RUTAS_SENSIBLES): autenticación, permisos, pagos y datos personales

- Usa la librería de autenticación del proyecto; nada de criptografía ni sesiones hechas a mano.
- Denegar por defecto: cada permiso nuevo se concede de forma explícita y se prueba que se deniega a quien no lo tiene.
- Comparaciones de secretos en tiempo constante; tokens con aleatoriedad criptográfica.
- Al cambiar contraseña o permisos, invalida las sesiones afectadas.

## Comandos

- `mise run setup`: tras clonar y en cada worktree nuevo
- `mise run check`: lint, formato, tipos, tests, build, secretos y dependencias (igual que CI)
- `mise run changelog`: regenera el CHANGELOG · `mise run version`: prepara una versión
- <!-- arranque en desarrollo -->

## Flujo de git

1. Rama desde `main`: `feat/NNN-nombre`, `fix/nombre`, `chore/` o `docs/`.
2. Commits pequeños en conventional commits, en español.
3. `mise run check` en verde antes de cada commit.
4. `git push -u`, luego PR/MR con la plantilla del repositorio. El merge lo hace el usuario.

## Alcance actual

<!-- Qué NO construir todavía. -->

## Decisiones abiertas

<!-- Pendientes. No asumir ninguna opción. -->
