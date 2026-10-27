-- =====================================================================
--  MOB VAULT — Update 2: wording + Codex off the Shelf
--  SQL Editor → New query → paste → Run. Safe to run more than once.
-- =====================================================================

-- The Codex is its own product, sold only through its pre-order. Hide it from the Shelf.
update public.volumes set status = 'hidden' where id = 'codex-7-gates';

-- Members are now called Keyholders (the "Inner Circle" name is retired).
update public.page_bodies b
   set body = '<p>Protect your path — and pass the lantern to someone who keeps <em>almost</em> making it.</p><p>Keyholders hold every sealed page, the private Shadow Journal, and the <strong>Guild Hall</strong>, where members walk this road together.</p>'
  from public.pages p
 where p.id = b.page_id and p.volume_id = 'destiny-lock' and p.sort = 12;
