# Kubernetes do Docker Desktop — G7

## Ambiente e limites

Usar exclusivamente contexto `docker-desktop`, namespace `fcg-phase2`. Não instalar Kind, criar outro cluster nem executar reset. Docker Desktop pode usar um provisionador interno chamado kind; isso não é um cluster separado gerenciado por CLI Kind. Neste ambiente, esse provisionador exige **Settings > General > Use containerd for pulling and storing images**. Após aplicar, aguardar engine e Kubernetes ficarem disponíveis. A troca de armazenamento pode ocultar imagens/containers clássicos sem apagá-los; os dados do Compose não são migrados para Kubernetes.

Referência: [Kubernetes integrado do Docker Desktop](https://docs.docker.com/desktop/use-desktop/kubernetes/). O script verifica o armazenamento quando o provisionador interno é kind e interrompe antes de alterar workloads se incompatível. Não faz mudanças nas configurações globais do Docker Desktop.

Pré-requisitos: Docker Desktop com cluster saudável, kubectl, PowerShell, cinco clones irmãos completos, conectividade para obter imagens base e storage class padrão com provisionamento dinâmico. SDK .NET não é necessário para o deploy por imagens. Para inspecionar:

```powershell
kubectl --context docker-desktop get nodes
kubectl --context docker-desktop get storageclass
docker desktop kubernetes status
```

## Configuração e deploy

Na raiz da infraestrutura:

```powershell
./scripts/Start-Kubernetes.ps1
```

O script constrói as quatro imagens locais com tag `g7`, cria tags `g7-<SHA256 da imagem>` e usa essas referências nos Jobs e Deployments. Assim uma imagem reconstruída não reutiliza a tag anterior no cache do nó. Os YAMLs mantêm a tag base como template; a substituição ocorre em memória, sem alterar os arquivos. Prepara Secrets/ConfigMaps, pausa APIs existentes, aplica dependências e espera readiness, executa os quatro Jobs de migration, executa bootstrap Users e implanta APIs. Em atualização há indisponibilidade local intencional para evitar DDL concorrente. `-SkipBuild` só é apropriado quando as imagens corretas já estão disponíveis. Não publicar imagens nem executar push para cumprir esta sequência.

Cada serviço mantém seu próprio `/k8s`: ConfigMap, Deployment, Service e migration-job; Users também possui bootstrap-job. Os manifests de dependências e namespace ficam neste repositório. O script reaproveita `postgres/init-services.sh` em ConfigMap, sem duplicar a definição dos quatro bancos e papéis. Não usar `apply -f` recursivo nos diretórios dos serviços: isso iniciaria Jobs e APIs sem ordenação.

`.env.k8s.local` é gerado localmente com senhas aleatórias, separado de `.env` do Compose. Não versionar ou compartilhar. Contém POSTGRES_ADMIN_PASSWORD, USERS_DB_PASSWORD, CATALOG_DB_PASSWORD, PAYMENTS_DB_PASSWORD, NOTIFICATIONS_DB_PASSWORD, RABBITMQ_PASSWORD, JWT_KEY, BOOTSTRAP_NAME, BOOTSTRAP_EMAIL e BOOTSTRAP_PASSWORD. Se o arquivo desaparecer e os Secrets já existirem, a inicialização falha para impedir rotação acidental. Recupere a configuração original; não apague PVCs para corrigir senha.

Secrets são enviados em JSON por stdin, sem valores em argumentos ou YAMLs versionados. Um Secret por aplicação, com conexão apenas do banco próprio e credencial RabbitMQ. Users/Catalog recebem chave JWT; Users recebe bootstrap. PostgreSQL usa seu Secret administrativo e as senhas dos papéis somente no provisionamento; nenhuma API usa fcg_admin. Kubernetes Secret não é um cofre e exige controle do acesso administrativo ao cluster.

ConfigMaps incluem DNS postgres/rabbitmq, porta AMQP 5672, vhost fcg, usuário fcg_local, HTTP 8080, issuer/audience JWT e modo de simulação Approved. Payments/Notifications não recebem JWT. Secrets/configuração injetados por ambiente exigem recriação do pod após alteração.

## Persistência e saúde

PostgreSQL usa PVC postgres-data de 2Gi; RabbitMQ usa rabbitmq-data de 1Gi. Ambos usam a storage class padrão, uma réplica e Recreate. PostgreSQL provisiona bancos só em volume vazio. Hostname RabbitMQ estável `rabbitmq` e nodename `rabbit@rabbitmq` preservam identidade entre pods. PVCs são independentes dos volumes Compose. Não remover namespace ou PVCs como parte de reinício; não executar reset do cluster para recuperar aplicação.

APIs usam UID/GID 1654, capabilities removidas, sem token Kubernetes, requests de 100m/128Mi e limits de 1 CPU/512Mi. Dependências possuem recursos próprios; esta implantação local não oferece alta disponibilidade. Recreate simplifica as atualizações locais; escalabilidade e rollout sem indisponibilidade não foram afirmados.

Startup/liveness das APIs usam `/health/live`; readiness usa `/health/ready` para banco e migrations. O broker pode estar indisponível mesmo com readiness HTTP: testar o fluxo assíncrono. Dependências possuem probes próprias. Jobs têm deadline e não retentam indefinidamente. Em falha, inspecione o Job e corrija a causa; Start-Kubernetes recria somente os Jobs anteriores e preserva PVCs. APIs podem permanecer paradas após falha; repetir o script após correção.

## Acesso e validação

Todos os Services são ClusterIP; comunicação interna via nomes DNS. Para acesso manual, execute em terminais separados:

```powershell
kubectl --context docker-desktop -n fcg-phase2 port-forward service/users 5181:8080 --address 127.0.0.1
kubectl --context docker-desktop -n fcg-phase2 port-forward service/catalog 5182:8080 --address 127.0.0.1
```

Para validar automaticamente:

```powershell
./scripts/Validate-G7.ps1 -SkipStart
```

O teste abre port-forwards locais em 5181–5184, encerrados em finally, e exige portas livres. Cria usuário e jogos de demonstração, testa boas-vindas, 202/Pending com Payments parado e sem concessão antecipada, aprovação após retomada, rejeição sem concessão/confirmação e nova tentativa aprovada. Alterna temporariamente Payments por ConfigMap e rollout, restaurando modo anterior ao finalizar. Não executar compras concorrentes durante a validação. Recria pods das dependências/APIs via Deployments e confere persistência em PVCs. Não remove dados de demonstração. Logs de port-forward ficam em `tests/TestResults/k8s/`, ignorado pelo Git.

Consultas administrativas ao banco técnico Notifications pertencem ao teste; não há acesso entre bancos pelas aplicações. Identidade lógica de notificação é única, mas o console pode repetir fisicamente após falha entre emissão e commit. Scripts completos dos serviços e G8 cobrem falhas específicas.

Inspeção sem segredos:

```powershell
kubectl --context docker-desktop -n fcg-phase2 get deployments,pods,services,pvc,jobs
kubectl --context docker-desktop -n fcg-phase2 logs job/users-migrate
kubectl --context docker-desktop -n fcg-phase2 logs deployment/notifications --tail=30
```

Resultados executados, falhas e limitações em [G7](../quality/g7-validation.md). Não exportar Secrets ou ambientes dos pods como evidência.
