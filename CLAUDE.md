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
- Garantias (`vGarantias()`): orçamentos aprovados com data de instalação, em garantia (ordem do que vence primeiro) e vencidas, com "Compras e NF" e "Atendimento" (abre OS de garantia).
- Agenda: "Nova OS" (`novaOS()`) para visita técnica, manutenção, garantia etc. sem orçamento. Instalações atrasadas, de hoje, próximas, aguardando agendamento (com a data limite pelo prazo da proposta) e concluídas.
- Catálogo de materiais: foto, datasheet, várias lojas por produto, importação de cotação.
- Mão de obra.
- Clientes: CEP com busca automática pelo ViaCEP (`buscaCEP()`, preenche endereço, bairro e "Cidade - UF"; o cliente guarda `cep`) e botões de rota no Google Maps e no Waze (`rotaURL()`). A Agenda e a OS também têm botão de rota.
- Empresa: preços e impostos, Pix, cartão, WhatsApp, redes sociais e avaliações, assinatura e backup (exportar e restaurar).

## Regras de negócio importantes

- Preço de venda = custo ÷ (1 − (imposto% + despesas% + lucro%)), arredondado para cima conforme `empresa.arredondar`.
- Custo do produto = preço da loja fixada ou, se nenhuma estiver fixada, da loja mais barata em `fornecedores`.
- Mão de obra são produtos com `categoria: 'servicos'`. Ficam fora do catálogo e da lista de compras.
- Pix: payload BR Code estático com CRC16-CCITT (funções `pixPayload` e `crc16`). Desconto do Pix em `empresa.descontoPix`.
- Cartão: a proposta não mostra tabela de parcelas, só uma linha (`cartaoTxt()`, ex.: "em 3x sem juros ou em até 12x com juros da operadora", a partir de `cartaoSemJuros` e `cartaoMax`). O bloco "Formas de pagamento" mostra o Pix e uma caixa do cartão; o botão "Pagar com cartão" usa o link do orçamento (`o.linkPagamento`, campo em Editar → Condições, gerado com o valor daquele orçamento) ou, na falta dele, `empresa.linkPagamento`. Duplicar não copia o link. No aceite, cartão vai com o valor total (`parc[0]`). A função `parcelas()` (tabela Price) continua no código, mas não aparece para o cliente.
- Com a nuvem ligada, "Link da proposta" grava uma cópia da proposta (`css`, `corpo`, `dados`) em `propostas` com um token aleatório de 43 caracteres (`o.linkToken`) e gera `proposta.html#token`. Clicar de novo atualiza a cópia e mantém o link. O cliente só acessa pelas funções `security definer`; o valor do aceite é calculado no banco a partir de `dados` (`totalN`, `vpN`, `parc[].tN`), não do navegador. O aceite grava `o.aceite` (com `via: 'link'`) e muda o status para aprovado direto na tabela `docs`, e o app avisa pelo realtime. Excluir o orçamento apaga a página; "Desfazer aceite" libera o link de novo; "Duplicar" não copia o link.
- WhatsApp do cliente: o aceite pede o WhatsApp (`aceite.whats`, parâmetro `p_whats` de `aceitar_proposta`; `proposta.html` tenta de novo sem ele se o banco ainda tiver a função antiga). `completarCliente()` grava CPF e WhatsApp no cadastro se estiverem vazios. Quando o aceite chega pelo realtime, `avisoAceite()` abre "Proposta aceita!" (ou só um aviso rápido se houver outra janela aberta ou o editor estiver aberto). `mensagemCliente()` abre o WhatsApp da empresa com a mensagem pronta para o cliente (`textoCliente()`, que muda conforme Pix, cartão ou a combinar e não fala de pagar se `o.pgto` existir). O recibo sai em PDF (logo, assinatura, CNPJ). "Enviar no WhatsApp": no celular abre o Compartilhar do aparelho com o PDF anexado (Web Share API; o PDF é gerado ao abrir o recibo para o toque não perder a permissão); no computador baixa o PDF e abre a conversa do cliente para anexar. "Baixar PDF" baixa o arquivo. Não é envio automático: automático exigiria a API oficial do WhatsApp (Meta), com função no Supabase.
- A proposta baixada é um HTML autônomo para o cliente. Ela mostra o Pix, o cartão e o aceite, que gera mensagem no WhatsApp (`wa.me`). No app, "Registrar aceite" lê essa mensagem.
- Textos padrão (pagamento, prazo, garantia): cada orçamento guarda os seus (`o.pagamento`, `o.prazo`, `o.garantia`), copiados da empresa. `atualizarTextos()` troca, ao carregar e depois de importar backup, os textos padrão antigos (`TEXTOS_ANTIGOS`, por campo) pelo atual de `DEF_EMPRESA`, na empresa e nos orçamentos ainda não aceitos (rascunho/enviado/revisão, sem OS avulsa). Texto personalizado não é mexido. Ao mudar um padrão, colocar o anterior em `TEXTOS_ANTIGOS`. O "5%" do texto de pagamento é fixo: se mudar `descontoPix`, mudar o texto.
- Condições na proposta (`.pp-cond`): Prazo e "Tempo estimado de execução" (calculado da mão de obra) lado a lado; pagamento, garantia e observações em linha inteira (`.cond-full`, `white-space:pre-line`).
- Aceite "50% + 50%" (`forma:'metade'`): `dadosCliente` grava `metade`/`metadeN`/`pixMetade` (Pix da entrada); a página mostra "Copiar código Pix da entrada" no bloco `#acc_ent`. `aceitar_proposta` no propostas.sql aceita `'metade'` (banco antigo grava 'combinar' e a página mostra 50% mesmo assim).
- A proposta não tem linha de assinatura do cliente (o aceite é pelo link ou WhatsApp). O Pix aparece numa caixa compacta: QR Code pequeno, valor e botão "Copiar código Pix".
- Agendamento / OS: `o.agenda` = `{data, hora, endereco, tecnico, duracao, obs, concluidoEm}`. `prazoLimite()` lê o prazo da proposta ("N dias [úteis]") e conta a partir de `aceite.data`, pulando sábado e domingo se forem úteis (feriados não). `osHTML()` é a ordem de serviço (serviços e materiais sem preço, assinaturas do técnico e do cliente) e sai em PDF por `htmlPDF()`, o mesmo do recibo. "Confirmar no WhatsApp" usa `textoAgenda()` e `enviarComPDF()` (celular: Compartilhar com a OS anexada; computador: conversa com o texto). Agendar não muda o status; "Concluir" muda para concluido. Execução da OS em `o.agenda`: `inicio`, `fim`, `relatorio`, `assTec`, `assCli`, `assCliNome`, `assCliEm` (assinaturas em PNG data URL, desenhadas em `padAssinatura()`), `fotos: {antes:[], depois:[]}`. Cada foto é `{p}` (caminho no Storage `os-fotos/<id do orçamento>/...`, com nuvem) ou `{d}` (data URL, sem nuvem). As fotos ficam em `fotoCache` na memória; `cortar43()` recorta para o PDF porque o html2canvas não faz `object-fit`. Sem assinatura do técnico, a OS usa `empresa.assinatura` se o técnico for o responsável. `htmlPDF()` quebra em várias páginas A4, cortando entre blocos. Excluir o orçamento apaga as fotos; Duplicar não copia o agendamento.
- Redes e avaliação: `empresa.linkAvaliacao` (link "Pedir avaliações" do Perfil da Empresa no Google), `googlePerfil`, `instagram`, `site`. O recibo e a OS finalizada mostram `avaliacaoHTML()` (estrelas, link e QR em PNG por `qrPNG()`, preparado com `prepAval()` antes de gerar o PDF, porque o PDF é imagem e o link não é clicável); as mensagens do recibo e da OS finalizada terminam com `textoAval()`. A proposta mostra Instagram, site e "Veja nossas avaliações no Google" no rodapé. O pedido é igual para todos os clientes (regra do Google: sem incentivo e sem filtrar quem avalia).
- Compras e garantia (`garantiaSheet()`, no Fechamento passo 5, no cadastro do cliente e na aba Garantias): `o.notas[índice do item] = {nf, data, revenda}` (mesma chave de `o.comprados`) e `o.instaladoEm`. `garantiaInfo()`: instalação = `instaladoEm` ou término da OS; garantia da instalação = instalação + `empresa.garantiaServDias`; dos equipamentos = data da nota (ou instalação) + `empresa.garantiaEquipMeses`.
- OS avulsa: registro em `orcamentos` com `tipo:'os'`, `osTipo` (`OS_TIPOS`), `motivo`, `origemId` (orçamento de origem, na garantia), `status:'aprovado'` e `agenda` já preenchida. Fica fora da lista de Orçamentos e das contagens do Início (entra no financeiro só se tiver valor). Abre direto a tela da OS; "Cobrar" usa o editor de orçamento (que volta para a OS). Na OS cobrada, o PDF tem um bloco único `.os-cob` (Valores, Total, pagamento e assinaturas; `htmlPDF()` não quebra página dentro dele) e depois as fotos; o pagamento (`pagOSHTML()`) é Pix com QR e copia e cola escrito, e cartão com o link escrito (sem QR). O link do cartão (`o.linkPagamento`) é colado na própria OS; `verOS()` avisa se faltar. Com a nuvem, a OS a receber vai também por link (`linkOSOnline()`: cópia na tabela `propostas`, `dados.tipo='os'`, aberta em `proposta.html` com "Copiar código Pix" e "Pagar com cartão"), e o link entra na mensagem (`textoOS(o,link)`). O recibo da OS diz "conforme OS Nº". Mensagens próprias em `textoAgenda()`/`textoOS()`. A numeração é a mesma dos orçamentos.
- Status dos orçamentos: rascunho, enviado, revisao, aprovado, recusado, execucao, concluido. Pagamento em `o.pgto` e aceite em `o.aceite`.

