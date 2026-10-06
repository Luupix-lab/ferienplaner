-- WK (Wiederholungskurs): neue Abwesenheitsart für alle MA
alter table public.requests drop constraint requests_kind_check;
alter table public.requests add constraint requests_kind_check check (kind in ('ferien', 'pruefung', 'wk'));

-- Prio nur für Ferien von Festangestellten, Prüfung nur Stundenlöhner,
-- Sperrtage gelten nur für Ferien (nicht für Prüfung und WK)
create or replace function public.check_blocked() returns trigger
language plpgsql security definer set search_path = '' as $$
declare b record; e record;
begin
  select * into e from public.employees where id = new.employee_id;
  if new.is_prio and e.hourly then raise exception '%', 'Stundenlöhner können keine Prio-Woche setzen'; end if;
  if new.is_prio and new.kind <> 'ferien' then raise exception '%', 'Prio gilt nur für Ferien'; end if;
  if new.kind = 'pruefung' and not e.hourly then raise exception '%', 'Prüfungsphasen sind nur für Stundenlöhner'; end if;
  if new.kind <> 'ferien' then return new; end if;
  select bd.* into b from public.blocked_days bd
   where bd.start_date <= new.end_date and bd.end_date >= new.start_date
     and (bd.category is null or bd.category = e.category)
   order by bd.start_date limit 1;
  if found then
    raise exception '%', 'Gesperrt vom ' || to_char(b.start_date, 'DD.MM.YYYY') || ' bis ' || to_char(b.end_date, 'DD.MM.YYYY')
      || coalesce(' (' || b.reason || ')', '');
  end if;
  return new;
end $$;
