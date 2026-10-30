-- DaylinTech: pasta privada "galeria" no Storage, para as fotos e vídeos da aba Galeria.
-- Rodar uma vez no Supabase: SQL Editor → New query → colar tudo → Run. Pode rodar de novo sem problema.
-- Só quem está na tabela "membros" vê, envia ou apaga. Limite de 50 MB por arquivo (o máximo do plano grátis).

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('galeria', 'galeria', false, 52428800,
        array['image/jpeg', 'video/mp4', 'video/quicktime', 'video/webm', 'video/3gpp'])
on conflict (id) do update
  set public = false, file_size_limit = excluded.file_size_limit, allowed_mime_types = excluded.allowed_mime_types;

drop policy if exists "membros veem a galeria"   on storage.objects;
drop policy if exists "membros enviam na galeria" on storage.objects;
drop policy if exists "membros alteram a galeria" on storage.objects;
drop policy if exists "membros apagam da galeria" on storage.objects;

create policy "membros veem a galeria" on storage.objects for select to authenticated
  using (bucket_id = 'galeria' and public.e_membro());
create policy "membros enviam na galeria" on storage.objects for insert to authenticated
  with check (bucket_id = 'galeria' and public.e_membro());
create policy "membros alteram a galeria" on storage.objects for update to authenticated
  using (bucket_id = 'galeria' and public.e_membro()) with check (bucket_id = 'galeria' and public.e_membro());
create policy "membros apagam da galeria" on storage.objects for delete to authenticated
  using (bucket_id = 'galeria' and public.e_membro());
