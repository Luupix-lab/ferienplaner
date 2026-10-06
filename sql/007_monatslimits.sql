-- Limit pro Monat (gilt jedes Jahr). Kein Eintrag = Standard-Limit aus category_limits.
create table public.month_limits (
  category text not null check (category in ('Clinic','Verkauf')),
  month int not null check (month between 1 and 12),
  max_parallel int not null check (max_parallel >= 1),
  primary key (category, month)
);
alter table public.month_limits enable row level security;
create policy "read month limits" on public.month_limits for select to anon, authenticated using (true);

-- p_max null = Monat zurück auf Standard
create or replace function public.admin_set_month_limit(p_pin text, p_category text, p_month int, p_max int) returns void
language plpgsql security definer set search_path = '' as $$
begin
  if not private.check_pin(p_pin) then raise exception 'Falsche PIN'; end if;
  if p_max is null then
    delete from public.month_limits where category = p_category and month = p_month;
  else
    insert into public.month_limits (category, month, max_parallel) values (p_category, p_month, p_max)
    on conflict (category, month) do update set max_parallel = excluded.max_parallel;
  end if;
end $$;

alter publication supabase_realtime add table public.month_limits;