## O que dependia do Claude (artefato) e precisa ser trocado

O app foi feito como artefato do claude.ai e usa `window.claude.use(...)`. Fora do Claude, essas funções não existem:

- `db`: já trocado. Com `config.js` preenchido, o app usa o Supabase com login (e-mail e senha); sem ele, cai para o `localStorage`.
- `downloads`: já trocado. `baixar()` agora faz download comum (Blob + `<a download>`).
- Leitura grátis de cotação (padrão): `LEITOR_GRATIS` em `lerCotacao()`. Texto do PDF (pdf.js) ou planilha, e foto por OCR no aparelho (Tesseract.js 7.0.0 em português, baixado do jsDelivr na primeira vez, `ocrImagens()`). O leitor de OCR fica aberto entre importações e começa a carregar quando a janela de importar abre (`ocrWorker()`); `prepOCR()` amplia prints pequenos para ~1600 px de largura (melhora muito a leitura), reduz fotos grandes e passa para cinza com contraste. `numOCR()` corrige trocas do OCR dentro de números (O→0, l→1, S→5) e `valorBR()` aceita 1.234,56, 189.90 e R$ 189. `lerTextoCotacao()` acha em cada linha código, quantidade (escolhida pela conta qtd × unitário = total), preço e frete, e associa ao catálogo por código/modelo ("mesmo modelo") ou por palavras do nome ("parecido"). Produto novo da leitura grátis sai no padrão do catálogo por `nomeBonito()`: frase normal com acento (`ACENTOS`), siglas e modelos em maiúsculas (`SIGLAS`, letras antes de número), sem código, sem "PÇ/UN" e sem marca (vai para Marca, `MARCAS`); o modelo vai para Modelo. No Catálogo, "Padronizar nomes" (`padronizarNomes()`) aparece quando há produto com nome todo em maiúsculas (`nomeGritado()`) e corrige com prévia, sem mexer em preço. Fica entre os marcadores `leitor-gratis:inicio/fim`. Com nuvem, a janela de importar deixa escolher "Grátis, no aparelho" ou "Com IA" (lembrado em `localStorage` `dt:leitura`).
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

