-- Stundenlöhner: Merkmal pro MA, Abwesenheitsart Ferien oder Prüfungsphase
alter table public.employees add column hourly boolean not null default false;
alter table public.requests add column kind text not null default 'ferien' check (kind in ('ferien', 'pruefung'));

drop function public.admin_save_employee(text, bigint, text, text, boolean, numeric, int);
create function public.admin_save_employee(p_pin text, p_id bigint, p_name text, p_category text, p_active boolean,
  p_days numeric default null, p_pensum int default 100, p_hourly boolean default false) returns void
language plpgsql security definer set search_path = '' as $$
begin
  if not private.check_pin(p_pin) then raise exception 'Falsche PIN'; end if;
  if p_id is null then
    insert into public.employees (name, category, active, vacation_days, pensum, hourly)
    values (trim(p_name), p_category, coalesce(p_active, true), p_days, coalesce(p_pensum, 100), coalesce(p_hourly, false));
  else
    update public.employees set name = trim(p_name), category = p_category, active = p_active,
      vacation_days = p_days, pensum = coalesce(p_pensum, 100), hourly = coalesce(p_hourly, false) where id = p_id;
  end if;
end $$;

-- Regeln für neue Einträge: Prio nur Festangestellte, Prüfung nur Stundenlöhner,
-- Sperrtage gelten für Ferien, nicht für Prüfungsphasen
create or replace function public.check_blocked() returns trigger
language plpgsql security definer set search_path = '' as $$
declare b record; e record;
begin
  select * into e from public.employees where id = new.employee_id;
  if new.is_prio and e.hourly then raise exception '%', 'Stundenlöhner können keine Prio-Woche setzen'; end if;
  if new.kind = 'pruefung' and not e.hourly then raise exception '%', 'Prüfungsphasen sind nur für Stundenlöhner'; end if;
  if new.kind = 'pruefung' then return new; end if;
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
