-- =====================================================================
--  MOB VAULT — Update 10
--  1. Shelf rows: Personal Growth, Business Development, Miscellaneous (+ cover images)
--  2. VIP Lounge: an open room for free members ("The Commons")
--  3. Profiles: username (also used to sign in), photo, mission statement
--     VIPs get a longer mission statement, an accent color, and a link
--  SQL Editor → New query → paste → Run. Safe to run more than once.
-- =====================================================================

-- ---------- 1. Shelf rows + covers ----------
alter table public.volumes add column if not exists category text not null default 'misc';
alter table public.volumes add column if not exists cover_url text;
alter table public.volumes drop constraint if exists volumes_category_chk;
alter table public.volumes add constraint volumes_category_chk check (category in ('growth','business','misc'));
update public.volumes set category = 'growth' where id = 'destiny-lock';

-- ---------- 2. Open room for free members ----------
update public.forum_categories set tier = 'member' where name = 'Introductions';
insert into public.forum_categories (name, sort, tier)
select 'The Commons', 0, 'member'
where not exists (select 1 from public.forum_categories where name = 'The Commons');

-- ---------- 3. Profiles ----------
alter table public.profiles add column if not exists username text;
alter table public.profiles add column if not exists avatar_url text;
alter table public.profiles add column if not exists bio text;
alter table public.profiles add column if not exists accent text;   -- VIP only
alter table public.profiles add column if not exists link text;     -- VIP only
alter table public.profiles drop constraint if exists profiles_username_chk;
alter table public.profiles add constraint profiles_username_chk check (username is null or username ~ '^[A-Za-z0-9_]{3,20}$');
create unique index if not exists profiles_username_unique on public.profiles (lower(username));

-- Is a username free?
create or replace function public.username_available(p_username text) returns boolean
language sql stable security definer set search_path = public as $$
  select p_username ~ '^[A-Za-z0-9_]{3,20}$'
     and not exists (select 1 from public.profiles where lower(username) = lower(p_username));
$$;
grant execute on function public.username_available(text) to anon, authenticated;

-- New sign-ups: keep the username they picked (if it is valid and free)
create or replace function public.handle_new_user() returns trigger
language plpgsql security definer set search_path = public as $$
declare v_user text := nullif(new.raw_user_meta_data->>'username','');
begin
  if v_user is not null and not public.username_available(v_user) then v_user := null; end if;
  insert into public.profiles (id, display_name, marketing_opt_in, username)
  values (new.id,
          left(coalesce(nullif(new.raw_user_meta_data->>'display_name',''), split_part(new.email,'@',1)), 40),
          coalesce((new.raw_user_meta_data->>'marketing_opt_in')::boolean, false),
          v_user)
  on conflict (id) do nothing;
  return new;
end $$;

-- Sign in with a username: checks the password, then gives back that account's email.
-- Never shows anyone's email without the right password. Max 10 tries per 15 minutes.
create table if not exists public.login_attempts (username text not null, at timestamptz not null default now());
alter table public.login_attempts enable row level security;   -- no policies: nobody reads it directly

create or replace function public.login_email(p_username text, p_password text) returns text
language plpgsql volatile security definer set search_path = public, extensions, auth as $$
declare v_email text;
begin
  delete from public.login_attempts where at < now() - interval '1 day';
  if (select count(*) from public.login_attempts
      where lower(username) = lower(p_username) and at > now() - interval '15 minutes') >= 10 then
    raise exception 'Too many tries. Please wait 15 minutes.';
  end if;
  insert into public.login_attempts(username) values (p_username);
  select u.email into v_email
    from public.profiles p join auth.users u on u.id = p.id
   where lower(p.username) = lower(p_username)
     and u.encrypted_password = extensions.crypt(p_password, u.encrypted_password);
  if v_email is not null then delete from public.login_attempts where lower(username) = lower(p_username); end if;
  return v_email;
end $$;
revoke all on function public.login_email(text, text) from public;
grant execute on function public.login_email(text, text) to anon, authenticated;

-- Save my profile (checks the limits on the server)
create or replace function public.update_my_profile(p_display_name text, p_username text, p_bio text,
                                                    p_avatar_url text, p_accent text, p_link text)
