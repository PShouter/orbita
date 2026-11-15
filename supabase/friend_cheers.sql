-- ============================================================
-- Орбита: дружеские поддержки (friend_cheers)
-- Таблица + RLS + Realtime
-- Запускать в Supabase SQL Editor (один раз).
-- ============================================================

-- 1. Таблица поддержек (cheers)
create table if not exists public.friend_cheers (
  id uuid primary key default gen_random_uuid(),
  from_user_id uuid not null references auth.users(id) on delete cascade,
  to_user_id uuid not null references auth.users(id) on delete cascade,
  created_at timestamptz not null default now()
);

-- Индексы для быстрых выборок «поддержки ко мне» и «от меня»
create index if not exists friend_cheers_to_idx
  on public.friend_cheers (to_user_id, created_at desc);
create index if not exists friend_cheers_from_idx
  on public.friend_cheers (from_user_id, created_at desc);

-- 2. RLS: включить построчную безопасность
alter table public.friend_cheers enable row level security;

-- Разрешить вставку любому авторизованному пользователю,
-- но нельзя отправлять поддержку самому себе
create policy "Авторизованные могут отправлять поддержки"
  on public.friend_cheers
  for insert
  to authenticated
  with check (
    auth.uid() = from_user_id
    and from_user_id <> to_user_id
  );

-- Читать можно только входящие поддержки (ради privacy и realtime)
-- (этого достаточно для счётчика поддержек в профиле и реального времени)
create policy "Пользователь видит только свои входящие поддержки"
  on public.friend_cheers
  for select
  to authenticated
  using (auth.uid() = to_user_id);

-- Удалять/менять нельзя — поддержки неизменяемы (никаких update/delete-политик).

-- 3. Realtime для таблицы friend_cheers
-- Мгновенно уведомляет пользователя о новой поддержке
alter publication supabase_realtime add table public.friend_cheers;