## Aba Impostos (`vImpostos`)
- Dados em `S.empresa.fiscal` (`fiscal()` dá os padrões): `regime` (mei/simples/outro), `ativ`, `inicio` (AAAA-MM), `consulta` (resumo do CNPJ), `das` ({'AAAA-MM':{st:'pago'|'parcelado',data,valor}}; sem registro = em aberto), `anual` e `irpf` ({ano:{st}}; IR é indexado pelo ano-calendário e mostrado como ano+1), `titular`, `extratoEm`, `lembretes`. Salvar com `salvarFiscal(m)`.
- Nunca criar campo de senha do gov.br.
- Consulta do CNPJ: BrasilAPI (`/api/cnpj/v1/`), reserva minhareceita.org. Só dados públicos; débitos não vêm daí (PGMEI tem captcha).
- Valor da guia MEI = 5% do salário mínimo do ano (`SAL_MIN`, atualizar todo janeiro) + ISS/ICMS (`MEI_ATIV`). Vence dia 20 do mês seguinte (`venceGuia`). Multa estimada 0,33%/dia até 20%, sem juros.
- Avisos na página inicial: `avisosFiscais()`. Lembretes: links do Google Agenda com RRULE e arquivo .ics (`icsFiscal`).
- A aba tem `class="internal"` (some no Modo cliente). A barra de baixo usa `grid-auto-flow:column`.

