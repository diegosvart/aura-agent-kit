# Libreria compartida de gh-account-guard.ps1 y pr-base-guard.ps1 (dot-source, no es un hook).
# Vive plana en .claude/hooks/ porque new-project-setup copia solo .claude/hooks/*.ps1.

# Divide un comando compuesto (&&, ||, ;, |) en segmentos, respetando comillas simples/dobles,
# para que cada invocacion se evalue de forma independiente. Sin esto, un comando tipo
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
        if ($ch -eq "'" -and -not $inDouble) { $inSingle = -not $inSingle; [void]$current.Append($ch); $i++; continue }
        if ($ch -eq '"' -and -not $inSingle) { $inDouble = -not $inDouble; [void]$current.Append($ch); $i++; continue }
        if (-not $inSingle -and -not $inDouble) {
            if (($i + 1) -lt $Command.Length -and $Command.Substring($i, 2) -in @('&&', '||')) {
                $segments.Add($current.ToString()) | Out-Null
                [void]$current.Clear()
                $i += 2
                continue
            }
            if ($ch -eq ';' -or $ch -eq '|' -or $ch -eq '&' -or $ch -eq "`n" -or $ch -eq "`r") {
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

# Una comilla que contiene $(...) o backticks NO es dato: el shell la expande ejecutando lo que
# haya dentro. Vaciarla dejaria pasar `git commit -m "$(gh pr create --base main)"`
# (review PR #363, bloqueante 1).
function Test-QuotedIsExecutable {
    param([string]$Quoted)
    return ($Quoted -match '\$\(' -or $Quoted.Contains('`'))
}

# Vacia solo el texto entre comillas que es dato (valor de flags de texto libre, argumentos de
# echo/printf) para que un --body "gh pr create" no dispare un bloqueo falso. Las comillas que son
# carga ejecutable (bash -c "...", pwsh -Command "...", cualquier $(...) o backtick) se conservan:
# vaciarlas dejaria pasar un comando real. Espera UN segmento (ver Split-ShellSegments). Limite
# conocido (Issue #340 punto 9): heredocs quedan fuera de scope.
function Remove-QuotedContent {
    param([string]$Command)

    $longFlags = '--(?:body|title|message|notes|description|comment|subject)'
    # Los flags cortos solo son texto libre cuando el segmento invoca git/gh, tambien tras
    # prefijos (VAR=x, sudo, env, command, time): `sudo -b "..."` y `watch -t "..."` usan -b/-t
    # para payload ejecutable, no para un mensaje (review PR #363, bloqueante 2).
    $shortFlags = '-(?:a?m|b|t)'
    $ghInvocation = '^\s*(?:(?:\w+=(?>"[^"]*"|''[^'']*''|[^\s"''])*|sudo|env|command|time)\s+)*(?:git|gh)\b'
    $flags = if ($Command -match $ghInvocation) { "$longFlags|$shortFlags" } else { $longFlags }

    $freeTextFlag = '(?<![\w-])(?<f>' + $flags + ')(?<sep>\s+|=)(?<q>' + $script:QuotedLiteral + ')'
    $result = [regex]::Replace($Command, $freeTextFlag, {
        param($m)
        if (Test-QuotedIsExecutable -Quoted $m.Groups['q'].Value) { return $m.Value }
        return $m.Groups['f'].Value + $m.Groups['sep'].Value + '""'
    })

    # Todo lo que sigue a echo/printf dentro del segmento son sus argumentos, asi que se vacian
    # todos los literales citados posteriores -- no solo el primero. Cubre `echo -e "..."` y
    # `printf "%s\n" "..."`.
    $echoLike = [regex]::Match($result, '(?<![\w-])(?:echo|printf)\b')
    if ($echoLike.Success) {
        $cut = $echoLike.Index + $echoLike.Length
        $echoArgs = [regex]::Replace($result.Substring($cut), $script:QuotedLiteral, {
            param($m)
            if (Test-QuotedIsExecutable -Quoted $m.Value) { return $m.Value }
            return '""'
        })
        $result = $result.Substring(0, $cut) + $echoArgs
    }
    return $result
}
