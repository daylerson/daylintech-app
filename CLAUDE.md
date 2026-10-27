# DaylinTech — app de orçamentos

App da DaylinTech, empresa de instalação de câmeras, alarmes, interfones, fechaduras digitais e elétrica. Slogan: "Tecnologia que protege". Toda a interface é em português do Brasil.

## Estrutura

- `index.html`: o app inteiro em um arquivo, com HTML, CSS e JavaScript puro, sem framework. Logo e imagens estão embutidas em base64.
- `dados/backup-daylintech.json`: dados reais exportados (produtos, clientes, orçamentos e `empresa`). Tem o mesmo formato que o app grava no `localStorage` (chave `daylintech:v1`). **Só local: `dados/` e `*.json` estão no `.gitignore`**, porque o site é público e o arquivo tem CPF de clientes, chave Pix e assinatura. Nunca commitar dados reais.
- `dados/<coleção>/*.json`: os mesmos dados, um arquivo por documento.
- `config.js`: URL e chave pública (anon/publishable) do Supabase. Vazio = modo local, só no navegador. Nunca colocar a chave `service_role`/secret.
- `supabase/schema.sql`: tabelas `docs` e `membros`, regras de acesso (RLS) e realtime. Rodar uma vez no SQL Editor do Supabase.
- `vendor/supabase-2.117.3.js`: biblioteca do Supabase servida pelo próprio site (funciona offline pelo service worker). Para atualizar, trocar o arquivo e `SUPABASE_SRC` no index.html e a lista em `sw.js`.
- `manifest.webmanifest`, `sw.js` e `icons/`: PWA (instalar na tela inicial e abrir sem internet). O service worker busca na rede primeiro e usa o cache só offline. Ao mudar a lista de arquivos do cache, subir a versão em `CACHE`.

Para rodar, sirva a pasta com qualquer servidor estático (ex.: `npx serve .`). O app abre vazio. Para carregar os dados, use **Empresa → Restaurar backup** e escolha o `.json`. **Exportar backup** baixa um `.json` com tudo, no mesmo formato.

## Telas

- Início: frase do dia, financeiro do mês, meta e avisos.
- Orçamentos e editor: materiais e mão de obra separados.
- Proposta, com fechamento (aceite, pagamento e recibo).
- Catálogo de materiais: foto, datasheet, várias lojas por produto, importação de cotação.
- Mão de obra.
- Clientes.
- Empresa: preços e impostos, Pix, cartão, WhatsApp, assinatura e backup (exportar e restaurar).

## Regras de negócio importantes

- Preço de venda = custo ÷ (1 − (imposto% + despesas% + lucro%)), arredondado para cima conforme `empresa.arredondar`.
- Custo do produto = preço da loja fixada ou, se nenhuma estiver fixada, da loja mais barata em `fornecedores`.
- Mão de obra são produtos com `categoria: 'servicos'`. Ficam fora do catálogo e da lista de compras.
- Pix: payload BR Code estático com CRC16-CCITT (funções `pixPayload` e `crc16`). Desconto do Pix em `empresa.descontoPix`.
- Cartão: parcelas pela tabela Price, acima de `cartaoSemJuros`, com juros de `cartaoJuros` ao mês.
- A proposta baixada é um HTML autônomo para o cliente. Ela mostra o Pix, o cartão e o aceite, que gera mensagem no WhatsApp (`wa.me`). No app, "Registrar aceite" lê essa mensagem.
- Status dos orçamentos: rascunho, enviado, revisao, aprovado, recusado, execucao, concluido. Pagamento em `o.pgto` e aceite em `o.aceite`.

## O que dependia do Claude (artefato) e precisa ser trocado

O app foi feito como artefato do claude.ai e usa `window.claude.use(...)`. Fora do Claude, essas funções não existem:

- `db`: já trocado. Com `config.js` preenchido, o app usa o Supabase com login (e-mail e senha); sem ele, cai para o `localStorage`.
- `downloads`: já trocado. `baixar()` agora faz download comum (Blob + `<a download>`).
- `sample`: leitura de cotações com IA (`lerCotacao`). Fora do Claude, precisa de um backend que chame a API da Anthropic. Nunca colocar a chave de API no front-end.

## Banco na nuvem (Supabase)

- Tudo fica na tabela `docs` (`col`, `id`, `data` jsonb), um registro por documento, no mesmo formato do backup. A empresa é `col='config'`, `id='empresa'`.
- `nuvemDb()` no index.html imita a API do banco do artefato (`collection().doc().set/delete`, `onSnapshot`), então `store` e as telas não mudaram. Atualiza ao vivo pelo realtime e recarrega tudo ao voltar para o app.
- Dados da empresa são compartilhados: qualquer e-mail na tabela `membros` vê e edita tudo. Quem não está lá entra, mas vê a tela "Sem acesso" e o banco não devolve nada.
- Usuários são criados no painel do Supabase (Authentication → Users → Add user, com "Auto confirm"). Deixar desligado o cadastro público ("Allow new users to sign up").
- Login, "Esqueci a senha" (link volta ao site e abre "Criar nova senha") e "Sair" na aba Empresa.
- Ao entrar com a nuvem vazia, o app oferece enviar os dados que estão no `localStorage` daquele aparelho. "Restaurar backup" na nuvem substitui tudo em lote (`db.importar`).

## Próximos passos sugeridos

1. ~~Trocar `baixar()` por download comum.~~ Feito.
2. Publicar em hospedagem estática (Vercel, Netlify ou GitHub Pages) para abrir no celular. A parte de PWA já está pronta.
3. ~~Banco real com login.~~ Feito (Supabase). Falta criar o projeto e preencher `config.js`.
4. Proposta como página online com link, para o aceite cair direto no sistema. Pix automático exige integração com um banco ou empresa de pagamentos (Mercado Pago, Asaas etc.).
