-- ============================================================
-- Орбита: RLS-политики для пользовательских таблиц синхронизации
-- Включает построчную безопасность и разрешает авторизованному
-- владельцу просматривать/создавать/обновлять/удалять только свои записи.
-- Запускать в Supabase SQL Editor (один раз), после tombstones.sql.
--
-- Таблицы: tasks, calendar_events, habits, notes, diary_entries,
--          shift_schedules, user_gamification, user_achievements
-- Логика: user_id = auth.uid() (владелец) на все операции.
-- ============================================================

-- Вспомогательная функция: включить RLS для владельца
-- (применяется ниже к каждой таблице отдельно).

-- 1. tasks
alter table public.tasks enable row level security;
drop policy if exists "tasks owner select" on public.tasks;
create policy "tasks owner select" on public.tasks
  for select to authenticated using (auth.uid() = user_id);
drop policy if exists "tasks owner insert" on public.tasks;
create policy "tasks owner insert" on public.tasks
  for insert to authenticated with check (auth.uid() = user_id);
drop policy if exists "tasks owner update" on public.tasks;
create policy "tasks owner update" on public.tasks
  for update to authenticated using (auth.uid() = user_id);
drop policy if exists "tasks owner delete" on public.tasks;
create policy "tasks owner delete" on public.tasks
  for delete to authenticated using (auth.uid() = user_id);

-- 2. calendar_events
alter table public.calendar_events enable row level security;
drop policy if exists "calendar_events owner select" on public.calendar_events;
create policy "calendar_events owner select" on public.calendar_events
  for select to authenticated using (auth.uid() = user_id);
drop policy if exists "calendar_events owner insert" on public.calendar_events;
create policy "calendar_events owner insert" on public.calendar_events
  for insert to authenticated with check (auth.uid() = user_id);
drop policy if exists "calendar_events owner update" on public.calendar_events;
create policy "calendar_events owner update" on public.calendar_events
  for update to authenticated using (auth.uid() = user_id);
drop policy if exists "calendar_events owner delete" on public.calendar_events;
create policy "calendar_events owner delete" on public.calendar_events
  for delete to authenticated using (auth.uid() = user_id);

-- 3. habits
alter table public.habits enable row level security;
drop policy if exists "habits owner select" on public.habits;
create policy "habits owner select" on public.habits
  for select to authenticated using (auth.uid() = user_id);
drop policy if exists "habits owner insert" on public.habits;
create policy "habits owner insert" on public.habits
  for insert to authenticated with check (auth.uid() = user_id);
drop policy if exists "habits owner update" on public.habits;
create policy "habits owner update" on public.habits
  for update to authenticated using (auth.uid() = user_id);
drop policy if exists "habits owner delete" on public.habits;
create policy "habits owner delete" on public.habits
  for delete to authenticated using (auth.uid() = user_id);

-- 4. notes
alter table public.notes enable row level security;
drop policy if exists "notes owner select" on public.notes;
create policy "notes owner select" on public.notes
  for select to authenticated using (auth.uid() = user_id);
drop policy if exists "notes owner insert" on public.notes;
create policy "notes owner insert" on public.notes
  for insert to authenticated with check (auth.uid() = user_id);
drop policy if exists "notes owner update" on public.notes;
create policy "notes owner update" on public.notes
  for update to authenticated using (auth.uid() = user_id);
drop policy if exists "notes owner delete" on public.notes;
create policy "notes owner delete" on public.notes
  for delete to authenticated using (auth.uid() = user_id);

-- 5. diary_entries
alter table public.diary_entries enable row level security;
drop policy if exists "diary_entries owner select" on public.diary_entries;
create policy "diary_entries owner select" on public.diary_entries
  for select to authenticated using (auth.uid() = user_id);
drop policy if exists "diary_entries owner insert" on public.diary_entries;
create policy "diary_entries owner insert" on public.diary_entries
  for insert to authenticated with check (auth.uid() = user_id);
drop policy if exists "diary_entries owner update" on public.diary_entries;
create policy "diary_entries owner update" on public.diary_entries
  for update to authenticated using (auth.uid() = user_id);
drop policy if exists "diary_entries owner delete" on public.diary_entries;
create policy "diary_entries owner delete" on public.diary_entries
  for delete to authenticated using (auth.uid() = user_id);

-- 6. shift_schedules
alter table public.shift_schedules enable row level security;
drop policy if exists "shift_schedules owner select" on public.shift_schedules;
create policy "shift_schedules owner select" on public.shift_schedules
  for select to authenticated using (auth.uid() = user_id);
drop policy if exists "shift_schedules owner insert" on public.shift_schedules;
create policy "shift_schedules owner insert" on public.shift_schedules
  for insert to authenticated with check (auth.uid() = user_id);
drop policy if exists "shift_schedules owner update" on public.shift_schedules;
create policy "shift_schedules owner update" on public.shift_schedules
  for update to authenticated using (auth.uid() = user_id);
drop policy if exists "shift_schedules owner delete" on public.shift_schedules;
create policy "shift_schedules owner delete" on public.shift_schedules
  for delete to authenticated using (auth.uid() = user_id);

-- 7. user_gamification (одна строка на пользователя, только select/insert/update)
alter table public.user_gamification enable row level security;
drop policy if exists "gamification owner select" on public.user_gamification;
create policy "gamification owner select" on public.user_gamification
  for select to authenticated using (auth.uid() = user_id);
drop policy if exists "gamification owner insert" on public.user_gamification;
create policy "gamification owner insert" on public.user_gamification
  for insert to authenticated with check (auth.uid() = user_id);
drop policy if exists "gamification owner update" on public.user_gamification;
create policy "gamification owner update" on public.user_gamification
  for update to authenticated using (auth.uid() = user_id);

-- 8. user_achievements
alter table public.user_achievements enable row level security;
drop policy if exists "achievements owner select" on public.user_achievements;
create policy "achievements owner select" on public.user_achievements
  for select to authenticated using (auth.uid() = user_id);
drop policy if exists "achievements owner insert" on public.user_achievements;
create policy "achievements owner insert" on public.user_achievements
  for insert to authenticated with check (auth.uid() = user_id);
drop policy if exists "achievements owner update" on public.user_achievements;
create policy "achievements owner update" on public.user_achievements
  for update to authenticated using (auth.uid() = user_id);
drop policy if exists "achievements owner delete" on public.user_achievements;
create policy "achievements owner delete" on public.user_achievements
  for delete to authenticated using (auth.uid() = user_id);