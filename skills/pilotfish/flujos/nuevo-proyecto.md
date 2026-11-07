# Flujo: nuevo proyecto

Actúa como arquitecto de software, senior del stack elegido e ingeniero de plataforma. Cada decisión: la mínima que cubre el alcance v1, justificada y reversible.

## Reglas

- Las fases 1 y 2 no crean ni instalan nada. La fase 3 empieza solo con aprobación explícita del plan.
- Todo por proyecto: runtimes y CLIs en `mise.toml`, dependencias dentro del repo. Nunca `npm i -g`, `pip install` fuera de `.venv`, `curl | sh`, `sudo` ni instalaciones globales sin permiso explícito.
- Comandos del runtime con `mise exec -- <cmd>` o `mise run <tarea>`.
- Versiones siempre verificadas en vivo (`mise latest <tool>`, `npm view <pkg> version`, docs oficiales). Nunca de memoria.
- Sin abstracciones especulativas: ni capas vacías, ni interfaces con una sola implementación, ni microservicios sin una razón medible.
- Si el directorio destino existe y no está vacío, para y pregunta. Excepción: un repo recién creado (por ejemplo desde Orca) se usa tal cual si no tiene archivos fuera de `.git`, o solo un `README`/`.gitignore` de plantilla, y como mucho un commit inicial. Si estás en un worktree (`git rev-parse --git-dir` ≠ `--git-common-dir`), para: el proyecto se crea en la copia principal.
- Comandos no interactivos. Un comando por llamada cuando dependa del anterior.
- Commits en conventional commits, en español. Nada en el repositorio menciona a ningún asistente ni herramienta de IA. `AGENTS.md`, `CLAUDE.md`, `.claude/` y `.worktreeinclude` existen solo en local, excluidos de git.

## Fase 1. Descubrimiento

Pregunta solo lo que no se deduzca de lo que ha dicho el usuario:

1. Problema, usuarios y qué entra en la v1 (y qué no).
2. Tipo: web fullstack, API, CLI, app nativa, librería, automatización o agente.
3. Datos personales o sensibles. Si los hay: región UE, minimización, base legal y retención.
4. Despliegue previsto, entornos y presupuesto.
5. Forja (GitHub o GitLab) y visibilidad (privado por defecto).
6. Stack: el que pida el usuario (verificado igualmente con `guias/stack.md`); si no, lo recomiendas en la fase 2.

## Fase 2. Plan

Lee y aplica `guias/stack.md`, `guias/arquitectura.md` y `guias/seguridad.md`. Preséntalo sin relleno:

1. **Alcance v1**: 3 a 7 capacidades y lista de fuera de alcance.
2. **Stack**: tabla capa | elección | versión verificada | fin de soporte | motivo | alternativa descartada. Capas: runtime, framework, datos, auth, hosting, tests, lint/formato.
3. **Arquitectura**: estilo, diagrama Mermaid, árbol de carpetas, modelo de datos inicial, límites entre módulos y las decisiones de la tabla de `guias/arquitectura.md`.
4. **Principios del proyecto**: los cinco base de `docs/ARCHITECTURE.md` más los propios del dominio.
5. **Calidad**: qué se testea y a qué nivel; qué ejecuta `mise run check`.
6. **Seguridad y privacidad** según `guias/seguridad.md`.
7. **Operación**: entornos, despliegue, migraciones, copias de seguridad, logs y errores, secretos en producción.
8. **Documentación**: README, arquitectura, ADR, especificaciones, comentarios de documentación en la API pública y CHANGELOG desde los commits. Si hay API: OpenAPI generado desde el código. Si hay despliegue: runbook.
9. **Instalación**: lista exacta de lo que va a `mise.toml`, servicios locales (contenedores) y lo que, si algo, queda global.
10. **Riesgos y decisiones abiertas.**

Pide aprobación explícita e itera hasta tenerla.

**Servicios locales** (Postgres, Redis, correo de pruebas…): contenedores con un `compose.yaml` en el proyecto. La aplicación corre en la máquina con mise. Un solo contenedor de base de datos para todos los worktrees, y en él unas bases propias de cada worktree (`scripts/entorno-worktree.sh`), para poder trabajar en paralelo.

## Fase 3. Ejecución

### 1. Comprobaciones

```bash
command -v git mise docker && docker compose version
git config user.name && git config user.email
gh auth status        # GitLab: glab auth status
```

Si falta algo, para y dilo. Si falta Docker y el plan lo necesita, pide permiso al usuario (es la única instalación global permitida): en Linux, Docker Engine con su guía oficial y el usuario en el grupo `docker`; en macOS, `brew install colima docker docker-compose` y `colima start`.

Ruta por defecto: `~/Projects/<nombre>`, o la carpeta actual si es un repo recién creado.

### 2. Scaffold y runtimes

Con la carpeta vacía, scaffold primero con versión explícita y sin git propio; después fija las herramientas. Si estás dentro de un repo recién creado, trabaja en esa carpeta; si tiene un commit inicial, bórralo (`git update-ref -d HEAD`, y quita el README o `.gitignore` de plantilla) y deja la rama en `main` (`git symbolic-ref HEAD refs/heads/main`).

```bash
mkdir -p ~/Projects/<nombre> && cd ~/Projects/<nombre>   # salvo repo recién creado
mise exec <tool>@<versión> -- <comando de scaffold>
mise use --pin <tool>@<versión>      # una vez por herramienta del plan
mise use --pin gitleaks@latest
mise use --pin osv-scanner@latest    # si no está en el registro: aqua:google/osv-scanner@latest
mise use --pin git-cliff@latest
mise trust
git init -b main                     # si el scaffold ya creó el repo: git branch -M main
```

