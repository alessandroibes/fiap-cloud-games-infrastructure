param([switch]$SkipStart)
. "$PSScriptRoot/Compose-Helpers.ps1"
$root = Split-Path $PSScriptRoot -Parent
Push-Location $root
$previousOutcome = $env:PAYMENT_OUTCOME
$changedMode = $false
function Set-PaymentMode([string]$mode) {
    $env:PAYMENT_OUTCOME = $mode
    Invoke-Compose up -d --no-deps --force-recreate payments
    Wait-Api $paymentsUrl
}
function New-Game([string]$name) {
    $response = Invoke-WebRequest "$catalogUrl/api/games" -Headers $adminHeaders -Method Post -ContentType 'application/json' -Body (@{name=$name;price=29.90} | ConvertTo-Json) -UseBasicParsing
    if ($response.StatusCode -ne 201) { throw 'Jogo não retornou 201.' }
    return ($response.Content | ConvertFrom-Json).id
}
function New-Order([string]$gameId) {
    $response = Invoke-WebRequest "$catalogUrl/api/orders" -Headers $headers -Method Post -ContentType 'application/json' -Body (@{gameId=$gameId} | ConvertTo-Json) -UseBasicParsing
    $order = $response.Content | ConvertFrom-Json
    if ($response.StatusCode -ne 202 -or $order.status -ne 'Pending') { throw 'Compra não retornou 202/Pending.' }
    return $order.orderId
}
function Wait-Order([string]$id, [string]$expected) {
    $deadline = [DateTime]::UtcNow.AddSeconds(90)
    do {
        $order = Invoke-RestMethod "$catalogUrl/api/orders/$id" -Headers $headers
        if ($order.status -eq $expected) { return }
        if ($order.status -ne 'Pending') { throw 'Resultado terminal divergente.' }
        Start-Sleep -Milliseconds 300
    } while ([DateTime]::UtcNow -lt $deadline)
    throw 'Pedido não concluiu no prazo.'
}
function Assert-Library([string]$gameId, [int]$expected) {
    $library = Invoke-RestMethod "$catalogUrl/api/library" -Headers $headers
    if (@($library | Where-Object { $_.gameId -eq $gameId }).Count -ne $expected) { throw 'Quantidade incorreta na biblioteca.' }
}
function Read-NotificationState([string]$id) {
    # Consulta administrativa exclusivamente de validação; não integra o runtime dos serviços.
    $subject = ([Guid]::Parse($id)).ToString()
    $sql = 'SELECT (SELECT count(*) FROM "Subjects" WHERE "SubjectId" = ''{0}''), (SELECT count(*) FROM "Notifications" WHERE "SubjectId" = ''{0}''), (SELECT count(*) FROM "Notifications" WHERE "SubjectId" = ''{0}'' AND "State" = ''Emitted'');' -f $subject
    $result = $sql | docker compose exec -T postgres psql -U fcg_admin -d fcg_notifications -t -A
    if ($LASTEXITCODE -ne 0) { throw 'Consulta de evidência Notifications falhou.' }
    return ($result -join '').Trim()
}
function Wait-Notification([string]$id, [bool]$emitted) {
    $expected = if ($emitted) { '1|1|1' } else { '1|0|0' }
    $deadline = [DateTime]::UtcNow.AddSeconds(90)
    do {
        if ((Read-NotificationState $id) -eq $expected) { return }
        Start-Sleep -Milliseconds 500
    } while ([DateTime]::UtcNow -lt $deadline)
    throw 'Notificação durável não atingiu o estado esperado.'
}
try {
    if (-not $SkipStart) { & "$PSScriptRoot/Start-Local.ps1" }
    Invoke-Compose config --quiet
    Wait-AllApis
    $settings = Get-LocalSettings
    $usersUrl = "http://127.0.0.1:$($settings['USERS_PORT'])"
    $catalogUrl = "http://127.0.0.1:$($settings['CATALOG_PORT'])"
    $paymentsUrl = "http://127.0.0.1:$($settings['PAYMENTS_PORT'])"
    $started = [DateTime]::UtcNow.ToString('o')
    $login = Invoke-RestMethod "$usersUrl/api/auth/login" -Method Post -ContentType 'application/json' -Body (@{email=$settings['BOOTSTRAP_EMAIL'];password=$settings['BOOTSTRAP_PASSWORD']} | ConvertTo-Json)
    $adminHeaders = @{Authorization="Bearer $($login.accessToken)"}
    $runId = [Guid]::NewGuid().ToString('N')
    $email = "g6-$runId@example.com"
    $password = 'Aa1!' + [Guid]::NewGuid().ToString('N')
    $response = Invoke-WebRequest "$usersUrl/api/users" -Method Post -ContentType 'application/json' -Body (@{name='Demonstracao G6';email=$email;password=$password} | ConvertTo-Json) -UseBasicParsing
    if ($response.StatusCode -ne 201) { throw 'Cadastro não retornou 201.' }
    $userId = ($response.Content | ConvertFrom-Json).id
    $login = Invoke-RestMethod "$usersUrl/api/auth/login" -Method Post -ContentType 'application/json' -Body (@{email=$email;password=$password} | ConvertTo-Json)
    $headers = @{Authorization="Bearer $($login.accessToken)"}
    Wait-Notification $userId $true
    $changedMode = $true
    Set-PaymentMode 'Approved'
    $approvedGame = New-Game "G6 aprovado $runId"
    $approvedOrder = New-Order $approvedGame
    Wait-Order $approvedOrder 'Approved'
    Assert-Library $approvedGame 1
    Wait-Notification $approvedOrder $true
    Set-PaymentMode 'Rejected'
    $retryGame = New-Game "G6 rejeitado e nova tentativa $runId"
    $rejectedOrder = New-Order $retryGame
    Wait-Order $rejectedOrder 'Rejected'
    Assert-Library $retryGame 0
    Wait-Notification $rejectedOrder $false
    Set-PaymentMode 'Approved'
    $retryOrder = New-Order $retryGame
    if ($retryOrder -eq $rejectedOrder) { throw 'Nova tentativa reutilizou pedido.' }
    Wait-Order $retryOrder 'Approved'
    Assert-Library $retryGame 1
    Wait-Notification $retryOrder $true
    $lines = docker compose logs --no-log-prefix --since $started notifications
    if ($LASTEXITCODE -ne 0) { throw 'Falha ao ler logs de Notifications.' }
    $records = @($lines | ForEach-Object { try { $record = $_ | ConvertFrom-Json; if ($record.notificationId) { $record } } catch { } })
    foreach ($subject in @($userId, $approvedOrder, $retryOrder)) {
        $matches = @($records | Where-Object { $_.subjectId -eq $subject })
        if (@($matches.notificationId | Select-Object -Unique).Count -ne 1) { throw 'Log esperado não encontrado ou identidade lógica duplicada.' }
    }
    if (@($records | Where-Object { $_.subjectId -eq $rejectedOrder }).Count -ne 0) { throw 'Rejected gerou log de confirmação.' }
    # Recria containers, mantendo volumes: mais forte que apenas reiniciar processos.
    Invoke-Compose stop users catalog payments notifications
    Invoke-Compose up -d --force-recreate --wait --wait-timeout 180 postgres rabbitmq
    Invoke-Compose up -d --force-recreate --wait --wait-timeout 180 users catalog payments notifications
    Wait-AllApis
    Wait-Order $approvedOrder 'Approved'
    Wait-Order $rejectedOrder 'Rejected'
    Wait-Order $retryOrder 'Approved'
    Assert-Library $approvedGame 1
    Assert-Library $retryGame 1
    Wait-Notification $userId $true
    Wait-Notification $approvedOrder $true
    Wait-Notification $rejectedOrder $false
    Wait-Notification $retryOrder $true
    [pscustomobject]@{UserId=$userId;ApprovedOrder=$approvedOrder;RejectedOrder=$rejectedOrder;RetryApprovedOrder=$retryOrder;Welcome=$true;RejectedConfirmation=$false;LibraryEntries=2;PersistedAfterRecreation=$true} | ConvertTo-Json
} finally {
    $env:PAYMENT_OUTCOME = $previousOutcome
    try {
        if ($changedMode) {
            Invoke-Compose up -d --no-deps --force-recreate payments
            Wait-Api $paymentsUrl
        }
    } finally { Pop-Location }
}
