# Índice de evidências técnicas

Este índice reúne execuções registradas. Capturas de tela e vídeo são entregáveis distintos: a existência de um teste aprovado não significa que já exista gravação ou imagem da execução.

| Escopo | Evidência versionada | Como reproduzir |
|---|---|---|
| Arquitetura e migração | [Inventário](../architecture/migration-inventory.md), [decisões funcionais](../architecture/functional-decisions.md), [ADRs](../architecture/decisions/README.md) | Inspecionar contratos, projetos e bancos independentes |
| Contratos e isolamento inicial | [G1](g1-validation.md) | scripts/Validate-G1.ps1; vhost de testes separado desde G6 |
| Users: 28 testes | docs/quality/g8-validation.md no repositório Users | scripts/Validate-G2.ps1 no Users |
| Catalog: 51 testes | docs/quality/g8-validation.md no repositório Catalog | scripts/Validate-G3.ps1 no Catalog |
| Payments: 45 testes | docs/quality/g8-validation.md no repositório Payments | scripts/Validate-G4.ps1 no Payments |
| Notifications: 47 testes | docs/quality/g8-validation.md no repositório Notifications | scripts/Validate-G5.ps1 no Notifications |
| Compose completo | [G6](g6-validation.md) | scripts/Start-Local.ps1 e scripts/Validate-G6.ps1 -SkipStart |
| Kubernetes Docker Desktop | [G7](g7-validation.md) | scripts/Start-Kubernetes.ps1 e scripts/Validate-G7.ps1 -SkipStart |
| Resiliência integrada | [G8](g8-validation.md) | scripts/Validate-G8.ps1 com cluster preparado e Payments Approved |
| Revisão documental da entrega | [G9](g9-preparation.md) | Conferir links, arquivos, status dos remotos e pendências acadêmicas |

## Resultado consolidado

G8 reexecutou **171 testes**, sem falhas ou ignorados, em 03/11/2026: 28 + 51 + 45 + 47. O total não soma execuções históricas, repetições de persistência nem assertions de scripts operacionais. Os TRX permanecem locais em TestResults; os resultados resumidos e horários estão versionados.

G6 comprovou Approved/Rejected/nova tentativa e persistência após recriar containers. G7 comprovou Pending sem concessão com Payments parado e recuperação entre pods com PVCs. G8 comprovou cadastro/compra com broker parado, Outboxes preservadas após reinício dos produtores, concorrência, replay e isolamento de evento inválido. Requisitos rastreados na [matriz](../challenge/traceability.md).

## Cuidados ao reproduzir

Scripts criam dados de demonstração e podem reiniciar containers/pods ou alterar temporariamente o modo de pagamento. Executar em janela sem compras concorrentes, seguindo os guias. Não publicar .env, Secrets, JWT, senhas ou saída de `docker compose config` expandida. G8 preserva deliberadamente um evento inválido na fila de erro; isso não representa uma compra real pendente.

Não foram validados carga prolongada, alta disponibilidade, perda de nó ou restauração de backup. A emissão no console não oferece exactly-once físico. A submissão acadêmica e o acesso do avaliador aos links exigem conferência separada.
