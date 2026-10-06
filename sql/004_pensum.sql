-- Pensum in % pro Mitarbeiter. Ferientage dürfen jetzt halbe Tage haben (z.B. 70 % = 17.5).
alter table public.employees add column pensum int not null default 100 check (pensum between 10 and 100);
alter table public.employees alter column vacation_days type numeric(5,1);
alter table public.employees drop constraint if exists employees_vacation_days_check;
alter table public.employees add constraint employees_vacation_days_check check (vacation_days between 0 and 366);

drop function public.admin_save_employee(text, bigint, text, text, boolean, int);
create function public.admin_save_employee(p_pin text, p_id bigint, p_name text, p_category text, p_active boolean,
  p_days numeric default null, p_pensum int default 100) returns void
language plpgsql security definer set search_path = '' as $$
begin
  if not private.check_pin(p_pin) then raise exception 'Falsche PIN'; end if;
  if p_id is null then
    insert into public.employees (name, category, active, vacation_days, pensum)
    values (trim(p_name), p_category, coalesce(p_active, true), p_days, coalesce(p_pensum, 100));
  else
    update public.employees set name = trim(p_name), category = p_category, active = p_active,
      vacation_days = p_days, pensum = coalesce(p_pensum, 100) where id = p_id;
  end if;
end $$;
