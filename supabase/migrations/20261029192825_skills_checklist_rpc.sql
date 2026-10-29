-- NOT APPLIED — Phase 11. Frank must type "push".
create or replace function public.set_student_checklist_item(
  p_student_id uuid,
  p_item_key text,
  p_done boolean
) returns void
language plpgsql
security definer
set search_path = ''
as $$
declare sid uuid;
begin
  select school_id into sid from public.students where id = p_student_id;
  if sid is null then raise exception 'Student not found'; end if;
  if not (private.can_manage_students(sid) or (
    exists (select 1 from public.students s where s.id = p_student_id and s.instructor_id = auth.uid())
  )) then
    raise exception 'Not allowed';
  end if;
  update public.student_checklist set done = p_done
  where student_id = p_student_id and item_key = p_item_key;
end;
$$;

revoke all on function public.set_student_checklist_item(uuid, text, boolean) from public, anon;
grant execute on function public.set_student_checklist_item(uuid, text, boolean) to authenticated;

create or replace function public.upsert_student_checklist_item(
  p_student_id uuid,
  p_item_key text,
  p_label text,
  p_done boolean default false
) returns void
language plpgsql
security definer
set search_path = ''
as $$
declare sid uuid;
begin
  select school_id into sid from public.students where id = p_student_id;
  if sid is null then raise exception 'Student not found'; end if;
  if not private.can_manage_students(sid) then raise exception 'Not allowed'; end if;
  insert into public.student_checklist (student_id, item_key, label, done, source)
  values (p_student_id, p_item_key, p_label, coalesce(p_done, false), 'school')
  on conflict (student_id, item_key) do update
    set label = excluded.label, done = excluded.done;
end;
$$;

revoke all on function public.upsert_student_checklist_item(uuid, text, text, boolean) from public, anon;
grant execute on function public.upsert_student_checklist_item(uuid, text, text, boolean) to authenticated;
