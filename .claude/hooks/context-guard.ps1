# context-guard.ps1 — UserPromptSubmit hook
#
# Estima el consumo de tokens de la sesión leyendo el transcript JSONL.
# Emite warnings cuando el contexto se acerca al límite operativo.
#
# Por qué existe: el agente no tiene visibilidad del token count. Sin advertencia,
# el autocompact puede dispararse y perder nuance de la conversación en curso.
#
# Estimación: total_chars / 4 ≈ tokens (±10% de margen, suficiente para guardia)
#
# Umbrales:
#   < 60k tokens  → sin ruido
#   60k–80k tokens → warning suave
#   ≥ 80k tokens  → warning urgente (compactar manualmente)
#
# Claude Code inyecta el input como JSON en stdin:
#   { "session_id": "...", "transcript_path": "...", "message": "..." }

$THRESHOLD_WARN  = 60000
$THRESHOLD_ALERT = 80000

# Leer stdin
$raw = $null
try {
    $raw = [Console]::In.ReadToEnd()
} catch {
    exit 0
}

if (-not $raw) { exit 0 }

$input_json = $null
try {
    $input_json = $raw | ConvertFrom-Json
} catch {
    exit 0
}

$transcript_path = $input_json.transcript_path
if (-not $transcript_path -or -not (Test-Path $transcript_path)) {
    exit 0
}

# Leer y parsear el transcript JSONL
$total_chars = 0
try {
    Get-Content $transcript_path | ForEach-Object {
        $entry = $_ | ConvertFrom-Json -ErrorAction SilentlyContinue
        if ($entry) {
            # Sumar contenido de mensajes (text blocks y tool results)
            if ($entry.content) {
                if ($entry.content -is [string]) {
                    $total_chars += $entry.content.Length
                } elseif ($entry.content -is [array]) {
                    foreach ($block in $entry.content) {
                        if ($block.text)    { $total_chars += $block.text.Length }
                        if ($block.content) {
                            if ($block.content -is [string]) {
                                $total_chars += $block.content.Length
                            } elseif ($block.content -is [array]) {
                                foreach ($inner in $block.content) {
                                    if ($inner.text) { $total_chars += $inner.text.Length }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
} catch {
    exit 0
}

$estimated_tokens = [int]($total_chars / 4)

if ($estimated_tokens -lt $THRESHOLD_WARN) {
    exit 0
}

# Construir warning según umbral
if ($estimated_tokens -ge $THRESHOLD_ALERT) {
    $warning = @"
⚠️ CONTEXT-GUARD — ALERTA URGENTE
Tokens estimados: ~$estimated_tokens / 80.000 umbral
El contexto está en zona crítica. Compactar manualmente antes de continuar:
  • Escribí /compact en el prompt para comprimir el historial
  • O cerrá la sesión con el protocolo session_end para guardar en Engram
Continuar sin compactar puede causar degradación o pérdida de contexto.
"@
} else {
    $warning = @"
ℹ️ CONTEXT-GUARD — Advertencia
Tokens estimados: ~$estimated_tokens / 80.000 umbral
El contexto está creciendo. Considerá compactar pronto con /compact.
"@
}

# Inyectar como contexto (sin bloquear — exit 0)
Write-Output $warning
exit 0
