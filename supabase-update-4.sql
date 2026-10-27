-- =====================================================================
--  MOB VAULT — Update 4: assign admin by EMAIL
--  SQL Editor → New query → paste → Run. Safe to run more than once.
-- =====================================================================

-- 1) Repair: give a profile to any account that doesn't have one yet.
--    (Accounts created before the setup script ran never got a profile,
--     which is why a display-name lookup can miss them.)
insert into public.profiles (id, display_name)
select u.id, left(coalesce(nullif(u.raw_user_meta_data->>'display_name',''), split_part(u.email,'@',1)), 40)
from auth.users u
left join public.profiles p on p.id = u.id
where p.id is null;

-- 2) make_admin('email') — finds the account by its sign-in email.
create or replace function public.make_admin(p_email text) returns text
language plpgsql security definer set search_path = public, auth as $$
declare v_id uuid;
begin
  select id into v_id from auth.users where lower(email) = lower(trim(p_email));
  if v_id is null then
    return 'No account found for ' || p_email || '. Create the account in the app first, then run this again.';
  end if;
  insert into public.profiles (id, display_name) values (v_id, split_part(p_email,'@',1))
    on conflict (id) do nothing;
  update public.profiles set is_admin = true, is_vip = true where id = v_id;
  return 'Done: ' || p_email || ' is now admin, with lifetime Keyholder access.';
end $$;

-- 3) remove_admin('email') — takes admin away (they keep a normal account).
create or replace function public.remove_admin(p_email text) returns text
language plpgsql security definer set search_path = public, auth as $$
declare v_id uuid;
begin
  select id into v_id from auth.users where lower(email) = lower(trim(p_email));
  if v_id is null then return 'No account found for ' || p_email || '.'; end if;
  update public.profiles set is_admin = false, is_vip = false where id = v_id;
  return 'Done: ' || p_email || ' is no longer admin.';
end $$;

-- Only you, from this SQL Editor, can run these. Nobody can call them from the app.
revoke all on function public.make_admin(text) from public, anon, authenticated;
revoke all on function public.remove_admin(text) from public, anon, authenticated;

-- 4) Make Evergreen admin
select public.make_admin('6stringshepherd@proton.me');

-- 5) Who is admin right now
select u.email, p.display_name, p.is_admin, p.is_vip
from public.profiles p join auth.users u on u.id = p.id
where p.is_admin;
