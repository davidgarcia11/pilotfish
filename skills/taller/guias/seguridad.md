# Seguridad desde el diseño

## En el plan

1. **Modelo de amenazas breve.** Activos (datos, dinero, cuentas), actores (anónimo, usuario, administrador, sistema externo), puntos de entrada y, para cada uno, qué puede salir mal (suplantación, manipulación, fuga de datos, denegación de servicio, escalada de privilegios) y la mitigación.
2. **Autenticación.** Proveedor o librería probada del stack, nunca hecha a mano. Contraseñas con argon2id o bcrypt si las hay. Cookies `HttpOnly`, `Secure`, `SameSite`. Límite de intentos. Doble factor si hay datos sensibles o dinero.
3. **Autorización.** Modelo explícito (roles, propiedad del recurso), comprobado en servidor en cada operación y a nivel de objeto. Denegar por defecto.
4. **Datos personales (RGPD).** Inventario de qué se guarda, para qué, base legal y cuánto tiempo. Minimización. Alojamiento en la UE. Derecho de acceso y supresión posibles. Categorías especiales (salud, biometría) solo si son imprescindibles.
5. **Secretos.** En local, `.env` fuera de git y validado al arrancar. En producción, el gestor de secretos del hosting o de la forja, nunca en el código ni en imágenes. Quién puede verlos y cómo se rotan.
6. **Dependencias.** Lockfile siempre, `osv-scanner` en el check, actualizaciones semanales (Dependabot en GitHub; `mise outdated` y el gestor del stack en GitLab). Dependencias nuevas justificadas.
7. **Web.** CSP, HSTS, `X-Content-Type-Options`, `frame-ancestors` y CORS restrictivo configurados desde el primer commit. Protección CSRF con autenticación por cookie.
8. **Operación.** Copias de seguridad cifradas con restauración probada, logs de eventos de seguridad sin datos personales, alertas de errores.

## Al montar el proyecto

- Cabeceras de seguridad y validación de configuración presentes en el código inicial, no como tarea pendiente.
- CI con `permissions: contents: read` y sin secretos en pull requests de forks.
- GitHub: activa las alertas de Dependabot y las actualizaciones de seguridad automáticas:
  ```bash
  gh api -X PUT repos/<owner>/<repo>/vulnerability-alerts
  gh api -X PUT repos/<owner>/<repo>/automated-security-fixes
  ```
- En `AGENTS.md`, la zona sensible (autenticación, permisos, pagos, datos personales) con sus rutas reales.

## Lo que no protege nada

- Ocultar rutas o IDs como única defensa.
- Validar solo en el cliente.
- Confiar en roles o IDs que envía el cliente.
- Desactivar una regla del linter o un test para que el check pase.
