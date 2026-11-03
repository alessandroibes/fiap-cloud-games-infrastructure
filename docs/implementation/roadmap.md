# Roadmap G0–G9 e critérios de aceite

Execução incremental autorizada; commits separados por repositório; sem push/publicação sem autorização. Decisões funcionais em [registro próprio](../architecture/functional-decisions.md).

| Gate | Entrega | Aceite |
|---|---|---|
| G0 | Git, READMEs, baseline, matriz e decisões | Cinco raízes Git; arquivos locais ignorados; ADRs preservados; contratos conferidos; origem intacta |
| G1 | PostgreSQL/RabbitMQ, Compose inicial e testes de contrato | Configuração sem segredos; isolamento de bancos; dependências saudáveis; JSON e identidade MassTransit compatíveis |
| G2 | Users, JWT, Outbox e Dockerfile | G1; testes cadastro/login/admin; evento atômico; falha do broker recuperável |
| G3 | Catalog, CRUD, pedidos, biblioteca e Dockerfile | G1/G2; 202/Pending; proprietário autorizado; concorrência e duplicidade protegidas |
| G4 | Payments, Inbox/Outbox e Dockerfile | G1/G3; resultado único por OrderId; Approved/Rejected; reentrega e conflito |
| G5 | Notifications e Dockerfile | G1/G2/G4; boas-vindas, confirmação Approved, deduplicação lógica e recuperação |
| G6 | Compose completo | G2–G5; cadastro e compras Approved/Rejected ponta a ponta, persistência em volumes |
| G7 | /k8s por serviço | G6; Docker Desktop Kubernetes, Deployments/Services/ConfigMaps/Secrets/PVCs/probes e fluxos |
| G8 | Resiliência e revisão | Broker indisponível, reinício, falha após commit, concorrência, inválidos e fila de erro |
| G9 | Entrega acadêmica | READMEs, checklist, roteiro <=20 min e relatório com dados/URLs reais solicitados ao responsável |

Dockerfile multi-stage e .dockerignore em G2–G5, antes de G6. /k8s no G7. G2 verifica publicação; boas-vindas ponta a ponta dependem de G5/G6. G1 valida contratos isolados; repetir nos tipos efetivos dos serviços.

## Qualidade transversal

- .NET 8; separação domínio/aplicação/infraestrutura/API quando apropriado.
- Restore/build/test com resultados registrados; integração real em PostgreSQL, nunca SQLite.
- Sem dependência de banco alheio; credenciais/contextos/migrations próprios; migrations explícitas antes das APIs.
- Estado e Outbox atômicos; Inbox, restrições únicas, retries finitos e filas de erro.
- Contratos locais, namespace aprovado, JSON camelCase, GUID, UTC, decimal BRL e identidade MassTransit testados.
- Approved concede/confirma uma vez logicamente; Rejected não concede/confirma; eventos conflitantes não revertem estado terminal.
- JWT, papéis, autorização por proprietário e logs sem segredos.
- Não marcar requisito validado por documentação apenas. Evidências em [G0](../quality/g0-validation.md), [G1](../quality/g1-validation.md) e nos registros G2–G5 dos respectivos serviços. [G6](../quality/g6-validation.md) e [G7](../quality/g7-validation.md) concluídos; G8–G9 planejados.

## Progresso consolidado

G2 Users (`b3ca6dc`), G3 Catalog (`bc80da6`), G4 Payments (`b841965`) e G5 Notifications (`43f7cd1`) concluídos em commits independentes, conforme registros de validação de cada repositório. Suas suítes completas não foram reexecutadas neste gate. G6 concluiu orquestração central e teste de cadastro, boas-vindas, Approved, Rejected, nova tentativa, confirmação e persistência após recriação de containers, além da regressão G1 com mensageria isolada. G7 concluiu a implantação Kubernetes Docker Desktop com Jobs explícitos, probes, Secrets, PVCs e fluxo integrado validado após substituição dos pods. Próximo gate: G8, resiliência e revisão.
