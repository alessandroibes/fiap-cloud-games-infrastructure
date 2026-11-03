. "$PSScriptRoot/Compose-Helpers.ps1"
. "$PSScriptRoot/Kubernetes-Helpers.ps1"
Add-Type -AssemblyName System.Net.Http
$root = Split-Path $PSScriptRoot -Parent
Push-Location $root
$script:forwards = @()
$brokerStopped = $false
$usersUrl = 'http://127.0.0.1:5181'
$catalogUrl = 'http://127.0.0.1:5182'
$managementUrl = 'http://127.0.0.1:15682/api'
function Stop-Forwards {
    foreach ($process in $script:forwards) {
        if (-not $process.HasExited) { $process.Kill(); $process.WaitForExit() }
        $process.Dispose()
    }
    $script:forwards = @()
}
function Forward([string]$service, [string]$ports) {
    $logs = Join-Path $root ('tests/TestResults/g8/' + [Guid]::NewGuid().ToString('N'))
    [void][IO.Directory]::CreateDirectory($logs)
    $arguments = @('--context','docker-desktop','-n','fcg-phase2','port-forward',"service/$service",$ports,'--address','127.0.0.1')
    $script:forwards += Start-Process -FilePath (Get-Command kubectl).Source -ArgumentList $arguments -PassThru -WindowStyle Hidden -RedirectStandardOutput "$logs/out.log" -RedirectStandardError "$logs/error.log"
}
function Start-ApiForwards {
    Stop-Forwards
    Forward users '5181:8080'; Wait-Api $usersUrl
    Forward catalog '5182:8080'; Wait-Api $catalogUrl
    foreach ($process in $script:forwards) { if ($process.HasExited) { throw 'Port-forward encerrado; confira portas livres.' } }
}
function Read-Sql([ValidateSet('users','catalog','payments','notifications')][string]$db, [string]$sql) {
    $output = $sql | kubectl --context docker-desktop -n fcg-phase2 exec -i deployment/postgres -- psql -v ON_ERROR_STOP=1 -U fcg_admin -d "fcg_$db" -t -A
    if ($LASTEXITCODE -ne 0) { throw 'Consulta de evidência falhou.' }
    return ($output -join '').Trim()
}
function Wait-Sql([string]$db, [string]$sql, [string]$expected) {
    $deadline = [DateTime]::UtcNow.AddSeconds(120)
    do {
        if ((Read-Sql $db $sql) -eq $expected) { return }
        Start-Sleep -Milliseconds 500
    } while ([DateTime]::UtcNow -lt $deadline)
    throw "Estado persistido esperado não observado em $db."
}
function Broker([string]$path, [string]$method = 'Get', $body = $null) {
    $parameters = @{Uri="$managementUrl/$path";Method=$method;Headers=$brokerHeaders;TimeoutSec=10}
    if ($null -ne $body) { $parameters.ContentType='application/json'; $parameters.Body=$body | ConvertTo-Json -Depth 15 -Compress }
    return Invoke-RestMethod @parameters
}
function Publish-Event([string]$type, [hashtable]$message) {
    $envelope = @{messageId=[Guid]::NewGuid().ToString();messageType=@("urn:message:FiapCloudGames.Contracts.V1:$type");message=$message;sentTime=[DateTime]::UtcNow.ToString('o')}
    $exchange = [Uri]::EscapeDataString("FiapCloudGames.Contracts.V1:$type")
    $result = Broker "exchanges/fcg/$exchange/publish" 'Post' @{properties=@{content_type='application/vnd.masstransit+json';delivery_mode=2};routing_key='';payload=($envelope | ConvertTo-Json -Depth 10 -Compress);payload_encoding='string'}
    if (-not $result.routed) { throw 'Evento de teste sem binding de destino.' }
}
function Wait-QueuesDrained {
    $deadline = [DateTime]::UtcNow.AddSeconds(60)
    do {
        $pending = 0
        foreach ($queue in @('payments-order-placed-v1','catalog-payment-processed-v1','notifications-payment-processed-v1','notifications-user-created-v1')) {
            $state = Broker "queues/fcg/$queue"
            if ($null -eq $state.messages -or $state.messages -ne 0) { $pending++ }
        }
        if ($pending -eq 0) { return }
        Start-Sleep -Milliseconds 500
    } while ([DateTime]::UtcNow -lt $deadline)
    throw 'Filas de consumo não esvaziaram.'
}
try {
    foreach ($service in @('users','catalog','payments','notifications','postgres','rabbitmq')) { Wait-Deployment $service }
    $replicas = ((Invoke-Kube get deployment rabbitmq -o json) | ConvertFrom-Json).spec.replicas
    if ($replicas -ne 1) { throw 'Validação requer RabbitMQ local com uma réplica.' }
    $mode = ((Invoke-Kube get configmap payments-config -o json) | ConvertFrom-Json).data.PaymentSimulation__Outcome
    if ($mode -ne 'Approved') { throw 'Validação requer Payments em Approved; não altera o modo existente.' }
    $settings = Get-KubernetesSettings
    $brokerHeaders = @{Authorization='Basic ' + [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes('fcg_local:' + $settings['RABBITMQ_PASSWORD']))}
    Start-ApiForwards
    $login = Invoke-RestMethod "$usersUrl/api/auth/login" -Method Post -ContentType 'application/json' -Body (@{email=$settings['BOOTSTRAP_EMAIL'];password=$settings['BOOTSTRAP_PASSWORD']} | ConvertTo-Json)
    $adminHeaders = @{Authorization="Bearer $($login.accessToken)"}
    $game = Invoke-RestMethod "$catalogUrl/api/games" -Headers $adminHeaders -Method Post -ContentType 'application/json' -Body (@{name=('Resiliencia G8 ' + [Guid]::NewGuid().ToString('N'));price=59.90} | ConvertTo-Json)
    $gameId = ([Guid]$game.id).ToString()
    $brokerStopped = $true
    Invoke-Kube scale deployment/rabbitmq --replicas=0
    Invoke-Kube wait --for=delete pod -l app=rabbitmq --timeout=90s
    $email = 'g8-' + [Guid]::NewGuid().ToString('N') + '@example.com'
    $password = 'Aa1!' + [Guid]::NewGuid().ToString('N')
    $response = Invoke-WebRequest "$usersUrl/api/users" -Method Post -ContentType 'application/json' -Body (@{name='Resiliencia G8';email=$email;password=$password} | ConvertTo-Json) -UseBasicParsing
    if ($response.StatusCode -ne 201) { throw 'Cadastro sem broker não retornou 201.' }
    $userId = ([Guid](($response.Content | ConvertFrom-Json).id)).ToString()
    $login = Invoke-RestMethod "$usersUrl/api/auth/login" -Method Post -ContentType 'application/json' -Body (@{email=$email;password=$password} | ConvertTo-Json)
    $headers = @{Authorization="Bearer $($login.accessToken)"}
    $http = New-Object System.Net.Http.HttpClient
    $http.DefaultRequestHeaders.Authorization = New-Object System.Net.Http.Headers.AuthenticationHeaderValue('Bearer', $login.accessToken)
    $contents = @(); $responses = @()
    try {
        $tasks = @(1..8 | ForEach-Object {
            $content = New-Object System.Net.Http.StringContent((@{gameId=$gameId} | ConvertTo-Json),[Text.Encoding]::UTF8,'application/json')
            $contents += $content
            $http.PostAsync("$catalogUrl/api/orders", $content)
        })
        $responses = @($tasks | ForEach-Object { $_.GetAwaiter().GetResult() })
        $accepted = @($responses | Where-Object { [int]$_.StatusCode -eq 202 })
        $conflicts = @($responses | Where-Object { [int]$_.StatusCode -eq 409 })
        if ($accepted.Count -ne 1 -or $conflicts.Count -ne 7) { throw 'Concorrência não produziu um aceite e sete conflitos.' }
        $order = $accepted[0].Content.ReadAsStringAsync().GetAwaiter().GetResult() | ConvertFrom-Json
        if ($order.status -ne 'Pending') { throw 'Pedido sem broker não permaneceu Pending.' }
        $orderId = ([Guid]$order.orderId).ToString()
    } finally { foreach ($item in $responses) { $item.Dispose() }; foreach ($item in $contents) { $item.Dispose() }; $http.Dispose() }
    $userOutbox = 'SELECT count(*) FROM "OutboxMessage" WHERE "Body" LIKE ''%{0}%'';' -f $userId
    $orderOutbox = 'SELECT count(*) FROM "OutboxMessage" WHERE "Body" LIKE ''%{0}%'';' -f $orderId
    Wait-Sql users $userOutbox '1'; Wait-Sql catalog $orderOutbox '1'
    $librarySql = 'SELECT count(*) FROM "Library" WHERE "OrderId" = ''{0}'';' -f $orderId
    Wait-Sql catalog $librarySql '0'
    Stop-Forwards
    foreach ($service in @('users','catalog')) { Invoke-Kube rollout restart "deployment/$service"; Wait-Deployment $service }
    Start-ApiForwards
    Wait-Sql users $userOutbox '1'; Wait-Sql catalog $orderOutbox '1'
    $detail = Invoke-RestMethod "$catalogUrl/api/orders/$orderId" -Headers $headers
    if ($detail.status -ne 'Pending') { throw 'Pedido mudou antes de recuperar o broker.' }
    Invoke-Kube scale deployment/rabbitmq --replicas=1
    Wait-Deployment rabbitmq
    $brokerStopped = $false
    Wait-Sql users $userOutbox '0'; Wait-Sql catalog $orderOutbox '0'
    Wait-Sql catalog $librarySql '1'
    $paymentSql = 'SELECT count(*) FROM "Payments" WHERE "OrderId" = ''{0}'';' -f $orderId
    $noticeSql = 'SELECT count(*) FROM "Notifications" WHERE "SubjectId" = ''{0}'' AND "State" = ''Emitted'';' -f $orderId
    Wait-Sql payments $paymentSql '1'; Wait-Sql notifications $noticeSql '1'
    Wait-Sql notifications ('SELECT count(*) FROM "Notifications" WHERE "SubjectId" = ''{0}'' AND "State" = ''Emitted'';' -f $userId) '1'
    Forward rabbitmq '15682:15672'
    $deadline = [DateTime]::UtcNow.AddSeconds(30)
    do { try { $null = Broker 'overview'; break } catch { if ([DateTime]::UtcNow -ge $deadline) { throw }; Start-Sleep -Milliseconds 300 } } while ($true)
    if ($script:forwards[-1].HasExited) { throw 'Port-forward RabbitMQ não ficou ativo.' }
    $replayId = [Guid]::NewGuid().ToString()
    $replay = @{eventId=$replayId;occurredAt=[DateTime]::UtcNow.ToString('o');orderId=$orderId;userId=$userId;gameId=$gameId;price=59.9;currency='BRL'}
    1..3 | ForEach-Object { Publish-Event OrderPlacedEvent $replay }
    Wait-Sql payments ('SELECT count(*) FROM "OrderReceipts" WHERE "EventId" = ''{0}'';' -f $replayId) '1'
    $payment = Read-Sql payments ('SELECT row_to_json(p) FROM "Payments" p WHERE "OrderId" = ''{0}'';' -f $orderId) | ConvertFrom-Json
    $resultId = [Guid]::NewGuid().ToString()
    $result = @{eventId=$resultId;occurredAt=[DateTime]::UtcNow.ToString('o');orderId=$orderId;paymentId=$payment.Id;userId=$userId;gameId=$gameId;price=59.9;currency='BRL';status='Approved'}
    1..3 | ForEach-Object { Publish-Event PaymentProcessedEvent $result }
    Wait-Sql catalog ('SELECT count(*) FROM "PaymentReceipts" WHERE "EventId" = ''{0}'';' -f $resultId) '1'
    Wait-Sql notifications ('SELECT count(*) FROM "EventReceipts" WHERE "EventId" = ''{0}'';' -f $resultId) '1'
    # Mesmo EventId em uma nova representação monetária: não deve gerar falso conflito.
    $result.price = [decimal]59.90
    Publish-Event PaymentProcessedEvent $result
    $invalidOrderId = [Guid]::NewGuid().ToString()
    $invalidEventId = [Guid]::NewGuid().ToString()
    Publish-Event OrderPlacedEvent @{eventId=$invalidEventId;occurredAt=[DateTime]::UtcNow.ToString('o');orderId=$invalidOrderId;userId=$userId;gameId=$gameId;price=-1;currency='BRL'}
    $deadline = [DateTime]::UtcNow.AddSeconds(60)
    $found = $false
    do {
        try {
            $messages = Broker 'queues/fcg/payments-order-placed-v1_error/get' 'Post' @{count=100;ackmode='ack_requeue_true';encoding='auto'}
            $found = @($messages | Where-Object { ($_.payload | ConvertFrom-Json).message.eventId -eq $invalidEventId }).Count -eq 1
        } catch { if ($_.Exception.Response -and [int]$_.Exception.Response.StatusCode -ne 404) { throw } }
        if (-not $found) { Start-Sleep -Milliseconds 500 }
    } while (-not $found -and [DateTime]::UtcNow -lt $deadline)
    if (-not $found) { throw 'Mensagem inválida não encontrada na fila de erro (inspeção limitada a 100).' }
    Wait-QueuesDrained
    foreach ($queue in @('payments-order-placed-v1_error','catalog-payment-processed-v1_error','notifications-payment-processed-v1_error')) {
        try {
            $messages = Broker "queues/fcg/$queue/get" 'Post' @{count=100;ackmode='ack_requeue_true';encoding='auto'}
            foreach ($message in $messages) {
                $id = ($message.payload | ConvertFrom-Json).message.eventId
                if ($id -in @($replayId,$resultId)) { throw 'Replay válido foi encaminhado incorretamente à fila de erro.' }
            }
        } catch { if (-not $_.Exception.Response -or [int]$_.Exception.Response.StatusCode -ne 404) { throw } }
    }
    Wait-Sql payments ('SELECT count(*) FROM "Payments" WHERE "OrderId" = ''{0}'';' -f $invalidOrderId) '0'
    Wait-Sql payments ('SELECT count(*) FROM "OrderReceipts" WHERE "EventId" = ''{0}'';' -f $invalidEventId) '0'
    Wait-Sql payments $paymentSql '1'; Wait-Sql catalog $librarySql '1'; Wait-Sql notifications $noticeSql '1'
    $detail = Invoke-RestMethod "$catalogUrl/api/orders/$orderId" -Headers $headers
    if ($detail.status -ne 'Approved') { throw 'Resultado final divergente.' }
    [pscustomobject]@{UserId=$userId;OrderId=$orderId;ConcurrentAccepted=1;ConcurrentConflicts=7;OutboxesRecoveredAfterRestart=$true;Payments=1;LibraryEntries=1;PurchaseNotifications=1;OrderReplayEventId=$replayId;PaymentReplayEventId=$resultId;InvalidEventInErrorQueue=$invalidEventId} | ConvertTo-Json
} finally {
    try { if ($brokerStopped) { Invoke-Kube scale deployment/rabbitmq --replicas=1; Wait-Deployment rabbitmq } }
    finally { Stop-Forwards; Pop-Location }
}