## Corretor de português
- `<body spellcheck="true">` liga o corretor do navegador/teclado em todos os campos.
- Botão "✓ Corrigir português" aparece embaixo de textarea e input de texto dentro de `.field` (não em `.row`, nem com `inputmode`) ao focar (`corrigivel`, listener `focusin`). Usa a API grátis do LanguageTool (`CORR_URL`, pt-BR, ~20 pedidos/min). A troca dispara `input` e `change`, então os campos que salvam sozinhos salvam a correção. `mousedown` com preventDefault no botão e na caixa, para o campo não perder o foco (blur salvaria e redesenharia a tela no meio).
- OS avulsa: "Editar OS" (`agendar`) também edita tipo e motivo.

## Navegação
- `NAV_MAIN` (Início, Orçamentos, Agenda, Clientes, Catálogo) fica na barra; o resto fica em "Mais" (`NAV_MAIS`, `abrirMais`, `data-act="mais"`). Quando a tela atual é do "Mais", o botão mostra o nome dela. Itens com 3º campo 1 são `internal` (somem no Modo cliente).

## Aba Operacional (`vOperacional`: `vCarro` e `vCompras`)
- Coleções novas: `veiculos`, `gastos` (do carro: tipo combustivel/manutencao/reforma/documento/seguro/multa/outro, `veiculoId`), `compras` (status pendente/comprado, prioridade urgente/normal/depois). Lista em `COLS`. O banco precisa do `supabase/operacional.sql` (amplia o check de `docs.col`); sem ele, `salvarOp` avisa.
- Backup: exporta todas as `COLS`; ao restaurar, coleção ausente no arquivo (backup antigo) fica como está.
- Consumo: `trechosConsumo` (km entre tanques cheios ÷ litros colocados depois do anterior).
- "Posto onde estou": geolocalização + Overpass API (amenity=fuel, 800 m); sem posto, endereço pelo Nominatim.
- Avisos de licenciamento/IPVA/seguro (≤30 dias), próxima revisão (≤500 km ou 15 dias), multas a pagar e compras urgentes vão para a página inicial (`avisosOperacionais`).
