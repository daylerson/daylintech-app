// DaylinTech: lê a cotação de um distribuidor com o Claude e devolve os itens em JSON.
// Usada por "Importar cotação" no app (função nuvemLeitor no index.html).
//
// Publicar: Supabase → Edge Functions → Deploy a new function → Via Editor,
// nome "ler-cotacao", colar este arquivo inteiro.
// Segredo: Edge Functions → Secrets → ANTHROPIC_API_KEY (chave de console.anthropic.com).
// A chave fica só aqui no servidor. Nunca colocar no site.
//
// Só atende quem está logado e está na tabela "membros" (função e_membro do schema.sql),
// para ninguém de fora gastar os créditos da API.

import Anthropic from "npm:@anthropic-ai/sdk@0.133.0";
import { createClient } from "npm:@supabase/supabase-js@2.117.3";

const MAX_IMAGENS = 5;
const MAX_PROMPT = 200_000;

const cors = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};
const responder = (status: number, corpo: unknown) =>
  new Response(JSON.stringify(corpo), { status, headers: { ...cors, "Content-Type": "application/json" } });

// Formato exato que o app espera (o mesmo pedido no texto do prompt).
const ouNulo = (t: Record<string, unknown>) => ({ anyOf: [t, { type: "null" }] });
const FORMATO = {
  type: "object",
  additionalProperties: false,
  required: ["distribuidora", "frete", "itens"],
  properties: {
    distribuidora: ouNulo({ type: "string" }),
    frete: ouNulo({ type: "number" }),
    itens: {
      type: "array",
      items: {
        type: "object",
        additionalProperties: false,
        required: ["descricao", "codigo", "qtd", "custoUnitario", "produtoId", "confianca", "novo"],
        properties: {
          descricao: { type: "string" },
          codigo: ouNulo({ type: "string" }),
          qtd: { type: "number" },
          custoUnitario: { type: "number" },
          produtoId: ouNulo({ type: "string" }),
          confianca: { type: "string", enum: ["alta", "media", "baixa"] },
          novo: ouNulo({
            type: "object",
            additionalProperties: false,
            required: ["nome", "categoria", "marca", "modelo", "unidade"],
            properties: {
              nome: { type: "string" },
              categoria: {
                type: "string",
                enum: ["cameras", "alarmes", "interfones", "fechaduras", "acessorios", "eletrica", "servicos"],
              },
              marca: { type: "string" },
              modelo: { type: "string" },
              unidade: { type: "string" },
            },
          }),
        },
      },
    },
  },
};

const client = new Anthropic(); // lê ANTHROPIC_API_KEY

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: cors });
  if (req.method !== "POST") return responder(405, { erro: "metodo" });

  // Chave pública do projeto: a que o app manda no cabeçalho "apikey" (projetos novos não têm
  // mais a SUPABASE_ANON_KEY); a checagem de verdade é o login do usuário, logo abaixo.
  const chavePublica = req.headers.get("apikey") || Deno.env.get("SUPABASE_ANON_KEY") || "";
  const sb = createClient(Deno.env.get("SUPABASE_URL")!, chavePublica, {
    global: { headers: { Authorization: req.headers.get("Authorization") ?? "" } },
  });
  const { data: membro, error: erroMembro } = await sb.rpc("e_membro");
  if (erroMembro || !membro) return responder(403, { erro: "sem_acesso" });
  if (!Deno.env.get("ANTHROPIC_API_KEY")) return responder(500, { erro: "sem_chave" });

  let corpo: { prompt?: unknown; imagens?: unknown };
  try {
    corpo = await req.json();
  } catch {
    return responder(400, { erro: "corpo" });
  }
  const prompt = String(corpo.prompt ?? "").slice(0, MAX_PROMPT);
  const imagens = (Array.isArray(corpo.imagens) ? corpo.imagens : [])
    .filter((x): x is string => typeof x === "string" && x.length > 0)
    .slice(0, MAX_IMAGENS);
  if (!prompt) return responder(400, { erro: "corpo" });

  const content: Anthropic.Beta.BetaContentBlockParam[] = [
    ...imagens.map((data) => ({
      type: "image" as const,
      source: { type: "base64" as const, media_type: "image/jpeg" as const, data: data.replace(/^data:[^,]*,/, "") },
    })),
    { type: "text", text: prompt },
  ];

  try {
    const r = await client.beta.messages.create({
      model: "claude-opus-5-5",
      max_tokens: 16000,
      // Se o modelo recusar, o próprio servidor tenta de novo no modelo recomendado.
      betas: ["server-side-fallback-2026-07-01"],
      fallbacks: "default",
      output_config: { effort: "medium", format: { type: "json_schema", schema: FORMATO } },
      messages: [{ role: "user", content }],
    });
    if (r.stop_reason === "refusal") return responder(422, { erro: "refused" });
    if (r.stop_reason === "max_tokens") return responder(422, { erro: "prompt_too_large" });
    const texto = r.content.flatMap((b) => (b.type === "text" ? [b.text] : [])).join("");
    try {
      return responder(200, { dados: JSON.parse(texto) });
    } catch {
      return responder(502, { erro: "invalid_json" });
    }
  } catch (e) {
    if (e instanceof Anthropic.RateLimitError) return responder(429, { erro: "rate_limited" });
    if (e instanceof Anthropic.AuthenticationError) return responder(500, { erro: "chave_invalida" });
    if (e instanceof Anthropic.PermissionDeniedError) return responder(500, { erro: "chave_invalida" });
    if (e instanceof Anthropic.BadRequestError) return responder(400, { erro: "rejeitado", detalhe: e.message });
    if (e instanceof Anthropic.APIError) return responder(502, { erro: "api", detalhe: String(e.status) });
    return responder(500, { erro: "falha" });
  }
});
