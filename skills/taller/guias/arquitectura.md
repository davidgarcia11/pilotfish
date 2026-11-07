# Diseñar la arquitectura

## Punto de partida

- **Monolito modular** por defecto. Microservicios, colas o eventos solo con una razón medible (escala, equipos independientes, aislamiento de fallos) escrita en un ADR.
- **Organización por dominio o funcionalidad**, no por capa técnica: `partes/`, `obras/`, `trabajadores/` antes que `controllers/`, `services/`, `models/`.
- **Dependencias hacia el dominio.** La lógica de negocio no importa frameworks, base de datos ni HTTP. Separa dominio e I/O solo donde haya reglas de negocio reales; un CRUD no necesita capas.
- **Sin dependencias circulares** entre módulos. Cada módulo expone una interfaz pequeña y oculta el resto.

## Decisiones que el plan debe dejar escritas

| Aspecto | Qué decidir |
|---|---|
| Atributos de calidad | Los 2 o 3 que mandan (seguridad, disponibilidad, rendimiento, coste) y su objetivo medible |
| Datos | Fuente única del esquema, tipos derivados de ella, migraciones versionadas y reversibles, restricciones en base de datos |
| Bordes | Validación con esquema en HTTP, formularios, ficheros, colas y variables de entorno; configuración validada al arrancar |
| Errores | Errores de dominio tipados, formato único de error hacia fuera, nada de trazas internas al usuario |
| Observabilidad | Logs estructurados en los bordes y en errores, sin datos personales; dónde se ven los errores en producción |
| Contratos | Cómo se describen las APIs (OpenAPI generado desde el código) y cómo se versionan |
| Estado y concurrencia | Transacciones, idempotencia en operaciones repetibles, bloqueo optimista donde dos personas editan lo mismo |
| Ficheros | Dónde se guardan (almacenamiento de objetos, nunca el disco del servidor), tamaño máximo, tipos permitidos |
| Interfaz | Accesibilidad (WCAG AA), estados de carga, vacío y error, uso en móvil si aplica |

## Pruebas

Unitarias en lógica de dominio, integración en endpoints y base de datos (con base real en contenedor, no simulada), extremo a extremo solo en flujos críticos.

## Entregables en el plan

Diagrama Mermaid de componentes y servicios externos, árbol de carpetas con la responsabilidad de cada una, modelo de datos inicial, límites entre módulos y el ADR 0001 con las alternativas descartadas.
