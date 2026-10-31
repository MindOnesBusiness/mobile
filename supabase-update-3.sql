-- =====================================================================
--  MOB VAULT — Update 3: file Shelf (PDF / audio / video) + admin
--  SQL Editor → New query → paste → Run. Safe to run more than once.
-- =====================================================================

-- ---------- Admin flag ----------
alter table public.profiles add column if not exists is_admin boolean not null default false;
-- (members can still only edit their own display_name — is_admin is not writable by them)

create or replace function public.is_admin() returns boolean
language sql stable security definer set search_path = public as $$
  select coalesce((select is_admin from public.profiles where id = auth.uid()), false);
$$;

-- RedTail becomes admin, with lifetime Keyholder access
update public.profiles set is_admin = true, is_vip = true where display_name ilike 'redtail';

-- ---------- Shelf items can now be files ----------
alter table public.volumes add column if not exists kind text not null default 'booklet';
alter table public.volumes add column if not exists tier text not null default 'free';
do $$ begin
  alter table public.volumes add constraint volumes_kind_chk check (kind in ('booklet','pdf','audio','video'));
exception when duplicate_object then null; end $$;
do $$ begin
  alter table public.volumes add constraint volumes_tier_chk check (tier in ('free','vip'));
exception when duplicate_object then null; end $$;

-- Where each file lives. Kept separate so Keyholder-only file locations stay private.
create table if not exists public.shelf_files (
  volume_id text primary key references public.volumes(id) on delete cascade,
  bucket text,          -- 'shelf-public' or 'shelf-sealed' (null for video links)
  file_path text,
  video_url text
);
alter table public.shelf_files enable row level security;

drop policy if exists "file info: free for all, sealed for keyholders" on public.shelf_files;
create policy "file info: free for all, sealed for keyholders" on public.shelf_files for select using (
  exists (select 1 from public.volumes v where v.id = volume_id and (v.tier = 'free' or public.is_vip() or public.is_admin()))
);
drop policy if exists "admin manages file info" on public.shelf_files;
create policy "admin manages file info" on public.shelf_files for all using (public.is_admin()) with check (public.is_admin());

-- Admin can see hidden items and add / edit / remove Shelf items
drop policy if exists "admin reads all volumes" on public.volumes;
create policy "admin reads all volumes" on public.volumes for select using (public.is_admin());
drop policy if exists "admin manages volumes" on public.volumes;
create policy "admin manages volumes" on public.volumes for all using (public.is_admin()) with check (public.is_admin());

-- ---------- File storage ----------
insert into storage.buckets (id, name, public) values ('shelf-public', 'shelf-public', true)
  on conflict (id) do nothing;
insert into storage.buckets (id, name, public) values ('shelf-sealed', 'shelf-sealed', false)
  on conflict (id) do nothing;

drop policy if exists "keyholders read sealed files" on storage.objects;
create policy "keyholders read sealed files" on storage.objects for select to authenticated
  using (bucket_id = 'shelf-sealed' and (public.is_vip() or public.is_admin()));

drop policy if exists "admin uploads shelf files" on storage.objects;
create policy "admin uploads shelf files" on storage.objects for insert to authenticated
  with check (bucket_id in ('shelf-public','shelf-sealed') and public.is_admin());

drop policy if exists "admin updates shelf files" on storage.objects;
create policy "admin updates shelf files" on storage.objects for update to authenticated
  using (bucket_id in ('shelf-public','shelf-sealed') and public.is_admin());

drop policy if exists "admin deletes shelf files" on storage.objects;
create policy "admin deletes shelf files" on storage.objects for delete to authenticated
  using (bucket_id in ('shelf-public','shelf-sealed') and public.is_admin());

-- Check: this should list RedTail. If it's empty, RedTail hasn't signed up yet
-- (or uses a different display name) — sign up first, then run this file again.
select display_name, is_admin, is_vip from public.profiles where is_admin;
