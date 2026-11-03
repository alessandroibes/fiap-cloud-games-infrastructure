param([switch]$SkipBuild)
. "$PSScriptRoot/Compose-Helpers.ps1"
$root = Split-Path $PSScriptRoot -Parent
Push-Location $root
try {
    & "$PSScriptRoot/Initialize-Local.ps1"
    foreach ($service in @('users', 'catalog', 'payments', 'notifications')) {
        if (-not (Test-Path "../fiap-cloud-games-$service/Dockerfile")) { throw "Clone irmão ausente: fiap-cloud-games-$service" }
    }
    Invoke-Compose config --quiet
    if (-not $SkipBuild) { Invoke-Compose build users catalog payments notifications }
    Invoke-Compose up -d --wait --wait-timeout 180 postgres rabbitmq
    # Transição dos projetos G2–G5: evita duas instâncias/portas e mantém containers/volumes.
    foreach ($service in @('users', 'catalog', 'payments', 'notifications')) {
        $containers = @(docker ps -q --filter "label=com.docker.compose.project=fcg-$service-local" --filter "label=com.docker.compose.service=$service")
        if ($LASTEXITCODE -ne 0) { throw 'Falha ao localizar serviços anteriores.' }
        foreach ($container in $containers) {
            docker stop $container
            if ($LASTEXITCODE -ne 0) { throw 'Falha ao parar serviço anterior.' }
        }
    }
    # Atualizações são operadas com APIs paradas para evitar concorrência com DDL.
    Invoke-Compose stop users catalog payments notifications
    foreach ($service in @('users', 'catalog', 'payments', 'notifications')) {
        Invoke-Compose run --rm --no-deps $service --migrate
    }
    Invoke-Compose run --rm --no-deps users --bootstrap
    Invoke-Compose up -d --wait --wait-timeout 180
    Wait-AllApis
    Write-Output 'Compose completo iniciado; quatro APIs prontas após migrations e bootstrap explícitos.'
} finally { Pop-Location }
