# Evidências G1 — 30/10/2026

G1 concluído no ambiente local Windows/PowerShell, SDK .NET 8.0.414, Docker Engine 29.9.2 e Compose v5.6.1. Somente o repositório de Infraestrutura foi alterado. Nenhuma migration de aplicação, push ou implantação Kubernetes foi executada.

## Comandos e resultados observados

| Comando | Resultado |
|---|---|
| docker compose config --quiet | Configuração válida, sem exibir segredos |
| docker compose up -d --wait --wait-timeout 180 | PostgreSQL e RabbitMQ healthy |
| dotnet restore FiapCloudGames.Infrastructure.sln --locked-mode | Sucesso |
| dotnet build FiapCloudGames.Infrastructure.sln --no-restore | Sucesso, zero avisos e erros |
| dotnet test ... --no-build --filter Category!=Infrastructure | 6 aprovados, zero falhas/ignorados |
| scripts/Validate-G1.ps1: suíte completa | 38 aprovados, zero falhas/ignorados |
| Mesmo script: reinício postgres/rabbitmq e filtro Phase=Persistence | 5 aprovados, zero falhas/ignorados |

O script completo foi executado com `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/Validate-G1.ps1`. Evidências brutas locais: tests/Contracts.Tests/TestResults/g1-contracts.trx, g1-full.trx e g1-persistence.trx (ignoradas pelo Git). O comando reproduzível é mantido no repositório; não confundir esses resultados com testes dos microsserviços ainda inexistentes.

## Cobertura efetiva

- Seis casos de estrutura/compatibilidade dos três eventos: tabelas Markdown versus tipos de propriedades; exemplos JSON; nomes camelCase; decimal numérico; UTC; campos obrigatórios ausentes rejeitados; URN MassTransit igual em dois assemblies distintos.
- Vinte combinações usuário/banco proibidas: acesso negado com SQLSTATE 42501, incluindo banco alheio e bancos administrativos postgres/template1.
- Quatro bancos próprios permitem DDL transacional, sem privilégios de superuser/createdb/createrole/replication; senha errada rejeitada com 28P01.
- Dois cenários reais RabbitMQ (Approved/Rejected): publicador e consumidores usam contratos de assemblies separados e duas instâncias de bus no mesmo processo de teste; os três eventos atravessam o broker e pagamento alcança Catalog e Notifications em filas independentes.
- Quatro marcadores PostgreSQL persistidos e uma mensagem RabbitMQ persistente em fila durável; os cinco foram encontrados após reinício, sem recriação no modo de verificação.

## Reprodutibilidade e limites

compose.yaml fixa os digests efetivamente usados:

- PostgreSQL: sha256:839fbb5a4942a7758dd93e18b42ea5649807491a0545b5eeeb8f0b8bb11857a5.
- RabbitMQ: sha256:d1fb8b38bd0805935907a22b2b7483fba38c9a8dd7e8a74bfba4a6e7a9e91707.

Credenciais aleatórias apenas no .env ignorado. Imagens baixadas, não publicadas. Containers e volumes permanecem disponíveis localmente; o script de validação não remove volumes.

Não demonstrado neste gate: transações Outbox/Inbox, idempotência de negócio, JWT/autorização, migrações EF, quatro processos de aplicação, compras reais, resiliência de consumidores de negócio ou deploy Kubernetes. As fixtures não são contratos de produção compartilhados; repetir a compatibilidade nos tipos locais dos serviços. O marcador técnico não é dado de usuário ou migration de negócio.

Próximo gate: G2, UsersAPI com PostgreSQL, cadastro normalizado, JWT, administração/bootstrap e publicação transacional de UserCreatedEvent.
