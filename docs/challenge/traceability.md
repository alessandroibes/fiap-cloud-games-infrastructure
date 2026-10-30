# Matriz de Rastreabilidade — Fase 2

## Estados

- `Planejado`: requisito identificado, implementação/evidência ainda não concluída.
- `Em implementação`: desenvolvimento iniciado.
- `Implementado`: artefato produzido, validação pendente.
- `Validado`: critério verificado com evidência.
- `Bloqueado`: impedimento concreto documentado.

> Estado inicial: todos `Planejado`. As referências `SPEC-*` e `ADR-*` legadas da matriz são identificadores lógicos. Os documentos efetivos estão em `docs/specifications/`, `docs/contracts/` e `docs/architecture/decisions/`. Os ADR-P2-001 a ADR-P2-007 estão **Aceitos**; os requisitos permanecem `Planejado` até implementação e validação.

| ID | Responsável | Artefato/contrato previsto | Evidência prevista | Status |
|---|---|---|---|---|
| FR-201 | UsersAPI | SPEC-USERS, ADR-P2-007 | Testes de cadastro/login/autorização | Planejado |
| FR-202 | CatalogAPI | SPEC-CATALOG | Testes de CRUD | Planejado |
| FR-203 | CatalogAPI | SPEC-PURCHASE, CONTRACT-ORDER | Evento publicado e testes | Planejado |
| FR-204 | PaymentsAPI | SPEC-PAYMENTS, CONTRACT-PAYMENT | Consumo e dois resultados simulados | Planejado |
| FR-205 | CatalogAPI | SPEC-PURCHASE, CONTRACT-PAYMENT | Aprovado concede; rejeitado não concede | Planejado |
| FR-206 | NotificationsAPI | SPEC-NOTIFICATIONS, CONTRACT-USER | Log de boas-vindas após evento | Planejado |
| FR-207 | NotificationsAPI | SPEC-NOTIFICATIONS, CONTRACT-PAYMENT | Log de confirmação apenas na aprovação | Planejado |
| EVT-201 | UsersAPI | CONTRACT-USER | `UserCreatedEvent` após cadastro | Planejado |
| EVT-202 | Todos | ADR-P2-003 | Fluxos assíncronos ponta a ponta | Planejado |
| ARC-201 | Todos | ADR-P2-001 | Quatro serviços independentes | Planejado |
| ARC-202 | Todos | README principal | Quatro repositórios Git | Planejado |
| ARC-203 | Todos | Soluções/projetos | `.sln` ou `.csproj` por serviço | Planejado |
| TECH-201 | Todos | Projetos .NET | TargetFramework e build | Planejado |
| DOCK-201 | Todos | Dockerfile | Quatro Dockerfiles funcionais | Planejado |
| DOCK-202 | Todos | Dockerfile | Multi-stage verificado | Planejado |
| DOCK-203 | Orquestração | docker-compose.yml | `docker-compose up` e fluxos | Planejado |
| K8S-201 | Todos | `/k8s` por repositório | Estruturas presentes | Planejado |
| K8S-202 | Todos | Deployment | Pods gerenciados por Deployment | Planejado |
| K8S-203 | Todos | ConfigMap | Configurações não sensíveis | Planejado |
| K8S-204 | Todos | Secret | Referências sem credenciais reais no Git | Planejado |
| K8S-205 | Todos | Service / configuração | Comunicação por nomes DNS internos | Planejado |
| K8S-206 | Orquestração + todos | Guia de deploy | Cluster local e pods saudáveis | Planejado |
| MSG-201 | Todos com mensageria | ADR-P2-003 | Biblioteca .NET integrada ao broker | Planejado |
| DEL-201 | Entrega | Roteiro de vídeo | Vídeo de até 20 min | Planejado |
| DEL-202 | Entrega | README principal | URLs dos quatro serviços | Planejado |
| DEL-203 | Todos | README por serviço | Finalidade e variáveis | Planejado |
| DEL-204 | Orquestração | README principal | Docker e Kubernetes reproduzíveis | Planejado |
| DEL-205 | Entrega | Relatório PDF/TXT | Dados e links solicitados | Planejado |

## Decisões aprovadas do projeto (não requisitos oficiais adicionais)

| Decisão | Baseline validada | Situação |
|---|---|---|
| Repositórios | Quatro serviços + infraestrutura | Aprovado |
| Broker/biblioteca | RabbitMQ + MassTransit | Aprovado |
| Persistência | PostgreSQL, bancos/credenciais por serviço | Aprovado |
| Contratos | V1, GUID, decimal BRL, locais + testes | Aprovado |
| Compra | HTTP 202/Pending, resultado determinístico | Aprovado |
| Confiabilidade | Outbox/Inbox, retries, filas de erro | Aprovado |
| Cluster local | Docker Desktop Kubernetes | Aprovado |

## Atualização

Ao concluir uma tarefa, alterar somente as linhas cujas evidências existam. Não confundir documentação aprovada com funcionalidade implementada. Registrar links para testes, manifests, commits ou roteiro de demonstração conforme forem criados.

## Rastreabilidade das decisões arquiteturais aceitas

| Decisão | Requisitos relacionados | Status |
|---|---|---|
| ADR-P2-001 — Serviços e repositórios | ARC-201, ARC-202, ARC-203 | Aceito |
| ADR-P2-002 — Dados por serviço | FR-201 a FR-205 | Aceito |
| ADR-P2-003 — RabbitMQ/MassTransit | EVT-201, EVT-202, MSG-201 | Aceito |
| ADR-P2-004 — Contratos de eventos | EVT-201, FR-203 a FR-207 | Aceito |
| ADR-P2-005 — Compra assíncrona | FR-203, FR-204, FR-205, FR-207 | Aceito |
| ADR-P2-006 — Outbox/Inbox | EVT-201, EVT-202, MSG-201 | Aceito |
| ADR-P2-007 — Segurança/containers/Kubernetes | TECH-201, DOCK-201 a DOCK-203, K8S-201 a K8S-206 | Aceito |

> **Atenção:** `Aceito` é status de decisão arquitetural, não de requisito implementado.
