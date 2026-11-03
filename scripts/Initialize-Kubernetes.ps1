. "$PSScriptRoot/Kubernetes-Helpers.ps1"
$root = Split-Path $PSScriptRoot -Parent
$path = Join-Path $root '.env.k8s.local'
if (-not (Test-Path -LiteralPath $path)) {
    $namespace = Invoke-Kube get namespace fcg-phase2 --ignore-not-found -o name
    if ($namespace) {
        $existing = Invoke-Kube get secret postgres-secret --ignore-not-found -o name
        if ($existing) { throw '.env.k8s.local ausente, mas Secrets já existem. Recupere o arquivo original; não gerar novas senhas para PVCs existentes.' }
    }
    $lines = @('BOOTSTRAP_NAME=Administrador Kubernetes', 'BOOTSTRAP_EMAIL=admin@fcg.local')
    $random = [Security.Cryptography.RandomNumberGenerator]::Create()
    try {
        foreach ($key in @('POSTGRES_ADMIN_PASSWORD','USERS_DB_PASSWORD','CATALOG_DB_PASSWORD','PAYMENTS_DB_PASSWORD','NOTIFICATIONS_DB_PASSWORD','RABBITMQ_PASSWORD','JWT_KEY','BOOTSTRAP_PASSWORD')) {
            $bytes = New-Object byte[] 32
            $random.GetBytes($bytes)
            $value = [BitConverter]::ToString($bytes).Replace('-','').ToLowerInvariant()
            if ($key -eq 'BOOTSTRAP_PASSWORD') { $value = 'Aa1!' + $value }
            $lines += $key + '=' + $value
        }
        [IO.File]::WriteAllLines($path,$lines,(New-Object Text.UTF8Encoding($false)))
    } finally { $random.Dispose() }
}
$settings = Get-KubernetesSettings
foreach ($key in @('POSTGRES_ADMIN_PASSWORD','USERS_DB_PASSWORD','CATALOG_DB_PASSWORD','PAYMENTS_DB_PASSWORD','NOTIFICATIONS_DB_PASSWORD','RABBITMQ_PASSWORD','JWT_KEY','BOOTSTRAP_NAME','BOOTSTRAP_EMAIL','BOOTSTRAP_PASSWORD')) {
    if ([string]::IsNullOrWhiteSpace($settings[$key])) { throw "Configuração Kubernetes ausente: $key" }
}
Invoke-Kube apply -f "$root/k8s/namespace.yaml"
$postgres = @{POSTGRES_PASSWORD=$settings['POSTGRES_ADMIN_PASSWORD']}
foreach ($service in @('users','catalog','payments','notifications')) {
    $key = $service.ToUpperInvariant() + '_DB_PASSWORD'
    $postgres[$key] = $settings[$key]
    $title = [Globalization.CultureInfo]::InvariantCulture.TextInfo.ToTitleCase($service)
    $values = @{
        ('ConnectionStrings__' + $title)="Host=postgres;Port=5432;Database=fcg_$service;Username=fcg_$service;Password=$($settings[$key])"
        RabbitMq__Password=$settings['RABBITMQ_PASSWORD']
    }
    if ($service -in @('users','catalog')) { $values['Jwt__Key'] = $settings['JWT_KEY'] }
    if ($service -eq 'users') {
        $values['AdminBootstrap__Name']=$settings['BOOTSTRAP_NAME']
        $values['AdminBootstrap__Email']=$settings['BOOTSTRAP_EMAIL']
        $values['AdminBootstrap__Password']=$settings['BOOTSTRAP_PASSWORD']
    }
    Apply-PrivateSecret "$service-secret" $values
}
Apply-PrivateSecret 'postgres-secret' $postgres
Apply-PrivateSecret 'rabbitmq-secret' @{RABBITMQ_DEFAULT_PASS=$settings['RABBITMQ_PASSWORD']}
$config = kubectl --context docker-desktop --namespace fcg-phase2 create configmap postgres-init --from-file="10-services.sh=$root/postgres/init-services.sh" --dry-run=client -o json
if ($LASTEXITCODE -ne 0) { throw 'Falha ao preparar ConfigMap de provisionamento PostgreSQL.' }
$config | kubectl --context docker-desktop --namespace fcg-phase2 apply -f -
if ($LASTEXITCODE -ne 0) { throw 'Falha ao aplicar ConfigMap PostgreSQL.' }
Write-Output 'Configuração Kubernetes preparada; segredos locais preservados em .env.k8s.local ignorado.'
