# Matriz de integração e compatibilidade V1

| Evento | Publicador | Consumidor | Fila implementada |
|---|---|---|---|
| UserCreatedEvent | Users | Notifications | notifications-user-created-v1 |
| OrderPlacedEvent | Catalog | Payments | payments-order-placed-v1 |
| PaymentProcessedEvent | Payments | Catalog | catalog-payment-processed-v1 |
| PaymentProcessedEvent | Payments | Notifications | notifications-payment-processed-v1 |

Nomes explícitos e estáveis implementados em G2–G5. Catalog e Notifications não competem na mesma fila. No G1 as filas de teste são prefixadas g1 e recebem sufixo aleatório para isolar execuções, com exclusão automática ao encerrar consumers. A fila técnica g1-validation-persistence é durável e exclusiva da verificação de reinício.

Desde G6, os testes G1 usam exclusivamente o vhost fcg_g1_tests. Prefixos de filas não bastam para isolar publicações em exchanges de contratos compartilhados; o vhost separado impede que fixtures sejam processadas pelos serviços do vhost fcg.

Identidade esperada: urn:message:FiapCloudGames.Contracts.V1:NomeDoEvento. O assembly não faz parte dessa identidade. Os projetos de fixtures Producer.Contracts e Consumer.Contracts têm cópias separadas, não compartilham fontes nem tipos. Não são bibliotecas para distribuir aos microsserviços.

Testes verificam tipos/campos contra as tabelas Markdown, desserialização dos exemplos, JSON camelCase, decimal numérico, campos obrigatórios, URN e transmissão real pelo RabbitMQ. PaymentProcessedEvent Approved e Rejected chegam a dois consumers independentes. Validações de negócio, Outbox, Inbox, idempotência e autorização pertencem aos gates dos serviços; não estão implementadas pelas fixtures.

Os serviços mantêm testes com seus tipos locais efetivos e cópias independentes nos projetos de teste, conforme registros G2–G5. A validação G6 exercita os quatro serviços juntos. Alteração incompatível exige V2. O pagamento possui snapshot BRL; CorrelationId não é obrigatório no payload. Não publicar senha, hash ou JWT.
