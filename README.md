# fiap-cloud-games-infrastructure

Contratos V1, documentação transversal e orquestração de PostgreSQL, RabbitMQ e serviços.

## Estado

G0–G8 concluídos nos respectivos repositórios. Os quatro microsserviços possuem implementação, testes, Dockerfiles e manifestos /k8s. Compose e Kubernetes Docker Desktop executam os fluxos de aprovação/rejeição com persistência validada. G8 reexecutou 171 testes e validou recuperação de Outbox, concorrência e replay no cluster. G9 possui preparação documental; vídeo, dados acadêmicos e submissão ainda dependem do responsável.

## Repositórios

| Componente | Código e documentação |
|---|---|
| UsersAPI | [fiap-cloud-games-users](https://github.com/alessandroibes/fiap-cloud-games-users) |
| CatalogAPI | [fiap-cloud-games-catalog](https://github.com/alessandroibes/fiap-cloud-games-catalog) |
| PaymentsAPI | [fiap-cloud-games-payments](https://github.com/alessandroibes/fiap-cloud-games-payments) |
| NotificationsAPI | [fiap-cloud-games-notifications](https://github.com/alessandroibes/fiap-cloud-games-notifications) |
| Infraestrutura | [fiap-cloud-games-infrastructure](https://github.com/alessandroibes/fiap-cloud-games-infrastructure) |

Em um diretório vazio, clone os cinco repositórios como irmãos:

```powershell
git clone https://github.com/alessandroibes/fiap-cloud-games-users.git
git clone https://github.com/alessandroibes/fiap-cloud-games-catalog.git
git clone https://github.com/alessandroibes/fiap-cloud-games-payments.git
git clone https://github.com/alessandroibes/fiap-cloud-games-notifications.git
git clone https://github.com/alessandroibes/fiap-cloud-games-infrastructure.git
cd fiap-cloud-games-infrastructure
```

Não é necessário clonar a Fase 1 para executar a Fase 2. Cada clone tem histórico e build próprios.

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
- [Implantação Kubernetes Docker Desktop](docs/implementation/kubernetes-desktop.md).
- [Estado da validação G7](docs/quality/g7-validation.md).
- [Evidências de resiliência G8](docs/quality/g8-validation.md).
- [Recuperação e reprodução dos testes de falha](docs/implementation/recovery-runbook.md).
- [Visão técnica e diagrama](docs/architecture/system-overview.md).
- [Índice de evidências](docs/quality/evidence-index.md).
- [Preparação e pendências G9](docs/quality/g9-preparation.md).

## Execução e configuração

Com Docker Desktop iniciado e SDK .NET 8 instalado, execute na raiz:

```powershell
./scripts/Start-Local.ps1
./scripts/Validate-G6.ps1 -SkipStart
```

Mantenha os quatro clones de serviços ao lado deste clone, com seus nomes originais. Start-Local constrói imagens, inicia dependências, para APIs anteriores, executa migrations e bootstrap explicitamente e verifica readiness. Validate-G6 cria dados de demonstração, alterna o modo de pagamento e recria containers para verificar persistência. Execute sem outras compras em andamento. Veja efeitos, recuperação e comandos individuais no [guia](docs/implementation/compose-complete.md).

APIs em localhost:5081–5084, PostgreSQL em localhost:55432, RabbitMQ em localhost:5672 e painel em localhost:15672. Credenciais em .env ignorado; variáveis em .env.example. Nunca imprimir configuração expandida com segredos. Para parar sem apagar dados: `docker compose stop`. Depois da preparação explícita, `docker compose up --build` inicia a solução; não executa migrations no startup.

Os projetos Producer.Contracts e Consumer.Contracts são fixtures independentes de teste, não bibliotecas compartilhadas pelos serviços. Os testes G1 continuam disponíveis por `scripts/Validate-G1.ps1`; esse script reinicia PostgreSQL/RabbitMQ e deve rodar em janela sem outras validações. Não utilizar SQLite ou Kind.

## Kubernetes Docker Desktop

Com o cluster docker-desktop disponível e armazenamento de imagens compatível, execute na infraestrutura:

```powershell
./scripts/Start-Kubernetes.ps1
./scripts/Validate-G7.ps1 -SkipStart
kubectl --context docker-desktop -n fcg-phase2 get deployments,pods,services,pvc,jobs
```

Secrets são preparados a partir de .env.k8s.local ignorado. Bancos/PVCs e credenciais são independentes do Compose. Migrações e bootstrap ocorrem por Jobs explícitos antes das APIs. Os Services são internos; acesso manual por port-forward em 5181–5184, conforme o [guia completo](docs/implementation/kubernetes-desktop.md). `Validate-G8.ps1` adiciona indisponibilidade do broker e replay; veja efeitos e limites no [procedimento de recuperação](docs/implementation/recovery-runbook.md).

## Evidências e entrega

Os registros G0–G8 descrevem execuções reais e suas limitações; não representam vídeo gravado ou submissão acadêmica. Materiais pessoais da entrega ficam localmente em docs/course/, ignorados conforme a organização do projeto. Para avaliar a aplicação a partir dos clones, use os READMEs, contratos, manifestos, scripts e [índice de evidências](docs/quality/evidence-index.md), todos versionados.

## Git e segurança

Clone independente fornecido pelo responsável; manter o origin existente. Commits separados, sem push ou publicação de imagens sem autorização. Documentação técnica é versionada. AGENTS.md, specs/, .codex/ e docs/course/ são locais e ignorados; segredos fora do Git.
