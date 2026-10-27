# DaylinTech — app de orçamentos

App da DaylinTech, empresa de instalação de câmeras, alarmes, interfones, fechaduras digitais e elétrica. Slogan: "Tecnologia que protege". Toda a interface é em português do Brasil.

## Estrutura

- `index.html`: o app inteiro em um arquivo, com HTML, CSS e JavaScript puro, sem framework. Logo e imagens estão embutidas em base64.
- `dados/backup-daylintech.json`: dados reais exportados (produtos, clientes, orçamentos e `empresa`). Tem o mesmo formato que o app grava no `localStorage` (chave `daylintech:v1`).
- `dados/<coleção>/*.json`: os mesmos dados, um arquivo por documento.
- `manifest.webmanifest`, `sw.js` e `icons/`: PWA (instalar na tela inicial e abrir sem internet). O service worker busca na rede primeiro e usa o cache só offline. Ao mudar a lista de arquivos do cache, subir a versão em `CACHE`.

Para rodar, sirva a pasta com qualquer servidor estático (ex.: `npx serve .`). Com o `localStorage` vazio, o app carrega o backup sozinho.

## Telas

- Início: frase do dia, financeiro do mês, meta e avisos.
- Orçamentos e editor: materiais e mão de obra separados.
- Proposta, com fechamento (aceite, pagamento e recibo).
- Catálogo de materiais: foto, datasheet, várias lojas por produto, importação de cotação.
- Mão de obra.
- Clientes.
- Empresa: preços e impostos, Pix, cartão, WhatsApp e assinatura.

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

- `db`: banco na nuvem. Fora do Claude, o app já cai para o `localStorage`, que guarda os dados só naquele navegador. Para usar em vários aparelhos, trocar o objeto `store` e a função `initStore` por um banco real (ex.: Supabase ou Firebase), com login.
- `downloads`: já trocado. `baixar()` agora faz download comum (Blob + `<a download>`).
- `sample`: leitura de cotações com IA (`lerCotacao`). Fora do Claude, precisa de um backend que chame a API da Anthropic. Nunca colocar a chave de API no front-end.

## Próximos passos sugeridos

1. ~~Trocar `baixar()` por download comum.~~ Feito.
2. Publicar em hospedagem estática (Vercel, Netlify ou GitHub Pages) para abrir no celular. A parte de PWA já está pronta.
3. Banco real com login, migrando os dados de `dados/backup-daylintech.json`.
4. Proposta como página online com link, para o aceite cair direto no sistema. Pix automático exige integração com um banco ou empresa de pagamentos (Mercado Pago, Asaas etc.).
