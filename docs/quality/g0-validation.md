# Evidências G0 — 30/10/2026

Preparação documental e organização local verificadas. G1–G9 permanecem planejados; não há aplicação implementada nem execução de testes .NET nesta etapa.

## Ambiente verificado

| Verificação executada | Resultado |
|---|---|
| dotnet --list-sdks (inspeção inicial) | SDK 8.0.414 instalado, além de 7/9/10 |
| git --version (inspeção inicial) | 2.45.0.windows.1 |
| docker compose version (inspeção inicial) | v2.28.1-desktop.1 |
| docker info --format '{{.ServerVersion}}' após ativação pelo responsável | Engine 29.9.2 acessível |
| kubectl config get-contexts | docker-desktop presente e ativo |
| kubectl --context docker-desktop get nodes --request-timeout=10s | desktop-control-plane Ready, v1.36.1 |

A primeira inspeção ocorreu antes da ativação do Docker/Kubernetes pelo responsável. A nova leitura substitui aquele impedimento. Estes resultados não comprovam deploy dos microsserviços.

## Git e documentos

- Cinco clones fornecidos pelo responsável, branch main e remoto origin preservados. Raiz do workspace sem .git.
- git rev-parse --show-toplevel executado em cada clone: raízes próprias.
- git check-ignore executado em cada clone para AGENTS.md, specs/roadmap-local.md, .codex/README.md, docs/course/teste.pdf e .env: cinco exclusões confirmadas por repositório. Os caminhos ilustrativos não foram criados.
- README.md e docs/architecture/decisions/ADR-P2-001.md não são ignorados.
- Comparação Get-FileHash: 35 cópias dos ADRs (sete por repositório) idênticas à baseline.
- Três contratos canônicos idênticos à baseline: exemplos convertidos com ConvertFrom-Json, campos conferidos, IDs convertíveis em Guid, datas terminadas em Z, preço numérico/BRL e status Approved/Rejected quando aplicáveis.
- git status --porcelain da Fase 1 sem saída; nenhuma escrita realizada na origem.

## Alcance da validação

A conferência dos contratos é documental: não substitui testes de serialização C#, validação de payloads inválidos ou identidade MassTransit. Esses testes pertencem a G1 e aos serviços efetivos. Sem migrations, build, dotnet test, deploy ou publicação nesta etapa.

Os documentos locais operacionais não entram nos commits. Correções na pasta-pai/baseline permanecem locais por não haver Git na raiz; documentação técnica necessária está nos clones, incluindo ADRs, especificações, matriz e decisões confirmadas.

## Próxima etapa

G1: Compose de PostgreSQL/RabbitMQ com credenciais locais não versionadas, isolamento e persistência; testes de contrato e documentação de inicialização. Não criar soluções dos quatro serviços antes da preparação e validação dessa dependência.
