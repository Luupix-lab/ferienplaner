-- Ferientage pro Jahr je Mitarbeiter (null = nicht hinterlegt)
alter table public.employees add column vacation_days int check (vacation_days between 0 and 366);

drop function public.admin_save_employee(text, bigint, text, text, boolean);
create function public.admin_save_employee(p_pin text, p_id bigint, p_name text, p_category text, p_active boolean, p_days int default null) returns void
language plpgsql security definer set search_path = '' as $$
begin
  if not private.check_pin(p_pin) then raise exception 'Falsche PIN'; end if;
  if p_id is null then
    insert into public.employees (name, category, active, vacation_days) values (trim(p_name), p_category, coalesce(p_active, true), p_days);
  else
    update public.employees set name = trim(p_name), category = p_category, active = p_active, vacation_days = p_days where id = p_id;
  end if;
end $$;
