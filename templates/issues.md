# Template — Issue de Proyecto

> **Uso:** Crear nuevos issues en el proyecto. Cada issue es una unidad de trabajo completa.

---

## Estructura del Issue

```markdown
# {{TÍTULO_CORTO}}

## Descripción
{{Descripción detallada de lo que se necesita hacer}}

## Contexto
- **Por qué** necesitamos esto
- **Qué problema resuelve**
- **Contexto adicional** (links, docs, decisiones previas)

## Criterios de Aceptación (DoD)
- [ ] {{Criterio 1}}
- [ ] {{Criterio 2}}
- [ ] {{Criterio 3}}
- [ ] {{Criterio N}}

## Implementación Sugerida
{{Opcional: sugerencias de cómo implementarlo}}

### Pasos
1. {{Paso 1}}
2. {{Paso 2}}
3. {{Paso 3}}

## Dependencias
- {{Issue #N}} — {{descripción}}
- {{Recurso externo}}

## Etiquetas
- {{label 1}}
- {{label 2}}

## Rama Sugerida
`{{TIPO}}/{{CODIGO}}-{{descripcion}}`
Desde: `develop`

---

## Ejemplo Completo

```markdown
# Feature: Agregar autenticación JWT

## Descripción
Implementar autenticación basada en JWT para proteger los endpoints de la API.

## Contexto
- **Por qué**: Actualmente no hay protección en los endpoints
- **Qué problema resuelve**: Acceso no autorizado a datos sensibles
- **Contexto adicional**: Ver ADR-0012 para decisiones de arquitectura

## Criterios de Aceptación (DoD)
- [ ] Endpoint /auth/login devuelve JWT válido
- [ ] Middleware valida JWT en endpoints protegidos
- [ ] Tests unitarios para auth service
- [ ] Tests de integración para login
- [ ] Docs actualizados en /docs/auth.md

## Implementación Sugerida
1. Crear módulo auth/ con jwt_handler.py
2. Agregar dependencia pyjwt
3. Crear middleware de validación
4. Agregar rutas en app.py

## Dependencias
- Ninguna

## Etiquetas
- feature
- security
- ready

## Rama Sugerida
`feature/issue-42-agregar-auth-jwt`
Desde: `develop"
```

---

## Labels Recomendados

| Label | Cuándo usarlo |
|-------|---------------|
| `ready` | Listo para trabajar |
| `wip` | En progreso |
| `blocked` | Bloqueado por otra dependencia |
| `feature` | Nueva funcionalidad |
| `fix` | Corrección de bug |
| `refactor` | Refactorización |
| `docs` | Documentación |
| `security` | Cambios de seguridad |
| `infrastructure` | Cambios de infra |

---

## Reglas

1. **Un issue = una unidad de trabajo** — no crear mega-issues
2. **DoD medible** — criterios objetivos, no subjetivos
3. **Contexto suficiente** — el agente debe entender sin preguntar
4. **Rama sugerida** — facilitar el start

---

## Commands del Agente

Al crear un issue, el agente puede:
- Agregar automáticamente la etiqueta `ready`
- Crear la rama sugerida
- Agregar al Project board
- Configurar auto-cierre en PR