-- Zweistufige Freigabe für Ferien: offen → bestaetigt (Teamleitung) → genehmigt (Verkaufsleitung).
-- WK und Prüfungsphase: Bestätigung der Teamleitung ist final (offen → genehmigt).
alter table public.requests drop constraint requests_status_check;
alter table public.requests add constraint requests_status_check
  check (status in ('offen', 'bestaetigt', 'genehmigt', 'abgelehnt'));

create or replace function public.admin_set_status(p_pin text, p_id bigint, p_status text) returns void
language plpgsql security definer set search_path = '' as $$
declare r record;
begin
  if not private.check_pin(p_pin) then raise exception 'Falsche PIN'; end if;
  select * into r from public.requests where id = p_id;
  if not found then raise exception '%', 'Eintrag nicht gefunden'; end if;
  if p_status = 'bestaetigt' and r.kind <> 'ferien' then
    raise exception '%', 'Nur Ferien haben die Zwischenstufe bestätigt';
  end if;
  if p_status = 'genehmigt' and r.kind = 'ferien' and r.status <> 'bestaetigt' then
    raise exception '%', 'Ferien müssen zuerst von der Teamleitung bestätigt werden';
  end if;
  update public.requests set status = p_status where id = p_id;
end $$;
