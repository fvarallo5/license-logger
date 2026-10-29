-- LOCAL / STAGING SEED ONLY. Every person, school, phone number and email here is FAKE.
-- Emails use the reserved .example domain. Never run this on production.
-- Story matches the Flutter mockup (lib/data/sample_data.dart): Green Light Driving (Austin),
-- students Maya & Leo Lopez, parents Ana & Carlos, instructor Jordan Hale.
-- A second school (Blue Line Driving) exists only to prove schools can't see each other.
-- Noah Kim is an INDEPENDENT student (no driving school, practising with his mom Grace).

-- ---------- people (auth.users -> profiles via the live on_auth_user_created trigger) ----------
insert into auth.users (instance_id, id, aud, role, email, encrypted_password, email_confirmed_at,
                        raw_app_meta_data, raw_user_meta_data, created_at, updated_at)
select '00000000-0000-0000-0000-000000000000', v.id::uuid, 'authenticated', 'authenticated', v.email,
       extensions.crypt('LocalOnly-Password1', extensions.gen_salt('bf')), now(),
       '{"provider":"email","providers":["email"]}'::jsonb, jsonb_build_object('full_name', v.name), now(), now()
from (values
  ('00000000-0000-4000-8000-000000000001', 'owner@greenlight.example',   'Dana Reyes'),
  ('00000000-0000-4000-8000-000000000002', 'jordan@greenlight.example',  'Jordan Hale'),
  ('00000000-0000-4000-8000-000000000003', 'desk@greenlight.example',    'Priya Shah'),
  ('00000000-0000-4000-8000-000000000011', 'maya@student.example',       'Maya Lopez'),
  ('00000000-0000-4000-8000-000000000012', 'leo@student.example',        'Leo Lopez'),
  ('00000000-0000-4000-8000-000000000021', 'ana@family.example',         'Ana Lopez'),
  ('00000000-0000-4000-8000-000000000022', 'carlos@family.example',      'Carlos Lopez'),
  ('00000000-0000-4000-8000-000000000031', 'owner@blueline.example',     'Morgan Blake'),
  ('00000000-0000-4000-8000-000000000032', 'sam@student.example',        'Sam Carter'),
  ('00000000-0000-4000-8000-000000000041', 'stranger@nowhere.example',   'Not Linked'),
  ('00000000-0000-4000-8000-000000000051', 'noah@student.example',       'Noah Kim'),
  ('00000000-0000-4000-8000-000000000052', 'grace@family.example',       'Grace Kim')
) as v(id, email, name)
on conflict (id) do nothing;

update public.profiles set account_type = 'staff'   where id in ('00000000-0000-4000-8000-000000000001','00000000-0000-4000-8000-000000000002','00000000-0000-4000-8000-000000000003','00000000-0000-4000-8000-000000000031');
update public.profiles set account_type = 'student' where id in ('00000000-0000-4000-8000-000000000011','00000000-0000-4000-8000-000000000012','00000000-0000-4000-8000-000000000032','00000000-0000-4000-8000-000000000051');
update public.profiles set account_type = 'family'  where id in ('00000000-0000-4000-8000-000000000021','00000000-0000-4000-8000-000000000022','00000000-0000-4000-8000-000000000052');

-- ---------- schools ----------
insert into public.schools (id, name, city, phone, timezone, created_by) values
  ('10000000-0000-4000-8000-000000000001', 'Green Light Driving', 'Austin, TX', '(512) 555-0142', 'America/Chicago', '00000000-0000-4000-8000-000000000001'),
  ('10000000-0000-4000-8000-000000000002', 'Blue Line Driving',   'Dallas, TX', '(214) 555-0199', 'America/Chicago', '00000000-0000-4000-8000-000000000031')
on conflict (id) do nothing;

insert into public.school_members (school_id, user_id, role, access) values
  ('10000000-0000-4000-8000-000000000001', '00000000-0000-4000-8000-000000000001', 'owner',      private.school_normalize_access('owner', '{}')),
  ('10000000-0000-4000-8000-000000000001', '00000000-0000-4000-8000-000000000002', 'instructor', private.school_normalize_access('instructor', '{}')),
  ('10000000-0000-4000-8000-000000000001', '00000000-0000-4000-8000-000000000003', 'front_desk', private.school_normalize_access('front_desk', '{}')),
  ('10000000-0000-4000-8000-000000000002', '00000000-0000-4000-8000-000000000031', 'owner',      private.school_normalize_access('owner', '{}'))
