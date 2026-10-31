-- =====================================================================
--  MOB VAULT — Update 11
--  Gives Destiny Lock a short description for its Shelf cover.
--  SQL Editor → New query → paste → Run. Safe to run more than once.
-- =====================================================================
update public.volumes
   set subtitle = 'Seven short practices to protect your plans, energy, and timing.'
 where id = 'destiny-lock';
