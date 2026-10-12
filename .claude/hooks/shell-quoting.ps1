# Libreria compartida de gh-account-guard.ps1 y pr-base-guard.ps1 (dot-source, no es un hook).
# Vive plana en .claude/hooks/ porque new-project-setup copia solo .claude/hooks/*.ps1.
#
# Principio rector (Issue #370): fail-closed. Los guards deciden sobre el texto que devuelve
# Remove-QuotedContent y sobre los tokens de Get-SegmentCommandInfo; ante cualquier duda sobre cual
# es el comando real, el texto se conserva (el guard lo ve y bloquea), nunca se vacia.

# Divide un comando compuesto (&&, ||, ;, |) en segmentos, respetando comillas simples/dobles y
# escapes con \ (fuera de comillas simples), para que cada invocacion se evalue de forma
# independiente. Sin esto, un comando tipo
# 'gh pr create --base develop ... && gh pr create --base main ...' dejaba pasar el segundo
# porque la extraccion de flags buscaba en todo el string, no por invocacion (code-review PR #233).
function Split-ShellSegments {
    param([string]$Command)
    $segments = New-Object System.Collections.Generic.List[string]
    $current = New-Object System.Text.StringBuilder
    $inSingle = $false
    $inDouble = $false
    $i = 0
    while ($i -lt $Command.Length) {
        $ch = $Command[$i]
        if ($ch -eq '\' -and -not $inSingle) {
            [void]$current.Append($ch)
            if (($i + 2) -lt $Command.Length -and $Command[$i + 1] -eq "`r" -and $Command[$i + 2] -eq "`n") {
                [void]$current.Append("`r`n")
                $i += 3
                continue
            }
            if (($i + 1) -lt $Command.Length) { [void]$current.Append($Command[$i + 1]) }
            $i += 2
            continue
        }
        if ($ch -eq "'" -and -not $inDouble) { $inSingle = -not $inSingle; [void]$current.Append($ch); $i++; continue }
        if ($ch -eq '"' -and -not $inSingle) { $inDouble = -not $inDouble; [void]$current.Append($ch); $i++; continue }
        if (-not $inSingle -and -not $inDouble) {
            if (($i + 1) -lt $Command.Length -and $Command.Substring($i, 2) -in @('&&', '||')) {
                $segments.Add($current.ToString()) | Out-Null
                [void]$current.Clear()
                $i += 2
                continue
            }
            $ampIsRedirect = ($ch -eq '&') -and ((($i + 1) -lt $Command.Length -and $Command[$i + 1] -eq '>') -or ($i -gt 0 -and ($Command[$i - 1] -eq '>' -or $Command[$i - 1] -eq '<')))
            if ($ch -eq ';' -or $ch -eq '|' -or ($ch -eq '&' -and -not $ampIsRedirect) -or $ch -eq "`n" -or $ch -eq "`r") {
                $segments.Add($current.ToString()) | Out-Null
                [void]$current.Clear()
                $i += 1
                continue
            }
        }
        [void]$current.Append($ch)
        $i++
    }
    $segments.Add($current.ToString()) | Out-Null
    return $segments
}

