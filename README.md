# fiap-cloud-games-infrastructure

Contratos V1, documentação transversal e orquestração de PostgreSQL, RabbitMQ e serviços.

## Estado

Preparação documental G0 em 30/10/2026. Ainda não há aplicação executável, Dockerfile ou manifests Kubernetes. Nenhum teste de aplicação foi executado. Os gates seguintes entregarão essas capacidades com evidências.

## Documentação

- [ADRs aceitos](docs/architecture/decisions/README.md).
- [Decisões funcionais confirmadas](docs/architecture/functional-decisions.md).
- [Contratos V1](docs/contracts/v1/README.md).
- [Matriz de migração](docs/architecture/migration-inventory.md).
- [Roadmap e critérios de aceite](docs/implementation/roadmap.md).
- [Validação G0](docs/quality/g0-validation.md).

## Execução e configuração

Comandos, variáveis, migrations, Docker e Kubernetes serão documentados quando implementados e verificados. PostgreSQL isolado por serviço persistente, RabbitMQ/MassTransit e Docker Desktop Kubernetes são decisões aprovadas. Migrations serão explícitas antes das APIs. Não utilizar SQLite ou Kind.

## Git e segurança

Clone independente fornecido pelo responsável; manter o origin existente. Commits separados, sem push ou publicação de imagens sem autorização. Documentação técnica é versionada. AGENTS.md, specs/, .codex/ e docs/course/ são locais e ignorados; segredos fora do Git.
