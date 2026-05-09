# Comando — /doc-check

> **Invoca:** `agents/doc-guardian.md`
> **Cuándo usar:** Después de crear o modificar archivos `.md`, o para verificar integridad general del repo.

---

## Uso

```
/doc-check              # verifica todo el repo
/doc-check <ruta>       # verifica solo ese archivo
```

---

## Qué Hace

1. Invoca `agents/doc-guardian.md`
2. Verifica referencias, skills, comandos y agentes mencionados vs existentes
3. Verifica consistencia de versión
4. Detecta placeholders sin completar fuera de templates
5. Verifica estructura requerida en SKILL.md y agents/*.md
6. Emite reporte con [ROTO], [INCONSISTENTE], [INCOMPLETO], [OK]
7. Veredicto final: **ÍNTEGRO** o **REQUIERE CORRECCIÓN**

---

## Cuándo Se Invoca Automáticamente

- `session_end.md` lo invoca si hubo cambios en archivos `.md` durante la sesión
- Después de cualquier `/auto-research` que modifique documentación

---

## Proceso

```
/doc-check
    ↓
doc-guardian escanea archivos objetivo
    ↓
ÍNTEGRO → continuar (no bloquea)
REQUIERE CORRECCIÓN → lista de problemas
    ↓ (si hay problemas)
Corregir antes de commitear
```

---

## Ejemplo de Reporte

```
## Doc Check — resultado

| Archivo | Estado | Detalle |
|---------|--------|---------|
| agents/challenger.md | [OK] | — |
| skills/systematic-debugging/SKILL.md | [OK] | — |
| commands/brainstorm.md | [OK] | — |

**Veredicto: ÍNTEGRO** ✓
```
