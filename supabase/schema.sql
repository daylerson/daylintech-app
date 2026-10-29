-- DaylinTech: banco do app de orçamentos.
-- Rodar uma vez no Supabase: SQL Editor → New query → colar tudo → Run.
--
-- Todos os dados (produtos, clientes, orçamentos e a configuração da empresa)
-- ficam na tabela "docs", um registro por documento, no mesmo formato do backup.
-- Só quem está na tabela "membros" consegue ler ou gravar qualquer coisa.

create table if not exists public.docs (
  col            text        not null check (col in ('produtos', 'clientes', 'orcamentos', 'config', 'veiculos', 'gastos', 'compras')),
  id             text        not null,
  data           jsonb       not null,
  atualizado_em  timestamptz not null default now(),
  atualizado_por uuid                 default auth.uid(),
  primary key (col, id)
);

-- E-mails com acesso ao app. Não tem nenhuma regra de acesso de propósito:
-- pelo app ninguém lê nem altera. Edite pelo painel do Supabase (Table Editor).
create table if not exists public.membros (
  email text primary key check (email = lower(email))
);

-- Quem está logado está na lista de membros?
create or replace function public.e_membro()
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1 from public.membros
    where email = lower(coalesce(auth.jwt() ->> 'email', ''))
  );
$$;

revoke all on function public.e_membro() from public, anon;
grant execute on function public.e_membro() to authenticated;

create or replace function public.docs_carimbo()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  new.atualizado_em := now();
  new.atualizado_por := auth.uid();
  return new;
end;
$$;

drop trigger if exists docs_carimbo on public.docs;
create trigger docs_carimbo before insert or update on public.docs
  for each row execute function public.docs_carimbo();

alter table public.docs    enable row level security;
alter table public.membros enable row level security;

revoke all on public.docs    from anon;
revoke all on public.membros from anon, authenticated;

drop policy if exists "membros leem"    on public.docs;
drop policy if exists "membros incluem" on public.docs;
drop policy if exists "membros alteram" on public.docs;
drop policy if exists "membros apagam"  on public.docs;
create policy "membros leem"    on public.docs for select to authenticated using (public.e_membro());
create policy "membros incluem" on public.docs for insert to authenticated with check (public.e_membro());
create policy "membros alteram" on public.docs for update to authenticated using (public.e_membro()) with check (public.e_membro());
create policy "membros apagam"  on public.docs for delete to authenticated using (public.e_membro());

-- Atualização ao vivo entre aparelhos.
do $$
begin
  if exists (select 1 from pg_publication where pubname = 'supabase_realtime')
     and not exists (select 1 from pg_publication_tables
                     where pubname = 'supabase_realtime' and schemaname = 'public' and tablename = 'docs') then
    alter publication supabase_realtime add table public.docs;
  end if;
end $$;

-- Troque pelo e-mail que você vai usar para entrar (em minúsculas).
-- Para dar acesso a outra pessoa, repita esta linha com o e-mail dela.
insert into public.membros (email) values ('seu-email@exemplo.com') on conflict do nothing;