Si el scaffold hizo su propio commit, borra `.git` y vuelve a `git init -b main`. Si generó `AGENTS.md` o `CLAUDE.md`, integra lo útil en tu `AGENTS.md` y deja `CLAUDE.md` con `@AGENTS.md`.

### 3. Base del estándar

```bash
pilotfish scaffold --forge github   # o gitlab; --services y --runbook si el plan los incluye
```

Copia sin sobrescribir: hooks de git (secretos, formato de commits y firmas de IA), `scripts/comprobar-commits.sh`, `cliff.toml`, CI, plantilla de PR/MR, `docs/`, `AGENTS.md`, `CLAUDE.md`, `.claude/` (permisos y hook que bloquea commits en `main`), `.worktreeinclude`, y con `--services` el `compose.yaml` y `scripts/entorno-worktree.sh`. Configura `core.hooksPath`, la exclusión local y el `.gitignore`. Lee su salida y resuelve lo que indique.

### 4. Rellenar con el plan aprobado

- `mise.toml`: las tareas de `$(pilotfish path)/plantillas/tareas/<stack>.toml` (no las copia `pilotfish scaffold`: adáptalas al proyecto), más `version.toml` y, con servicios, `servicios.toml`. `check` incluye lint, formato, tipos, tests, build, `gitleaks` y `osv-scanner`. Con servicios, `setup` termina con `mise run entorno`.
- Herramientas de lint, formato y test del stack como dependencias de desarrollo, con su configuración.
- **Con base de datos:** la app usa `DATABASE_URL` y los tests `TEST_DATABASE_URL`, nunca la de desarrollo, con las migraciones aplicadas antes de ejecutarlos. El servidor de desarrollo usa `PORT` y los e2e `E2E_PORT`. Todas salen de `.env.worktree`, que mise carga después de `.env`. En CI, el servicio de base de datos hace de base de tests. En `.env` usa una contraseña de base de datos sin caracteres especiales de URL.
- Con API: OpenAPI generado desde el código, nunca escrito a mano, exportado con `mise run api-docs`; `check` falla si no coincide.
- `AGENTS.md`, `docs/ARCHITECTURE.md`, `docs/adr/0001-stack-y-arquitectura.md` y, con despliegue, `docs/RUNBOOK.md` con el plan aprobado. En `AGENTS.md`, sustituye `RUTAS_*` por los patrones reales (por ejemplo `src/**/*.test.ts`) y `COMANDO_TEST_ARCHIVO` por el comando del stack; borra las zonas que no apliquen y añade las del dominio.
- Seguridad del código inicial según `guias/seguridad.md`: cabeceras, validación de configuración y autenticación de librería desde el primer commit.
- `README.md`: qué es, requisitos (mise; Docker si hay servicios), arranque (`mise trust && mise install && mise run setup`) y comandos.
- `.env.example`: cada variable que necesite el proyecto, sin valores.
- GitHub: `ECOSISTEMA` en `.github/dependabot.yml`. GitLab: `VERSION_MISE` en `.gitlab-ci.yml`.
- Versiones de imagen verificadas en `compose.yaml` y versiones mayores actuales de las actions del CI.

No debe quedar ningún marcador:

```bash
grep -rnE 'NOMBRE|VERSION_[A-Z]+|ECOSISTEMA|AAAA-MM-DD|RUTAS_[A-Z_]+|COMANDO_TEST' --exclude-dir={.git,node_modules,.venv,target,.mise} . AGENTS.md
grep -n '<!--' AGENTS.md docs/ARCHITECTURE.md docs/adr/0001-*.md docs/RUNBOOK.md 2>/dev/null
```

### 5. Probar las protecciones

Cada uno de estos commits debe fallar:

```bash
printf 'token=ghp_%s\n' "$(LC_ALL=C tr -dc 'A-Za-z0-9' </dev/urandom | head -c 36)" > leak-test.txt
git add leak-test.txt && git commit -m "test: gitleaks"
git rm --cached -q leak-test.txt && rm leak-test.txt
```

```bash
git commit --allow-empty -m "mensaje sin formato"
```

Si alguno pasa, para: la protección no funciona.

### 6. Verificación local

```bash
mise run setup
mise run check
```

Corrige hasta que pase.

### 7. Primer commit y repositorio

```bash
git add -A
git status --short     # nada de .env, node_modules, binarios, secretos ni archivos de los agentes
git commit -m "chore: estructura inicial del proyecto"
gh repo create <nombre> --private --source=. --remote=origin --push   # si ya existe origin: git push -u origin main
```

GitLab: `glab repo create <nombre> --private --defaultBranch main` y `git push -u origin main`.

GitHub: activa las alertas y actualizaciones de seguridad de Dependabot con los comandos de `guias/seguridad.md`. Un repositorio privado gratuito no protege ramas: los hooks, el CI y el merge hecho por el usuario hacen de barrera.

### 8. Comprobación de limpieza

- `mise ls`: cada herramienta con origen en el `mise.toml` del proyecto.
- `git ls-files | grep -iE 'claude|agents\.md|worktreeinclude'` vacío y `scripts/comprobar-commits.sh $(git rev-list --max-parents=0 HEAD)..HEAD` en verde.

### 9. Cierre

Resume en 8 líneas como máximo: ruta, stack, URL del repo y comandos. Termina con la configuración de Orca para el repositorio (Ajustes → Repositorio):

- Rama base: `origin/main`.
- Script de preparación: `mise trust && mise install && mise run setup`.
- Al borrar un worktree, si Orca permite un script de archivo: `scripts/entorno-worktree.sh --borrar`.
