# Runbook de NOMBRE

> Procedimientos de operación paso a paso. Cada procedimiento se prueba al menos una vez antes de necesitarlo.

## Entornos

| Entorno | URL | Despliegue | Datos |
|---|---|---|---|
| Producción | | | reales |
| Pruebas | | | ficticios |

## Desplegar

1.
2.
3. Comprobación posterior: <!-- ruta de salud, flujo clave -->

## Volver a la versión anterior

1.
2.

## Migraciones de base de datos en producción

- Antes: copia de seguridad reciente comprobada.
- Migraciones compatibles con la versión anterior del código (ampliar → desplegar → contraer).
- Cómo aplicarlas:
- Cómo revertirlas:

## Copias de seguridad

| Qué | Frecuencia | Retención | Dónde |
|---|---|---|---|
| Base de datos | | | |
| Archivos subidos | | | |

### Restaurar

1.
2.
3. Última prueba de restauración: pendiente

## Secretos

| Secreto | Dónde vive | Cómo se rota | Última rotación |
|---|---|---|---|
| | | | |

## Monitorización y alertas

| Señal | Umbral | Quién recibe la alerta |
|---|---|---|
| Errores | | |
| Disponibilidad | | |

## Incidencias

1. Confirmar el alcance: qué falla, desde cuándo, a quién afecta.
2. Mitigar primero (volver a la versión anterior, desactivar la funcionalidad), investigar después.
3. Comunicar a los afectados.
4. Tras resolver: informe en `docs/incidencias/AAAA-MM-DD-titulo.md` con cronología, causa raíz, impacto y acciones.

## Tareas periódicas

| Tarea | Frecuencia | Cómo |
|---|---|---|
| Revisar y aplicar actualizaciones de dependencias | semanal | PR de Dependabot o `mise outdated` |
| Probar la restauración de una copia | trimestral | sección «Restaurar» |
