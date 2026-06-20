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
# Umbrales (ventana real: 200k tokens):
#   < 130k tokens  → sin ruido
#   130k–160k tokens → warning suave (~65-80% de la ventana)
#   ≥ 160k tokens  → warning urgente (dejar buffer para autocompact de 33k)
#
# Claude Code inyecta el input como JSON en stdin:
#   { "session_id": "...", "transcript_path": "...", "message": "..." }

$THRESHOLD_WARN  = 130000
$THRESHOLD_ALERT = 160000

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

# Estimacion rapida por tamaño de archivo (evita timeout con transcripts grandes)
# file_bytes / 8 ≈ tokens (JSONL tiene overhead de estructura ~2x vs tokens reales)
# Calibrado contra /context: 190k bytes → ~89k tokens reales (ventana 200k)
$estimated_tokens = 0
try {
    $file_size = (Get-Item $transcript_path).Length
    $estimated_tokens = [int]($file_size / 8)
} catch {
    exit 0
}

if ($estimated_tokens -lt $THRESHOLD_WARN) {
    exit 0
}

# Construir warning según umbral
if ($estimated_tokens -ge $THRESHOLD_ALERT) {
    $warning = @"
⚠️ CONTEXT-GUARD — ALERTA URGENTE
Tokens estimados: ~$estimated_tokens / 200.000 ventana
El contexto está en zona crítica. Compactar manualmente antes de continuar:
  • Escribí /compact en el prompt para comprimir el historial
  • O cerrá la sesión con el protocolo session_end para guardar en Engram
Continuar sin compactar puede causar degradación o pérdida de contexto.
"@
} else {
    $warning = @"
ℹ️ CONTEXT-GUARD — Advertencia
Tokens estimados: ~$estimated_tokens / 200.000 ventana
El contexto está creciendo. Considerá compactar pronto con /compact.
"@
}

# Inyectar como contexto (sin bloquear — exit 0)
Write-Output $warning
exit 0
