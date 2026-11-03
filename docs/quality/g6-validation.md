# G6 — registro de validação

Data: 03/11/2026 (America/Sao_Paulo). **G6 concluído.**

## Executado

- Leitura de requisitos, ADRs, decisões funcionais, contratos e instruções locais.
- Compose central com quatro APIs, builds a partir de clones independentes, bancos e credenciais por serviço e manutenção dos volumes existentes.
- Inicializador de configuração executado preservando credenciais locais e importando JWT/bootstrap existentes de Users, sem alterar irmãos.
- `docker compose config --quiet`: concluído sem erros.
- Parser PowerShell nos cinco scripts: sem erros de sintaxe.
- `dotnet restore FiapCloudGames.Infrastructure.sln --locked-mode`: sucesso.
- `dotnet build FiapCloudGames.Infrastructure.sln --no-restore`: sucesso, zero erros e avisos.
- `dotnet test ... --no-build --filter FullyQualifiedName~ContractTests`: **6 aprovados, 0 falhas, 0 ignorados**. TRX local ignorado: `tests/Contracts.Tests/TestResults/g6-contracts.trx`.
- Reexecução de Initialize-Local com comparação de hash do arquivo: configuração preservada integralmente.
- Start-Local executado: quatro builds Docker concluídos (camadas em cache), dependências saudáveis, quatro comandos de migration concluídos, bootstrap idempotente (`Created=false`) e quatro APIs com readiness 200.
- Transição das quatro instâncias individuais para Compose central, sem remover volumes ou containers anteriores.
- Validate-G6 concluído com código 0, incluindo restauração do modo original de Payments.
- Aprovação concedeu uma entrada; rejeição não concedeu jogo e teve subject durável sem registro de notificação; nova tentativa usou outro pedido aprovado. Boas-vindas e confirmações verificadas por registros duráveis e logs JSON.
- Recriação de PostgreSQL, RabbitMQ e quatro APIs: estados dos três pedidos, duas entradas na biblioteca e registros técnicos de notificações preservados.

## Identificadores observados

| Evidência | ID |
|---|---|
| Usuário cadastrado | 059887e4-3306-4c81-b139-b45536aa8326 |
| Pedido aprovado | 12d98c62-4f9f-400e-99a2-bab0496a7609 |
| Pedido rejeitado | 94e5a4d1-37f1-4df9-b5a0-d4c9a7f3e1d8 |
| Nova tentativa aprovada | 93126ace-825b-424e-a70d-e9df49f2df14 |

## Regressão final

- Validate-G1 após correção do isolamento: **38 testes aprovados, 0 falhas**, seguidos de **5 verificações de persistência aprovadas** após reinício de PostgreSQL/RabbitMQ. As cinco são reexecuções do subconjunto de persistência, não casos adicionais distintos.
- Restore locked e build novamente concluídos, sem erros ou avisos.
- Resultados locais ignorados: `g1-full.trx` e `g1-persistence.trx` em `tests/Contracts.Tests/TestResults/`.

## Falha encontrada e correção

A primeira regressão G1 passou 37 de 38 testes. O teste de transporte antigo publicava fixtures no vhost fcg: com Payments ativo, um resultado gerado pelo serviço chegou ao consumer do teste antes do resultado ilustrativo esperado. Filas com prefixos distintos não isolavam os exchanges dos contratos. Foi corrigido para provisionar e utilizar exclusivamente fcg_g1_tests, inclusive no teste de persistência. Nenhum contrato ou serviço foi alterado para acomodar o teste.

A execução antiga deixou eventos ilustrativos processados e mensagens nas filas de erro de aplicação: catalog-payment-processed-v1_error com 3 e notifications-payment-processed-v1_error com 2 mensagens na inspeção após a falha. Essas evidências não foram purgadas; os registros ilustrativos também foram preservados. Não reprocessar esses eventos como compras reais. A fila técnica antiga g1-validation-persistence no vhost fcg foi preservada; novas execuções usam a homônima no vhost isolado.

O engine Docker estava indisponível na primeira tentativa (pipe dockerDesktopLinuxEngine ausente). Docker Desktop foi iniciado, engine 29.9.2 disponível, e a validação integrada foi efetivamente executada. Dados de demonstração foram preservados. Teste realizado na instalação existente; não comprova instalação em máquina nova. As migrations foram executadas sobre schemas já presentes. Os testes de schemas vazios pertencem aos gates dos serviços.

Não há garantia de exactly-once físico no console. O teste central valida identidade lógica, estado durável e emissão normal; falhas após emissão são cobertas nos testes G5. Nenhuma suíte completa dos quatro serviços foi reexecutada no G6, pois seus fontes permaneceram intactos.

## Evidências anteriores dos serviços

| Gate | Repositório | Commit local concluído |
|---|---|---|
| G2 | fiap-cloud-games-users | b3ca6dc |
| G3 | fiap-cloud-games-catalog | bc80da6 |
| G4 | fiap-cloud-games-payments | b841965 |
| G5 | fiap-cloud-games-notifications | 43f7cd1 |

Consultar `docs/quality/gN-validation.md` de cada clone para resultados completos. Não houve alteração do código dos serviços ou da Fase 1 nesta preparação. Kubernetes permanece no G7.
