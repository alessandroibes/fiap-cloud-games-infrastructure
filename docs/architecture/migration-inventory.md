# Inventário e matriz de migração

Consolidado em 30/10/2026 a partir do inventário estático da Fase 1 já realizado nesta conversa. Origem: repositório irmão fiap-cloud-games, somente referência. Nenhum build, teste ou migration da origem foi executado nesta preparação.

## Projetos e dependências

Solução FiapCloudGames.sln, .NET 8, SDK 8.0.414. Domain sem dependências internas; Application depende de Domain; Infrastructure depende de Application/Domain; Api depende de Application/Infrastructure. Três projetos de testes: domínio, aplicação e integração HTTP.

Pacotes históricos: EF Core SQLite/Design, Identity Core e JWT Bearer 8.0.20; Hosting Abstractions 8.0.1; System.IdentityModel.Tokens.Jwt 7.1.2; Swashbuckle 6.6.2; xUnit 2.9.2, runner 2.8.2, Test SDK 17.11.1 e MVC Testing 8.0.20. Isto não seleciona versões para a Fase 2.

## Matriz de reaproveitamento

| Origem | Destino | Classificação | Adaptação |
|---|---|---|---|
| User, PasswordPolicy, UserRole e testes | Users | Alto | Manter regras; isolamento do serviço |
| Email | Users | Parcial | Normalizar cadastro/login e impor unicidade |
| LoginUseCase, PasswordHasher, JwtTokenService | Users | Alto | Configuração própria e testes de validação/claims |
| RegisterUserUseCase | Users | Parcial | Usuário + UserCreatedEvent na mesma transação com Outbox |
| Administração e bootstrap | Users | Parcial | Preservar acesso Admin, idempotência e segredos externos |
| UserRepository | Users | Parcial | PostgreSQL e tratamento de unicidade, sem código SQLite 19 |
| Game, CreateGameUseCase | Catalog | Parcial | Completar CRUD, escala monetária e exclusão lógica |
| UserGame | Catalog | Parcial | Concessão somente após Approved; remover FK para Users |
| GetLibraryUseCase e projeção | Catalog | Parcial | Não consultar banco de usuários; preservar preço atual |
| AcquireGameUseCase | Catalog | Fluxo incompatível | Pedido Pending + Outbox + 202; concessão por consumer |
| Promotion e CreatePromotionUseCase | Nenhum no mínimo | Não migrar | Preservar somente na origem |
| AppDbContext/migrations SQLite | Serviços persistentes | Referência de modelagem | Contextos, bancos, credenciais e migrations PostgreSQL separados |
| Pagamento | Payments | Novo | Simulação determinística, resultado único por OrderId, Inbox/Outbox |
| Notificações | Notifications | Novo | Consumers, persistência técnica e logs deduplicados logicamente |
| ProblemDetails, Swagger, logs JSON | APIs pertinentes | Parcial | Exceções locais, correlação e health checks reais |
| Testes de regras e autenticação | Users/Catalog | Alto | Ajustar projetos e regras confirmadas |
| Testes HTTP/SQLite/aquisição | Users/Catalog | Parcial | PostgreSQL, contratos e consistência eventual |

## Entidades e regras

User exige nome, e-mail válido e hash; cadastro público cria User. Senha: pelo menos oito caracteres, letra, número e símbolo/pontuação. Game exige nome e preço decimal não negativo. UserGame rejeita IDs vazios e registra AcquiredAt. Promotion exige jogo existente, desconto maior que zero até 100 e fim posterior ao início. IDs já são GUIDs. Não há validação explícita de duas casas no domínio de Game.

Casos de uso: RegisterUser, Login, ListUsers, GetUserById, UpdateUserRole, CreateGame, AcquireGame, GetLibrary e CreatePromotion. O catálogo original contém criação, não CRUD completo.

## HTTP e autenticação

| Endpoint original | Acesso | Sucesso |
|---|---|---|
| POST /api/users | Público | 201 |
| POST /api/auth/login | Público | 200 |
| GET /api/admin/users e /api/admin/users/{id} | Admin | 200 |
| PUT /api/admin/users/{id}/role | Admin | 204 |
| POST /api/games | Admin | 201 |
| POST /api/library/games/{gameId} | Autenticado | 201 imediato, incompatível |
| GET /api/library | Autenticado | 200, biblioteca própria |
| POST /api/promotions | Admin | 201 |
| GET /api/health | Público | 200 fixo |

JWT HS256, claims sub/email/role, issuer/audience/assinatura/expiração validados, tolerância zero, duração 60 minutos e chave externa de pelo menos 32 bytes. PasswordHasher ASP.NET Core; sem refresh. Biblioteca usa sub do JWT. ProblemDetails para erros; Swagger em Development. Health não verifica dependências.

## Persistência, migrations e testes

AppDbContext compartilhado: Users, Games, UserGames, Promotions. E-mail único; UserGames tem PK (UserId, GameId) e FKs com cascade para usuários/jogos; Promotions tem FK para Game. Preço (18,2), desconto (5,2), com limitações de imposição no SQLite.

Migrations: 20260823230438_CreateUsers, 20260824112536_CreateGames, 20260824113850_CreateUserGames e 20260824114859_CreatePromotions, com designers e snapshot. Não portar histórico SQLite. DatabaseInitializer chama MigrateAsync no startup; factory dos testes também aplica migrations. Repositórios salvam internamente e tratam erros específicos SQLite; rever fronteira transacional para Outbox.

Testes existentes cobrem domínio, casos de uso, HTTP, hash, JWT, bootstrap, autorização, Swagger e biblioteca própria, com SQLite em memória na integração. Há Postman e documentação TDD. Não há implementação/testes de broker, Outbox/Inbox, pedidos, pagamentos ou notificações, nem Docker/Compose/Kubernetes identificados na origem.

## Ruptura da aquisição

AcquireGame verifica usuário/jogo/duplicidade e concede imediatamente. Essa regra, a resposta 201 e os testes de inclusão imediata não são reutilizáveis. A Fase 2 registra pedido Pending com snapshot de preço, publica via Outbox e responde 202. Apenas PaymentProcessedEvent Approved concede. Impedir pendência duplicada e concessão repetida; resultado conflitante não reverte estado terminal. UserId externo não tem FK entre serviços. Biblioteca mantém preço atual; pedido conserva preço histórico. Sem importação legada.

Veja [decisões confirmadas](functional-decisions.md) e [roadmap](../implementation/roadmap.md).
