-- ============================================================
-- Орбита: таблица ошибок приложения (app_errors)
-- Сбор ошибок/крашей с устройств пользователей для разработчика.
-- Запускать в Supabase SQL Editor (один раз), после rls_policies.sql.
--
-- Кто пишет: анонимы и авторизованные с postgres-ролью сервисного ключа
-- (error_report_service использует клиент с real anon/anonKey, что работает
-- через client API и автоматически подставляет auth.uid()).
-- ============================================================

create table if not exists public.app_errors (
  id bigint generated always as identity primary key,
  user_id uuid,
  app_version text,
  build_number text,
  platform text,
  platform_version text,
  device text,
  level text default 'error',
  message text,
  error text,
  stack text,
  context text,
  created_at timestamptz not null default now()
);

-- Индекс для удобной выборки по времени
create index if not exists app_errors_created_idx
  on public.app_errors (created_at desc);

-- RLS: вставка разрешена (клиентские ключи могут писать), чтение/изменение —
-- только для сервера. Разработчик смотрит логи через дашборд/сервисный ключ.
alter table public.app_errors enable row level security;

-- Вставка: разрешена любому (авторизованному или анониму),
-- чтобы фиксировать ошибки даже до входа.
drop policy if exists "app_errors insert" on public.app_errors;
create policy "app_errors insert"
  on public.app_errors
  for insert
  to anon, authenticated
  with check (true);

-- Чтение: только сервер (нет политики select) — пользователи не читают чужие логи.
drop policy if exists "app_errors select" on public.app_errors;