-- =====================================================================
--  MOB VAULT — Supabase setup
--  Paste this whole file into Supabase → SQL Editor → New query → Run.
--  Safe to run once on a fresh project.
-- =====================================================================

-- ---------- PROFILES (one per member) ----------
create table public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  display_name text not null default 'Member',
  is_vip boolean not null default false,
  vip_source text,                       -- 'code:CODEX', 'blockonomics', 'manual', ...
  vip_since timestamptz,
  created_at timestamptz not null default now()
);

-- Auto-create a profile when someone signs up
create function public.handle_new_user() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  insert into public.profiles (id, display_name)
  values (new.id, left(coalesce(nullif(new.raw_user_meta_data->>'display_name',''), split_part(new.email,'@',1)), 40));
  return new;
end $$;
create trigger on_auth_user_created after insert on auth.users
  for each row execute function public.handle_new_user();

-- Helper: is the current user VIP?
create function public.is_vip() returns boolean
language sql stable security definer set search_path = public as $$
  select coalesce((select is_vip from public.profiles where id = auth.uid()), false);
$$;

alter table public.profiles enable row level security;
create policy "read own profile" on public.profiles for select using (id = auth.uid());
create policy "vip can see member names" on public.profiles for select using (public.is_vip());
create policy "update own profile" on public.profiles for update using (id = auth.uid());
-- Members may only change their display name — never their VIP status
revoke update on public.profiles from authenticated, anon;
grant update (display_name) on public.profiles to authenticated;

-- ---------- LIBRARY ----------
create table public.volumes (
  id text primary key,
  numeral text not null,
  title text not null,
  subtitle text,
  status text not null default 'live' check (status in ('live','soon','hidden')),
  sort int not null default 0
);

create table public.pages (                -- page list + teasers: visible to everyone
  id bigint generated always as identity primary key,
  volume_id text not null references public.volumes(id) on delete cascade,
  sort int not null,
  numeral text not null,
  title text not null,
  tier text not null default 'free' check (tier in ('free','vip')),
  teaser text
);

create table public.page_bodies (          -- the actual words: VIP pages protected
  page_id bigint primary key references public.pages(id) on delete cascade,
  body text not null
);

alter table public.volumes enable row level security;
alter table public.pages enable row level security;
alter table public.page_bodies enable row level security;
create policy "anyone reads live volumes" on public.volumes for select using (status <> 'hidden');
create policy "anyone reads page list" on public.pages for select using (true);
create policy "free bodies public, vip bodies for vip" on public.page_bodies for select using (
  exists (select 1 from public.pages p where p.id = page_id and (p.tier = 'free' or public.is_vip()))
);

-- ---------- VIP KEYS (Codex bundle, manual sales) ----------
create table public.vip_codes (
  code text primary key,
  source text not null default 'manual',   -- e.g. 'CODEX-PRESALE'
  redeemed_by uuid references public.profiles(id),
  redeemed_at timestamptz,
  created_at timestamptz not null default now()
);
alter table public.vip_codes enable row level security;  -- no policies = no direct access

create function public.redeem_vip_code(p_code text) returns boolean
language plpgsql security definer set search_path = public as $$
declare v_source text;
begin
  if auth.uid() is null then raise exception 'Please sign in first.'; end if;
  update public.vip_codes set redeemed_by = auth.uid(), redeemed_at = now()
   where code = upper(trim(p_code)) and redeemed_by is null
   returning source into v_source;
  if v_source is null then return false; end if;
  update public.profiles set is_vip = true, vip_source = 'code:' || v_source, vip_since = now()
   where id = auth.uid();
  return true;
end $$;
revoke all on function public.redeem_vip_code(text) from public, anon;
grant execute on function public.redeem_vip_code(text) to authenticated;

-- Admin-only: generate keys. Run in the SQL editor, e.g.
--   select * from public.generate_vip_codes(50, 'CODEX-PRESALE');
create function public.generate_vip_codes(n int, p_source text)
returns setof text language plpgsql security definer set search_path = public as $$
declare c text; i int := 0;
begin
  while i < n loop
    c := 'MOB-' || upper(substr(md5(random()::text || clock_timestamp()::text),1,4)) || '-' ||
                   upper(substr(md5(random()::text || clock_timestamp()::text),1,4));
    begin
      insert into public.vip_codes(code, source) values (c, p_source);
      i := i + 1; return next c;
    exception when unique_violation then -- try again
    end;
  end loop;
