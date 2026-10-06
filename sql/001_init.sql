-- Grundgerüst: Mitarbeiter, Limits, Ferienwünsche, Admin-PIN und Admin-Funktionen
create extension if not exists pgcrypto with schema extensions;

create table public.employees (
  id bigint generated always as identity primary key,
  name text not null unique,
  category text not null check (category in ('Clinic','Verkauf')),
  active boolean not null default true
);

create table public.category_limits (
  category text primary key check (category in ('Clinic','Verkauf')),
  max_parallel int not null default 1 check (max_parallel >= 1)
);
insert into public.category_limits values ('Clinic',1),('Verkauf',2);

create table public.requests (
  id bigint generated always as identity primary key,
  employee_id bigint not null references public.employees(id) on delete cascade,
  start_date date not null,
  end_date date not null,
  is_prio boolean not null default false,
  status text not null default 'offen' check (status in ('offen','genehmigt','abgelehnt')),
  note text,
  created_at timestamptz not null default now(),
  check (end_date >= start_date),
  check (not is_prio or end_date - start_date <= 6)
);
create unique index one_prio_per_year on public.requests (employee_id, (extract(year from start_date))) where is_prio and status <> 'abgelehnt';
create index on public.requests (start_date, end_date);

-- Admin-PIN (gehasht, nicht über die API erreichbar). Den ersten PIN separat setzen:
-- insert into private.admin (id, pin_hash) values (1, extensions.crypt('<PIN>', extensions.gen_salt('bf')));
create schema if not exists private;
create table private.admin (id int primary key default 1 check (id = 1), pin_hash text not null);

create or replace function private.check_pin(p_pin text) returns boolean
language sql security definer set search_path = '' as $$
  select exists (select 1 from private.admin where pin_hash = extensions.crypt(p_pin, pin_hash));
$$;

alter table public.employees enable row level security;
alter table public.category_limits enable row level security;
alter table public.requests enable row level security;
create policy "read employees" on public.employees for select to anon, authenticated using (true);
create policy "read limits" on public.category_limits for select to anon, authenticated using (true);
create policy "read requests" on public.requests for select to anon, authenticated using (true);
create policy "insert open requests" on public.requests for insert to anon, authenticated with check (status = 'offen');
create policy "delete open requests" on public.requests for delete to anon, authenticated using (status = 'offen');

create or replace function public.admin_login(p_pin text) returns boolean
language sql security definer set search_path = '' as $$ select private.check_pin(p_pin); $$;

create or replace function public.admin_set_status(p_pin text, p_id bigint, p_status text) returns void
language plpgsql security definer set search_path = '' as $$
begin
  if not private.check_pin(p_pin) then raise exception 'Falsche PIN'; end if;
  update public.requests set status = p_status where id = p_id;
end $$;

create or replace function public.admin_delete_request(p_pin text, p_id bigint) returns void
language plpgsql security definer set search_path = '' as $$
begin
  if not private.check_pin(p_pin) then raise exception 'Falsche PIN'; end if;
  delete from public.requests where id = p_id;
end $$;

create or replace function public.admin_save_employee(p_pin text, p_id bigint, p_name text, p_category text, p_active boolean) returns void
language plpgsql security definer set search_path = '' as $$
begin
  if not private.check_pin(p_pin) then raise exception 'Falsche PIN'; end if;
  if p_id is null then
    insert into public.employees (name, category, active) values (trim(p_name), p_category, coalesce(p_active, true));
  else
    update public.employees set name = trim(p_name), category = p_category, active = p_active where id = p_id;
  end if;
end $$;

create or replace function public.admin_set_limit(p_pin text, p_category text, p_max int) returns void
language plpgsql security definer set search_path = '' as $$
begin
  if not private.check_pin(p_pin) then raise exception 'Falsche PIN'; end if;
  update public.category_limits set max_parallel = p_max where category = p_category;
end $$;

create or replace function public.admin_change_pin(p_pin text, p_new text) returns void
language plpgsql security definer set search_path = '' as $$
begin
  if not private.check_pin(p_pin) then raise exception 'Falsche PIN'; end if;
  if length(p_new) < 4 then raise exception 'PIN zu kurz'; end if;
  update private.admin set pin_hash = extensions.crypt(p_new, extensions.gen_salt('bf'));
end $$;

revoke execute on function private.check_pin(text) from public, anon, authenticated;
grant usage on schema private to postgres;

alter publication supabase_realtime add table public.requests, public.employees, public.category_limits;
