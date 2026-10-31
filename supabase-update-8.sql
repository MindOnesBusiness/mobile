-- =====================================================================
--  MOB VAULT — Update 8
--  1. PayPal monthly plan for Keyholders
--  2. One Shelf item can hold a free peek, a members copy, and a full copy
--  3. Destiny Lock becomes a PDF item
--  4. The Codex leaves the Shelf list (it lives only in its pre-order card)
--  SQL Editor → New query → paste → Run. Safe to run more than once.
-- =====================================================================

-- ---------- 1. PayPal ----------
alter table public.profiles add column if not exists paypal_sub_id text;
alter table public.profiles add column if not exists paypal_status text;   -- 'new', 'active', 'ended'
alter table public.profiles add column if not exists paypal_since timestamptz;

-- Keyholder = lifetime switch, time left, or a live PayPal plan
create or replace function public.is_vip() returns boolean
language sql stable security definer set search_path = public as $$
  select coalesce((select is_vip or coalesce(vip_until > now(), false) or coalesce(paypal_status in ('new','active'), false)
                   from public.profiles where id = auth.uid()), false);
$$;

-- Called by the app right after PayPal says "approved"
create or replace function public.record_paypal_subscription(p_sub text) returns void
language plpgsql security definer set search_path = public as $$
begin
  if auth.uid() is null then raise exception 'Please sign in first.'; end if;
  if p_sub !~ '^I-[A-Z0-9]{6,40}$' then raise exception 'That PayPal plan number does not look right.'; end if;
  update public.profiles
     set paypal_sub_id = p_sub, paypal_status = 'new', paypal_since = now(),
         vip_source = 'paypal', vip_since = coalesce(vip_since, now())
   where id = auth.uid();
end $$;
revoke all on function public.record_paypal_subscription(text) from public, anon;
grant execute on function public.record_paypal_subscription(text) to authenticated;

-- Admin: mark a PayPal plan as checked, ended, or back on
create or replace function public.admin_set_paypal(p_id uuid, p_status text) returns void
language plpgsql security definer set search_path = public as $$
begin
  if not public.is_admin() then raise exception 'Admins only.'; end if;
  if p_status not in ('new','active','ended') then raise exception 'Unknown status.'; end if;
  update public.profiles set paypal_status = p_status where id = p_id;
end $$;
revoke all on function public.admin_set_paypal(uuid, text) from public, anon;
grant execute on function public.admin_set_paypal(uuid, text) to authenticated;

create or replace function public.my_profile() returns json
language sql stable security definer set search_path = public as $$
  select json_build_object('display_name', display_name, 'is_vip', is_vip, 'is_admin', is_admin,
                           'vip_source', vip_source, 'vip_until', vip_until, 'marketing_opt_in', marketing_opt_in,
                           'paypal_status', paypal_status)
  from public.profiles where id = auth.uid();
$$;

drop function if exists public.admin_members();
create or replace function public.admin_members()
returns table(id uuid, email text, display_name text, role text, joined timestamptz,
              keyholder_until timestamptz, email_confirmed boolean, opted_in boolean, list_added_at timestamptz,
              paypal_status text, paypal_sub_id text)
language plpgsql stable security definer set search_path = public, auth as $$
begin
  if not public.is_admin() then raise exception 'Admins only.'; end if;
  return query
  select p.id, u.email::text, p.display_name,
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

-- ---------- 2. Versions: free peek / members copy / full copy ----------
create table if not exists public.shelf_versions (
  volume_id text not null references public.volumes(id) on delete cascade,
  tier text not null check (tier in ('free','member','vip')),
  bucket text not null,      -- 'site' (file in the GitHub folder), 'shelf-public' or 'shelf-sealed'
  file_path text not null,
  primary key (volume_id, tier)
);
alter table public.shelf_versions enable row level security;
drop policy if exists "versions by level" on public.shelf_versions;
create policy "versions by level" on public.shelf_versions for select using (
  tier = 'free' or (tier = 'member' and public.is_member()) or public.is_vip() or public.is_admin());
drop policy if exists "admin manages versions" on public.shelf_versions;
create policy "admin manages versions" on public.shelf_versions for all using (public.is_admin()) with check (public.is_admin());

-- Which levels an item has (no file paths), so the app can say "Keyholders get the full book"
create or replace function public.shelf_levels() returns table(volume_id text, levels text[])
language sql stable security definer set search_path = public as $$
  select volume_id, array_agg(tier order by case tier when 'free' then 0 when 'member' then 1 else 2 end)
  from public.shelf_versions group by volume_id;
$$;
grant execute on function public.shelf_levels() to anon, authenticated;

-- Sealed files: Keyholders, admins, and members (for member-level files)
drop policy if exists "sealed files by level" on storage.objects;
create policy "sealed files by level" on storage.objects for select to authenticated using (
  bucket_id = 'shelf-sealed' and (
    public.is_vip() or public.is_admin()
    or exists (select 1 from public.shelf_files f join public.volumes v on v.id = f.volume_id
               where f.bucket = 'shelf-sealed' and f.file_path = storage.objects.name and v.tier = 'member')
    or exists (select 1 from public.shelf_versions sv
               where sv.bucket = 'shelf-sealed' and sv.file_path = storage.objects.name and sv.tier = 'member')));

-- ---------- 3. Destiny Lock becomes a PDF ----------
update public.volumes
   set kind = 'pdf', tier = 'free', status = 'live',
       subtitle = 'Keep what is yours safe'
 where id = 'destiny-lock';
-- The free peek lives in the app's GitHub folder. Upload the other two in the app (Add tab → Files).
insert into public.shelf_versions (volume_id, tier, bucket, file_path)
values ('destiny-lock', 'free', 'site', 'destiny-lock-free-peek.pdf')
on conflict (volume_id, tier) do update set bucket = excluded.bucket, file_path = excluded.file_path;

-- ---------- 4. The Codex leaves the Shelf list ----------
delete from public.volumes where id = 'codex-7-gates';
