-- DaylinTech: fotos das ordens de serviço (antes e depois).
-- Rodar uma vez no Supabase, DEPOIS do schema.sql: SQL Editor → New query → colar tudo → Run.
-- Pode rodar de novo sem problema.
--
-- As fotos ficam numa pasta privada do Storage ("os-fotos"), uma subpasta por orçamento.
-- Só quem está na tabela "membros" consegue ver, enviar ou apagar.

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('os-fotos', 'os-fotos', false, 5242880, array['image/jpeg'])
on conflict (id) do update
  set public = false, file_size_limit = excluded.file_size_limit, allowed_mime_types = excluded.allowed_mime_types;

drop policy if exists "membros veem fotos da OS"    on storage.objects;
drop policy if exists "membros enviam fotos da OS"  on storage.objects;
drop policy if exists "membros alteram fotos da OS" on storage.objects;
drop policy if exists "membros apagam fotos da OS"  on storage.objects;

create policy "membros veem fotos da OS" on storage.objects for select to authenticated
  using (bucket_id = 'os-fotos' and public.e_membro());
create policy "membros enviam fotos da OS" on storage.objects for insert to authenticated
  with check (bucket_id = 'os-fotos' and public.e_membro());
create policy "membros alteram fotos da OS" on storage.objects for update to authenticated
  using (bucket_id = 'os-fotos' and public.e_membro()) with check (bucket_id = 'os-fotos' and public.e_membro());
create policy "membros apagam fotos da OS" on storage.objects for delete to authenticated
  using (bucket_id = 'os-fotos' and public.e_membro());