on conflict do nothing;

select private.seed_package_catalog('10000000-0000-4000-8000-000000000001');
select private.seed_package_catalog('10000000-0000-4000-8000-000000000002');

insert into public.lots (id, school_id, name, is_default) values
  ('11000000-0000-4000-8000-000000000001', '10000000-0000-4000-8000-000000000001', 'Green Light lot', true)
on conflict do nothing;
insert into public.cars (id, school_id, name, plate, color, model, assigned_user_id) values
  ('12000000-0000-4000-8000-000000000001', '10000000-0000-4000-8000-000000000001', 'Red Civic', 'LRN-4821', '#C0392B', 'Honda Civic', '00000000-0000-4000-8000-000000000002')
on conflict do nothing;

-- ---------- students ----------
insert into public.students (id, school_id, first_name, last_name, state_code, permit_on, hour_goal, night_goal,
                             instructor_id, user_id, join_code) values
  ('20000000-0000-4000-8000-000000000001', '10000000-0000-4000-8000-000000000001', 'Maya', 'Lopez', 'TX', '2026-04-14', 50, 10,
   '00000000-0000-4000-8000-000000000002', '00000000-0000-4000-8000-000000000011', 'MAYA01'),
  ('20000000-0000-4000-8000-000000000002', '10000000-0000-4000-8000-000000000001', 'Leo', 'Lopez', 'TX', '2026-09-30', 50, 10,
   null, '00000000-0000-4000-8000-000000000012', 'LEO002'),
  ('20000000-0000-4000-8000-000000000003', '10000000-0000-4000-8000-000000000002', 'Sam', 'Carter', 'TX', '2026-08-01', 50, 10,
   null, '00000000-0000-4000-8000-000000000032', 'SAM003'),
  ('20000000-0000-4000-8000-000000000004', '10000000-0000-4000-8000-000000000001', 'Riley', 'Unclaimed', 'TX', null, 50, 10,
   null, null, 'RILEY4'),
  -- Independent: school_id NULL. Owned by Noah's own account, linked to Grace below.
  ('20000000-0000-4000-8000-000000000005', null, 'Noah', 'Kim', 'TX', '2026-07-20', 50, 10,
   null, '00000000-0000-4000-8000-000000000051', 'NOAH05')
on conflict (id) do nothing;

insert into public.student_contacts (school_id, student_id, name, email, kind, user_id) values
  ('10000000-0000-4000-8000-000000000001', '20000000-0000-4000-8000-000000000001', 'Ana Lopez', 'ana@family.example', 'guardian', '00000000-0000-4000-8000-000000000021');

insert into public.family_links (id, student_id, user_id, relationship) values
  ('30000000-0000-4000-8000-000000000001', '20000000-0000-4000-8000-000000000001', '00000000-0000-4000-8000-000000000021', 'parent'),
  ('30000000-0000-4000-8000-000000000002', '20000000-0000-4000-8000-000000000001', '00000000-0000-4000-8000-000000000022', 'parent'),
  ('30000000-0000-4000-8000-000000000003', '20000000-0000-4000-8000-000000000002', '00000000-0000-4000-8000-000000000021', 'parent'),
  ('30000000-0000-4000-8000-000000000004', '20000000-0000-4000-8000-000000000002', '00000000-0000-4000-8000-000000000022', 'parent'),
  ('30000000-0000-4000-8000-000000000005', '20000000-0000-4000-8000-000000000005', '00000000-0000-4000-8000-000000000052', 'parent')
on conflict do nothing;

insert into public.supervisors (id, student_id, user_id, name, relationship, can_sign, meets_requirements) values
  ('40000000-0000-4000-8000-000000000001', '20000000-0000-4000-8000-000000000001', '00000000-0000-4000-8000-000000000021', 'Ana Lopez', 'parent', true, true),
  ('40000000-0000-4000-8000-000000000002', '20000000-0000-4000-8000-000000000001', '00000000-0000-4000-8000-000000000022', 'Carlos Lopez', 'parent', true, true),
  ('40000000-0000-4000-8000-000000000003', '20000000-0000-4000-8000-000000000001', '00000000-0000-4000-8000-000000000002', 'Jordan Hale', 'instructor', false, true),
  ('40000000-0000-4000-8000-000000000004', '20000000-0000-4000-8000-000000000002', '00000000-0000-4000-8000-000000000021', 'Ana Lopez', 'parent', true, true),
  ('40000000-0000-4000-8000-000000000005', '20000000-0000-4000-8000-000000000002', '00000000-0000-4000-8000-000000000022', 'Carlos Lopez', 'parent', true, true),
  ('40000000-0000-4000-8000-000000000006', '20000000-0000-4000-8000-000000000005', '00000000-0000-4000-8000-000000000052', 'Grace Kim', 'parent', true, true)
