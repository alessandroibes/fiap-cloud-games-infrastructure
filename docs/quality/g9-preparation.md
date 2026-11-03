# G9 — Preparação documental e entrega

Data: 03/11/2026 (America/Sao_Paulo). **Em preparação; entrega acadêmica ainda não concluída.**

## Artefatos

- READMEs revisados com finalidade, configuração, links reais, execução integrada e acesso à documentação de cada serviço.
- [Visão técnica](../architecture/system-overview.md) com diagrama, responsabilidades, compra assíncrona e limites.
- [Índice de evidências](evidence-index.md) com resultados executados e comandos reproduzíveis.
- Materiais acadêmicos em docs/course/, exclusivamente locais e ignorados: roteiro de vídeo e checklist de evidências. Essa localização segue a organização definida pelo responsável. O relatório será criado pelo próprio responsável, conforme confirmação nesta etapa; não é necessário enviar dados pessoais para prepará-lo aqui.

## Conferência dos remotos

`git ls-remote origin refs/heads/main` foi executado por leitura nos cinco clones antes das alterações G9. Todos os remotos coincidiam com o HEAD local G8:

| Repositório | Commit remoto observado |
|---|---|
| fiap-cloud-games-users | ee9d4f4 |
| fiap-cloud-games-catalog | a61a80a |
| fiap-cloud-games-payments | 2b95624 |
| fiap-cloud-games-notifications | e11d1f6 |
| fiap-cloud-games-infrastructure | f6a027b |

As URLs do README foram obtidas dos remotos existentes; o origin SSH do Catalog foi apenas representado como link HTTPS, sem alterar a configuração Git. A tentativa de consulta pública pelo navegador de pesquisa retornou cache miss; isso não prova repositório privado nem valida acesso anônimo. O responsável deve confirmar acesso dos avaliadores e publicar os novos commits G9 quando desejar. Nenhum push foi executado nesta etapa.

## Pendências para conclusão

- Gravar vídeo real de até 20 minutos, publicar conforme regras da turma e fornecer URL acessível.
- Responsável criar o relatório final com grupo, participantes, Discord e links exigidos; conferir documentos e acesso dos avaliadores.
- Publicar os commits documentais G9 e conferir que o relatório aponta para o conteúdo final.
- Efetuar a submissão acadêmica pelo responsável.

DEL-201 e DEL-205 não estão validados pela existência de roteiro/checklist. G0–G8 permanecem concluídos; não houve reexecução das suítes apenas por alterações documentais no G9.

## Validação documental

- Conferidos 120 links locais em 12 arquivos, sem destinos ausentes ou marcadores residuais de template.
- `git diff --check` executado nos cinco repositórios, sem erros.
- `git check-ignore` confirmou que os três materiais de docs/course/ e as configurações locais .env/.env.k8s.local ficam ignorados; nenhum arquivo de docs/course/ é rastreado.
- Fase 1 sem alterações no `git status --short`.
- Roteiro planejado com 18min30s e margem de 1min30s; duração real depende do ensaio e da gravação pelo responsável.

Alterações restritas à documentação; não foram executadas migrations, implantação ou suítes de aplicação nesta etapa.
