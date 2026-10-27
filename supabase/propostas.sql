-- DaylinTech: proposta com link para o cliente.
-- Rodar uma vez no Supabase, DEPOIS do schema.sql: SQL Editor → New query → colar tudo → Run.
-- Pode rodar de novo sem problema.
--
-- Cada link tem um código aleatório (token) de 43 caracteres. O cliente não faz login:
-- ele só consegue ver e aceitar a proposta daquele código, pelas funções ver_proposta e
-- aceitar_proposta. A tabela em si continua fechada para quem não é membro.

create table if not exists public.propostas (
  token        text        primary key check (length(token) >= 32),
  orcamento_id text        not null,
  css          text        not null,
  corpo        text        not null,
  dados        jsonb       not null,
  criado_em    timestamptz not null default now(),
  criado_por   uuid                 default auth.uid(),
  visto_em     timestamptz,
  aceite       jsonb,
  aceito_em    timestamptz
);
create index if not exists propostas_orcamento on public.propostas (orcamento_id);

alter table public.propostas enable row level security;
revoke all on public.propostas from anon;

drop policy if exists "membros gerenciam" on public.propostas;
create policy "membros gerenciam" on public.propostas for all to authenticated
  using (public.e_membro()) with check (public.e_membro());

-- O cliente abre o link.
create or replace function public.ver_proposta(p_token text)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  r public.propostas;
begin
  select * into r from public.propostas where token = p_token;
  if not found then
    return null;
  end if;
  if r.visto_em is null and not public.e_membro() then
    update public.propostas set visto_em = now() where token = p_token;
  end if;
  return jsonb_build_object('css', r.css, 'corpo', r.corpo, 'dados', r.dados, 'aceite', r.aceite);
end;
$$;

-- O cliente aceita. O valor vem do que foi gravado na proposta, não do navegador do cliente.
create or replace function public.aceitar_proposta(p_token text, p_nome text, p_doc text, p_forma text, p_parcela int default 0)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  r public.propostas;
  parc jsonb;
  ac jsonb;
  v_valor numeric;
  v_parcelas int := 1;
begin
  select * into r from public.propostas where token = p_token for update;
  if not found then
    raise exception 'proposta não encontrada' using errcode = 'P0002';
  end if;
  if r.aceite is not null then
    return r.aceite;  -- já aceita: não sobrescreve
  end if;

  p_nome := left(btrim(coalesce(p_nome, '')), 200);
  p_doc  := left(btrim(coalesce(p_doc, '')), 30);
  if p_nome = '' then
    raise exception 'informe o nome' using errcode = '22023';
  end if;

  if p_forma = 'pix' and (r.dados ? 'vpN') then
    v_valor := (r.dados ->> 'vpN')::numeric;
  elsif p_forma = 'cartao' then
    parc := r.dados -> 'parc' -> coalesce(p_parcela, 0);
    if parc is null or coalesce(p_parcela, 0) < 0 then
      raise exception 'parcelamento inválido' using errcode = '22023';
    end if;
    v_valor := (parc ->> 'tN')::numeric;
    v_parcelas := (parc ->> 'n')::int;
  else
    p_forma := 'combinar';
    v_valor := (r.dados ->> 'totalN')::numeric;
  end if;

  ac := jsonb_build_object(
    'nome', p_nome, 'doc', p_doc, 'forma', p_forma, 'parcelas', v_parcelas,
    'valor', v_valor, 'data', to_char(now() at time zone 'utc', 'YYYY-MM-DD"T"HH24:MI:SS.MS"Z"'),
    'via', 'link');

  update public.propostas set aceite = ac, aceito_em = now() where token = p_token;

  -- Marca o orçamento como aprovado no app (aparece na hora para quem estiver com ele aberto).
  update public.docs
     set data = data || jsonb_build_object(
           'aceite', ac,
           'status', case when data ->> 'status' in ('aprovado', 'execucao', 'concluido') then data ->> 'status' else 'aprovado' end,
           'atualizadoEm', ac ->> 'data')
   where col = 'orcamentos' and id = r.orcamento_id;

  return ac;
end;
$$;

revoke all on function public.ver_proposta(text) from public;
revoke all on function public.aceitar_proposta(text, text, text, text, int) from public;
grant execute on function public.ver_proposta(text) to anon, authenticated;
grant execute on function public.aceitar_proposta(text, text, text, text, int) to anon, authenticated;
