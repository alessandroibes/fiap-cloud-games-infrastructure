# Infraestrutura local — G1

Este documento registra a implantação inicial do G1. Para a solução atual com quatro APIs e migrations explícitas, consulte [Compose completo](compose-complete.md). O Compose agora inclui serviços de aplicação: para iniciar apenas as dependências use `docker compose up -d --wait postgres rabbitmq`. As limitações ao final descrevem exclusivamente o escopo histórico do G1.

## Preparação

Pré-requisitos: SDK .NET 8.0.414 (ou patch compatível), Docker Desktop com engine Linux e Docker Compose. Executar na raiz deste repositório:

```powershell
./scripts/Initialize-Local.ps1
docker compose config --quiet
docker compose up -d --wait --wait-timeout 180 postgres rabbitmq
./scripts/Validate-G1.ps1
```

Se a política local impedir scripts, executar `powershell -NoProfile -ExecutionPolicy Bypass -File ./scripts/Validate-G1.ps1` somente para este processo. Não alterar a política global. O script valida, compila, testa e reinicia apenas postgres/rabbitmq deste Compose. Não remove volumes nem executa migrations de aplicações.

Initialize-Local cria .env com senhas independentes de 256 bits, sem imprimi-las; preserva valores existentes e acrescenta chaves novas necessárias ao G6. Reutiliza configuração JWT/bootstrap do Users local quando disponível. .env.example documenta chaves sem credenciais utilizáveis. Não usar `docker compose config` sem --quiet em logs compartilhados: a saída expandida contém segredos. Não versionar .env nem resultados brutos que contenham dados sensíveis.

## Endereços e credenciais

| Recurso | Host local | Dentro do Compose | Identidade |
|---|---|---|---|
| PostgreSQL | 127.0.0.1:55432 | postgres:5432 | Administrador fcg_admin; senha POSTGRES_ADMIN_PASSWORD |
| Users | mesmo servidor | mesmo servidor | Banco/usuário fcg_users; USERS_DB_PASSWORD |
| Catalog | mesmo servidor | mesmo servidor | Banco/usuário fcg_catalog; CATALOG_DB_PASSWORD |
| Payments | mesmo servidor | mesmo servidor | Banco/usuário fcg_payments; PAYMENTS_DB_PASSWORD |
| Notifications técnico | mesmo servidor | mesmo servidor | Banco/usuário fcg_notifications; NOTIFICATIONS_DB_PASSWORD |
| RabbitMQ AMQP | 127.0.0.1:5672 | rabbitmq:5672 | fcg_local, vhost fcg; RABBITMQ_PASSWORD |
| RabbitMQ painel | http://127.0.0.1:15672 | rabbitmq:15672 | Mesma identidade local |

Portas configuráveis por POSTGRES_PORT, RABBITMQ_PORT e RABBITMQ_MANAGEMENT_PORT em .env. Os testes leem esse arquivo sem expor valores. Não acessar bancos usando fcg_admin nas aplicações. Papéis dos serviços não têm superuser, createdb, createrole ou replication; PUBLIC não pode conectar nos bancos de negócio, postgres ou template1. Os papéis podem executar DDL no próprio banco para migrations explícitas. Não há tabelas compartilhadas ou FKs entre bancos.

## Persistência e reinício

Volumes nomeados postgres-data e rabbitmq-data, prefixados pelo projeto fiap-cloud-games. Hostname do RabbitMQ é estável para preservar seu diretório de dados. Os scripts de init PostgreSQL só rodam em volume vazio; mudar .env não altera senhas já armazenadas. Não apagar volumes para resolver divergência de senha: recuperar o .env original ou realizar rotação controlada. Não executar `down -v` sem decisão explícita de descarte.

Para parar preservando dados: `docker compose stop`. Para retomar: `docker compose up -d --wait`. Para observar estado: `docker compose ps`. O health PostgreSQL usa TCP para não aceitar o servidor temporário da inicialização. Testes verificam quatro conexões próprias, vinte conexões proibidas, senha incorreta e ausência de privilégios de cluster.

Os testes criam somente marcadores técnicos no schema g1_validation de cada banco e na fila g1-validation-persistence. A partir do G6, todas as mensagens de testes G1 usam o vhost exclusivo fcg_g1_tests, criado via API de gerenciamento com permissões para fcg_local, evitando interferência nas filas de aplicação do vhost fcg. O vhost permanece para a verificação de persistência. Após reinício, o modo G1_VERIFY_PERSISTENCE=1 verifica os marcadores sem recriar dados; consome a mensagem persistida. Não executar suítes simultâneas contra o mesmo ambiente técnico. O script completo semeia novamente para permitir repetição.

## Dependências e limites

MassTransit.RabbitMQ 8.5.8, Npgsql 8.0.8 e dependências de teste fixados com lockfile. Restore reproduzível por `dotnet restore --locked-mode`. Nenhum provedor EF foi selecionado neste gate; versões EF/Npgsql/MassTransit.EntityFrameworkCore serão compatibilizadas na implementação dos serviços.

As imagens no compose.yaml estão fixadas pelo digest efetivamente baixado e testado (PostgreSQL 17/bookworm e RabbitMQ 4.2.9-management). Atualizações de imagem devem ser explícitas e repetir a validação. Não usar tag flutuante sem revisão do digest.

G1 não sobe APIs, não cria migrations EF, não implementa Outbox/Inbox e não demonstra compra real. Kubernetes já disponível no ambiente será usado no G7.

Referências consultadas: [imagem PostgreSQL](https://hub.docker.com/_/postgres), [imagem RabbitMQ](https://hub.docker.com/_/rabbitmq), [MassTransit e identidade de mensagens](https://masstransit.io/documentation/configuration/serialization), [pacote MassTransit.RabbitMQ 8.5.8](https://www.nuget.org/packages/MassTransit.RabbitMQ/8.5.8).
