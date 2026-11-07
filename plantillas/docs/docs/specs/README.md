# Especificaciones

Cada funcionalidad se especifica antes de programarse. Una carpeta por funcionalidad:

```text
docs/specs/
└── 001-nombre-corto/
    ├── spec.md    Qué y por qué: problema, historias de usuario, criterios de aceptación
    ├── plan.md    Cómo: diseño técnico, código reutilizado, datos, pruebas y riesgos
    └── tasks.md   Tareas ordenadas; cada una es un commit con su test
```

## Ciclo de vida

| Estado | Significado |
|---|---|
| Borrador | En redacción |
| Aprobada | Especificación y plan aprobados; se puede implementar |
| Implementada | Integrada en `main` |
| Descartada | No se implementará; se conserva el motivo |

## Reglas

- La especificación describe comportamiento observable, nunca la implementación.
- Cada criterio de aceptación es verificable y tiene al menos un test.
- Si durante el desarrollo cambia el alcance, se actualiza `spec.md` antes que el código.
- Los planes respetan los principios de [`docs/ARCHITECTURE.md`](../ARCHITECTURE.md).
