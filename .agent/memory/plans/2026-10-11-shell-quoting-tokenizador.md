---
status: done
issue: 370
pr: "#371"
commit: 5d580d2
completed_at: 2026-10-11
date: 2026-10-11
---

# Plan Issue #370 — Palabra-comando por tokenizador en shell-quoting (cierre de la clase de bypass de #369)

## 1. Diagnóstico (por qué 3 rondas no bastaron)

Ambos guards hacen `match` textual (regex) sobre el segmento YA VACIADO por `Remove-QuotedContent`
(`\bgit\s+push\b`, `\bgh\s+pr\s+create\b`). **La clase tiene DOS mecanismos** (corregido tras challenger):
- **M-A (vaciado indebido):** vaciar una comilla que sí se ejecuta.
- **M-B (dequoting de la palabra detectada):** el shell quita comillas/escapes, la regex no:
  `gh pr "create" --base main`, `gh "pr" create`, `gh pr cr'eate'`, `gh pr crea\te`,
  `git "push" origin main`, `git pu\sh` pasan hoy los guards (PoC del challenger).
M-A ocurre cuando `Remove-QuotedContent` cree que el segmento es una
invocación git/gh (habilita `-m/-am/-b/-t` como texto libre) pero el comando real es otro
(`sudo -b "..."`), o cuando la rama `echo|printf` se activa por la sola presencia de la palabra.

La causa raíz es el método: decidir "¿esto es git/gh?" con regex sobre el string crudo. Cada
parche (grupo atómico, tokenizar el valor) cerró una variante; la regex sigue admitiendo
particiones del prefijo que el shell no hace. Bypasses encontrados en review de #369:
`FOO="sudo git" sudo -b`, `FOO=x"a git" sudo -b`, `FOO=$(echo git) sudo -b` (abierto),
más preexistentes: `echo|printf` en cualquier parte, `\"` escapada en `Split-ShellSegments`,
funsub `${ cmd; }`, `gh-wrapper` reconocido como gh.

Nota de seguridad de diseño: los guards solo pueden fallar por **falso positivo** si
`Remove-QuotedContent` es conservador (no vacía => el match ve el texto => bloquea). Por eso el
criterio rector es **fail-closed**: ante cualquier duda, no vaciar.

## 2. Diseño

Cambios aditivos (no se tocan firmas públicas):

