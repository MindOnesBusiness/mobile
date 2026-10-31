-- =====================================================================
--  MOB VAULT — Update 6: member list for your email list
--  SQL Editor → New query → paste → Run. Safe to run more than once.
-- =====================================================================

-- Did they opt in to emails? And have you added them to your list yet?
alter table public.profiles add column if not exists marketing_opt_in boolean not null default false;
alter table public.profiles add column if not exists list_added_at timestamptz;

-- New sign-ups: save the opt-in checkbox from the sign-up form
create or replace function public.handle_new_user() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  insert into public.profiles (id, display_name, marketing_opt_in)
  values (new.id,
          left(coalesce(nullif(new.raw_user_meta_data->>'display_name',''), split_part(new.email,'@',1)), 40),
          coalesce((new.raw_user_meta_data->>'marketing_opt_in')::boolean, false))
  on conflict (id) do nothing;
  return new;
end $$;

-- Backfill anyone who signed up before this update
update public.profiles p set marketing_opt_in = true
from auth.users u
where u.id = p.id and coalesce((u.raw_user_meta_data->>'marketing_opt_in')::boolean, false);

-- Members can change their own email preference from the Account tab
create or replace function public.set_my_opt_in(p_on boolean) returns void
language sql security definer set search_path = public as $$
  update public.profiles set marketing_opt_in = p_on where id = auth.uid();
$$;
revoke all on function public.set_my_opt_in(boolean) from public, anon;
grant execute on function public.set_my_opt_in(boolean) to authenticated;

-- Own profile now includes the email preference
create or replace function public.my_profile() returns json
language sql stable security definer set search_path = public as $$
  select json_build_object('display_name', display_name, 'is_vip', is_vip, 'is_admin', is_admin,
                           'vip_source', vip_source, 'vip_until', vip_until, 'marketing_opt_in', marketing_opt_in)
  from public.profiles where id = auth.uid();
$$;

-- ADMIN ONLY: everyone's name, email and level
drop function if exists public.admin_members();
create or replace function public.admin_members()
returns table(id uuid, email text, display_name text, role text, joined timestamptz,
              keyholder_until timestamptz, email_confirmed boolean, opted_in boolean, list_added_at timestamptz)
language plpgsql stable security definer set search_path = public, auth as $$
begin
  if not public.is_admin() then raise exception 'Admins only.'; end if;
  return query
  select p.id, u.email::text, p.display_name,
         case when p.is_admin then 'Admin'
              when p.is_vip or coalesce(p.vip_until > now(), false) then 'Keyholder'
              when p.vip_until is not null then 'Former Keyholder'
              else 'Member' end,
         u.created_at, p.vip_until, u.email_confirmed_at is not null, p.marketing_opt_in, p.list_added_at
  from public.profiles p join auth.users u on u.id = p.id
  order by u.created_at desc;
end $$;
revoke all on function public.admin_members() from public, anon;
grant execute on function public.admin_members() to authenticated;

-- ADMIN ONLY: tick people off once they're on your email list
create or replace function public.admin_mark_added(p_ids uuid[], p_added boolean) returns void
language plpgsql security definer set search_path = public as $$
begin
  if not public.is_admin() then raise exception 'Admins only.'; end if;
  update public.profiles set list_added_at = case when p_added then now() else null end where id = any(p_ids);
end $$;
revoke all on function public.admin_mark_added(uuid[], boolean) from public, anon;
grant execute on function public.admin_mark_added(uuid[], boolean) to authenticated;
