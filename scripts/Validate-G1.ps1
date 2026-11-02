$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
Push-Location $root
$previousMode = $env:G1_VERIFY_PERSISTENCE
try {
    & "$PSScriptRoot/Initialize-Local.ps1"
    docker compose config --quiet
    if ($LASTEXITCODE -ne 0) { throw 'Compose inválido.' }
    docker compose up -d --wait --wait-timeout 180
    if ($LASTEXITCODE -ne 0) { throw 'Dependências indisponíveis.' }
    dotnet restore FiapCloudGames.Infrastructure.sln --locked-mode
    if ($LASTEXITCODE -ne 0) { throw 'Restore falhou.' }
    dotnet build FiapCloudGames.Infrastructure.sln --no-restore
    if ($LASTEXITCODE -ne 0) { throw 'Build falhou.' }
    $env:G1_VERIFY_PERSISTENCE = '0'
    dotnet test FiapCloudGames.Infrastructure.sln --no-build --logger 'trx;LogFileName=g1-full.trx'
    if ($LASTEXITCODE -ne 0) { throw 'Testes G1 falharam.' }
    docker compose restart postgres rabbitmq
    if ($LASTEXITCODE -ne 0) { throw 'Reinício falhou.' }
    docker compose up -d --wait --wait-timeout 180
    if ($LASTEXITCODE -ne 0) { throw 'Dependências não recuperadas.' }
    $env:G1_VERIFY_PERSISTENCE = '1'
    dotnet test FiapCloudGames.Infrastructure.sln --no-build --filter 'Phase=Persistence' --logger 'trx;LogFileName=g1-persistence.trx'
    if ($LASTEXITCODE -ne 0) { throw 'Persistência após reinício falhou.' }
    Write-Output 'G1 validado: contratos, isolamento, broker e persistência após reinício.'
} finally {
    $env:G1_VERIFY_PERSISTENCE = $previousMode
    Pop-Location
}
