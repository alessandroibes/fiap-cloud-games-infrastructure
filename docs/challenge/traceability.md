# Matriz de Rastreabilidade — Fase 2

## Estados

- `Planejado`: requisito identificado, implementação/evidência ainda não concluída.
- `Em implementação`: desenvolvimento iniciado.
- `Implementado`: artefato produzido, validação pendente.
- `Validado`: critério verificado com evidência.
- `Bloqueado`: impedimento concreto documentado.

> Atualização de 03/11/2026: G0–G8 concluídos; G9 com preparação documental, pendente de vídeo/dados/submissão. Referências SPEC/CONTRACT são identificadores lógicos, com documentos em docs/specifications/ e docs/contracts/. Evidências G2–G5 ficam em docs/quality/gN-validation.md de cada serviço; [G6](../quality/g6-validation.md) e [G7](../quality/g7-validation.md) consolidam a integração. Aceitação de ADR não equivale a requisito validado.

| ID | Responsável | Artefato/contrato previsto | Evidência prevista | Status |
|---|---|---|---|---|
| FR-201 | UsersAPI | SPEC-USERS, ADR-P2-007 | Testes de cadastro/login/autorização | Validado |
| FR-202 | CatalogAPI | SPEC-CATALOG | Testes de CRUD | Validado |
| FR-203 | CatalogAPI | SPEC-PURCHASE, CONTRACT-ORDER | Evento publicado e testes | Validado |
| FR-204 | PaymentsAPI | SPEC-PAYMENTS, CONTRACT-PAYMENT | Consumo e dois resultados simulados | Validado |
| FR-205 | CatalogAPI | SPEC-PURCHASE, CONTRACT-PAYMENT | Aprovado concede; rejeitado não concede | Validado |
| FR-206 | NotificationsAPI | SPEC-NOTIFICATIONS, CONTRACT-USER | Log de boas-vindas após evento | Validado |
| FR-207 | NotificationsAPI | SPEC-NOTIFICATIONS, CONTRACT-PAYMENT | Log de confirmação apenas na aprovação | Validado |
| EVT-201 | UsersAPI | CONTRACT-USER | `UserCreatedEvent` após cadastro | Validado |
| EVT-202 | Todos | ADR-P2-003 | Fluxos assíncronos ponta a ponta | Validado |
| ARC-201 | Todos | ADR-P2-001 | Quatro serviços independentes | Validado |
| ARC-202 | Todos | README principal | Quatro repositórios Git | Validado |
| ARC-203 | Todos | Soluções/projetos | `.sln` ou `.csproj` por serviço | Validado |
| TECH-201 | Todos | Projetos .NET | TargetFramework e build | Validado |
| DOCK-201 | Todos | Dockerfile | Quatro Dockerfiles funcionais | Validado |
| DOCK-202 | Todos | Dockerfile | Multi-stage verificado | Validado |
| DOCK-203 | Orquestração | compose.yaml | Compose V2, Start-Local e fluxos G6 | Validado |
| K8S-201 | Todos | `/k8s` por repositório | Estruturas presentes | Validado |
| K8S-202 | Todos | Deployment | Pods gerenciados por Deployment | Validado |
| K8S-203 | Todos | ConfigMap | Configurações não sensíveis | Validado |
| K8S-204 | Todos | Secret | Referências sem credenciais reais no Git | Validado |
| K8S-205 | Todos | Service / configuração | Comunicação por nomes DNS internos | Validado |
| K8S-206 | Orquestração + todos | Guia de deploy | Cluster local e pods saudáveis | Validado |
| MSG-201 | Todos com mensageria | ADR-P2-003 | Biblioteca .NET integrada ao broker | Validado |
| DEL-201 | Entrega | Roteiro de vídeo | Vídeo de até 20 min | Planejado |
| DEL-202 | Entrega | README principal | URLs reais e remotos conferidos; acesso do avaliador pendente | Implementado |
| DEL-203 | Todos | README por serviço | Finalidade e variáveis | Validado |
| DEL-204 | Orquestração | README principal | Docker e Kubernetes reproduzíveis | Validado |
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

Revisão transversal G8: [171 testes e resiliência no cluster](../quality/g8-validation.md). Evidências funcionais mantidas; os entregáveis acadêmicos restantes continuam Planejado até receber dados/URLs e produzir a entrega.
