-- Sperrtage: Zeiträume, in denen keine Ferien eingetragen werden können.
-- category null = gilt für alle, sonst nur für Clinic bzw. Verkauf.
create table public.blocked_days (
  id bigint generated always as identity primary key,
  start_date date not null,
  end_date date not null,
  category text check (category in ('Clinic','Verkauf')),
  reason text,
  created_at timestamptz not null default now(),
  check (end_date >= start_date)
);
alter table public.blocked_days enable row level security;
create policy "read blocked" on public.blocked_days for select to anon, authenticated using (true);

create or replace function public.admin_add_block(p_pin text, p_start date, p_end date, p_category text, p_reason text) returns void
language plpgsql security definer set search_path = '' as $$
begin
  if not private.check_pin(p_pin) then raise exception 'Falsche PIN'; end if;
  insert into public.blocked_days (start_date, end_date, category, reason)
  values (p_start, p_end, nullif(p_category, ''), nullif(trim(p_reason), ''));
end $$;

create or replace function public.admin_delete_block(p_pin text, p_id bigint) returns void
language plpgsql security definer set search_path = '' as $$
begin
  if not private.check_pin(p_pin) then raise exception 'Falsche PIN'; end if;
  delete from public.blocked_days where id = p_id;
end $$;

-- Neue Ferienwünsche in Sperrtagen ablehnen (auch wenn jemand die App umgeht)
create or replace function public.check_blocked() returns trigger
language plpgsql security definer set search_path = '' as $$
declare b record;
begin
  select bd.* into b from public.blocked_days bd
    join public.employees e on e.id = new.employee_id
   where bd.start_date <= new.end_date and bd.end_date >= new.start_date
     and (bd.category is null or bd.category = e.category)
   order by bd.start_date limit 1;
  if found then
    raise exception '%', 'Gesperrt vom ' || to_char(b.start_date, 'DD.MM.YYYY') || ' bis ' || to_char(b.end_date, 'DD.MM.YYYY')
      || coalesce(' (' || b.reason || ')', '');
  end if;
  return new;
end $$;
revoke execute on function public.check_blocked() from public, anon, authenticated;
create trigger requests_check_blocked before insert on public.requests
  for each row execute function public.check_blocked();

alter publication supabase_realtime add table public.blocked_days;
