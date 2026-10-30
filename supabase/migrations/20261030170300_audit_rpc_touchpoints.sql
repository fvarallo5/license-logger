-- Applied 2026-10-30 on nqfjudwncistygsmcgrq.
-- Best-effort audit helper matching public.audit_log shape
-- (action check: insert|update|delete; columns: table_name, row_pk, changed).

create or replace function private.audit_safe(
  p_school_id uuid,
  p_action text,          -- must be insert | update | delete
  p_table_name text,
  p_row_pk text,
  p_changed jsonb default '{}'::jsonb,
  p_student_id uuid default null
) returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  a text := lower(coalesce(p_action, 'update'));
begin
  if a not in ('insert', 'update', 'delete') then
    a := 'update';
  end if;
  insert into public.audit_log (
    school_id, student_id, actor_id, action, table_name, row_pk, changed
  ) values (
    p_school_id,
    p_student_id,
    auth.uid(),
    a,
    left(coalesce(p_table_name, 'unknown'), 120),
    left(coalesce(p_row_pk, ''), 120),
    coalesce(p_changed, '{}'::jsonb)
  );
exception when others then
  null; -- never fail the caller
end;
$$;

revoke all on function private.audit_safe(uuid, text, text, text, jsonb, uuid)
  from public, anon, authenticated;

comment on function private.audit_safe(uuid, text, text, text, jsonb, uuid) is
  'Best-effort audit_log insert for SECURITY DEFINER RPCs. Example: perform private.audit_safe(school_id, ''update'', ''lessons'', lesson_id::text, jsonb_build_object(''status'', new_status));';
