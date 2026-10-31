-- =====================================================================
--  MOB VAULT — Update 5: three levels of access
--    Guest (not signed in)  →  free content only
--    Member (free account)  →  free + member content, a taste of the Guild Hall
--    Keyholder (paid)       →  everything
--  SQL Editor → New query → paste → Run. Safe to run more than once.
-- =====================================================================

create or replace function public.is_member() returns boolean
language sql stable as $$ select auth.uid() is not null $$;

-- ---------- Shelf + booklet pages get a 'member' level ----------
alter table public.pages drop constraint if exists pages_tier_check;
alter table public.pages add constraint pages_tier_check check (tier in ('free','member','vip'));
alter table public.volumes drop constraint if exists volumes_tier_chk;
alter table public.volumes add constraint volumes_tier_chk check (tier in ('free','member','vip'));

drop policy if exists "free bodies public, vip bodies for vip" on public.page_bodies;
drop policy if exists "page bodies by level" on public.page_bodies;
create policy "page bodies by level" on public.page_bodies for select using (
  exists (select 1 from public.pages p where p.id = page_id and (
    p.tier = 'free' or (p.tier = 'member' and public.is_member()) or public.is_vip() or public.is_admin())));

drop policy if exists "file info: free for all, sealed for keyholders" on public.shelf_files;
drop policy if exists "file info by level" on public.shelf_files;
create policy "file info by level" on public.shelf_files for select using (
  exists (select 1 from public.volumes v where v.id = volume_id and (
    v.tier = 'free' or (v.tier = 'member' and public.is_member()) or public.is_vip() or public.is_admin())));

drop policy if exists "keyholders read sealed files" on storage.objects;
drop policy if exists "sealed files by level" on storage.objects;
create policy "sealed files by level" on storage.objects for select to authenticated using (
  bucket_id = 'shelf-sealed' and (
    public.is_vip() or public.is_admin() or exists (
      select 1 from public.shelf_files f join public.volumes v on v.id = f.volume_id
      where f.bucket = 'shelf-sealed' and f.file_path = storage.objects.name and v.tier = 'member')));

-- Destiny Lock: guests get the opening, members get the defenses, Keyholders get the rest
update public.pages set tier = 'free'   where volume_id = 'destiny-lock' and sort in (0, 1);
update public.pages set tier = 'member' where volume_id = 'destiny-lock' and sort in (2, 3, 4, 12);
update public.pages set tier = 'vip'    where volume_id = 'destiny-lock' and sort between 5 and 11;
update public.pages set teaser = 'Join free to keep reading.' where volume_id = 'destiny-lock' and tier = 'member' and teaser is null;

-- ---------- Member names: everyone signed in can see display names, nothing else ----------
drop policy if exists "read own profile" on public.profiles;
drop policy if exists "vip can see member names" on public.profiles;
drop policy if exists "signed-in see display names" on public.profiles;
create policy "signed-in see display names" on public.profiles for select to authenticated using (true);
revoke select on public.profiles from anon, authenticated;
grant select (id, display_name, created_at) on public.profiles to authenticated;

-- The app reads your own status (Keyholder, admin, expiry) through this instead
create or replace function public.my_profile() returns json
language sql stable security definer set search_path = public as $$
  select json_build_object('display_name', display_name, 'is_vip', is_vip, 'is_admin', is_admin,
                           'vip_source', vip_source, 'vip_until', vip_until)
  from public.profiles where id = auth.uid();
$$;
revoke all on function public.my_profile() from public, anon;
grant execute on function public.my_profile() to authenticated;

-- ---------- Guild Hall: members get the open rooms, Keyholders get every room ----------
alter table public.forum_categories add column if not exists tier text not null default 'vip';
alter table public.forum_categories drop constraint if exists forum_categories_tier_chk;
alter table public.forum_categories add constraint forum_categories_tier_chk check (tier in ('member','vip'));
update public.forum_categories set tier = 'member' where name = 'Introductions';

create or replace function public.can_enter_category(p_cat bigint) returns boolean
language sql stable security definer set search_path = public as $$
  select public.is_vip() or public.is_admin() or (public.is_member() and exists (
    select 1 from public.forum_categories c where c.id = p_cat and c.tier = 'member'));
$$;

drop policy if exists "vip reads categories" on public.forum_categories;
drop policy if exists "members read categories" on public.forum_categories;
create policy "members read categories" on public.forum_categories for select using (public.is_member());

drop policy if exists "vip reads threads" on public.forum_threads;
drop policy if exists "vip posts threads" on public.forum_threads;
drop policy if exists "read threads by room" on public.forum_threads;
drop policy if exists "post threads by room" on public.forum_threads;
create policy "read threads by room" on public.forum_threads for select using (public.can_enter_category(category_id));
create policy "post threads by room" on public.forum_threads for insert
  with check (author_id = auth.uid() and public.can_enter_category(category_id));

drop policy if exists "vip reads posts" on public.forum_posts;
drop policy if exists "vip replies" on public.forum_posts;
drop policy if exists "read replies by room" on public.forum_posts;
drop policy if exists "reply by room" on public.forum_posts;
create policy "read replies by room" on public.forum_posts for select using (
  exists (select 1 from public.forum_threads t where t.id = thread_id and public.can_enter_category(t.category_id)));
create policy "reply by room" on public.forum_posts for insert with check (
  author_id = auth.uid() and exists (select 1 from public.forum_threads t where t.id = thread_id and public.can_enter_category(t.category_id)));

-- The tease: members see the TITLES of Keyholder-room discussions (never the words)
create or replace function public.guild_teasers() returns table(id bigint, category_id bigint, title text, created_at timestamptz, replies bigint)
language sql stable security definer set search_path = public as $$
  select t.id, t.category_id, t.title, t.created_at, (select count(*) from public.forum_posts p where p.thread_id = t.id)
  from public.forum_threads t join public.forum_categories c on c.id = t.category_id
  where c.tier = 'vip' and public.is_member()
  order by t.created_at desc limit 30;
$$;
revoke all on function public.guild_teasers() from public, anon;
grant execute on function public.guild_teasers() to authenticated;
