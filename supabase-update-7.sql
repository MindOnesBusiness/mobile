-- =====================================================================
--  MOB VAULT — Update 7: make or remove admins from inside the app
--  (Add tab → Members → Make admin / Remove admin)
--  SQL Editor → New query → paste → Run. Safe to run more than once.
--  The SQL commands make_admin('email') / remove_admin('email') still work too.
-- =====================================================================

create or replace function public.admin_set_admin(p_id uuid, p_on boolean) returns text
language plpgsql security definer set search_path = public as $$
begin
  if not public.is_admin() then raise exception 'Admins only.'; end if;
  if p_id = auth.uid() and not p_on then raise exception 'You can''t remove your own admin role.'; end if;
  if p_on then
    update public.profiles set is_admin = true, is_vip = true where id = p_id;
  else
    update public.profiles set is_admin = false, is_vip = false where id = p_id;
  end if;
  return 'ok';
end $$;
revoke all on function public.admin_set_admin(uuid, boolean) from public, anon;
grant execute on function public.admin_set_admin(uuid, boolean) to authenticated;