on conflict do nothing;

-- ---------- drives (from sample_data.dart) ----------
-- Inserted as 'pending'; the ones marked signed are then signed through sign_drive(),
-- exactly like the app would, so sign-off rows and locks are real.
create temporary table seed_drives (
  code text, student uuid, sup uuid, kind text, src text, day date, t0 time, t1 time,
  mins int, night int, miles numeric, a text, b text, cond text[], skills text[], notes text, sign text
) on commit drop;

insert into seed_drives values
 ('D-1018','20000000-0000-4000-8000-000000000001','40000000-0000-4000-8000-000000000001','practice','gps','2026-10-18','19:10','20:10',60,60,25.2,'Home · Mueller','Home · Mueller','{Dry,Night,"Light traffic"}','{"Night driving","Highway merge"}','Short night run on 290.',null),
 ('D-1017','20000000-0000-4000-8000-000000000001','40000000-0000-4000-8000-000000000001','practice','auto_detected','2026-10-17','10:00','12:30',150,0,61.4,'Home · Mueller','Home · Mueller','{Dry,"Sunny 78°F","Moderate traffic",Highway}','{"Highway merge","Lane changes","Unprotected lefts","Parking lot"}','MoPac north to 183, back on Loop 360.',null),
 ('L-1015','20000000-0000-4000-8000-000000000001',null,'lesson','instructor','2026-10-15','16:00','17:00',60,0,16.2,'Green Light lot','Green Light lot','{Dry,Clear}','{"Lane changes",Mirrors}','Instructor lesson · Red Civic','instructor'),
 ('D-1013','20000000-0000-4000-8000-000000000001','40000000-0000-4000-8000-000000000002','practice','gps','2026-10-13','19:10','20:10',60,60,23.9,'Home · Mueller','Home · Mueller','{Dry,Night}','{"Night driving","Lane changes"}','Night drive on 290 frontage.','on_device'),
 ('D-1011','20000000-0000-4000-8000-000000000001','40000000-0000-4000-8000-000000000001','practice','gps','2026-10-11','14:00','15:30',90,0,35.7,'Home · Mueller','Home · Mueller','{Dry,Sunny,"Moderate traffic"}','{"Unprotected lefts",Roundabout}','Practiced unprotected lefts on Berkman.','family'),
 ('L-1008','20000000-0000-4000-8000-000000000001',null,'lesson','instructor','2026-10-08','16:00','17:00',60,0,14.8,'Green Light lot','Green Light lot','{Dry,Clear}','{Residential,Stops}','Instructor lesson · Red Civic','instructor'),
 ('D-1006','20000000-0000-4000-8000-000000000001','40000000-0000-4000-8000-000000000002','practice','gps','2026-10-06','17:15','18:15',60,0,22.4,'Home · Mueller','Home · Mueller','{Dry,Clear,"Heavy traffic"}','{Merging,"Lane changes"}','IH-35 frontage roads.','on_device'),
 ('D-1004','20000000-0000-4000-8000-000000000001','40000000-0000-4000-8000-000000000001','practice','gps','2026-10-04','09:30','10:30',60,0,26.1,'Home · Mueller','Zilker Park','{Dry,Sunny,"Light traffic"}','{"Left turns","Lane changes"}','Downtown loop, Cesar Chavez.','family'),
 ('D-0927','20000000-0000-4000-8000-000000000001','40000000-0000-4000-8000-000000000002','practice','gps','2026-09-27','11:00','11:42',42,0,15.3,'Home · Mueller','Home · Mueller','{Wet,"Light rain"}','{Residential,"Following distance"}','Light rain, slowed down, longer gaps.','on_device'),
 ('D-0923','20000000-0000-4000-8000-000000000001','40000000-0000-4000-8000-000000000001','practice','gps','2026-09-23','18:00','18:48',48,0,19.6,'Home · Mueller','H-E-B Mueller','{Dry,Sunny,"Heavy traffic"}','{"Lane changes",Parking}','Rush hour on Airport Blvd.','family'),
 ('D-0920','20000000-0000-4000-8000-000000000001','40000000-0000-4000-8000-000000000001','practice','gps','2026-09-20','19:45','20:45',60,60,24.8,'Home · Mueller','Home · Mueller','{Dry,Night,"Light traffic"}','{"Night driving",Headlights}','First night drive. High beams on Manor Rd.','family'),
 ('D-0914','20000000-0000-4000-8000-000000000001','40000000-0000-4000-8000-000000000002','practice','manual','2026-09-14','15:00','15:40',40,0,12.0,'Home · Mueller','Home · Mueller','{Dry,Cloudy}','{Residential}','Phone was off, entered by hand.','on_device'),
 ('D-0909','20000000-0000-4000-8000-000000000001','40000000-0000-4000-8000-000000000002','practice','gps','2026-09-09','17:30','18:24',54,0,21.5,'Home · Mueller','Home · Mueller','{Dry,Clear,"Moderate traffic"}','{Residential,"Stop signs"}','Four-way stops and right turns.','on_device'),
 ('D-0906','20000000-0000-4000-8000-000000000001','40000000-0000-4000-8000-000000000001','practice','gps','2026-09-06','10:00','10:50',50,0,18.2,'Home · Mueller','Home · Mueller','{Dry,Sunny,"Light traffic"}','{"Parking lot",Residential}','First drive: empty lot, then quiet streets.','family'),
 ('D-1019','20000000-0000-4000-8000-000000000002','40000000-0000-4000-8000-000000000005','practice','gps','2026-10-19','11:00','11:45',45,0,14.1,'Home · Mueller','Home · Mueller','{Dry,Sunny}','{"Parking lot",Residential}','First drive.',null),
 ('D-1012','20000000-0000-4000-8000-000000000002','40000000-0000-4000-8000-000000000004','practice','gps','2026-10-12','10:00','10:40',40,0,9.8,'Home · Mueller','Home · Mueller','{Dry,Clear}','{"Parking lot"}','Empty lot basics.','family'),
 ('D-0901','20000000-0000-4000-8000-000000000003',null,'practice','gps','2026-09-01','09:00','10:00',60,0,20.0,'Dallas','Dallas','{Dry}','{Residential}','Other school''s student.',null),
 -- Noah (independent): 150 min on 10/16 -> 120 credited (TX 2 h/day cap), 30 night; one pending, one signed on his phone.
 ('N-1016','20000000-0000-4000-8000-000000000005','40000000-0000-4000-8000-000000000006','practice','gps','2026-10-16','18:00','20:30',150,30,52.0,'Home · Round Rock','Home · Round Rock','{Dry,Dusk}','{"Highway merge","Night driving"}','Long loop on 45.','family'),
 ('N-1019','20000000-0000-4000-8000-000000000005','40000000-0000-4000-8000-000000000006','practice','gps','2026-10-19','09:00','10:00',60,0,20.5,'Home · Round Rock','Home · Round Rock','{Dry}','{Residential}','Neighborhood practice.','on_device'),
 ('N-1021','20000000-0000-4000-8000-000000000005','40000000-0000-4000-8000-000000000006','practice','gps','2026-10-21','17:00','17:40',40,0,11.0,'Home · Round Rock','H-E-B','{Dry}','{Parking}','Waiting for Mom to sign.',null);

