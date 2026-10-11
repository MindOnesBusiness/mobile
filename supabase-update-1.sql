-- =====================================================================
--  MOB VAULT — Update 1: VIP expiration dates + timed VIP keys
--  Run AFTER supabase-setup.sql (SQL Editor → New query → paste → Run).
--  Safe to run more than once.
--
--  How VIP works after this update:
--    • Each key carries a number of days (30 for a $22 membership,
--      180 for the Codex pre-sale bundle).
--    • Redeeming a key ADDS its days to the member's remaining time,
--      so early renewals never lose days.
--    • Access locks automatically when vip_until passes.
--    • profiles.is_vip = true is a lifetime/admin override (use it for yourself).
-- =====================================================================

alter table public.profiles add column if not exists vip_until timestamptz;
alter table public.vip_codes add column if not exists days int not null default 30;

-- VIP = lifetime override OR time remaining
create or replace function public.is_vip() returns boolean
language sql stable security definer set search_path = public as $$
  select coalesce((select is_vip or coalesce(vip_until > now(), false)
                   from public.profiles where id = auth.uid()), false);
$$;

create or replace function public.redeem_vip_code(p_code text) returns boolean
language plpgsql security definer set search_path = public as $$
declare v_source text; v_days int;
begin
  if auth.uid() is null then raise exception 'Please sign in first.'; end if;
  update public.vip_codes set redeemed_by = auth.uid(), redeemed_at = now()
   where code = upper(trim(p_code)) and redeemed_by is null
   returning source, days into v_source, v_days;
  if v_source is null then return false; end if;
  update public.profiles
     set vip_until  = greatest(coalesce(vip_until, now()), now()) + make_interval(days => v_days),
         vip_source = 'code:' || v_source,
         vip_since  = coalesce(vip_since, now())
   where id = auth.uid();
  return true;
end $$;
revoke all on function public.redeem_vip_code(text) from public, anon;
grant execute on function public.redeem_vip_code(text) to authenticated;

-- Key generator now takes a number of days
drop function if exists public.generate_vip_codes(int, text);
create or replace function public.generate_vip_codes(n int, p_source text, p_days int default 30)
returns setof text language plpgsql security definer set search_path = public as $$
declare c text; i int := 0;
begin
  while i < n loop
    c := 'MOB-' || upper(substr(md5(random()::text || clock_timestamp()::text),1,4)) || '-' ||
                   upper(substr(md5(random()::text || clock_timestamp()::text),1,4));
    begin
      insert into public.vip_codes(code, source, days) values (c, p_source, p_days);
      i := i + 1; return next c;
    exception when unique_violation then
    end;
  end loop;
end $$;
revoke all on function public.generate_vip_codes(int, text, int) from public, anon, authenticated;

-- ---------------------------------------------------------------------
--  Handy admin queries (run any time in the SQL Editor):
--
--  20 membership keys (30 days each):
--    select * from public.generate_vip_codes(20, 'MEMBERSHIP', 30);
--
--  50 Codex pre-sale keys (6 months each):
--    select * from public.generate_vip_codes(50, 'CODEX-PRESALE', 180);
--
--  Unused keys:
--    select code, source, days from public.vip_codes where redeemed_by is null order by created_at;
--
--  Members and when their VIP ends:
--    select display_name, is_vip as lifetime, vip_until from public.profiles order by vip_until desc nulls last;
-- ---------------------------------------------------------------------
