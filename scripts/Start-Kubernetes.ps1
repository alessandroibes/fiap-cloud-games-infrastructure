param([switch]$SkipBuild)
. "$PSScriptRoot/Kubernetes-Helpers.ps1"
$root = Split-Path $PSScriptRoot -Parent
Invoke-Kube get nodes
$status = docker desktop kubernetes status
if ($LASTEXITCODE -ne 0) { throw 'Docker Desktop Kubernetes indisponível.' }
$driver = docker info --format '{{json .DriverStatus}}'
if ($LASTEXITCODE -ne 0) { throw 'Engine Docker indisponível.' }
if (($status -match 'Mode:\s+kind') -and ($driver -notmatch 'io.containerd.snapshotter')) {
    throw 'O provisionador interno do Docker Desktop exige containerd image store. Habilite Use containerd for pulling and storing images antes de construir/deployar.'
}
$images = @{}
foreach ($service in @('users','catalog','payments','notifications')) {
    $repo = Join-Path $root "../fiap-cloud-games-$service"
    if (-not (Test-Path "$repo/k8s/migration-job.yaml")) { throw "Clone/manifests ausentes: $service" }
    if (-not $SkipBuild) {
        docker build -t "fiap-cloud-games-${service}:g7" $repo
        if ($LASTEXITCODE -ne 0) { throw "Build falhou: $service" }
    }
    $id = docker image inspect --format '{{.Id}}' "fiap-cloud-games-${service}:g7"
    if ($LASTEXITCODE -ne 0 -or $id -notmatch '^sha256:[a-f0-9]{64}$') { throw "Imagem local não encontrada: $service" }
    $images[$service] = "fiap-cloud-games-${service}:g7-" + $id.Substring(7)
    docker tag "fiap-cloud-games-${service}:g7" $images[$service]
    if ($LASTEXITCODE -ne 0) { throw 'Falha ao identificar imagem por conteúdo.' }
}
& "$PSScriptRoot/Initialize-Kubernetes.ps1"
# Pausa APIs existentes antes de alterar schemas; não remove Deployments nem PVCs.
foreach ($service in @('users','catalog','payments','notifications')) {
    $existing = Invoke-Kube get deployment $service --ignore-not-found -o name
    if ($existing) { Invoke-Kube scale "deployment/$service" --replicas=0 }
}
foreach ($service in @('users','catalog','payments','notifications')) {
    Invoke-Kube wait --for=delete pod -l "app=$service" --timeout=90s
}
Invoke-Kube apply -f "$root/k8s/postgres.yaml"
Invoke-Kube apply -f "$root/k8s/rabbitmq.yaml"
Wait-Deployment 'postgres'
Wait-Deployment 'rabbitmq'
foreach ($service in @('users','catalog','payments','notifications')) {
    $dir = Join-Path $root "../fiap-cloud-games-$service/k8s"
    Invoke-Kube apply -f "$dir/configmap.yaml"
    Invoke-Kube delete job "$service-migrate" --ignore-not-found --wait=true
    Apply-ApplicationManifest "$dir/migration-job.yaml" $images[$service]
    Invoke-Kube wait --for=condition=complete "job/$service-migrate" --timeout=200s
}
Invoke-Kube delete job users-bootstrap --ignore-not-found --wait=true
Apply-ApplicationManifest "$root/../fiap-cloud-games-users/k8s/bootstrap-job.yaml" $images['users']
Invoke-Kube wait --for=condition=complete job/users-bootstrap --timeout=200s
foreach ($service in @('users','catalog','payments','notifications')) {
    $dir = Join-Path $root "../fiap-cloud-games-$service/k8s"
    Invoke-Kube apply -f "$dir/service.yaml"
    Apply-ApplicationManifest "$dir/deployment.yaml" $images[$service]
}
foreach ($service in @('users','catalog','payments','notifications')) { Wait-Deployment $service }
Invoke-Kube get 'deployments,pods,services,pvc,jobs'
