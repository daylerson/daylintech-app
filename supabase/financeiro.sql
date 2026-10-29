-- DaylinTech: libera no banco o Financeiro (e qualquer aba nova daqui para frente, sem precisar rodar SQL de novo).
-- Rodar uma vez no Supabase: SQL Editor → New query → colar tudo → Run.
-- Pode rodar de novo sem problema. Não apaga nada. As regras de acesso continuam as mesmas:
-- só quem está na tabela "membros" lê ou grava.

alter table public.docs drop constraint if exists docs_col_check;
alter table public.docs add constraint docs_col_check check (col ~ '^[a-z_]{1,40}$');
