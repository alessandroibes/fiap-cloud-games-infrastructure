# Requisitos — Tech Challenge Fase 2

## Fonte e escopo

Fonte: `TC NETT - Fase 2(1).pdf`, páginas 2–6. A evolução parte do MVP monolítico FIAP Cloud Games e exige quatro serviços autônomos, eventos e execução em Docker/Kubernetes. Identificadores abaixo são **internos deste projeto**, não códigos oficiais da FIAP.

## Funcionalidades obrigatórias

| ID | Requisito oficial | Critério de verificação proposto | Fonte |
|---|---|---|---|
| FR-201 | UsersAPI: cadastro, autenticação JWT e autorização | Cadastrar, autenticar e verificar acesso autorizado/não autorizado | p. 3 |
| FR-202 | CatalogAPI: CRUD de jogos | Operações de criação, consulta, alteração e exclusão demonstráveis | p. 3 |
| FR-203 | CatalogAPI: iniciar compra para biblioteca | Receber solicitação e publicar `OrderPlacedEvent` com `UserId`, `GameId`, `Price` | pp. 3–4 |
| FR-204 | PaymentsAPI: pagamento simulado | Consumir `OrderPlacedEvent` e publicar `PaymentProcessedEvent` com `Approved` ou `Rejected` | p. 3 |
| FR-205 | CatalogAPI: concessão condicionada à aprovação | Consumir `PaymentProcessedEvent`; adicionar à biblioteca apenas se `Approved` | p. 4 |
| FR-206 | NotificationsAPI: boas-vindas | Consumir `UserCreatedEvent` e registrar envio simulado no console | p. 3 |
| FR-207 | NotificationsAPI: confirmação de compra | Consumir `PaymentProcessedEvent` e registrar confirmação apenas quando `Approved` | p. 4 |
| EVT-201 | Publicação de evento de cadastro | `UsersAPI` publica `UserCreatedEvent` após criar usuário | p. 3 |
| EVT-202 | Mensageria assíncrona | Fluxos operam com RabbitMQ **ou** Kafka | pp. 3–5 |

## Arquitetura e infraestrutura obrigatórias

| ID | Requisito oficial | Evidência esperada | Fonte |
|---|---|---|---|
| ARC-201 | Quatro microsserviços distintos | UsersAPI, CatalogAPI, PaymentsAPI, NotificationsAPI | p. 3 |
| ARC-202 | Repositório Git independente por serviço | Quatro URLs Git e históricos separados | pp. 2–3 |
| ARC-203 | Cada serviço com solução `.sln` ou projeto `.csproj` | Estrutura verificável em cada repositório | p. 4 |
| TECH-201 | .NET 8 ou superior em todos os serviços | `TargetFramework` e builds | p. 4 |
| DOCK-201 | Dockerfile próprio em cada repositório | Quatro Dockerfiles | pp. 4–5 |
| DOCK-202 | Dockerfiles com multi-stage builds | Inspeção e build das imagens | p. 4 |
| DOCK-203 | Aplicação completa executável com `docker-compose up` | Execução integrada e demonstração dos fluxos | p. 5 |
| K8S-201 | Pasta `/k8s` na raiz de cada repositório de serviço | Diretórios e manifestos por serviço | p. 4 |
| K8S-202 | Deployments (não Pods avulsos) | `kubectl get deployments,pods` | p. 4 |
| K8S-203 | ConfigMaps para configurações não sensíveis | Manifestos e consumo por serviços | p. 4 |
| K8S-204 | Secrets para informações sensíveis | Referências a Secrets; nenhum segredo real versionado | p. 4 |
| K8S-205 | Comunicação interna por nomes de Kubernetes Services | Endereços internos configurados por nome de Service, quando aplicável | p. 5 |
| K8S-206 | Implantação testada em cluster local | Kind, Minikube, k3d ou Docker Desktop Kubernetes; pods em execução | p. 5 |
| MSG-201 | Biblioteca .NET robusta para broker | MassTransit ou cliente oficial apropriado | p. 5 |

## Entregáveis obrigatórios

| ID | Entrega | Evidência | Fonte |
|---|---|---|---|
| DEL-201 | Vídeo com até 20 minutos | Mostrar repositórios, Compose, fluxos, manifestos e Kubernetes local | p. 5 |
| DEL-202 | Links dos repositórios individuais | Quatro links acessíveis | p. 5 |
| DEL-203 | README por microsserviço | Finalidade e variáveis de ambiente | p. 6 |
| DEL-204 | README principal de orquestração | Passos Docker e Kubernetes | p. 6 |
| DEL-205 | Relatório PDF ou TXT | Grupo, participantes/Discord, documentação, repositórios e vídeo | p. 6 |

## Opcional expresso

- `OPT-201`: quinto repositório dedicado à orquestração (p. 4). **Decisão do projeto (ADR-P2-001):** adotá-lo para Compose, documentação transversal e roteiro de deploy; manter `/k8s` nos quatro serviços.

## Pontos não definidos pelo enunciado

São decisões de engenharia a registrar, **não requisitos oficiais adicionais**: RabbitMQ versus Kafka; MassTransit versus cliente oficial; banco e migrações por serviço; esquema completo e versionamento dos eventos; correlação e idempotência; política determinística de aprovação/rejeição; mecanismo de entrega confiável; autenticação interserviços; observabilidade; CI/CD; escolha do cluster local.

O enunciado **não exige** AKS, ECS, Kafka CDC, Event Sourcing, HPA ou cloud pública. A adoção só deve ocorrer mediante decisão justificada.

## Critério de conclusão da Fase 2

Os requisitos acima devem estar demonstráveis por código, testes, configuração e evidências. Nenhuma linha deve ser marcada `Validado` apenas pela existência da documentação.
