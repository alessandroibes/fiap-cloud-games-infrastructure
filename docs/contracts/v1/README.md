# Contratos de integração V1 — aceitos

**Status:** Aceito (ADR-P2-004). A FIAP exige os três eventos; os campos adicionais são decisões do projeto.

Esta pasta é a especificação canônica versionada. Conferência documental em 30/10/2026: campos e exemplos JSON alinhados ao ADR-P2-004. Testes C#/MassTransit ainda serão implementados em G1; não inferir interoperabilidade executada desta revisão.

- `user-created-v1.md`
- `order-placed-v1.md`
- `payment-processed-v1.md`

Contratos C# locais por serviço no namespace `FiapCloudGames.Contracts.V1`, especificação central no repositório de infraestrutura e testes de compatibilidade de JSON e identidade MassTransit. Alterações incompatíveis exigem V2.

`OccurredAt` é UTC; GUID para IDs; `decimal` em BRL; `Approved` e `Rejected` são os únicos resultados. `CorrelationId` não integra obrigatoriamente o payload V1 aprovado; a correlação de negócio usa `OrderId` e a técnica pode utilizar cabeçalhos do transporte.
