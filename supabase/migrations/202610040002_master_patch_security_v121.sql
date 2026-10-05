revoke execute on function public.resolve_rpg_share_code(text) from public,anon;
grant execute on function public.resolve_rpg_share_code(text) to authenticated;
create or replace function public.set_rpg_master_patch(p_share_code text,p_patch jsonb) returns boolean language plpgsql security definer set search_path=public,pg_temp as $$
begin
 if auth.uid() is null then return false; end if;
 if not exists(select 1 from public.rpg_character_link_requests l join public.rpg_shared_characters s on s.owner_id=l.character_owner_id and s.share_code=l.share_code where s.share_code=p_share_code and l.requester_id=auth.uid() and l.status='approved') then return false; end if;
 update public.rpg_shared_characters set master_patch=coalesce(p_patch,'{}'::jsonb),master_patch_updated_at=now() where share_code=p_share_code;
 return found;
end $$;
revoke all on function public.set_rpg_master_patch(text,jsonb) from public,anon;
grant execute on function public.set_rpg_master_patch(text,jsonb) to authenticated;
drop policy if exists "approved masters update shared characters" on public.rpg_shared_characters;
