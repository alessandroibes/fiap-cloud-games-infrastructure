# fiap-cloud-games-infrastructure

Contratos V1, documentação transversal e orquestração de PostgreSQL, RabbitMQ e serviços.

## Estado

G0–G6 concluídos nos respectivos repositórios. Os quatro microsserviços possuem implementação, testes e Dockerfiles. Este Compose integra as APIs, PostgreSQL e RabbitMQ, com fluxo de aprovação/rejeição e persistência validados. Kubernetes pertence ao G7.

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
- [Operação do Compose completo](docs/implementation/compose-complete.md).
- [Estado da validação G6](docs/quality/g6-validation.md).

## Execução e configuração

Com Docker Desktop iniciado e SDK .NET 8 instalado, execute na raiz:

```powershell
./scripts/Start-Local.ps1
./scripts/Validate-G6.ps1 -SkipStart
```

Mantenha os quatro clones de serviços ao lado deste clone, com seus nomes originais. Start-Local constrói imagens, inicia dependências, para APIs anteriores, executa migrations e bootstrap explicitamente e verifica readiness. Validate-G6 cria dados de demonstração, alterna o modo de pagamento e recria containers para verificar persistência. Execute sem outras compras em andamento. Veja efeitos, recuperação e comandos individuais no [guia](docs/implementation/compose-complete.md).

APIs em localhost:5081–5084, PostgreSQL em localhost:55432, RabbitMQ em localhost:5672 e painel em localhost:15672. Credenciais em .env ignorado; variáveis em .env.example. Nunca imprimir configuração expandida com segredos. Para parar sem apagar dados: `docker compose stop`. Depois da preparação explícita, `docker compose up --build` inicia a solução; não executa migrations no startup.

Os projetos Producer.Contracts e Consumer.Contracts são fixtures independentes de teste, não bibliotecas compartilhadas pelos serviços. Os testes G1 continuam disponíveis por `scripts/Validate-G1.ps1`; esse script reinicia PostgreSQL/RabbitMQ e deve rodar em janela sem outras validações. Não utilizar SQLite ou Kind.

## Git e segurança

Clone independente fornecido pelo responsável; manter o origin existente. Commits separados, sem push ou publicação de imagens sem autorização. Documentação técnica é versionada. AGENTS.md, specs/, .codex/ e docs/course/ são locais e ignorados; segredos fora do Git.
