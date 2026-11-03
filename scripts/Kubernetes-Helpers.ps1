$ErrorActionPreference = 'Stop'
function Invoke-Kube {
    kubectl --context docker-desktop --namespace fcg-phase2 @args
    if ($LASTEXITCODE -ne 0) { throw 'Comando Kubernetes falhou; contexto docker-desktop, namespace fcg-phase2.' }
}
function Get-KubernetesSettings {
    $settings = @{}
    foreach ($line in Get-Content -LiteralPath (Join-Path $PSScriptRoot '../.env.k8s.local')) {
        if ($line -and -not $line.StartsWith('#')) {
            $pair = $line.Split('=', 2)
            $settings[$pair[0]] = $pair[1]
        }
    }
    return $settings
}
function Wait-Deployment([string]$name) {
    Invoke-Kube rollout status "deployment/$name" --timeout=300s
}
function Apply-ApplicationManifest([string]$path, [string]$image) {
    $document = kubectl --context docker-desktop -n fcg-phase2 create --dry-run=client -f $path -o json
    if ($LASTEXITCODE -ne 0) { throw 'Manifesto de aplicação inválido.' }
    $resource = $document | ConvertFrom-Json
    $resource.spec.template.spec.containers[0].image = $image
    $resource | ConvertTo-Json -Depth 40 | kubectl --context docker-desktop -n fcg-phase2 apply -f -
    if ($LASTEXITCODE -ne 0) { throw 'Falha ao aplicar manifesto com imagem identificada por conteúdo.' }
}
function Apply-PrivateSecret([string]$name, [hashtable]$values) {
    # JSON somente em stdin; não enviar segredos em argumentos, arquivos YAML ou logs.
    $document = @{apiVersion='v1';kind='Secret';metadata=@{name=$name;namespace='fcg-phase2'};type='Opaque';stringData=$values}
    $document | ConvertTo-Json -Depth 6 -Compress | kubectl --context docker-desktop --namespace fcg-phase2 apply --server-side --field-manager=fcg-local-secrets -f -
    if ($LASTEXITCODE -ne 0) { throw 'Falha ao aplicar Secret local.' }
}
