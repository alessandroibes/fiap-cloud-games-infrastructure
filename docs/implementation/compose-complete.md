# Compose completo — G6

## Pré-requisitos e configuração

Docker Desktop iniciado com engine Linux, Docker Compose V2 e PowerShell. SDK .NET 8 necessário para testes .NET, não para builds Docker. Os clones independentes devem estar no mesmo diretório:

```text
repositorios/
  fiap-cloud-games-infrastructure/
  fiap-cloud-games-users/
  fiap-cloud-games-catalog/
  fiap-cloud-games-payments/
  fiap-cloud-games-notifications/
```

Na infraestrutura, execute `./scripts/Initialize-Local.ps1`. O script cria segredos aleatórios somente para chaves ausentes; preserva valores existentes. Se houver `.env` no Users, importa JWT e bootstrap para manter a instalação anterior. Em clones novos não depende desses arquivos. Valores vazios são erro: não copie `.env.example` como configuração final sem preenchimento. A inicialização pode ser repetida sem rotacionar credenciais. Arquivos `.env` dos serviços não são alterados nem usados pelo Compose central.

| Variáveis | Uso |
|---|---|
| POSTGRES_ADMIN_PASSWORD | Provisionamento inicial; nunca usado pelas APIs |
| USERS_DB_PASSWORD, CATALOG_DB_PASSWORD, PAYMENTS_DB_PASSWORD, NOTIFICATIONS_DB_PASSWORD | Credencial independente de cada banco lógico |
| RABBITMQ_PASSWORD | Usuário local fcg_local, vhost fcg |
| JWT_KEY, JWT_ISSUER, JWT_AUDIENCE | Users emite e Catalog valida JWT; chave externa com pelo menos 32 bytes |
| BOOTSTRAP_NAME, BOOTSTRAP_EMAIL, BOOTSTRAP_PASSWORD | Administrador inicial; bootstrap não substitui administrador existente |
| PAYMENT_OUTCOME | Approved por padrão ou Rejected; afeta novos pagamentos |
| USERS_PORT, CATALOG_PORT, PAYMENTS_PORT, NOTIFICATIONS_PORT | HTTP 5081, 5082, 5083, 5084 por padrão |
| POSTGRES_PORT, RABBITMQ_PORT, RABBITMQ_MANAGEMENT_PORT | 55432, 5672, 15672 por padrão |

Portas vinculadas apenas a 127.0.0.1. Variáveis do processo prevalecem sobre `.env`, conforme Compose. Evite overrides inadvertidos; não imprima `docker compose config` expandido. Alterar senhas no arquivo não altera credenciais já persistidas: recuperar os valores originais ou planejar rotação controlada. Não apagar volumes para corrigir autenticação.

## Inicialização e atualização

Na raiz da infraestrutura:

```powershell
./scripts/Start-Local.ps1
docker compose ps
```

O script valida os clones e a configuração, constrói os quatro Dockerfiles multi-stage, inicia PostgreSQL/RabbitMQ e aguarda seus health checks. Para os containers dos projetos individuais `fcg-{serviço}-local` identificados pelos labels exatos do Compose, mantendo-os e preservando volumes. Para também as APIs centrais antes de executar DDL. Executa sequencialmente os comandos explícitos:

```powershell
docker compose run --rm --no-deps users --migrate
docker compose run --rm --no-deps catalog --migrate
docker compose run --rm --no-deps payments --migrate
docker compose run --rm --no-deps notifications --migrate
docker compose run --rm --no-deps users --bootstrap
docker compose up -d --wait --wait-timeout 180
```

Os comandos usam a mesma imagem e o banco próprio do serviço; não publicam portas nem iniciam a API. Bootstrap é idempotente, e migrations já aplicadas não são reaplicadas. O script termina após HTTP 200 em `/health/ready` das quatro APIs. O `--wait` do Compose verifica dependências e containers em execução; a verificação HTTP adicional confirma schemas disponíveis. Readiness das APIs não comprova disponibilidade do broker ou fluxo de negócio.

Depois da preparação explícita, `docker compose up --build` inicia a solução completa em primeiro plano. Não há migration automática no startup. Para atualizar código/schema, execute Start-Local novamente em janela sem compras: há indisponibilidade local. `-SkipBuild` reutiliza imagens previamente construídas; não usar após alteração de código sem rebuild.

Se uma migration falhar, o script interrompe antes de iniciar as APIs; elas podem permanecer paradas. Corrija a causa e repita Start-Local. Os containers e volumes anteriores não são removidos. Para voltar à orquestração individual, pare as quatro APIs centrais antes de iniciar os Compose individuais, preservando PostgreSQL/RabbitMQ centrais. Nunca mantenha orquestrações concorrentes dos mesmos serviços.

## Validação integrada

```powershell
./scripts/Validate-G6.ps1 -SkipStart
```

Sem `-SkipStart`, também executa Start-Local. A validação cria usuário e dois jogos identificados por GUID, exige cadastro 201, login JWT, boas-vindas duráveis, compra 202/Pending, aprovação com uma entrada na biblioteca, rejeição sem entrada nem notificação e novo pedido aprovado após rejeição. Confere logs de boas-vindas/confirmação por identidade lógica, não promete exactly-once físico. Consulta somente dados técnicos do Notifications por comando administrativo de teste; aplicações não acessam bancos alheios.

O teste altera temporariamente PAYMENT_OUTCOME no processo e recria Payments a cada modo. Restaura o valor anterior em finally. Execute sem outras compras concorrentes. Depois recria os containers das dependências e APIs, preservando os mesmos volumes e verificando novamente pedidos, biblioteca e registros de notificações. As credenciais de bootstrap devem corresponder ao administrador já persistido. Dados de demonstração permanecem; não há limpeza destrutiva. A saída final contém somente IDs e resultados, nunca JWT ou senhas.

O teste central não substitui os testes de concorrência, contratos, falha após commit e deduplicação dos serviços. Evidências e pendências efetivas constam no [registro G6](../quality/g6-validation.md).

`./scripts/Validate-G1.ps1` executa a regressão de contratos, isolamento PostgreSQL e persistência. Seus eventos usam o vhost exclusivo fcg_g1_tests, provisionado pelo teste via API de gerenciamento. Reinicia as dependências, portanto execute fora de compras ou outras suítes em andamento.

## Operação e persistência

```powershell
docker compose stop
docker compose up -d
docker compose logs --tail 50 notifications
```

Projeto `fiap-cloud-games`, rede `fiap-cloud-games_default`, volumes `fiap-cloud-games_postgres-data` e `fiap-cloud-games_rabbitmq-data` preservados do G1. Hostname estável do RabbitMQ. Não executar `down -v`. Serviços usam DNS postgres/rabbitmq e credenciais próprias, sem dependências de banco entre APIs. A mudança do health check RabbitMQ para usuário rabbitmq evita criar cookie Erlang pertencente a root.

Pagamentos e notificações só expõem health checks; endpoints funcionais estão em Users e Catalog. A ausência de autenticação nos health checks locais não permite envio de pagamentos ou notificações. Kubernetes Docker Desktop e probes pertencem ao G7.
