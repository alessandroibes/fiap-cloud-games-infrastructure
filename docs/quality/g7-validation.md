# G7 — Kubernetes Docker Desktop

Data: 03/11/2026 (America/Sao_Paulo). **G7 concluído.**

## Preparação executada

- Contexto docker-desktop existente, nó desktop-control-plane Ready, Kubernetes v1.36.1, containerd 2.3.1; sem instalação de CLI Kind ou criação de cluster alternativo.
- Storage class padrão standard, provisionador rancher.io/local-path.
- Manifestos próprios em cada microsserviço, migrations em Jobs, namespace e dependências na infraestrutura.
- Namespace fcg-phase2 e seis Secrets criados pelo script, com credenciais geradas em arquivo local ignorado. ConfigMap de inicialização PostgreSQL gerado do script canônico.
- `kubectl apply --dry-run=server` em todos os manifestos: aceitos pelo API server.
- Parser PowerShell nos scripts novos: sem erros de sintaxe.
- Identificado armazenamento clássico incompatível com provisionador interno do Docker Desktop; responsável habilitou armazenamento containerd. Engine confirmou io.containerd.snapshotter.v1. Primeira tentativa logo após a troca encontrou API server ainda indisponível.

## Implantação executada

- Quatro imagens construídas com restore locked e publish .NET 8, sem alterações nos fontes de negócio.
- PostgreSQL/RabbitMQ implantados em PVCs novos; quatro migrations e bootstrap executados por Jobs antes das APIs.
- Seis Deployments disponíveis (1/1), seis Services ClusterIP e dois PVCs Bound, 2Gi PostgreSQL/1Gi RabbitMQ.
- Reaplicação via Start-Kubernetes -SkipBuild concluída com código 0, usando tags derivadas do SHA256 das imagens. Os cinco Jobs concluíram novamente; cada banco possui uma linha em __EFMigrationsHistory; bootstrap retornou Created=false.
- Imagens identificadas por conteúdo disponibilizadas pelo armazenamento containerd do Docker Desktop, sem push ou registry externo.

## Ajustes observados

A mudança de armazenamento feita pelo responsável foi seguida pela recriação automática do cluster pelo Docker Desktop (novo identificador e idade do nó). Ainda não havia PVCs de aplicação nessa etapa. Namespace e Secrets foram reaplicados com os mesmos valores do arquivo local. Não foi executado reset-cluster ou comando Kind.

A primeira implantação deixou todos os Deployments prontos, mas a listagem final falhou porque PowerShell expandiu a lista de recursos separada por vírgulas ao chamar a função wrapper. A string foi colocada entre aspas e a implantação completa foi repetida com sucesso. Probes de startup das dependências falharam brevemente durante a primeira inicialização e depois ficaram saudáveis, sem reinícios de containers nessa inspeção.

## Validação funcional executada

`Validate-G7.ps1 -SkipStart` terminou com código 0, incluindo restauração de Payments para Approved e encerramento dos processos de port-forward criados pelo teste.

- Cadastro 201 e login JWT; boas-vindas emitidas com registro técnico durável.
- Payments escalado para zero antes da primeira compra: HTTP 202/Pending, biblioteca vazia e ausência de confirmação. Após retomada, pagamento aprovado, concessão e confirmação.
- Modo Rejected: pedido rejeitado, sem entrada na biblioteca e sem notificação; recebimento do evento comprovado por subject técnico persistido.
- Nova tentativa: outro OrderId aprovado, uma entrada para o jogo e confirmação lógica única.
- Logs JSON de boas-vindas e duas confirmações encontrados; nenhum log de confirmação para o pedido rejeitado.
- Substituição dos pods de PostgreSQL/RabbitMQ e APIs via Deployments, preservando os mesmos PVCs: três estados terminais, duas entradas na biblioteca e registros técnicos mantidos.
- Inspeção final: seis Deployments 1/1, cinco Jobs Complete, dois PVCs Bound; quatro filas de consumo com zero mensagens e um consumidor cada. Nenhuma fila de erro presente nesse namespace/broker novo.
- Execução nos quatro containers API confirmou UID 1654. Modo final de Payments: Approved.

| Evidência | Identificador |
|---|---|
| Usuário cadastrado | d71db35a-b96a-4c73-a7dd-b218d4d617a2 |
| Pedido aprovado | ccf28509-bb3e-405c-a912-f2d8d56ee02e |
| Pedido rejeitado | 5971cdf2-3c06-4b56-95c5-589d0cc8828d |
| Nova tentativa aprovada | 91c9436e-378c-4e64-82a1-7d52c531c2d6 |
| Volume PostgreSQL | pvc-cdd2acd2-ef4d-46e0-8abd-3c76d89aaf10 |
| Volume RabbitMQ | pvc-2e25bb13-0a18-4bf5-94a9-e515fa90050e |

## Limites

Testes executados por scripts operacionais e chamadas HTTP/SQL/AMQP reais, sem contagem fictícia de testes xUnit. Suítes completas G2–G5 não foram reexecutadas; o código de negócio permaneceu intacto. O teste comprova recuperação entre pods na instalação local, não recuperação após perda do nó ou exclusão de PVC. Não há alta disponibilidade ou garantia de exactly-once físico nos logs. G8 permanece responsável pela revisão transversal de falhas e recuperação.

Nenhum contrato V1 ou arquivo da Fase 1 alterado. Imagens apenas locais, sem push ou publicação externa.
