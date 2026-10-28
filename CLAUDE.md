# DaylinTech — app de orçamentos

App da DaylinTech, empresa de instalação de câmeras, alarmes, interfones, fechaduras digitais e elétrica. Slogan: "Tecnologia que protege". Toda a interface é em português do Brasil.

## Estrutura

- `index.html`: o app inteiro em um arquivo, com HTML, CSS e JavaScript puro, sem framework. Logo e imagens estão embutidas em base64.
- `dados/backup-daylintech.json`: dados reais exportados (produtos, clientes, orçamentos e `empresa`). Tem o mesmo formato que o app grava no `localStorage` (chave `daylintech:v1`). **Só local: `dados/` e `*.json` estão no `.gitignore`**, porque o site é público e o arquivo tem CPF de clientes, chave Pix e assinatura. Nunca commitar dados reais.
- `dados/<coleção>/*.json`: os mesmos dados, um arquivo por documento.
- `config.js`: URL e chave pública (anon/publishable) do Supabase. Vazio = modo local, só no navegador. Nunca colocar a chave `service_role`/secret.
- `supabase/schema.sql`: tabelas `docs` e `membros`, regras de acesso (RLS) e realtime. Rodar uma vez no SQL Editor do Supabase.
- `supabase/propostas.sql`: tabela `propostas` e funções `ver_proposta` / `aceitar_proposta` (proposta com link). Rodar depois do schema.sql.
- `supabase/fotos.sql`: pasta privada `os-fotos` no Storage para as fotos das OS, só para membros. Rodar depois do schema.sql.
- `supabase/functions/ler-cotacao/index.ts`: Edge Function que lê cotações com a API da Anthropic (`claude-opus-5-5`, saída em JSON Schema, `fallbacks: "default"`). Só atende membros (`e_membro`). Precisa do segredo `ANTHROPIC_API_KEY` no Supabase. Publicada pelo painel (Edge Functions → editor), não pelo GitHub Pages.
- `proposta.html`: página pública que o cliente abre (`proposta.html#<token>`), sem login.
- `vendor/html2canvas-1.4.1.min.js` e `vendor/jspdf-4.2.1.umd.min.js`: geram o recibo em PDF (`reciboPDF()`), carregados só quando o recibo abre.
- `vendor/supabase-2.117.3.js`: biblioteca do Supabase servida pelo próprio site (funciona offline pelo service worker). Para atualizar, trocar o arquivo e `SUPABASE_SRC` no index.html e a lista em `sw.js`.
- `manifest.webmanifest`, `sw.js` e `icons/`: PWA (instalar na tela inicial e abrir sem internet). O service worker busca na rede primeiro e usa o cache só offline. Ao mudar a lista de arquivos do cache, subir a versão em `CACHE`.

Para rodar, sirva a pasta com qualquer servidor estático (ex.: `npx serve .`). O app abre vazio. Para carregar os dados, use **Empresa → Restaurar backup** e escolha o `.json`. **Exportar backup** baixa um `.json` com tudo, no mesmo formato.

## Telas

- Início: frase do dia, financeiro do mês, meta e avisos.
- Orçamentos e editor: materiais e mão de obra separados.
- Proposta, com fechamento (aceite, pagamento, recibo e agendamento).
- Ordem de serviço (`view os`, `vOS()`): andamento (iniciar/finalizar serviço, corrigir horários), fotos antes e depois, relatório do serviço, assinaturas do técnico e do cliente, PDF, envio ao cliente e concluir.
- Agenda: instalações atrasadas, de hoje, próximas, aguardando agendamento (com a data limite pelo prazo da proposta) e concluídas.
- Catálogo de materiais: foto, datasheet, várias lojas por produto, importação de cotação.
- Mão de obra.
- Clientes.
- Empresa: preços e impostos, Pix, cartão, WhatsApp, assinatura e backup (exportar e restaurar).

## Regras de negócio importantes