returns void language plpgsql security definer set search_path = public as $$
declare v_vip boolean := public.is_vip() or public.is_admin(); v_max int;
begin
  if auth.uid() is null then raise exception 'Please sign in first.'; end if;
  v_max := case when v_vip then 280 else 100 end;
  if char_length(coalesce(p_bio,'')) > v_max then
    raise exception 'Your mission statement can be up to % characters.', v_max; end if;
  if p_username is not null and p_username !~ '^[A-Za-z0-9_]{3,20}$' then
    raise exception 'Usernames are 3 to 20 letters, numbers, or underscores.'; end if;
  if p_username is not null and exists (select 1 from public.profiles
       where lower(username) = lower(p_username) and id <> auth.uid()) then
    raise exception 'That username is taken.'; end if;
  if not v_vip and (p_accent is not null or p_link is not null) then
    raise exception 'Accent colors and links are for VIPs.'; end if;
  if p_link is not null and (p_link !~ '^https://' or char_length(p_link) > 120) then
    raise exception 'Links must start with https:// and be under 120 characters.'; end if;
  if p_accent is not null and p_accent !~ '^#[0-9A-Fa-f]{6}$' then raise exception 'Unknown color.'; end if;
  update public.profiles set
    display_name = left(coalesce(nullif(trim(p_display_name),''), display_name), 40),
    username = p_username, bio = nullif(trim(p_bio),''), avatar_url = p_avatar_url,
    accent = p_accent, link = p_link
  where id = auth.uid();
end $$;
revoke all on function public.update_my_profile(text,text,text,text,text,text) from public, anon;
grant execute on function public.update_my_profile(text,text,text,text,text,text) to authenticated;

-- What members can see about each other (no emails, no payment info)
create or replace view public.public_profiles as
  select p.id, p.username, p.display_name, p.avatar_url, p.bio, p.created_at, p.is_admin,
         (p.is_admin or p.is_vip or coalesce(p.vip_until > now(), false) or coalesce(p.paypal_status in ('new','active'), false)) as is_vip,
         case when (p.is_admin or p.is_vip or coalesce(p.vip_until > now(), false) or coalesce(p.paypal_status in ('new','active'), false)) then p.accent end as accent,
         case when (p.is_admin or p.is_vip or coalesce(p.vip_until > now(), false) or coalesce(p.paypal_status in ('new','active'), false)) then p.link end as link
  from public.profiles p;
revoke all on public.public_profiles from public, anon;
grant select on public.public_profiles to authenticated;

-- My own profile now includes the new fields
create or replace function public.my_profile() returns json
language sql stable security definer set search_path = public as $$
  select json_build_object('display_name', display_name, 'is_vip', is_vip, 'is_admin', is_admin,
                           'vip_source', vip_source, 'vip_until', vip_until, 'marketing_opt_in', marketing_opt_in,
                           'paypal_status', paypal_status, 'username', username, 'avatar_url', avatar_url,
                           'bio', bio, 'accent', accent, 'link', link)
  from public.profiles where id = auth.uid();
$$;

-- Admin member list shows usernames too
drop function if exists public.admin_members();
create or replace function public.admin_members()
returns table(id uuid, email text, display_name text, username text, role text, joined timestamptz,
              keyholder_until timestamptz, email_confirmed boolean, opted_in boolean, list_added_at timestamptz,
              paypal_status text, paypal_sub_id text)
language plpgsql stable security definer set search_path = public, auth as $$
begin
  if not public.is_admin() then raise exception 'Admins only.'; end if;
  return query
  select p.id, u.email::text, p.display_name, p.username,
         case when p.is_admin then 'Admin'
              when p.is_vip or coalesce(p.vip_until > now(), false) or coalesce(p.paypal_status in ('new','active'), false) then 'Keyholder'
              when p.vip_until is not null or p.paypal_status = 'ended' then 'Former Keyholder'
              else 'Member' end,
         u.created_at, p.vip_until, u.email_confirmed_at is not null, p.marketing_opt_in, p.list_added_at,
         p.paypal_status, p.paypal_sub_id
  from public.profiles p join auth.users u on u.id = p.id
  order by u.created_at desc;
end $$;
revoke all on function public.admin_members() from public, anon;
grant execute on function public.admin_members() to authenticated;

-- ---------- Profile photos ----------
insert into storage.buckets (id, name, public) values ('avatars', 'avatars', true) on conflict (id) do nothing;
drop policy if exists "people upload their own photo" on storage.objects;
create policy "people upload their own photo" on storage.objects for insert to authenticated
  with check (bucket_id = 'avatars' and (storage.foldername(name))[1] = auth.uid()::text);
drop policy if exists "people change their own photo" on storage.objects;
create policy "people change their own photo" on storage.objects for update to authenticated
  using (bucket_id = 'avatars' and (storage.foldername(name))[1] = auth.uid()::text);
drop policy if exists "people delete their own photo" on storage.objects;
create policy "people delete their own photo" on storage.objects for delete to authenticated
  using (bucket_id = 'avatars' and (storage.foldername(name))[1] = auth.uid()::text);
