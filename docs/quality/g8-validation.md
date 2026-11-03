# G8 — Resiliência e revisão transversal

Data: 03/11/2026 (America/Sao_Paulo). **G8 concluído.**

## Suítes executadas

Scripts Validate-G2/G3/G4/G5 executados nos respectivos repositórios, com PostgreSQL/RabbitMQ reais e exclusivos dos testes. Restore locked e build concluídos sem erros/avisos. Resultados TRX locais, ignorados pelo Git:

| Serviço | Aprovados | Falhas | Horário local da execução |
|---|---:|---:|---|
| Users | 28 | 0 | 14:23:00–14:23:39 |
| Catalog | 51 | 0 | 14:22:23–14:23:38 |
| Payments | 45 | 0 | 14:24:07–14:25:03 |
| Notifications | 47 | 0 | 14:25:32–14:26:23 |

Total: **171 testes aprovados**, sem falhas ou ignorados. Destes, três casos foram acrescentados ao Catalog. Os demais foram reexecutados, não apenas reaproveitados dos registros anteriores. Formatação Catalog por `dotnet format whitespace --verify-no-changes --no-restore`: código 0.

## Correções e compatibilidade

- Catalog normaliza o preço a duas casas no fingerprint de novos receipts. Recibos antigos continuam aceitos quando diferem somente pela escala decimal; outros campos e valores divergentes permanecem inválidos. Não foi criada migration nem alterado contrato V1.
- Testes verificam 59.9/59.90/59.9000, inclusive fingerprint legado com escala 3, e rejeitam preço/status divergentes.
- Interceptor de transação injeta falha depois do commit da concessão e antes do ACK; reinício da API/reenvio não duplica biblioteca. A fixture aguarda startup do bus nos reinícios normais, mantendo opção sem espera no cenário de broker indisponível.
- Health check RabbitMQ dos testes Users alinhado aos demais serviços para executar como rabbitmq, evitando criação de cookie pertencente a root.

## Cobertura reexecutada

| Risco | Evidência |
|---|---|
| Concorrência e unicidade | Users: e-mail; Catalog: pedidos/posse; Payments: OrderId; Notifications: tipo/subject |
| Rollback antes de commit | Testes Users/Catalog/Payments/Notifications verificam ausência de estado parcial |
| Falha depois de commit/antes do ACK | Catalog e Payments com interceptores; reentrega e efeito único |
| Falha entre console e confirmação | Notifications: dois logs físicos, uma identidade lógica e recuperação após reinício |
| Retentativas limitadas e replay | Catalog/Payments/Notifications: quatro tentativas totais, fila de erro e recuperação após corrigir falha injetada |
| Mensagens inválidas/conflitantes | Filas de erro, sem concessão/pagamento/notificação parcial |
| Autenticação/autorização | JWT, Admin, proprietário, assinatura/issuer/audience/expiração/sub inválidos |
| Schema ausente | Startup não migra automaticamente; liveness saudável e readiness indisponível |
| Contratos V1 | Campos, identidade MassTransit e assemblies independentes nas quatro suítes |

## Cluster

Start-Kubernetes reconstruiu imagens e atualizou a instalação, mantendo PVCs, banco e contratos. Jobs de migrations/bootstrap concluídos. Validate-G8 terminou com código 0 e comprovou:

- Broker escalado a zero; cadastro concluído e oito compras simultâneas resultaram em um HTTP 202/Pending e sete conflitos 409.
- Uma mensagem durável na Outbox de Users e outra na de Catalog; biblioteca ainda vazia. Reinício real dos dois produtores sem broker preservou as duas mensagens e o pedido Pending.
- Broker restaurado: ambas as Outboxes esvaziaram; pagamento aprovado, uma entrada na biblioteca, boas-vindas e confirmação Emitted.
- Três reenvios de pedido e três de resultado, com MessageIds distintos e EventId lógico estável, geraram um recibo por evento e mantiveram os efeitos únicos. Reenvio adicional do resultado com outra escala decimal não gerou falso conflito.
- Evento OrderPlacedEvent com preço negativo encontrado na fila de erro, sem Payment ou OrderReceipt. Inspeção reencaminha para a mesma fila; evidência não removida.
- Filas de consumo drenadas; os IDs dos reenvios válidos não apareceram nas filas de erro inspecionadas.

| Evidência | Identificador |
|---|---|
| Usuário cadastrado sem broker | 22824f21-9f15-40e0-a577-92b75b438464 |
| Pedido recuperado | 89e3ee99-b055-4c7d-8f5a-7417adaff33b |
| EventId do replay de pedido | 0d7d1186-42d1-4e5c-8eaf-8c2400d2d216 |
| EventId do replay de pagamento | 37df10b9-0f08-4b5e-b47d-fdcae21fc0c6 |
| EventId inválido preservado | 90757eec-4d10-4dee-8359-cae7b0e9328c |

A mensagem inválida pertence exclusivamente à demonstração G8 em payments-order-placed-v1_error. Não é pagamento real pendente de aprovação e não deve ser reprocessada sem investigação. Consultas SQL e publicações administrativas pertencem ao teste; aplicações continuam sem acesso ao banco alheio.

Inspeção final: seis Deployments 1/1; quatro filas de consumo com zero mensagens e um consumidor cada; payments-order-placed-v1_error com uma mensagem e nenhum consumidor. Nenhum port-forward do namespace permaneceu em execução. Os quatro ambientes Docker exclusivos de testes foram parados ao finalizar, preservando volumes; o cluster permaneceu ativo.

## Limites

Sem promessa de exactly-once físico, teste de carga, perda de nó ou recuperação de backup. Falha precisa entre commit e ACK é injetada em teste, não um kill de sistema operacional nessa janela. Código da Fase 1 preservado; sem push ou publicação externa de imagens. Procedimento operacional em [recuperação](../implementation/recovery-runbook.md).