- Preço de venda = custo ÷ (1 − (imposto% + despesas% + lucro%)), arredondado para cima conforme `empresa.arredondar`.
- Custo do produto = preço da loja fixada ou, se nenhuma estiver fixada, da loja mais barata em `fornecedores`.
- Mão de obra são produtos com `categoria: 'servicos'`. Ficam fora do catálogo e da lista de compras.
- Pix: payload BR Code estático com CRC16-CCITT (funções `pixPayload` e `crc16`). Desconto do Pix em `empresa.descontoPix`.
- Cartão: a proposta não mostra tabela de parcelas, só uma linha (`cartaoTxt()`, ex.: "em 3x sem juros ou em até 12x com juros da operadora", a partir de `cartaoSemJuros` e `cartaoMax`). O bloco "Formas de pagamento" mostra o Pix e uma caixa do cartão; o botão "Pagar com cartão" usa o link do orçamento (`o.linkPagamento`, campo em Editar → Condições, gerado com o valor daquele orçamento) ou, na falta dele, `empresa.linkPagamento`. Duplicar não copia o link. No aceite, cartão vai com o valor total (`parc[0]`). A função `parcelas()` (tabela Price) continua no código, mas não aparece para o cliente.
- Com a nuvem ligada, "Link da proposta" grava uma cópia da proposta (`css`, `corpo`, `dados`) em `propostas` com um token aleatório de 43 caracteres (`o.linkToken`) e gera `proposta.html#token`. Clicar de novo atualiza a cópia e mantém o link. O cliente só acessa pelas funções `security definer`; o valor do aceite é calculado no banco a partir de `dados` (`totalN`, `vpN`, `parc[].tN`), não do navegador. O aceite grava `o.aceite` (com `via: 'link'`) e muda o status para aprovado direto na tabela `docs`, e o app avisa pelo realtime. Excluir o orçamento apaga a página; "Desfazer aceite" libera o link de novo; "Duplicar" não copia o link.
- WhatsApp do cliente: o aceite pede o WhatsApp (`aceite.whats`, parâmetro `p_whats` de `aceitar_proposta`; `proposta.html` tenta de novo sem ele se o banco ainda tiver a função antiga). `completarCliente()` grava CPF e WhatsApp no cadastro se estiverem vazios. Quando o aceite chega pelo realtime, `avisoAceite()` abre "Proposta aceita!" (ou só um aviso rápido se houver outra janela aberta ou o editor estiver aberto). `mensagemCliente()` abre o WhatsApp da empresa com a mensagem pronta para o cliente (`textoCliente()`, que muda conforme Pix, cartão ou a combinar e não fala de pagar se `o.pgto` existir). O recibo sai em PDF (logo, assinatura, CNPJ). "Enviar no WhatsApp": no celular abre o Compartilhar do aparelho com o PDF anexado (Web Share API; o PDF é gerado ao abrir o recibo para o toque não perder a permissão); no computador baixa o PDF e abre a conversa do cliente para anexar. "Baixar PDF" baixa o arquivo. Não é envio automático: automático exigiria a API oficial do WhatsApp (Meta), com função no Supabase.
- A proposta baixada é um HTML autônomo para o cliente. Ela mostra o Pix, o cartão e o aceite, que gera mensagem no WhatsApp (`wa.me`). No app, "Registrar aceite" lê essa mensagem.
- Texto de pagamento: cada orçamento guarda o seu (`o.pagamento`), copiado de `empresa.pagamento`. `atualizarTextos()` troca, ao carregar e depois de importar backup, os textos padrão antigos (`PAG_ANTIGOS`) pelo atual de `DEF_EMPRESA`. Texto personalizado não é mexido. Ao mudar o padrão, colocar o anterior em `PAG_ANTIGOS`.
- A proposta não tem linha de assinatura do cliente (o aceite é pelo link ou WhatsApp). O Pix aparece numa caixa compacta: QR Code pequeno, valor e botão "Copiar código Pix".
- Agendamento / OS: `o.agenda` = `{data, hora, endereco, tecnico, duracao, obs, concluidoEm}`. `prazoLimite()` lê o prazo da proposta ("N dias [úteis]") e conta a partir de `aceite.data`, pulando sábado e domingo se forem úteis (feriados não). `osHTML()` é a ordem de serviço (serviços e materiais sem preço, assinaturas do técnico e do cliente) e sai em PDF por `htmlPDF()`, o mesmo do recibo. "Confirmar no WhatsApp" usa `textoAgenda()` e `enviarComPDF()` (celular: Compartilhar com a OS anexada; computador: conversa com o texto). Agendar não muda o status; "Concluir" muda para concluido. Execução da OS em `o.agenda`: `inicio`, `fim`, `relatorio`, `assTec`, `assCli`, `assCliNome`, `assCliEm` (assinaturas em PNG data URL, desenhadas em `padAssinatura()`), `fotos: {antes:[], depois:[]}`. Cada foto é `{p}` (caminho no Storage `os-fotos/<id do orçamento>/...`, com nuvem) ou `{d}` (data URL, sem nuvem). As fotos ficam em `fotoCache` na memória; `cortar43()` recorta para o PDF porque o html2canvas não faz `object-fit`. Sem assinatura do técnico, a OS usa `empresa.assinatura` se o técnico for o responsável. `htmlPDF()` quebra em várias páginas A4, cortando entre blocos. Excluir o orçamento apaga as fotos; Duplicar não copia o agendamento.
- Status dos orçamentos: rascunho, enviado, revisao, aprovado, recusado, execucao, concluido. Pagamento em `o.pgto` e aceite em `o.aceite`.

## O que dependia do Claude (artefato) e precisa ser trocado

O app foi feito como artefato do claude.ai e usa `window.claude.use(...)`. Fora do Claude, essas funções não existem:

- `db`: já trocado. Com `config.js` preenchido, o app usa o Supabase com login (e-mail e senha); sem ele, cai para o `localStorage`.
- `downloads`: já trocado. `baixar()` agora faz download comum (Blob + `<a download>`).
- Leitura grátis de cotação (padrão): `LEITOR_GRATIS` em `lerCotacao()`. Texto do PDF (pdf.js) ou planilha, e foto por OCR no aparelho (Tesseract.js 7.0.0 em português, baixado do jsDelivr na primeira vez, `ocrImagens()`). `lerTextoCotacao()` acha em cada linha código, quantidade (escolhida pela conta qtd × unitário = total), preço e frete, e associa ao catálogo por código/modelo ("mesmo modelo") ou por palavras do nome ("parecido"). Fica entre os marcadores `leitor-gratis:inicio/fim`. Com nuvem, a janela de importar deixa escolher "Grátis, no aparelho" ou "Com IA" (lembrado em `localStorage` `dt:leitura`).
- `sample`: já trocado. Com a nuvem ligada, `getSample()` devolve `nuvemLeitor`, que chama a função `ler-cotacao` do Supabase com o mesmo formato (`limits()`, `json()`); os códigos de erro dela viram mensagens em `MSG_SAMPLE`. A chave da Anthropic fica só nos segredos do Supabase, nunca no site.

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
3. ~~Banco real com login.~~ Feito (Supabase).
4. ~~Proposta como página online com link.~~ Feito.
5. Pix automático (confirmação do pagamento sem conferir o extrato) exige integração com um banco ou empresa de pagamentos (Mercado Pago, Asaas etc.), com backend.
