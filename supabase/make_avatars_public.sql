-- ============================================================
-- Орбита: сделать bucket "avatars" публичным
-- Запускать в Supabase SQL Editor (один раз).
-- Нужно, чтобы public URL аватарок открывался у друзей
-- на других устройствах (иначе NetworkImage получает 403/404).
-- ============================================================

-- 1. Обновить существующий bucket на public = true
update storage.buckets
set public = true
where id = 'avatars';

-- 2. Гарантировать, что bucket существует (если не создан кодом)
insert into storage.buckets (id, name, public)
values ('avatars', 'avatars', true)
on conflict (id) do update
set public = true;

-- 3. Разрешить анонимный GET файлов (необходимо для public-чтения)
create policy "Public read avatars"
  on storage.objects
  for select
  to public
  using (bucket_id = 'avatars');