$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
$path = Join-Path $root '.env'
$lines = @()
$settings = @{}
if (Test-Path -LiteralPath $path) { $lines = @(Get-Content -LiteralPath $path) }
foreach ($line in $lines) {
    if ($line -and -not $line.StartsWith('#')) { $pair = $line.Split('=', 2); $settings[$pair[0]] = $pair[1] }
}
$legacy = @{}
$legacyPath = Join-Path $root '../fiap-cloud-games-users/.env'
if (Test-Path -LiteralPath $legacyPath) {
    foreach ($line in Get-Content -LiteralPath $legacyPath) {
        if ($line -and -not $line.StartsWith('#')) { $pair = $line.Split('=', 2); $legacy[$pair[0]] = $pair[1] }
    }
}
$defaults = [ordered]@{
    POSTGRES_PORT='55432'; RABBITMQ_PORT='5672'; RABBITMQ_MANAGEMENT_PORT='15672'
    USERS_PORT='5081'; CATALOG_PORT='5082'; PAYMENTS_PORT='5083'; NOTIFICATIONS_PORT='5084'
    JWT_ISSUER='fiap-cloud-games-users'; JWT_AUDIENCE='fiap-cloud-games'
    BOOTSTRAP_NAME='Administrador local'; BOOTSTRAP_EMAIL='admin@fcg.local'; PAYMENT_OUTCOME='Approved'
}
$mapping = @{JWT_KEY='Jwt__Key'; JWT_ISSUER='Jwt__Issuer'; JWT_AUDIENCE='Jwt__Audience'; BOOTSTRAP_NAME='AdminBootstrap__Name'; BOOTSTRAP_EMAIL='AdminBootstrap__Email'; BOOTSTRAP_PASSWORD='AdminBootstrap__Password'}
foreach ($key in $mapping.Keys) {
    if ($legacy[$mapping[$key]]) { $defaults[$key] = $legacy[$mapping[$key]] }
}
$random = [Security.Cryptography.RandomNumberGenerator]::Create()
try {
    foreach ($key in @('POSTGRES_ADMIN_PASSWORD', 'USERS_DB_PASSWORD', 'CATALOG_DB_PASSWORD', 'PAYMENTS_DB_PASSWORD', 'NOTIFICATIONS_DB_PASSWORD', 'RABBITMQ_PASSWORD', 'JWT_KEY', 'BOOTSTRAP_PASSWORD')) {
        $bytes = New-Object byte[] 32
        $random.GetBytes($bytes)
        if (-not $defaults.Contains($key)) {
            $defaults[$key] = [BitConverter]::ToString($bytes).Replace('-', '').ToLowerInvariant()
            if ($key -eq 'BOOTSTRAP_PASSWORD') { $defaults[$key] = 'Aa1!' + $defaults[$key] }
        }
    }
    foreach ($key in $defaults.Keys) {
        if ($settings.ContainsKey($key)) {
            if ([string]::IsNullOrWhiteSpace($settings[$key])) { throw "Valor vazio em .env: $key. Corrija explicitamente; credenciais existentes não serão substituídas." }
        } else { $lines += $key + '=' + $defaults[$key] }
    }
    $encoding = New-Object Text.UTF8Encoding($false)
    [IO.File]::WriteAllLines($path, $lines, $encoding)
} finally { $random.Dispose() }
Write-Output '.env preparado; valores existentes preservados. Configuração Users reutilizada quando disponível; novos segredos aleatórios. Não compartilhar.'