**D1. `Get-SegmentCommandInfo -Segment <string>`** (nueva, en shell-quoting.ps1). Tokeniza el
segmento de izquierda a derecha, solo la región de prefijo hasta hallar la palabra-comando:
- Separador de token: espacio/tab **fuera de comillas y sin escape**.
- `\` fuera de comillas simples escapa el carácter siguiente (se agrega al token).
- `'...'`: literal hasta la siguiente `'`. `"..."`: hasta `"` no escapada (`\` escapa dentro).
- **Taint** (sticky): si fuera de comillas simples aparece `$(`, `` ` ``, `${`, `$((`, o si una
  comilla queda sin cerrar antes de hallar la palabra-comando, el resultado es
  `Tainted=$true, Command=$null`.
- Token es **asignación** si matchea `^[A-Za-z_][A-Za-z0-9_]*=` (nombre POSIX; `1A=x` NO lo es
  => es la palabra-comando `1A=x`, desconocida). Se salta entero (su valor no importa).
- Token es **wrapper** si es exactamente `sudo|env|command|time` (mismo conjunto actual): se salta.
- El primer token que no es asignación ni wrapper es la **palabra-comando**. Si contiene
  comillas o `\` en crudo => `Command=$null` (desconocida). Devuelve `{ Command; Tainted }`.
- **Salida ampliada:** además de `Command`/`Tainted`, devuelve `Tokens`: la lista de palabras
  del segmento COMPLETO ya sin comillas ni escapes (como las vería el shell). Cada token marca
  si contenía expansión.
- Reconocimiento: `Command -ieq 'git'` o `-ieq 'gh'` (igualdad exacta: `gh-wrapper`,
  `git-foo`, `/usr/bin/git` quedan desconocidos => fail-closed).

**D2. `Remove-QuotedContent`** usa D1:
- Flags largos (`--body|--title|...`): se vacían SOLO si `Command` es git/gh y no `Tainted`
  (cierra R1: `sudo --body "PAY"`, `sudo -b "x --body 'PAY'"`). `Tainted` => identidad TOTAL
  (largos, cortos y echo); `Test-QuotedIsExecutable` sigue protegiendo el valor de cada flag.
- Flags cortos (`-m/-am/-b/-t`): solo si `Command` es git/gh y no `Tainted`.
- Rama `echo|printf`: solo si `Command` es `echo|printf` y no `Tainted` (no "en cualquier parte").
- Se mantiene el chequeo `Test-QuotedIsExecutable` por comilla.

**D3. `Split-ShellSegments`:** `\` fuera de comillas simples escapa el siguiente carácter
(no abre/cierra comilla ni separa). Backslash final no lanza.

**D4. `Test-QuotedIsExecutable`:** agregar `${ ` y `${|` (funsub bash 5.3). `${VAR}` no es ejecutable.

**D5. Guards matchean sobre tokens (cierra M-B).** Nueva función aditiva
`Test-SegmentInvokes -Segment -Words @('gh','pr','create')` (o equivalente) que compara los
primeros tokens dequoteados tras prefijos/wrappers, con igualdad exacta case-insensitive.
`pr-base-guard` (`create|edit|merge`), `gh-account-guard` (`git push`, `gh pr create`,
`gh repo edit`) la usan en lugar de `\bgit\s+push\b` etc. Si el segmento es Tainted o la palabra
no se puede determinar => el guard trata el segmento como POSIBLE invocación y aplica su
chequeo conservador (fail-closed). `Get-CommandFlagValue`/`Get-MergeTarget` dejan de hacer
`Trim('"')` ad-hoc y leen tokens. **ASK FIRST (aprobado por el usuario 2026-10-11):** cambia
cómo los dos guards deciden; firmas públicas de las 3 funciones existentes de shell-quoting
NO cambian, los guards sí cambian internamente.

Fuera de scope (riesgos residuales declarados, ver §6): heredocs, `$(...)` anidado más allá del
taint conservador, wrappers con opciones (`sudo -u x git` => falso positivo fail-closed),
paths absolutos (`/usr/bin/git` => falso positivo), flags largos en comandos no git/gh (R1).

## 3. Setlist de pruebas

Convención: PAY = texto con el comando guardado (`gh pr create --base main --title x` para
pr-base-guard; `git push origin x` para gh-account-guard). "Identidad" = `Remove-QuotedContent`
devuelve el string de entrada sin cambios. "Vaciado" = la comilla del flag queda `""`.

### A. Reconocimiento legítimo (Vaciado; sin falsos positivos) — `PREFIJO git commit -m "PAY"`
A1 sin prefijo · A2 `FOO=a` · A3 `FOO="a b"` · A4 `FOO='a b'` · A5 `A="x y" B=z` ·
A6 `VAR=x"y z"` · A7 `FOO=` · A8 `FOO=""` · A9 tab entre prefijo y git · A10 `FOO=a\ b` ·
A11 `FOO="a=b;c"` · A12 `FOO='$(x)'` (comilla simple => literal, no taint) ·
A13 `A=1 B="x y" env git` · A14 cadena `time env command sudo git` · A15 `-am` ·
A16 `gh pr create -t "PAY" -b "PAY"` · A17 `GIT commit -m "PAY"` (case-insensitive, se fija el comportamiento).

### B. Taint (Identidad; el guard BLOQUEA si PAY es el comando real)
Prefijos: B1 `FOO=$(echo git)` · B2 `FOO=$(echo a b)` · B3 ``FOO=`echo git` `` ·
B4 `FOO=${X:-git}` · B5 `FOO=$((1+1))` · B6 `FOO="$(echo git)"` · B7 `FOO=x$(echo git)` ·
B8 `FOO=${ cmd; }` · B9 `FOO="a $(b) c"` · B10 `FOO=$(echo git )` (git suelto tras espacio) ·
B11 comilla sin cerrar en el prefijo (`FOO="a b`).
Colas por prefijo: `sudo -b "PAY"` · `sudo -t "PAY"` · `watch -t "PAY"` · `git commit -m "PAY"`
(falso positivo aceptado y documentado: tainted + git real => conserva => el guard puede bloquear).

### C. Corpus histórico de bypass (Identidad cuando el comando final NO es git/gh)
C1 `FOO="sudo git" sudo -b` · C2 `FOO='a git' sudo -t` · C3 `FOO="a git" sudo -t` ·
C4 `FOO=x"a git" sudo -b` · C5 `FOO=x'a git' sudo -b` · C6 `FOO=-"a git" sudo -b` ·
C7 `FOO=x"a gh" sudo -b` · C8 `A=1 FOO=x"a git" sudo -b` · C9 `FOO=x"a git" env sudo -b` ·
C10 `FOO=~"a git" sudo -t` · C11 `FOO=\"a git\" sudo -b` · C12 `FOO=$'a git' sudo -b` ·
C13 `FOO=$"a git" sudo -b` · C14 `FOO="a"git sudo -b` · C15 `FOO=a"b git" sudo -b` ·
C16 `FOO=x=y"a git" sudo -b` · C17 `time env command sudo` encadenado con valor mixto ·
C18 `watch -t "PAY"` · C19 `bash -xt "PAY"` · C20 `sudo -m "PAY"` · C21 `bash -c / sh -c / pwsh -Command "PAY"` ·
C22 `FOO="a b" bash -c "PAY"` · C23 `1A=x git commit -m "PAY"` (nombre inválido => comando desconocido) ·
C24 `gh-wrapper pr create -t "PAY"` · C25 `git-foo commit -m "PAY"` · C26 `/usr/bin/git commit -m "PAY"` (se fija: no reconocido).

### D. echo/printf
D1 `echo "a" "b"` Vaciado · D2 `FOO=1 echo "x"` Vaciado · D3 `printf "%s" "x"` Vaciado · D4 `echo -e "a"` Vaciado ·
D5 `FOO=$(echo 1) sudo -b "PAY"` Identidad · D6 `sudo -b "echo hi" "PAY"` Identidad ·
D7 `bash -c "echo x" "PAY"` Identidad · D8 `echo "$(gh pr create)"` Identidad (ejecutable) ·
D9 `echo` como argumento (`git commit -m "echo" -F x`) no activa la rama para el resto.

### E. `Split-ShellSegments`
E1 los 9 casos actuales (se mantienen) · E2 `git commit -m "it\"s" && sudo -b "PAY"` => 2 segmentos ·
E3 `echo a\;b` => 1 · E4 `echo \"a && b` => 2 (comilla escapada no abre comilla) ·
E5 `echo 'a\' && b` => 2 (en comilla simple `\` es literal) · E6 `echo "a\\" && b` => 2 ·
E7 backslash final no lanza · E8 CRLF separa · E9 `a &&b` y `a&& b`.

### F. `Test-QuotedIsExecutable`
F1 `$(`, F2 backtick, F3 `${ cmd; }`, F4 `${|cmd;}` => ejecutable · F5 `${VAR}` y texto plano => no.

### G. Robustez
G1 cadena vacía y solo espacios no lanzan · G2 comillas desbalanceadas varias no lanzan y => Identidad ·
G3 ReDoS: 4000 prefijos `A=1 ` + `git commit -m "x"` y un valor de 40.000 caracteres, cada uno < 1 s ·
G4 `=x git`, solo `=`, `FOO` sin `=` => comando desconocido/no lanza.

### H0. Harness de verdad-de-terreno con bash real (oráculo independiente)
Script de pruebas (Pester, se salta con mensaje si no hay bash) que, para cada comando del
producto prefijo x wrapper x cola (incluye J y K), ejecuta en `bash -c` real con STUBS en un
PATH temporal (`git`, `gh`, `sudo`, `env`, `watch`, `xargs` que registran su `argv` en un log y
no hacen nada). De ese log se DERIVA qué se ejecutó de verdad (¿se invocó el stub `gh` con
`pr create`?). Invariante: si el log muestra la invocación guardada, el guard sobre el
comando original DEBE bloquear. Es el oráculo que no comparte modelo mental con la
implementación. Los `isGit`/`tainted` de H dejan de ser etiquetas manuales donde se pueda: se
verifican contra este log.

### H. Matriz combinatoria con oráculo declarativo (shell-quoting.Tests.ps1)
Cada prefijo lleva metadato `tainted` (declarado a mano, no calculado por el código bajo prueba);
cada cola lleva `isGit`. Oráculo: `vaciado <=> (-not tainted) -and isGit`; en otro caso Identidad.
Prefijos: A1–A14 (no tainted) ∪ B1–B11 (tainted) ∪ C1–C16 (no tainted pero adversariales).
Wrappers: `''`, `sudo `, `env `, `command `, `time env command sudo `.
Colas: `git commit -m "PAY"`, `git commit -am "PAY"`, `gh pr create -t "PAY"`, `sudo -b "PAY"`,
`sudo -t "PAY"`, `watch -t "PAY"`, `bash -c "PAY"`, `sudo -b "x --body 'PAY'"`,
`sudo --body "PAY"`, `sudo --body="PAY"`, `git commit --message "PAY"`.
~40 prefijos x 5 wrappers x 7 colas = 1400 combinaciones evaluadas en bucles y reportadas como
lista de fallas (un `It` por familia, falla mostrando las combinaciones violadas).

### J. Dequoting de la palabra detectada (M-B) — el guard debe BLOQUEAR
J1 `gh pr "create" --base main` · J2 `gh "pr" create --base main` · J3 `gh pr cr'eate' --base main` ·
J4 `gh pr crea\te --base main` · J5 `g"h" pr create --base main` · J6 `"gh" pr create ...` ·
J7 `git "push" origin main` · J8 `git pu\sh` · J9 `g'i't push` · J10 `GH PR CREATE --base main` (case) ·
J11 con prefijos/wrappers: `FOO=1 sudo gh pr "create" ...` · J12 `gh pr create --b"ase" main`.
Regresión fail-closed ya verificada (fijar como tests): `>f git commit -m "PAY"`, `2>&1 sudo -b "PAY"`,
`{ git commit -m "PAY"; }`, `g"i"t commit -m "PAY"` (Identidad), `-b"PAY"` pegado, `A+=x sudo -b "PAY"`.
Decisión documentada: `GIT commit -m` se trata como git (PATH case-insensitive en Windows).

### K. Flags largos x palabra-comando (cierra R1)
K1 `sudo --body "PAY"` · K2 `sudo -b "x --body 'PAY'"` · K3 `bash -c "x --title 'PAY'"` ·
K4 `xargs -I{} sh -c "--notes 'PAY'"` · K5 `sudo --body="PAY"` · K6 `watch --message "PAY"` =>
Identidad y el guard bloquea. Contraste: `gh issue create --body "PAY"` y
`git commit --message "PAY"` siguen Vaciado.

### I. E2E por guard (pr-base-guard.Tests.ps1 y gh-account-guard.Tests.ps1)
Mismo producto prefijo x wrapper x cola con PAY real:
- Identidad (B, C, D5–D7, sin git real) => `decision = block`.
- Vaciado legítimo (A con git real) => `$null`.
Más los casos puntuales por guard: los 3 bypass de las rondas de review, A3 y B1.

## 4. Pasos de ejecución (TDD, 1 rama, 1 PR)

Rama: `fix/issue-370-shell-quoting-tokenizador` desde develop DESPUÉS de mergear #369.

### Paso 1: Tests en RED
- Qué: escribir A–I; correrlos contra develop (con #369) y registrar cuáles fallan y por qué.
- Archivos: shell-quoting.Tests.ps1, pr-base-guard.Tests.ps1, gh-account-guard.Tests.ps1
- Seguridad: confirmar que los casos B, C-nuevos, D4–D6, E2–E6, F3–F4 y C23–C25 fallan por la razón correcta.
- Despacho: INLINE (depende del contexto vivo de las 3 rondas de review)

### Paso 1b: Harness bash de verdad-de-terreno (H0)
- Qué: construir el harness con stubs y generar el producto de comandos; correrlo contra el código actual para confirmar que detecta J/K como bypass reales.
- Archivos: shell-quoting.Tests.ps1 (o `ground-truth.Tests.ps1` nuevo en .claude/hooks/)
- Seguridad: los stubs no ejecutan nada real; PATH temporal aislado.
- Despacho: DELEGAR (fork — tarea autocontenida y de salida voluminosa; el enunciado del plan basta)

### Paso 2: D3 + D4 (Split escape y funsub)
- Qué: cambios mínimos con sus tests E y F en GREEN.
- Archivos: shell-quoting.ps1
- Seguridad: el escape no debe permitir que una comilla escapada oculte un separador real.
- Despacho: INLINE (depende del contexto vivo: decisiones de diseño recién acordadas con el usuario)

### Paso 3: D1 + D2 (palabra-comando, tokens, flags largos solo git/gh)
- Qué: `Get-SegmentCommandInfo` (con Tokens) y reescritura de `$ghInvocation`/`echoLike` en `Remove-QuotedContent`.
- Archivos: shell-quoting.ps1
- Seguridad: fail-closed; G3 mide ReDoS; no tocar firmas públicas existentes.
- Despacho: INLINE (depende del contexto vivo)

### Paso 3b: D5 (guards matchean sobre tokens)
- Qué: `Test-SegmentInvokes` y migrar pr-base-guard/gh-account-guard (y Get-CommandFlagValue/Get-MergeTarget) a tokens; tests J en GREEN.
- Archivos: shell-quoting.ps1, pr-base-guard.ps1, gh-account-guard.ps1 y sus .Tests.ps1
- Seguridad: Tainted/desconocido => chequeo conservador; ningún bloqueo actual se relaja.
- Despacho: INLINE (depende del contexto vivo; es el núcleo del cambio de contrato aprobado)

### Paso 4: Matrices H, H0 e I en GREEN + suite completa
- Qué: `run-all-tests.sh` verde; registrar tiempos de las suites.
- Archivos: los .Tests.ps1
- Seguridad: ninguna prueba se relaja para pasar.
- Despacho: INLINE (≤3 tool-calls, sin ahorro medible al aislar)

### Paso 5: Diferencial contra e733f17
- Qué: script en scratchpad que corre el corpus A–D contra e733f17 y la rama; el único delta
  permitido son los casos B (antes vaciaba alguno), D4–D6, E2–E6, F3–F4, C24–C25. Cualquier otro
  delta se investiga antes de seguir.
- Archivos: scratchpad (no se versiona); resultado resumido en el PR.
- Seguridad: detecta regresiones de falso negativo que los tests no previeron.
- Despacho: DELEGAR (fork — ejecución mecánica y salida voluminosa que no hace falta releer)

### Paso 6: Revisión independiente (criterio de salida)
- Qué: un revisor fresco recibe SOLO el código y el harness H0 (sin la lista de ataque, para
  que no sea circular) y la instrucción de buscar bypasses por su cuenta; se le declaran
  únicamente los residuales. DoD: una ronda sin bloqueantes.
- Archivos: ninguno (solo lectura)
- Seguridad: es la verificación externa de todo lo anterior.
- Despacho: DELEGAR (subagente fresco opus — independencia del contexto vivo es el punto)

## 5. Definición de Done
- [ ] RED registrado en Paso 1 y GREEN en Paso 4; `run-all-tests.sh` verde
- [ ] Harness H0 (bash real + stubs): ningún caso donde se ejecute la invocación guardada y el guard no bloquee
- [ ] Diferencial del Paso 5 sin deltas inesperados (deltas esperados incluyen J y K)
- [ ] Revisión del Paso 6 sin bloqueantes
- [ ] PR con template unificado (Qué/Beneficio/Por qué/Cómo/AC/Testing), `Closes #370` vía open-pr.sh

## 6. Riesgos residuales declarados (no se arreglan acá)
R1 RESUELTO (flags largos solo git/gh). R2 Heredocs y `$'...'` ANSI-C en la palabra-comando. R3 `$(...)` anidado más allá del taint. R4 Wrappers con opciones (`sudo -u x git`):
falso positivo fail-closed. R5 Paths absolutos/`.exe`: falso positivo fail-closed.
R6 Programas no listados que ejecutan un argumento (`xargs`, `find -exec`, `timeout`, `nice`):
solo importa si su argumento queda bajo un flag corto o echo, que ya no se vacía si la
palabra-comando no es git/gh/echo/printf.

## 7. Preguntas abiertas para el challenger
Q1. ¿Restringir también los flags largos a git/gh (cerraría R1 a costa de falsos positivos en otros CLIs)?
Q2. ¿Vale la pena que `Tainted` no vacíe flags largos (identidad total) o es excesivo?
Q3. ¿El oráculo declarativo de la matriz H es realmente independiente de la implementación?
Q4. ¿Falta algún vector fuera de la región de prefijo (p. ej. redirecciones antes de la palabra-comando: `>f git commit`, `2>&1 sudo -b`; `!`; `{ git ...; }`; subshell `( ... )`)?
