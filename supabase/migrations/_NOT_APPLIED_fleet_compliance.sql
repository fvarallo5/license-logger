-- NOT APPLIED — Phase 6. Frank must type "push".
-- update_car_compliance + update_lot_coords (SECURITY DEFINER, search_path '', anon revoked)

create or replace function public.update_car_compliance(
  p_car_id uuid,
  p_school_id uuid,
  p_patch jsonb
) returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  if not private.can_manage_people(p_school_id) then
    raise exception 'Not allowed';
  end if;
  update public.cars set
    service_due = case when p_patch ? 'service_due' then nullif(p_patch->>'service_due','')::date else service_due end,
    inspect_due = case when p_patch ? 'inspect_due' then nullif(p_patch->>'inspect_due','')::date else inspect_due end,
    reg_due = case when p_patch ? 'reg_due' then nullif(p_patch->>'reg_due','')::date else reg_due end,
    ins_due = case when p_patch ? 'ins_due' then nullif(p_patch->>'ins_due','')::date else ins_due end,
    dual_control = case when p_patch ? 'dual_control' then (p_patch->>'dual_control')::boolean else dual_control end,
    notes = case when p_patch ? 'notes' then coalesce(p_patch->>'notes','') else notes end,
    assigned_user_id = case when p_patch ? 'assigned_user_id' then nullif(p_patch->>'assigned_user_id','')::uuid else assigned_user_id end,
    odo_miles = case when p_patch ? 'odo_miles' then (p_patch->>'odo_miles')::numeric else odo_miles end
  where id = p_car_id and school_id = p_school_id;
end;
$$;

revoke all on function public.update_car_compliance(uuid, uuid, jsonb) from public, anon;
grant execute on function public.update_car_compliance(uuid, uuid, jsonb) to authenticated;

create or replace function public.update_lot_coords(
  p_lot_id uuid,
  p_school_id uuid,
  p_lat numeric,
  p_lng numeric
) returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  if not private.can_manage_people(p_school_id) then
    raise exception 'Not allowed';
  end if;
  update public.lots set lat = p_lat, lng = p_lng
  where id = p_lot_id and school_id = p_school_id;
end;
$$;

revoke all on function public.update_lot_coords(uuid, uuid, numeric, numeric) from public, anon;
grant execute on function public.update_lot_coords(uuid, uuid, numeric, numeric) to authenticated;
