# Elegir el stack

## Método

1. **Requisitos que deciden.** Del descubrimiento, extrae solo lo que condiciona la tecnología: tipo de producto, usuarios y concurrencia esperada, datos (relacionales, documentos, ficheros, tiempo real), integraciones, despliegue y presupuesto, plataformas (web, móvil, escritorio) y requisitos legales.
2. **Candidatos.** Dos o tres opciones realistas por capa, nunca más. El stack que el usuario ya domina siempre es candidato.
3. **Verificación en vivo** de cada candidato antes de recomendarlo (WebSearch y documentación oficial, nunca de memoria):
   - versión estable actual y si es LTS;
   - fecha de fin de soporte (endoflife.date o la web oficial);
   - actividad del proyecto: última versión, mantenedores, ritmo de parches de seguridad;
   - vulnerabilidades conocidas recientes;
   - licencia compatible con el uso previsto.
4. **Evaluación** con la tabla de criterios. Descarta lo que falle un criterio eliminatorio.
5. **Recomendación**: una opción por capa, con su motivo y la alternativa descartada. El usuario decide.

## Criterios

| Criterio | Eliminatorio cuando |
|---|---|
| Encaje con los requisitos | No cubre una capacidad de la v1 sin rodeos |
| Dominio del usuario | — (pesa mucho: una tecnología conocida y madura gana a una mejor que no conoce) |
| Madurez y soporte | Sin versión estable, sin mantenimiento activo o con fin de soporte en menos de un año |
| Seguridad | Historial de vulnerabilidades graves sin parchear o sin política de seguridad |
| Tipado y tooling | Sin tipado estático ni linter maduro (salvo scripts pequeños) |
| Coste de operar | Requiere infraestructura que el presupuesto o el equipo no pueden mantener |
| Ecosistema | Las librerías clave del dominio no existen o están abandonadas |
| Simplicidad | Añade piezas (colas, microservicios, caché) que la v1 no necesita |

Preferencias por defecto, salvo que los requisitos digan otra cosa:

- **Una sola tecnología** de punta a punta antes que dos (TypeScript en cliente y servidor, por ejemplo).
- **Servicios gestionados** (base de datos, autenticación, correo, ficheros) antes que autogestionados.
- **Autenticación de un proveedor o librería probada**, nunca hecha a mano.
- **Postgres** para datos relacionales multiusuario; **SQLite** para local o monousuario.
- **Hosting en la UE** si hay datos personales de personas en la UE.

## Stacks de referencia

| Stack | Para | En `mise.toml` | Scaffold | Tareas base |
|---|---|---|---|---|
| Next.js (TS) | Web fullstack, paneles, apps internas | `node` LTS | `npx create-next-app@<versión> . --yes --disable-git` | `tareas/node.toml` |
| API Node (TS) | API sola, integraciones | `node` LTS | `npm init -y` + Fastify o Hono | `tareas/node.toml` |
| Python | API (FastAPI), datos, IA, automatización, CLI | `python`, `uv` | `uv init` | `tareas/python.toml` |
| Java / Spring Boot | Backend empresarial, dominios complejos | `java` temurin LTS | Spring Initializr con Maven Wrapper | `tareas/java.toml` |
| Go | Servicios de alto rendimiento, CLI distribuibles | `go`, `golangci-lint` | `go mod init <módulo>` | `tareas/go.toml` |
| SwiftUI | Apps de Apple | nada; Xcode del App Store | proyecto de Xcode | swiftlint · `xcodebuild test` |

Para cada stack, en el plan: framework de tests, linter, formateador, validación de esquemas, ORM o capa de datos y librería de autenticación, todos con versión verificada.
