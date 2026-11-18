-- ============================================================
-- Орбита: tombstones (мягкое удаление) для синхронизации
-- Добавляет колонку deleted_at к user-таблицам, чтобы удаление
-- с одного устройства расходилось на все остальные.
-- Запускать в Supabase SQL Editor (один раз), после friend_cheers.sql.
-- ============================================================

-- 1. Добавляем deleted_at к таблицам (мягкое удаление)
alter table public.tasks
  add column if not exists deleted_at timestamptz;
alter table public.calendar_events
  add column if not exists deleted_at timestamptz;
alter table public.habits
  add column if not exists deleted_at timestamptz;
alter table public.notes
  add column if not exists deleted_at timestamptz;
alter table public.diary_entries
  add column if not exists deleted_at timestamptz;
alter table public.shift_schedules
  add column if not exists deleted_at timestamptz;

-- 2. Индексы для фильтрации tombstone'ов в синке
create index if not exists tasks_deleted_idx
  on public.tasks (user_id, deleted_at);
create index if not exists calendar_events_deleted_idx
  on public.calendar_events (user_id, deleted_at);
create index if not exists habits_deleted_idx
  on public.habits (user_id, deleted_at);
create index if not exists notes_deleted_idx
  on public.notes (user_id, deleted_at);
create index if not exists diary_entries_deleted_idx
  on public.diary_entries (user_id, deleted_at);
create index if not exists shift_schedules_deleted_idx
  on public.shift_schedules (user_id, deleted_at);

-- 3. Примечание:
-- habit_logs НЕ включается: таблица полностью локальная (не синится в облако),
-- поэтому для неё не нужны ни deleted_at, ни RLS в Supabase.
-- Клиент сам решает применять tombstone или нет по updated_at.
-- RLS-политики select оставляем без изменений: tombstone'ы (deleted_at != null)
-- отдаются тому же владельцу (auth.uid() = user_id) — клиент удаляет их локально,
-- поэтому недопонимания между устройствами не возникает.