insert into public.drives (id, student_id, supervisor_id, kind, source, status, started_at, ended_at, tz,
                           duration_minutes, night_minutes, distance_miles, start_label, end_label,
                           conditions, skills, notes, route_polyline, route_point_count, created_by)
select extensions.uuid_generate_v5('6ba7b811-9dad-11d1-80b4-00c04fd430c8'::uuid, 'licenselogger-seed:' || code),
       student, sup, kind, src, 'pending',
       (day + t0) at time zone 'America/Chicago', (day + t1) at time zone 'America/Chicago', 'America/Chicago',
       mins, night, miles, a, b, cond, skills, notes,
       '_p~iF~ps|U_ulLnnqC_mqNvxq`@', 3,
       (select user_id from public.students where id = student)
  from seed_drives;

-- Sign through the real RPC, as the right person.
do $$
declare
  r record;
  who uuid;
begin
  for r in select sd.*, extensions.uuid_generate_v5('6ba7b811-9dad-11d1-80b4-00c04fd430c8'::uuid, 'licenselogger-seed:' || sd.code) as drive_id
             from seed_drives sd where sd.sign is not null loop
    who := case r.sign
             when 'on_device' then (select user_id from public.students where id = r.student)
             when 'family' then (select user_id from public.supervisors where id = r.sup)
             else '00000000-0000-4000-8000-000000000002'::uuid end;
    perform set_config('request.jwt.claims', jsonb_build_object('sub', who, 'role', 'authenticated')::text, true);
    perform public.sign_drive(r.drive_id,
              case r.sign when 'family' then 'family_account' else r.sign end,
              r.sup,
              case r.sign when 'on_device' then (select upper(left(split_part(name, ' ', 1), 1) || left(split_part(name, ' ', 2), 1))
                                                   from public.supervisors where id = r.sup) end,
              '{"model":"iPhone 15 (seed)","os":"iOS 26","app_version":"1.0.0-seed"}'::jsonb);
  end loop;
  perform set_config('request.jwt.claims', '', true);
