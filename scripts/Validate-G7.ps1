param([switch]$SkipStart)
. "$PSScriptRoot/Compose-Helpers.ps1"
. "$PSScriptRoot/Kubernetes-Helpers.ps1"
$root = Split-Path $PSScriptRoot -Parent
Push-Location $root
$previousOutcome = $null
$script:forwardProcesses = @()
$changedMode = $false
function Stop-Forwards {
    foreach ($process in $script:forwardProcesses) {
        if (-not $process.HasExited) { $process.Kill(); $process.WaitForExit() }
        $process.Dispose()
    }
    $script:forwardProcesses = @()
}
function Start-Forwards {
    Stop-Forwards
    $logs = Join-Path $root ('tests/TestResults/k8s/' + [Guid]::NewGuid().ToString('N'))
    [void][IO.Directory]::CreateDirectory($logs)
    $ports = @{users=5181;catalog=5182;payments=5183;notifications=5184}
    try {
        foreach ($service in $ports.Keys) {
            $arguments = @('--context','docker-desktop','--namespace','fcg-phase2','port-forward',"service/$service","$($ports[$service]):8080",'--address','127.0.0.1')
            $process = Start-Process -FilePath (Get-Command kubectl).Source -ArgumentList $arguments -PassThru -WindowStyle Hidden -RedirectStandardOutput "$logs/$service.log" -RedirectStandardError "$logs/$service.err"
            $script:forwardProcesses += $process
            Wait-Api "http://127.0.0.1:$($ports[$service])"
            if ($process.HasExited) { throw 'Port-forward não ficou ativo; verifique conflito de porta em 5181–5184.' }
        }
    } catch { Stop-Forwards; throw }
}
function Set-PaymentMode([string]$mode) {
    $config = (Invoke-Kube get configmap payments-config -o json) | ConvertFrom-Json
    $config.data.PaymentSimulation__Outcome = $mode
    $config | ConvertTo-Json -Depth 20 | kubectl --context docker-desktop -n fcg-phase2 replace -f -
    if ($LASTEXITCODE -ne 0) { throw 'Falha ao alterar simulação.' }
    Invoke-Kube rollout restart deployment/payments
    Wait-Deployment 'payments'
    Start-Forwards
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
    $result = $sql | kubectl --context docker-desktop -n fcg-phase2 exec -i deployment/postgres -- psql -U fcg_admin -d fcg_notifications -t -A
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
    if (-not $SkipStart) { & "$PSScriptRoot/Start-Kubernetes.ps1" }
    foreach ($service in @('users','catalog','payments','notifications')) { Wait-Deployment $service }
    $settings = Get-KubernetesSettings
    $previousOutcome = ((Invoke-Kube get configmap payments-config -o json) | ConvertFrom-Json).data.PaymentSimulation__Outcome
    $usersUrl = 'http://127.0.0.1:5181'
    $catalogUrl = 'http://127.0.0.1:5182'
    $paymentsUrl = 'http://127.0.0.1:5183'
    Start-Forwards
    $started = [DateTime]::UtcNow.ToString('o')
    $login = Invoke-RestMethod "$usersUrl/api/auth/login" -Method Post -ContentType 'application/json' -Body (@{email=$settings['BOOTSTRAP_EMAIL'];password=$settings['BOOTSTRAP_PASSWORD']} | ConvertTo-Json)
    $adminHeaders = @{Authorization="Bearer $($login.accessToken)"}
    $runId = [Guid]::NewGuid().ToString('N')
    $email = "g7-$runId@example.com"
    $password = 'Aa1!' + [Guid]::NewGuid().ToString('N')
    $response = Invoke-WebRequest "$usersUrl/api/users" -Method Post -ContentType 'application/json' -Body (@{name='Demonstracao G7';email=$email;password=$password} | ConvertTo-Json) -UseBasicParsing
    if ($response.StatusCode -ne 201) { throw 'Cadastro não retornou 201.' }
    $userId = ($response.Content | ConvertFrom-Json).id
    $login = Invoke-RestMethod "$usersUrl/api/auth/login" -Method Post -ContentType 'application/json' -Body (@{email=$email;password=$password} | ConvertTo-Json)
    $headers = @{Authorization="Bearer $($login.accessToken)"}
    Wait-Notification $userId $true
    $changedMode = $true
    Set-PaymentMode 'Approved'
    $approvedGame = New-Game "G7 aprovado $runId"
    # Evidência observável de Pending sem concessão antes do processamento.
    try {
        Invoke-Kube scale deployment/payments --replicas=0
        Invoke-Kube wait --for=delete pod -l app=payments --timeout=90s
        $approvedOrder = New-Order $approvedGame
        Wait-Order $approvedOrder 'Pending'
        Assert-Library $approvedGame 0
        if ((Read-NotificationState $approvedOrder) -ne '0|0|0') { throw 'Confirmação criada antes de processar pagamento.' }
    } finally {
        Invoke-Kube scale deployment/payments --replicas=1
        Wait-Deployment 'payments'
        Start-Forwards
    }
    Wait-Order $approvedOrder 'Approved'
    Assert-Library $approvedGame 1
    Wait-Notification $approvedOrder $true
    Set-PaymentMode 'Rejected'
    $retryGame = New-Game "G7 rejeitado e nova tentativa $runId"
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
    $lines = Invoke-Kube logs deployment/notifications --since-time=$started
    if ($LASTEXITCODE -ne 0) { throw 'Falha ao ler logs de Notifications.' }
    $records = @($lines | ForEach-Object { try { $record = $_ | ConvertFrom-Json; if ($record.notificationId) { $record } } catch { } })
    foreach ($subject in @($userId, $approvedOrder, $retryOrder)) {
        $matches = @($records | Where-Object { $_.subjectId -eq $subject })
        if (@($matches.notificationId | Select-Object -Unique).Count -ne 1) { throw 'Log esperado não encontrado ou identidade lógica duplicada.' }
    }
    if (@($records | Where-Object { $_.subjectId -eq $rejectedOrder }).Count -ne 0) { throw 'Rejected gerou log de confirmação.' }
    # Substitui pods via Deployment, mantendo claims e dados do namespace.
    Stop-Forwards
    foreach ($service in @('users','catalog','payments','notifications')) { Invoke-Kube scale "deployment/$service" --replicas=0 }
    foreach ($service in @('users','catalog','payments','notifications')) { Invoke-Kube wait --for=delete pod -l "app=$service" --timeout=90s }
    foreach ($service in @('postgres','rabbitmq')) { Invoke-Kube rollout restart "deployment/$service"; Wait-Deployment $service }
    foreach ($service in @('users','catalog','payments','notifications')) { Invoke-Kube scale "deployment/$service" --replicas=1; Wait-Deployment $service }
    Start-Forwards
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
    try {
        if ($changedMode) { Set-PaymentMode $previousOutcome }
    } finally { Stop-Forwards; Pop-Location }
}
