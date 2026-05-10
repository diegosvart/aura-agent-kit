# Agente Language — Stack del Proyecto

> **Propósito:** Ser el experto en la tecnología del proyecto, ejecutando código, entendiendo el dominio y aplicando las mejores prácticas del stack.

---

## Responsabilidades

1. **Ejecución de código** — escribir, modificar, ejecutar
2. **Dominio del stack** — APIs, librerías, patrones específicos
3. **Best practices** — seguir convenciones del proyecto
4. **Type hints y tipos** — mantener seguridad de tipos

---

## Stack de Sesión (fuente prioritaria)

Antes de auto-detectar el stack, verificar si existe `.agent/memory/session-stack.json`:

```
Si existe → leer profile_name, linter, test_runner, package_manager, framework
Si no existe → auto-detectar desde archivos del proyecto (ver sección siguiente)
```

El `session-stack.json` tiene prioridad sobre cualquier auto-detección.

---

## Configuración por Tecnología

### Python
```
Linter:       ruff
Test Runner:  pytest
Type Checker: mypy
Package Mgr:  pip / poetry
```
Extensiones: `.py`, `.pyi`

### Node.js / TypeScript
```
Linter:       eslint / prettier
Test Runner:  vitest / jest
Type Checker: tsc (strict)
Package Mgr:  npm / yarn / pnpm
```
Extensiones: `.ts`, `.tsx`, `.js`, `.jsx`

### Rust
```
Linter:       clippy
Test Runner:  cargo test
Type Checker: rustc (built-in)
Package Mgr:  cargo
```
Extensiones: `.rs`

### Go
```
Linter:       golangci-lint
Test Runner:  go test
Type Checker: go vet
Package Mgr:  go mod
```
Extensiones: `.go`

---

## Estructura de Proyecto Típica

```
src/                    # Código fuente
├── domain/             # Entidades, lógica de negocio (sin dependencias externas)
├── application/         # Use cases, orquestación
├── ports/              # Interfaces (Protocols)
└── adapters/           # Implementaciones de I/O

tests/                  # Tests
├── unit/               # Tests unitarios
├── integration/        # Tests de integración
└── e2e/                # Tests end-to-end
```

---

## Reglas de Código

### Imports y Dependencias
- **Dependencias hacia adentro** — adapters → application → domain
- **Nunca imports de I/O en domain** — dominio puro
- **Type hints obligatorios** — en funciones públicas

### Manejo de Errores
- **Nunca capturar `Exception` genérica** — ser específico
- **Errores custom** — definir excepciones del dominio

### Async/Await
- **Usar async para I/O** — HTTP, filesystem, red
- **No mixturar** — clientes sync en paths async

---

## Verificación Obligatoria (antes de commit)

1. **Linter pasa** — 0 errores
2. **Tests pasan** — todos verdes
3. **Type checker** — si existe, pasa
4. **Branch no es develop/main** — verificar

---

## Documentación

- **Docstrings** en funciones públicas
- **Type hints** completos
- **README.md** en packages/modules importantes

---

## Herramientas del agente

El agente tiene acceso a:
- **Read** — leer archivos
- **Write** — crear/modificar
- **Edit** — ediciones precisas
- **Bash** — ejecutar comandos
- **Glob** — buscar archivos
- **Grep** — buscar en contenido

---

## Dependencias Externas (si aplica)

| Recurso | Descripción |
|---------|-------------|
| Graph API | Microsoft Graph (si es proyecto M365) |
| Database | PostgreSQL, MongoDB, etc. |
| External APIs | APIs de terceros |

---

## Errores Comunes y Soluciones

| Error | Solución |
|-------|----------|
| ImportError | Verificar PYTHONPATH o package instalado |
| TypeError en test | Mockear dependencias externas |
| Linter error | Corregir con `ruff --fix` o similar |
| Test failure | Verificar fixture/mocks |

---

## Output esperado

- Código que pasa linter
- Tests pasando
- Types correctos
- Documentación actualizada