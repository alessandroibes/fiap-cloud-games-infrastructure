$ErrorActionPreference = 'Stop'
function Get-LocalSettings {
    $settings = @{}
    foreach ($line in Get-Content -LiteralPath (Join-Path $PSScriptRoot '../.env')) {
        if ($line -and -not $line.StartsWith('#')) {
            $pair = $line.Split('=', 2)
            $value = [Environment]::GetEnvironmentVariable($pair[0], 'Process')
            if ([string]::IsNullOrEmpty($value)) { $value = $pair[1] }
            $settings[$pair[0]] = $value
        }
    }
    return $settings
}
function Invoke-Compose {
    docker compose @args
    if ($LASTEXITCODE -ne 0) { throw 'Comando Docker Compose falhou; consulte a saída anterior.' }
}
function Wait-Api([string]$url) {
    $deadline = [DateTime]::UtcNow.AddSeconds(90)
    do {
        try {
            $response = Invoke-WebRequest "$url/health/ready" -UseBasicParsing -TimeoutSec 5
            if ($response.StatusCode -eq 200) { return }
        } catch { }
        Start-Sleep -Milliseconds 500
    } while ([DateTime]::UtcNow -lt $deadline)
    throw "API não ficou pronta: $url"
}
function Wait-AllApis {
    $settings = Get-LocalSettings
    foreach ($service in @('USERS', 'CATALOG', 'PAYMENTS', 'NOTIFICATIONS')) {
        Wait-Api "http://127.0.0.1:$($settings[$service + '_PORT'])"
    }
}
