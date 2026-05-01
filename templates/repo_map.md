# Template — Mapa del Proyecto

> **Uso:** Documentar la estructura y contexto del proyecto para que el agente lo entienda rápidamente.

---

## Información General

| Campo | Valor |
|-------|-------|
| **Nombre** | {{PROJECT_NAME}} |
| **Descripción** | {{DESCRIPCIÓN_CORTA}} |
| **Stack Principal** | {{PYTHON/NODE/RUST/GO/etc.}} |
| **Rama Base** | `develop` |
| **Rama Release** | `main` |

---

## Estructura de Archivos

```
{{PROJECT_NAME}}/
├── src/                          # Código fuente
│   ├── domain/                   # Entidades, lógica de negocio (puro)
│   ├── application/             # Use cases, orquestación
│   ├── ports/                    # Interfaces (Protocols/ABCs)
│   └── adapters/                # Implementaciones de I/O
│       ├── graph/                # Integraciones Graph API
│       ├── csv/                  # Lectura/escritura CSV
│       └── html/                 # Generación de reportes
│
├── tests/                        # Tests
│   ├── unit/                     # Tests unitarios
│   ├── integration/              # Tests de integración
│   └── e2e/                      # Tests end-to-end
│
├── docs/                         # Documentación
│   ├── adr/                      # Architecture Decision Records
│   ├── ports/                    # Contratos de ports
│   └── {{OTROS_DOCS}}
│
├── .agent/                       # Configuración del agente
│   ├── agents/                   # Definición de agentes
│   ├── protocols/                # Protocolos de sesión
│   ├── context/                  # Contexto del proyecto
│   └── memory/                   # Memoria de sesión
│
├── .github/
│   └── workflows/                # GitHub Actions
│
├── pyproject.toml / package.json  # Dependencias
└── README.md                      # Doc principal
```

---

## Stack Tecnológico

| Componente | Tecnología | Versión |
|------------|------------|---------|
| **Lenguaje** | {{Python/Node.js/etc}} | {{VERSION}} |
| **Linter** | {{ruff/eslint/etc}} | - |
| **Test** | {{pytest/vitest/etc}} | - |
| **Type Check** | {{mypy/tsc/etc}} | - |
| **Package Mgr** | {{pip/npm/cargo/etc}} | - |

---

## Dependencias Externas

| Servicio | Propósito | Credenciales |
|----------|-----------|--------------|
| {{Microsoft Graph}} | API de M365 | Entra ID App |
| {{Database}} | Persistencia | .env |
| {{External API}} | Integración | API Key |

---

## Comandos Principales

```bash
# Desarrollo
{{COMANDO_DEV}}

# Tests
{{COMANDO_TEST}}

# Linter
{{COMANDO_LINTER}}

# Build
{{COMANDO_BUILD}}
```

---

## Convenciones

### Ramas
- Feature: `feature/issue-N-descripcion`
- Fix: `fix/issue-N-descripcion`
- Chore: `chore/issue-N-descripcion`

### Commits
- Conventional Commits: `feat:`, `fix:`, `chore:`, `docs:`, `refactor:`

### Documentación
- ADRs en `docs/adr/` (formato MADR)
- Contratos de ports en `docs/ports/`
- Decisiones de proyecto en `docs/`

---

## Puntos de Contacto

| Rol | Contacto |
|-----|----------|
| **Tech Lead** | {{NOMBRE}} |
| **PO** | {{NOMBRE}} |
| **Infra** | {{NOMBRE}} |

---

## Notas del Proyecto

- {{Nota importante 1}}
- {{Nota importante 2}}
- {{Nota importante 3}}

---

*Este archivo se genera al inicio del proyecto y se actualiza según cambios significativos.*