end $$;

-- ---------- lessons ----------
insert into public.lessons (id, student_id, instructor_id, car_id, lot_id, starts_at, ends_at, topic, pickup, status, drive_id, created_by) values
  ('50000000-0000-4000-8000-000000000001', '20000000-0000-4000-8000-000000000001', '00000000-0000-4000-8000-000000000002',
   '12000000-0000-4000-8000-000000000001', '11000000-0000-4000-8000-000000000001',
   timestamp '2026-10-29 16:00' at time zone 'America/Chicago', timestamp '2026-10-29 17:00' at time zone 'America/Chicago',
   'Highway merge practice', 'Green Light lot', 'booked', null, '00000000-0000-4000-8000-000000000003'),
  ('50000000-0000-4000-8000-000000000002', '20000000-0000-4000-8000-000000000001', '00000000-0000-4000-8000-000000000002',
   '12000000-0000-4000-8000-000000000001', '11000000-0000-4000-8000-000000000001',
   timestamp '2026-10-15 16:00' at time zone 'America/Chicago', timestamp '2026-10-15 17:00' at time zone 'America/Chicago',
   'Lane changes', 'Green Light lot', 'completed',
   extensions.uuid_generate_v5('6ba7b811-9dad-11d1-80b4-00c04fd430c8'::uuid, 'licenselogger-seed:L-1015'), '00000000-0000-4000-8000-000000000003')
on conflict do nothing;

-- ---------- billing (QuickBooks mirror, not connected locally) ----------
insert into public.billing_customers (id, school_id, student_id, display_name, email) values
  ('60000000-0000-4000-8000-000000000001', '10000000-0000-4000-8000-000000000001', '20000000-0000-4000-8000-000000000001', 'Ana Lopez', 'ana@family.example')
on conflict do nothing;
insert into public.invoices (id, school_id, customer_id, student_id, doc_number, txn_date, due_date, subtotal, total, balance, status) values
  ('61000000-0000-4000-8000-000000000001', '10000000-0000-4000-8000-000000000001', '60000000-0000-4000-8000-000000000001',
   '20000000-0000-4000-8000-000000000001', 'GL-1001', '2026-09-01', '2026-09-15', 450.00, 450.00, 200.00, 'partially_paid')
on conflict do nothing;
insert into public.invoice_lines (invoice_id, line_no, description, quantity, unit_price, amount) values
  ('61000000-0000-4000-8000-000000000001', 1, '10-hour BTW package', 1, 450.00, 450.00)
on conflict do nothing;
insert into public.payments (id, school_id, customer_id, invoice_id, student_id, amount, received_on, method) values
  ('62000000-0000-4000-8000-000000000001', '10000000-0000-4000-8000-000000000001', '60000000-0000-4000-8000-000000000001',
   '61000000-0000-4000-8000-000000000001', '20000000-0000-4000-8000-000000000001', 250.00, '2026-09-02', 'card')
on conflict do nothing;

-- The seed inserted drives as "pending" before signing them, which queued
-- reminder emails. Clear them so a fresh local stack starts with an empty outbox.
delete from private.notification_outbox;
