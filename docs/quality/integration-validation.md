# Estratégia de testes e validação — Fase 2

**Estado:** Proposta. Diferenciar evidência de teste executado de critério planejado.

## Camadas
- **Unitários:** regras de domínio, autorização, transições de pedido, política de pagamento, deduplicação.
- **Integração:** persistência isolada, migrations, publicação/consumo via broker de teste e contratos serializados.
- **Ponta a ponta com Docker Compose:** cadastro → boas-vindas; pedido → aprovação → biblioteca + confirmação; pedido → rejeição → biblioteca inalterada.
- **Kubernetes local:** Deployments, Services, ConfigMaps, Secrets e quatro APIs com Pods disponíveis; repetir fluxos usando o broker do cluster.
- **Resiliência:** indisponibilidade temporária do broker, mensagens repetidas, restart de consumer, payload inválido, falta de configuração/segredo.

## Matriz de cenários mínimos

| Cenário | Resultado esperado | Evidência |
|---|---|---|
| Cadastro válido | Usuário persistido; boas-vindas simuladas | API + logs do consumer |
| Cadastro inválido | Erro de validação; sem evento | Teste e logs |
| Compra aprovada | Pedido aprovado; biblioteca atualizada uma vez; confirmação simulada | Pedido + biblioteca + logs |
| Compra rejeitada | Pedido rejeitado; biblioteca inalterada; sem confirmação | Pedido + biblioteca + logs |
| Evento duplicado | Sem efeitos duplicados | Teste com replay |
| Broker temporariamente indisponível | Evento persistido na Outbox aprovada para entrega posterior | Teste de recuperação |
| Deploy local | Todos os Pods/Services operacionais | `kubectl get deployments,pods,services` |

## Gates
`dotnet restore`, `dotnet build`, `dotnet test` por serviço; `docker compose config`, `docker compose up --build` e testes integrados; `kubectl apply`/`kubectl get` em cluster local. Documentar comandos, ambiente e resultados reais. Não marcar `Validado` sem execução.
