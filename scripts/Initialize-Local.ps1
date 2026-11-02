$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
$path = Join-Path $root '.env'
if (Test-Path -LiteralPath $path) {
    Write-Output '.env já existe; credenciais preservadas.'
    exit 0
}
$lines = @('POSTGRES_PORT=55432', 'RABBITMQ_PORT=5672', 'RABBITMQ_MANAGEMENT_PORT=15672')
$random = [Security.Cryptography.RandomNumberGenerator]::Create()
try {
    foreach ($key in @('POSTGRES_ADMIN_PASSWORD', 'USERS_DB_PASSWORD', 'CATALOG_DB_PASSWORD', 'PAYMENTS_DB_PASSWORD', 'NOTIFICATIONS_DB_PASSWORD', 'RABBITMQ_PASSWORD')) {
        $bytes = New-Object byte[] 32
        $random.GetBytes($bytes)
        $lines += $key + '=' + ([BitConverter]::ToString($bytes).Replace('-', '').ToLowerInvariant())
    }
    $encoding = New-Object Text.UTF8Encoding($false)
    [IO.File]::WriteAllLines($path, $lines, $encoding)
} finally { $random.Dispose() }
Write-Output '.env criado com credenciais aleatórias locais; não versionar nem compartilhar.'
