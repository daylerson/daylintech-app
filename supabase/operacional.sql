-- DaylinTech: libera no banco os dados da aba Operacional (carro, gastos do carro e lista de compras).
-- Rodar uma vez no Supabase, DEPOIS do schema.sql: SQL Editor → New query → colar tudo → Run.
-- Pode rodar de novo sem problema. Não apaga nada: só aumenta a lista de tipos de dado aceitos.
-- As regras de acesso continuam as mesmas: só quem está na tabela "membros" lê ou grava.

alter table public.docs drop constraint if exists docs_col_check;
alter table public.docs add constraint docs_col_check
  check (col in ('produtos', 'clientes', 'orcamentos', 'config', 'veiculos', 'gastos', 'compras'));
