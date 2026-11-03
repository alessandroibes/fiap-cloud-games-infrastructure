# Recuperação e validação de resiliência — G8

## Reprodução

Requer G7 implantado, contexto docker-desktop, namespace fcg-phase2, RabbitMQ com uma réplica e Payments em Approved. Execute sem compras ou outras validações concorrentes:

```powershell
./scripts/Validate-G8.ps1
```

O teste usa portas locais 5181/5182 e 15682, encerra seus port-forwards ao finalizar e restaura RabbitMQ em finally se houver falha durante a indisponibilidade. Não remove dados, PVCs ou filas. Credenciais vêm de `.env.k8s.local`, sem impressão de senha/JWT. O evento inválido gerado permanece na fila de erro como evidência; a inspeção via API do RabbitMQ utiliza requeue e é limitada a 100 mensagens. Em fila maior, investigar o evento pelo ID com procedimento operacional próprio antes de repetir o teste.

O script valida:

1. Broker parado; cadastro 201 e oito compras HTTP simultâneas, com um 202/Pending e sete 409.
2. Outboxes de Users/Catalog duráveis, biblioteca vazia; reinício dos dois produtores sem broker e manutenção do pedido/Outboxes.
3. Retomada do broker; entrega dos eventos, Outboxes esvaziadas, um pagamento, uma concessão e notificações emitidas.
4. Reenvios de OrderPlacedEvent/PaymentProcessedEvent com MessageIds distintos e EventId lógico repetido; efeito único e recebimentos verificáveis. Preços numericamente iguais com escalas diferentes não constituem conflito.
5. Evento com preço negativo na fila de erro de Payments, sem pagamento/receipt; não há consumer automático dessa fila.

As publicações administrativas do teste usam envelopes MassTransit V1 no RabbitMQ local. Não há endpoint público de replay ou acesso entre bancos pelas aplicações. Consultas SQL administrativas apenas verificam evidências e não alteram dados de negócio.

## Broker indisponível e mensagens pendentes

Verificar `kubectl --context docker-desktop -n fcg-phase2 get deployments,pods,pvc` e logs de RabbitMQ. Se o teste foi interrompido abruptamente com broker escalado a zero, restaurar explicitamente:

```powershell
kubectl --context docker-desktop -n fcg-phase2 scale deployment/rabbitmq --replicas=1
kubectl --context docker-desktop -n fcg-phase2 rollout status deployment/rabbitmq --timeout=300s
```

Outboxes publicam após retorno do broker, sem recriar pedidos ou usuários. Confirmar estado dos pedidos e drenagem das filas. Readiness HTTP verifica banco/schema e pode continuar saudável sem broker: não usar somente health check como prova de conclusão de compra. Não apagar Outbox/Inbox/receipts para forçar entrega.

## Filas de erro

Filas: payments-order-placed-v1_error, catalog-payment-processed-v1_error, notifications-user-created-v1_error e notifications-payment-processed-v1_error, criadas quando ocorre erro. A ausência de uma fila de erro nunca utilizada é normal. Cada consumidor tem três retentativas progressivas de 1s, 5s e 15s para falha transitória; eventos permanentemente inválidos não são retentados dessa forma.

Procedimento de recuperação:

1. Identificar fila, EventId/OrderId e causa pelos logs/headers. Inspecionar sem ACK destrutivo e sem exportar payload pessoal indiscriminadamente.
2. Corrigir a causa técnica antes de replay. Para payload inválido ou resultado conflitante, manter em quarentena e investigar; não alterar dados monetários nem aprovar manualmente um pedido para silenciar erro.
3. Para mensagem originalmente válida, reenviar de forma controlada à fila do consumidor correto, preservando o evento e sua identidade lógica. Não enviar para a exchange global sem avaliar consumidores adicionais.
4. Verificar efeito persistido único e ausência de novo erro; só então decidir a remoção da cópia da fila de erro. Requeue para a própria `_error` apenas recoloca a mensagem nessa fila e não retoma o consumer de negócio.

Não há purge automático nem consumidor automático de `_error`. As suítes isoladas demonstram esgotamento de quatro tentativas totais e replay após remoção da falha injetada; esse teste controlado não autoriza replay indiscriminado dos eventos inválidos criados pelo roteiro G8.

## Notificações Failed

Notifications registra falhas de emissão e chega a Failed após quatro tentativas registradas. Corrigir a causa antes de executar o comando explícito `--retry-failed` na imagem do serviço, com o mesmo ConfigMap/Secret. O comando redefine apenas Failed para Pending, preservando NotificationId; não altera Emitted. Use um Job operacional derivado do Job de migration, com nome próprio e argumento `--retry-failed`; aguarde conclusão e verifique os registros/logs. Não há endpoint HTTP para essa operação.

O teste de recuperação com Failed é executado na suíte Notifications. A escrita no stdout e o commit PostgreSQL não são atômicos: uma falha entre ambos pode repetir o mesmo NotificationId fisicamente. A garantia é unicidade lógica, não exactly-once ou retenção permanente do console.

## Limites e segurança

Falhas precisamente após commit são injetadas nos testes EF/consumidores; a execução no cluster inclui reinício real de pods e indisponibilidade real do broker. Não foi simulada perda do nó, corrupção de PVC, restauração de backup ou carga prolongada. Não remover namespace/PVCs ou resetar o cluster como recuperação de aplicação. Os resultados efetivamente executados estão em [G8](../quality/g8-validation.md).
