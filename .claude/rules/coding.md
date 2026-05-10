---
paths:
  - "src/**"
  - "**/*.py"
  - "**/*.ts"
  - "**/*.tsx"
  - "**/*.js"
  - "**/*.jsx"
  - "**/*.rs"
  - "**/*.go"
  - "tests/**"
  - "test/**"
---

# Coding Rules — TDD y Calidad

## Iron Law (P3)

```
NO HAY CÓDIGO DE PRODUCCIÓN SIN UN TEST QUE FALLE PRIMERO
```

## Ciclo obligatorio por cada función/feature

1. **RED** — Escribir un test mínimo que falle
2. **Verificar RED** — Ejecutar y confirmar que falla por la razón correcta
3. **GREEN** — Escribir el código más simple que lo haga pasar
4. **Verificar GREEN** — Ejecutar y confirmar que pasa
5. **REFACTOR** — Limpiar sin romper tests
6. **Commit** — Mensaje convencional (`feat/fix/chore/refactor/test`)

## Detección de stack (ejecutar antes de asumir herramientas)

```
pyproject.toml / requirements.txt → Python: ruff, pytest, mypy
package.json                       → Node.js: eslint, npm test, tsc
Cargo.toml                         → Rust: clippy, cargo test, cargo check
go.mod                             → Go: golangci-lint, go test
```

## Reglas de código

- **Sin comentarios** que expliquen QUÉ hace el código — los nombres lo dicen
- **Comentar solo el POR QUÉ** cuando hay una restricción no obvia o workaround
- **Sin abstracciones prematuras** — tres líneas similares no es duplicación
- **Sin manejo de errores** para escenarios imposibles — solo en boundaries externos
- **Sin feature flags** ni backwards-compatibility shims — cambiar el código directamente

## Definición de Done (DoD) para código

- [ ] Linter pasa (0 errores)
- [ ] Tests pasan (todos verdes)
- [ ] Cada función nueva tiene al menos un test
- [ ] No hay `console.log`, `print`, `dbg!` de debug
- [ ] No hay secrets ni keys en el código
- [ ] Rama no es `develop` ni `main`
- [ ] Commit con mensaje convencional

## DoD reducido para hotfixes urgentes

- [ ] Linter pasa
- [ ] Test del bug específico pasa
- [ ] No rompe tests existentes