end $$;
revoke all on function public.generate_vip_codes(int, text) from public, anon, authenticated;

-- ---------- GUILD HALL (VIP forum) ----------
create table public.forum_categories (
  id bigint generated always as identity primary key,
  name text not null,
  sort int not null default 0
);
create table public.forum_threads (
  id bigint generated always as identity primary key,
  category_id bigint not null references public.forum_categories(id),
  author_id uuid not null references public.profiles(id) on delete cascade,
  title text not null check (char_length(title) between 1 and 140),
  body text not null check (char_length(body) between 1 and 5000),
  created_at timestamptz not null default now()
);
create table public.forum_posts (
  id bigint generated always as identity primary key,
  thread_id bigint not null references public.forum_threads(id) on delete cascade,
  author_id uuid not null references public.profiles(id) on delete cascade,
  body text not null check (char_length(body) between 1 and 5000),
  created_at timestamptz not null default now()
);
alter table public.forum_categories enable row level security;
alter table public.forum_threads enable row level security;
alter table public.forum_posts enable row level security;
create policy "vip reads categories" on public.forum_categories for select using (public.is_vip());
create policy "vip reads threads" on public.forum_threads for select using (public.is_vip());
create policy "vip posts threads" on public.forum_threads for insert with check (public.is_vip() and author_id = auth.uid());
create policy "author deletes thread" on public.forum_threads for delete using (author_id = auth.uid());
create policy "vip reads posts" on public.forum_posts for select using (public.is_vip());
create policy "vip replies" on public.forum_posts for insert with check (public.is_vip() and author_id = auth.uid());
create policy "author deletes post" on public.forum_posts for delete using (author_id = auth.uid());

insert into public.forum_categories (name, sort) values
  ('Introductions',1), ('Destiny Lock Circle',2), ('Shadow Work',3), ('Guild Business',4);

-- =====================================================================
--  CONTENT: Volume I — Destiny Lock
-- =====================================================================
insert into public.volumes (id, numeral, title, subtitle, status, sort) values
  ('destiny-lock','I','Destiny Lock','Guard your path against destiny swapping','live',1),
  ('codex-7-gates','II','Codex of the 7 Gates','Coming soon to the Vault','soon',2);

