# fiap-cloud-games-infrastructure

Contratos V1, documentação transversal e orquestração de PostgreSQL, RabbitMQ e serviços.

## Estado

G0 concluído. G1 entrega PostgreSQL/RabbitMQ no Compose, isolamento dos quatro bancos e testes .NET de contratos e infraestrutura. Ainda não há microsserviços, Outbox/Inbox ou manifests Kubernetes; essas capacidades pertencem aos próximos gates.

## Documentação

- [ADRs aceitos](docs/architecture/decisions/README.md).
- [Decisões funcionais confirmadas](docs/architecture/functional-decisions.md).
- [Contratos V1](docs/contracts/v1/README.md).
- [Matriz de migração](docs/architecture/migration-inventory.md).
- [Roadmap e critérios de aceite](docs/implementation/roadmap.md).
- [Validação G0](docs/quality/g0-validation.md).
- [Infraestrutura local e variáveis](docs/implementation/local-infrastructure.md).
- [Matriz de integração V1](docs/contracts/v1/integration-matrix.md).
- [Evidências G1](docs/quality/g1-validation.md).

## Execução e configuração

Com Docker Desktop iniciado e SDK .NET 8 instalado, execute na raiz:

```powershell
./scripts/Initialize-Local.ps1
docker compose config --quiet
docker compose up -d --wait --wait-timeout 180
./scripts/Validate-G1.ps1
```

O último comando executa testes e reinicia apenas os containers deste Compose para verificar persistência. PostgreSQL em localhost:55432, RabbitMQ em localhost:5672 e painel em localhost:15672. Credenciais aleatórias em .env ignorado; variáveis documentadas em .env.example. Nunca imprimir configuração expandida com segredos. Para parar sem apagar dados: `docker compose stop`.

Os projetos Producer.Contracts e Consumer.Contracts são fixtures independentes de teste, não bibliotecas compartilhadas pelos futuros serviços. Migrations de aplicações serão explícitas antes das APIs, a partir de G2. Não utilizar SQLite ou Kind.

## Git e segurança

Clone independente fornecido pelo responsável; manter o origin existente. Commits separados, sem push ou publicação de imagens sem autorização. Documentação técnica é versionada. AGENTS.md, specs/, .codex/ e docs/course/ são locais e ignorados; segredos fora do Git.
