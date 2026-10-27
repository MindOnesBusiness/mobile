-- =====================================================================
--  MOB VAULT — Update 9: new names
--  The Guild Hall is now the VIP Lounge, so its "Guild Business" room
--  becomes "Vault Business". Safe to run more than once.
-- =====================================================================
update public.forum_categories set name = 'Vault Business' where name = 'Guild Business';