$script:QuotedLiteral = '"[^"]*"|''[^'']*'''
$script:ShellSpecials = [char[]]@(' ', "`t", "`n", "`r", '\', "'", '"', '`', '$')
$script:AssignmentToken = [regex]'^[A-Za-z_][A-Za-z0-9_]*='
$script:CommandWrappers = @('sudo', 'env', 'command', 'time')
$script:SlowChars = [char[]]@('\', "'", '"', '`', '$')
$script:InfoCache = @{}
$script:ExpansionChars = [char[]]@('$', '`')
$script:RedirectInText = [regex]'(?<!\S)(?:\d*|&)(?:>>|>\||<>|<<<|<<|>|<)(?:\s+\S+|&?\S*)'
$script:BareCache = @{}
$script:RedirectToken = [regex]'^(?:\d*|&)[<>]'
$script:RedirectOperator = [regex]'^(?:\d*|&)(?:>>|>\||<>|<<<|<<|>|<)$'

# Una comilla que contiene $(...), ${ cmd; } (funsub bash 5.3) o backticks NO es dato: el shell la
# expande ejecutando lo que haya dentro. Vaciarla dejaria pasar
# `git commit -m "$(gh pr create --base main)"` (review PR #363, bloqueante 1).
function Test-QuotedIsExecutable {
    param([string]$Quoted)
    $Quoted = $Quoted -replace '\\\r?\n', ''
    return ($Quoted -match '\$\(' -or $Quoted -match '\$\{[\s|]' -or $Quoted.Contains('`'))
}

# Tokeniza UN segmento como lo haria el shell (sin ejecutar nada): separa por espacios fuera de
# comillas, quita comillas y escapes. Devuelve:
#   Tokens       palabras ya sin comillas ni escapes (string[])
#   CommandIndex indice de la palabra-comando (la primera que no es NAME=valor ni wrapper
#                sudo|env|command|time), o -1
#   Command      la palabra-comando SOLO si venia sin comillas ni escapes ni '$'; si no, $null
#   CommandEnd   offset (en el segmento original) donde termina la palabra-comando
#   Tainted      $true si en la region de prefijo (hasta la palabra-comando) hay una expansion
#                ($( ` ${ $' $") o si hay una comilla sin cerrar en cualquier parte: el comando real
#                no se puede determinar con seguridad
function Get-SegmentCommandInfo {
    param([string]$Segment)
    if ($null -eq $Segment) { $Segment = '' }
    if ($script:InfoCache.ContainsKey($Segment)) { return $script:InfoCache[$Segment] }
    $tTexts = [System.Collections.Generic.List[string]]::new()
    $tRaws = [System.Collections.Generic.List[string]]::new()
    $tQuoted = [System.Collections.Generic.List[bool]]::new()
    $tTaint = [System.Collections.Generic.List[bool]]::new()
    $tEnd = [System.Collections.Generic.List[int]]::new()
    $text = [System.Text.StringBuilder]::new()
    $inTok = $false; $start = 0; $quoted = $false; $tokTaint = $false
    $state = 0
    $n = $Segment.Length
    $i = 0
    if ($Segment.IndexOfAny($script:SlowChars) -lt 0) {
        foreach ($m in [regex]::Matches($Segment, '[^\s]+')) {
            $tTexts.Add($m.Value); $tRaws.Add($m.Value); $tQuoted.Add($false); $tTaint.Add($false)
            $tEnd.Add($m.Index + $m.Length)
        }
        $i = $n
    }
    while ($i -lt $n) {
        if ($state -eq 0) {
            $stop = $Segment.IndexOfAny($script:ShellSpecials, $i)
            if ($stop -ne $i) {
                $runEnd = if ($stop -lt 0) { $n } else { $stop }
                if (-not $inTok) { $inTok = $true; $start = $i }
                [void]$text.Append($Segment.Substring($i, $runEnd - $i))
                $i = $runEnd
                if ($stop -ge 0 -and ($Segment[$stop] -eq ' ')) {
                    $tTexts.Add($text.ToString()); $tRaws.Add($Segment.Substring($start, $i - $start))
                    $tQuoted.Add($quoted); $tTaint.Add($tokTaint); $tEnd.Add($i)
                    [void]$text.Clear(); $inTok = $false; $quoted = $false; $tokTaint = $false
                    $i++
                }
                continue
            }
            $ch = $Segment[$i]
            if ($ch -eq ' ' -or $ch -eq "`t" -or $ch -eq "`n" -or $ch -eq "`r") {
                if ($inTok) {
                    $tTexts.Add($text.ToString()); $tRaws.Add($Segment.Substring($start, $i - $start))
                    $tQuoted.Add($quoted); $tTaint.Add($tokTaint); $tEnd.Add($i)
                    [void]$text.Clear(); $inTok = $false; $quoted = $false; $tokTaint = $false
                }
                $i++; continue
            }
            if ($ch -eq '\' -and ($i + 1) -lt $n -and $Segment[$i + 1] -eq "`n") { $i += 2; continue }
            if ($ch -eq '\' -and ($i + 2) -lt $n -and $Segment[$i + 1] -eq "`r" -and $Segment[$i + 2] -eq "`n") { $i += 3; continue }
            if (-not $inTok) { $inTok = $true; $start = $i }
            if ($ch -eq '\') {
                $quoted = $true
                if (($i + 1) -lt $n) { [void]$text.Append($Segment[$i + 1]); $i += 2 } else { [void]$text.Append($ch); $i++ }
            } elseif ($ch -eq "'") {
                $quoted = $true; $state = 1; $i++
            } elseif ($ch -eq '"') {
                $quoted = $true; $state = 2; $i++
            } elseif ($ch -eq '`') {
                $tokTaint = $true; [void]$text.Append($ch); $i++
            } else {
                $next = if (($i + 1) -lt $n) { $Segment[$i + 1] } else { [char]0 }
                if ($next -eq '(' -or $next -eq '{' -or $next -eq "'" -or $next -eq '"') { $tokTaint = $true }
                [void]$text.Append($ch); $i++
            }
        } elseif ($state -eq 1) {
            $end = $Segment.IndexOf("'", $i)
            if ($end -lt 0) { [void]$text.Append($Segment.Substring($i)); $i = $n; continue }
            [void]$text.Append($Segment.Substring($i, $end - $i))
            $state = 0; $i = $end + 1
        } else {
            $ch = $Segment[$i]
            if ($ch -eq '"') { $state = 0; $i++ }
            elseif ($ch -eq '\') {
                $next = if (($i + 1) -lt $n) { $Segment[$i + 1] } else { [char]0 }
                if ($next -eq "`n") {
                    $i += 2
                } elseif (($i + 2) -lt $n -and $next -eq "`r" -and $Segment[$i + 2] -eq "`n") {
                    $i += 3
                } elseif ($next -eq '$' -or $next -eq '`' -or $next -eq '"' -or $next -eq '\') {
                    [void]$text.Append($next); $i += 2
                } else { [void]$text.Append($ch); $i++ }
            } elseif ($ch -eq '`') {
                $tokTaint = $true; [void]$text.Append($ch); $i++
            } else {
                if ($ch -eq '$' -and ($i + 1) -lt $n -and ($Segment[$i + 1] -eq '(' -or $Segment[$i + 1] -eq '{')) { $tokTaint = $true }
                [void]$text.Append($ch); $i++
            }
        }
    }
    $unterminated = ($state -ne 0)
    if ($unterminated) { $tokTaint = $true }
    if ($inTok) {
        $tTexts.Add($text.ToString()); $tRaws.Add($Segment.Substring($start, $i - $start))
        $tQuoted.Add($quoted); $tTaint.Add($tokTaint); $tEnd.Add($i)
    }

    $cmdIdx = -1
    $tainted = $unterminated
    for ($k = 0; $k -lt $tTexts.Count; $k++) {
        if ($tTaint[$k]) { $tainted = $true }
        if ($script:AssignmentToken.IsMatch($tRaws[$k])) { continue }
        if (-not $tQuoted[$k] -and ($script:CommandWrappers -ccontains $tTexts[$k])) { continue }
        $cmdIdx = $k
        break
    }
    $command = $null
    $commandEnd = 0
    if ($cmdIdx -ge 0) {
        if (-not $tQuoted[$cmdIdx] -and -not $tTaint[$cmdIdx] -and $tTexts[$cmdIdx].IndexOf('$') -lt 0) { $command = $tTexts[$cmdIdx] }
        $commandEnd = $tEnd[$cmdIdx]
    }
    # Argv: las redirecciones (>f, 2>&1, > f) no son argumentos; bash las quita antes de armar argv, asi
    # que una redireccion entre las palabras no evita la invocacion (review #370, B1).
    $argv = [System.Collections.Generic.List[string]]::new()
    for ($k = 0; $k -lt $tTexts.Count; $k++) {
        if ($script:RedirectToken.IsMatch($tTexts[$k])) {
            if ($script:RedirectOperator.IsMatch($tTexts[$k])) { $k++ }
            continue
        }
        $argv.Add($tTexts[$k])
    }
    $result = [pscustomobject]@{
        Tokens = $tTexts.ToArray()
        Argv = $argv.ToArray()
        CommandIndex = $cmdIdx
        Command = $command
        CommandEnd = $commandEnd
        Tainted = $tainted
    }
    if ($script:InfoCache.Count -ge 20000) { $script:InfoCache.Clear() }
    $script:InfoCache[$Segment] = $result
    return $result
}
# Vacia solo el texto entre comillas que es dato (valor de flags de texto libre de git/gh, argumentos
# de echo/printf) para que un --body "gh pr create" no dispare un bloqueo falso. Todo lo demas se
# conserva: bash -c "...", sudo -b "...", cualquier $(...) o backtick, y cualquier segmento cuya
# palabra-comando no sea exactamente git/gh/echo/printf (o no se pueda determinar). Espera UN
# segmento (ver Split-ShellSegments). Limite conocido (Issue #340 punto 9): heredocs fuera de scope.
function Remove-QuotedContent {
    param([string]$Command)

    if ($script:BareCache.ContainsKey($Command)) { return $script:BareCache[$Command] }
    $bare = Remove-QuotedContentCore -Command $Command
    if ($script:BareCache.Count -ge 20000) { $script:BareCache.Clear() }
    $script:BareCache[$Command] = $bare
    return $bare
}

function Remove-QuotedContentCore {
    param([string]$Command)

    $info = Get-SegmentCommandInfo -Segment $Command
    if ($info.Tainted -or -not $info.Command) { return $Command }

    $word = $info.Command
    if ($word -ieq 'git' -or $word -ieq 'gh') {
        $flags = '--(?:body|title|message|notes|description|comment|subject)|-(?:a?m|b|t)'
        $freeTextFlag = '(?<![\w-])(?<f>' + $flags + ')(?<sep>\s+|=)(?<q>' + $script:QuotedLiteral + ')'
        return [regex]::Replace($Command, $freeTextFlag, {
            param($m)
            if (Test-QuotedIsExecutable -Quoted $m.Groups['q'].Value) { return $m.Value }
            return $m.Groups['f'].Value + $m.Groups['sep'].Value + '""'
        })
    }
    if ($word -ieq 'echo' -or $word -ieq 'printf') {
        $cut = $info.CommandEnd
        $echoArgs = [regex]::Replace($Command.Substring($cut), $script:QuotedLiteral, {
            param($m)
            if (Test-QuotedIsExecutable -Quoted $m.Value) { return $m.Value }
            return '""'
        })
        return $Command.Substring(0, $cut) + $echoArgs
    }
    return $Command
}

# Busca en UN segmento la invocacion de las palabras indicadas (ej. 'gh','pr','create|edit|merge';
# cada elemento admite alternativas separadas por '|'). Dos vias, ambas fail-closed:
#   1. regex sobre el texto ya depurado por Remove-QuotedContent (lo que veian los guards antes);
#   2. secuencia contigua de tokens sin comillas ni escapes, en cualquier posicion: cierra
#      `gh pr "create"`, `git pu\sh`, `g"h" pr create` que el shell normaliza y la regex no.
# Devuelve las palabras que matchearon (string[] en minuscula) o $null.
$script:InvocationSpecs = @{}

function Get-InvocationSpec {
    param([string[]]$Words)
    $key = $Words -join ' '
    $spec = $script:InvocationSpecs[$key]
    if (-not $spec) {
        $alts = [string[][]]::new($Words.Count)
        $groups = [string[]]::new($Words.Count)
        for ($k = 0; $k -lt $Words.Count; $k++) {
            $alts[$k] = $Words[$k].Split('|')
            $groups[$k] = '(' + $Words[$k] + ')'
        }
        $spec = [pscustomobject]@{
            Alts = $alts
            Regex = [regex]::new('\b' + ($groups -join '\s+') + '\b', 'IgnoreCase')
        }
        $script:InvocationSpecs[$key] = $spec
    }
    return $spec
}

function Find-SegmentInvocation {
    param([string]$Segment, [string[]]$Words)

    $spec = Get-InvocationSpec -Words $Words
    $alts = $spec.Alts
    $count = $Words.Count

    $bare = Remove-QuotedContent -Command $Segment
    $m = $spec.Regex.Match($bare)
    if ($m.Success) {
        $hit = [string[]]::new($count)
        for ($k = 0; $k -lt $count; $k++) { $hit[$k] = $m.Groups[$k + 1].Value.ToLowerInvariant() }
        return , $hit
    }

    $info = Get-SegmentCommandInfo -Segment $Segment
    $argv = $info.Argv
    for ($s = 0; $s -le $argv.Length - $count; $s++) {
        if ($alts[0] -notcontains $argv[$s]) { continue }
        $found = $true
        for ($k = 1; $k -lt $count; $k++) {
            if ($alts[$k] -notcontains $argv[$s + $k]) { $found = $false; break }
        }
        if ($found) {
            $hit = [string[]]::new($count)
            for ($k = 0; $k -lt $count; $k++) { $hit[$k] = $argv[$s + $k].ToLowerInvariant() }
            return , $hit
        }
    }

    # Si la palabra-comando es la buscada y el resto del segmento tiene una expansion ($IFS, $(), backtick),
    # el shell puede unir o separar las palabras de formas que no podemos modelar (palabras pegadas por
    # una variable): fail-closed, basta con que las palabras restantes aparezcan en orden en el resto.
    $windowHasExpansion = $false
    if ($info.CommandIndex -ge 0 -and $Segment.IndexOfAny($script:ExpansionChars) -ge 0) {
        $seen = 0
        for ($k = $info.CommandIndex; $k -lt $info.Tokens.Length -and $seen -lt $count; $k++) {
            $tok = $info.Tokens[$k]
            if ($k -gt $info.CommandIndex -and $script:RedirectToken.IsMatch($tok)) {
                if ($script:RedirectOperator.IsMatch($tok)) { $k++ }
                continue
            }
            if ($tok.IndexOfAny($script:ExpansionChars) -ge 0) { $windowHasExpansion = $true; break }
            $seen++
        }
    }
    if ($windowHasExpansion) {
        $cmdTok = $info.Tokens[$info.CommandIndex]
        $cmdHasExpansion = $cmdTok.IndexOfAny($script:ExpansionChars) -ge 0
        $lead = $null
        $cmdRest = ''
        foreach ($alt in $alts[0]) {
            if ($cmdTok -ieq $alt) { $lead = $alt; break }
            if ($cmdHasExpansion -and $cmdTok.StartsWith($alt, [System.StringComparison]::OrdinalIgnoreCase)) {
                $lead = $alt; $cmdRest = $cmdTok.Substring($alt.Length); break
            }
        }
        $restText = $cmdRest + ' ' + $Segment.Substring($info.CommandEnd)

        # (A) la palabra-comando es la buscada o una variable (`$G pr create`) y las palabras restantes
        # aparecen, en orden, en el resto del texto (palabras pegadas por una expansion, `gh pr${IFS}create`).
        if ($lead -or $cmdHasExpansion) {
            $pos = 0
            $hit = [string[]]::new($count)
            $hit[0] = if ($lead) { $lead.ToLowerInvariant() } else { $alts[0][0].ToLowerInvariant() }
            $ok = $true
            for ($k = 1; $k -lt $count; $k++) {
                $at = -1; $atWord = $null
                foreach ($alt in $alts[$k]) {
                    $idx = $restText.IndexOf($alt, $pos, [System.StringComparison]::OrdinalIgnoreCase)
                    if ($idx -ge 0 -and ($at -lt 0 -or $idx -lt $at)) { $at = $idx; $atWord = $alt }
                }
                if ($at -lt 0) { $ok = $false; break }
                $hit[$k] = $atWord.ToLowerInvariant()
                $pos = $at + $atWord.Length
            }
            if ($ok) { return , $hit }
        }

        # (B) la palabra-comando es la buscada y una de las posiciones de subcomando es una expansion
        # (`C=create; gh pr $C`): el shell decide en ejecucion, no se puede descartar -> fail-closed.
        if ($lead -and $cmdRest -eq '' -and $count -gt 1) {
            $seen = 0
            for ($k = $info.CommandIndex + 1; $k -lt $info.Tokens.Length -and $seen -lt ($count - 1); $k++) {
                $tok = $info.Tokens[$k]
                if ($script:RedirectToken.IsMatch($tok)) {
                    if ($script:RedirectOperator.IsMatch($tok)) { $k++ }
                    continue
                }
                if ($tok.IndexOfAny($script:ExpansionChars) -ge 0) {
                    $hit = [string[]]::new($count)
                    $hit[0] = $lead.ToLowerInvariant()
                    for ($m2 = 1; $m2 -lt $count; $m2++) { $hit[$m2] = $alts[$m2][0].ToLowerInvariant() }
                    return , $hit
                }
                $seen++
            }
        }
    }
    return $null
}

function Test-SegmentInvokes {
    param([string]$Segment, [string[]]$Words)
    return ($null -ne (Find-SegmentInvocation -Segment $Segment -Words $Words))
}