with p as (
  insert into public.pages (volume_id, sort, numeral, title, tier, teaser) values
  ('destiny-lock',0,'0','The Threshold','free',null),
  ('destiny-lock',1,'I','What Is Destiny Swapping?','free',null),
  ('destiny-lock',2,'II','Seal the Morning','free',null),
  ('destiny-lock',3,'III','Guard Your Gates','free',null),
  ('destiny-lock',4,'IV','Shut the Leak','free',null),
  ('destiny-lock',5,'V','Return to Sender','vip','Discernment for gifts, tokens and favors that come with strings.'),
  ('destiny-lock',6,'VI','Cut the Cord','vip','A three-minute release to take your energy back.'),
  ('destiny-lock',7,'VII','The Mirror Check','vip','Where you may be handing your power over yourself.'),
  ('destiny-lock',8,'VIII','Night Watch','vip','Guarding the gate while you sleep.'),
  ('destiny-lock',9,'IX','The Emergency Reset','vip','Four steps for the days everything is being pulled from you.'),
  ('destiny-lock',10,'X','The Destiny Declaration','vip','Your personal reclamation, written in your name.'),
  ('destiny-lock',11,'XI','Red Flag Quick-Scan','vip','Eight signs someone may be drawing from your well.'),
  ('destiny-lock',12,'XII','Pass the Lantern','free',null)
  returning id, sort
)
insert into public.page_bodies (page_id, body)
select p.id, b.body from p join (values
 (0, '<blockquote>Your blessings have your name on them. Keep it that way.</blockquote><p>Ever had everything lined up — then watched it slip away while someone else walked off with your exact breakthrough? Same job. Same favor. Same momentum.</p><p>Many traditions have a name for it. This booklet gives you <strong>fast, quiet, daily defenses</strong> — each one takes under five minutes.</p><p>Swipe to begin.</p>'),
 (1, '<p><strong>Destiny swapping</strong> is the spiritual belief that a person''s God-given path — their favor, opportunities, relationships, gifts and timing — can be diverted, traded or siphoned off by another, through envy, manipulation, ritual, or quietly gaining access to your energy, words or personal items.</p><p><strong>The signs people describe:</strong></p><ul><li>Repeated "almost" moments — the door closes at the last second</li><li>Someone close rising in exactly the areas where you stall</li><li>Sudden fog or heaviness after a certain connection</li><li>Dreams of losing, trading or handing over something valuable</li></ul><p>Whether you see it as spiritual warfare, energetic drain, or plain human envy — the defense starts the same way: <strong>guard your access points.</strong></p>'),
 (2, '<p><em>Sixty seconds.</em> Before your phone, before anyone else''s voice, speak your name and claim your day aloud:</p><p class="declare">"What is mine comes to me. What is not mine leaves me."</p><p>Whoever claims the first words of the day sets its direction. Make it you.</p>'),
 (3, '<p>Hair, nail clippings, worn clothing and photos are treated in many traditions as carriers of your essence.</p><ul><li>Dispose of them yourself.</li><li>Don''t lend what carries your scent or sweat.</li><li>Be mindful of who holds your photos.</li></ul>'),
 (4, '<p>Don''t announce plans before they''re done. Keep your birth time, full name and future moves on a need-to-know basis.</p><blockquote>Silence is a shield.</blockquote><p>Bonus: it''s also solid protection against everyday scams and identity theft.</p>'),
 (5, '<p>Not every gift is a blessing. Be discerning about unexpected gifts from people whose motives feel off.</p><ul><li><strong>Pause</strong> before accepting — notice what your gut says before your manners speak.</li><li><strong>Bless</strong> anything you keep: hold it, speak over it, claim it as clean.</li><li><strong>Release</strong> what still feels heavy — give it away or let it go.</li></ul><blockquote>Trust your gut over politeness.</blockquote>'),
 (6, '<p><em>Three minutes.</em> Take your energy back without hating anyone.</p><ol><li>Write the name of anyone you feel tangled with.</li><li>Speak aloud: <span class="declare" style="display:block;margin:8px 0">"I release you. I take back what is mine. I return what is yours. Go in peace."</span></li><li>Tear the paper and discard it.</li></ol><p>Repeat as often as the tangle returns. Each time, it loosens.</p>'),
 (7, '<p>Some swaps don''t happen <em>to</em> us. We give them away — our ideas, our time, our confidence — to people who never asked to carry them.</p><p class="declare">Where have I handed over my power, my ideas, or my time without meaning to?</p><p>Write the answer in your Shadow Journal. Name it, and it loses its grip.</p>'),
 (8, '<ul><li>Before sleep, cover yourself in prayer or a protective affirmation.</li><li>Keep a notebook by the bed.</li><li>Record dreams the moment you wake — before your phone, before you move.</li><li>Review weekly. <strong>Patterns reveal themselves.</strong></li></ul>'),
 (9, '<p>For the days it feels like everything is being pulled from you:</p><ol><li><strong>Fast</strong> from social media for 24 hours.</li><li><strong>Cleanse</strong> — a salt bath, or a long, intentional shower.</li><li><strong>Speak</strong> your full name and your three biggest goals aloud.</li><li><strong>Move</strong> — take one bold action toward your destiny that same day.</li></ol>'),
 (10,'<p>Write your name in the space and speak this aloud. Keep it where you will see it daily.</p><div class="declare"><p>I, ________, reclaim every gift, door and blessing assigned to me.</p><p>What was diverted returns. What was traded is restored. What was spoken against me falls to the ground.</p><p>My path carries my name, and I walk it in full.</p></div>'),
 (11,'<p>Signs someone may be drawing from your well:</p><ol><li>Excessive questions about your plans and timing</li><li>Mirroring your goals, style or words</li><li>Sudden closeness during your breakthrough season</li><li>Requests for personal items or photos</li><li>Downplaying your wins while studying them closely</li><li>Gifts that arrive with strings</li><li>Showing up only when you are rising</li><li>Pushing you to reveal details before they are done</li></ol><p>One flag is a moment. <strong>Three is a pattern.</strong> Guard accordingly.</p>'),
 (12,'<p>Protect your path — and pass the lantern to someone who keeps <em>almost</em> making it.</p><p>The Inner Circle holds the full booklet, your private journal, and the <strong>Guild Hall</strong>, where members walk this road together.</p>')
) as b(sort, body) on b.sort = p.sort;
