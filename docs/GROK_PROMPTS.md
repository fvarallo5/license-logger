# Ready-to-paste prompts: wire the apps to the LicenseLogger backend

Paste these one at a time into Grok in the matching codebase. Every prompt starts with the **shared rules** block, so copy that block in front of each one, or paste it once at the start of a session.

> Backend reference: this folder (`supabase/migrations/*.sql` for tables and RPCs, `supabase/functions/*/index.ts` for function request shapes). Give Grok access to it, or paste the relevant file, when it asks.

---

## Shared rules (paste first)

```
You are wiring an app to the LicenseLogger Supabase backend. Rules:
- Use only the public anon key + the signed-in user's session. NEVER put the service_role key or any secret in the app. Config comes from env: VITE_SUPABASE_URL / VITE_SUPABASE_ANON_KEY (dashboard) or --dart-define SUPABASE_URL / SUPABASE_ANON_KEY (Flutter).
- Row Level Security decides what each user sees. Don't re-implement permissions in the client; just handle "permission denied" (Postgres 42501) gracefully.
- Sensitive actions are RPCs (supabase.rpc(...)) or Edge Functions (supabase.functions.invoke(...)). Don't write those tables directly: drive_signoffs, family_links, family_invites, invoices status, qbo_*.
- Every list is paginated. Use the keyset RPCs (list_drives, school_students_progress) or .range() with a page size of 50 or less. Never fetch a whole table.
- Hours are stored as integer minutes. Show hours as minutes/60 with 1 decimal. Money is numeric with 2 decimals; never use floats for money math.
- No Realtime subscriptions and no "online" or presence pings. Refresh on screen focus or pull-to-refresh.
- Keep existing behaviour working. The live tables (schools, school_members, students, lots, cars, packages, invites) and RPCs (create_school, add_student, invite_to_school, accept_school_invite, accept_my_invites, add_lot, add_car, update_school, revoke_invite) are unchanged.
- School roles are owner / admin / front_desk / instructor. "Staff" in the product = front_desk.
- Students may have NO school: students.school_id (and school_id on drives, supervisors, family links, exports) can be null, meaning an independent student practising with family. Never assume a school exists; show "Independent" or "Practicing with family". Lessons, instructor sign-off and billing/QuickBooks exist only for school students.
- State rules (hours, caps, stages, supervisor age, forms) live in the database for all 50 states + DC. Never hard-code a state's numbers in the app; read them from rpc('student_rule_progress') / rpc('state_resources'). The shapes are in docs/STATE_RULES_SCHEMA.md. null means "no such rule / not known", never 0.
- Show friendly messages for errors and never show raw SQL.
```

---

## A. School dashboard (React 19 + Vite 6 PWA)

### A1. Supabase client and session

```
Set up a single Supabase client in src/lib/supabase.ts using @supabase/supabase-js v2 with VITE_SUPABASE_URL and VITE_SUPABASE_ANON_KEY. Add an AuthProvider (React context) that exposes session, user, loading, signIn(email,password), signUp, signOut, resetPassword. After sign-in, call supabase.rpc('accept_my_invites') once (it attaches pending staff invites to this email) and supabase.rpc('set_account_type', { p_type: 'staff' }) if profiles.account_type is 'unset'. Load the user's schools from school_members joined to schools (select id, role, access, schools(id,name,city,timezone)) and keep the "current school" in context and localStorage. Add .env.example with the two VITE_ vars. Don't commit .env.
```

### A2. Students roster with progress (paged)

```
Build the Students page using supabase.rpc('school_students_progress', { p_school_id, p_after_last, p_after_first, p_after_id, p_limit: 100 }). It returns rows sorted by last_name, first_name, id with practice_hours, night_hours, school_hours, hour_goal, night_goal, pending_drives, last_drive_at. Implement "Load more" keyset paging by passing the last row's last_name/first_name/student_id as the p_after_* args. Show a progress bar per student (practice_hours / hour_goal), a night badge, and a "pending sign-off" count chip. Keep the existing Add student flow (rpc add_student). Show each student's join_code (from students) with a "copy" button and a short "Give this code to the student to claim their profile in the app" hint.
```

### A2b. Link an existing LicenseLogger student, and release or former students

```
On the Students page add "Link existing LicenseLogger student": the student reads their LicenseLogger code from the app (6 characters) and front desk types it. Call supabase.rpc('request_student_link', { p_school_id, p_student_code }). The result status is requested / invalid / already_linked / rate_limited. Show "Request sent. The student or a parent must accept in the app". Never expect or show student details before they accept. List pending requests from school_link_requests (id, status, created_at, expires_at; there's no student name until accepted) with Cancel → rpc('cancel_student_link_request', { p_request_id }). Once accepted, the student just appears in school_students_progress.
Explain to staff in a help tooltip: if you already added the student with "Add student", give them that roster code instead. The app merges it into their existing profile and keeps their history.
On Student detail add "Release student" (owner/admin/front desk) → rpc('release_student', { p_student_id }) with a confirm dialog: "They keep their profile and history in the app. You keep your lessons, invoices and the drives signed while they were enrolled." Error 22023 means the student has no app account; offer "Mark inactive" (seat = 'inactive') instead.
Add a "Former students" tab from school_enrollments (where school_id = current and left_at is not null; columns first_name, last_name, joined_at, left_at, left_reason), paged with .range(). Anywhere you embed students(first_name, last_name) in lessons, invoices, payments, packages or drives, the join can now return null for a former student: fall back to the name from school_enrollments, or show "Former student". Make sure no page crashes on a null student.
```

### A3. Student detail: hours, drives, sign-off queue

```
Build the Student detail page:
1) Requirements card from supabase.rpc('student_rule_progress', { p_student_id }) (shape: docs/STATE_RULES_SCHEMA.md section 6). Show one bar per item in requirements[] (total, night, weather or challenging), each with credited_minutes / required_minutes and pending_minutes as "waiting for signature". Show stages[] as steps (with "estimated date" when milestone_assumed is true), caps (capped_days / capped_weeks), the instructor block when instructor.counts, and still_needed[] as plain sentences. Badge rule.status: verified, "partly verified" or "unconfirmed". If rule is null, show still_needed[0]. Add two small actions: "Record stage date" → rpc('set_rule_milestone', { p_student_id, p_key: stage.milestone, p_reached_on }) and "Driver-ed / other path" → rpc('set_rule_alternative', { p_student_id, p_key }) with options from my_rule_resources().requirements.alternatives (null clears it). The older flat rpc('student_hours_summary') still works if you need one row for a list.
2) A by-day chart from rpc('student_hours_by_day', { p_student_id, p_from, p_to }). Mark days where capped = true ("only the daily maximum counted"). Group by week_start when the rule has a weekly cap, and show weather_credited_minutes when the state counts bad weather.
3) A drives table from rpc('list_drives', { p_student_id, p_before_started_at, p_before_id, p_limit: 50 }), with "Load more" keyset paging using the last row's started_at and id. Columns: date (local_date), time, minutes, night minutes, weather minutes (only if the state counts weather), miles, supervisor_name, status chip (in_progress/pending/signed/rejected/voided), lock icon if locked_at.
4) Front desk / owner / admin get a "Void drive" action → rpc('void_drive', { p_drive_id, p_reason }) with a required reason, and a "Reject" action → rpc('reject_drive', { p_drive_id, p_reason }). Never offer edit on a signed drive.
5) Instructors sign lessons with rpc('sign_drive', { p_drive_id, p_method: 'instructor' }).
Add a "Pending sign-offs" widget on the home page from rpc('pending_signoffs', { p_limit: 50 }).
```

### A4. Family invites from the dashboard

```
On Student detail add "Invite family". Call supabase.functions.invoke('family-invite', { body: { action: 'create', student_id, relationship: 'parent', email (optional), max_uses: 2 } }). The response includes the code (shown ONCE, e.g. LL-7Q4K-M2) plus expires_at. Show it big with copy and share buttons and a warning that it can't be shown again. If an email was given, the function also emails it. List current links from family_links (select id, relationship, can_sign, status, user_id, created_at where student_id = ...) and invites from family_invites (code_hint, uses, max_uses, expires_at, revoked_at). Revoke them with invoke('family-invite', { body: { action: 'revoke_link', link_id } }) and { action: 'revoke_invite', invite_id }.
```

### A5. Exports (PDF/CSV)

```
Add "Download hours report (PDF)", "Download CSV" and, per drive row, "Drive PDF". Call supabase.functions.invoke('export-report', { body: { student_id, format: 'pdf' | 'csv', drive_id? } }). The response is { url, expires_in, export_id }. Open url in a new tab right away; it's a 10-minute signed link to a private bucket. Don't store or share the url. Handle a 429 ("too many exports, try again later"). The PDF already follows the student's state (form name/number, units, caps, weather, stages, and a notary block where the state needs one). Next to the button, show the form name and "how to use this log" from rpc('my_rule_resources', { p_student_id }).form and .how_to_use_licenselogger_log.
```

### A6. Schedule (lessons)

```
Build a week calendar using supabase.rpc('school_schedule', { p_school_id, p_from, p_to }) (max 1000 rows; request one week at a time). Create, edit and cancel lessons by inserting or updating public.lessons (school_id, student_id, instructor_id, car_id, lot_id, starts_at, ends_at, topic, pickup, status, notes). The database blocks double-booking an instructor or car. Catch Postgres error 23P01 and show "That instructor or car is already booked at that time". Times are timestamptz; show them in the school's timezone (schools.timezone).
```

### A7. Billing and QuickBooks (Pay page)

```
Build the Pay page for users with pay access (owner/admin, or access.pay = true).
- Customers: billing_customers (paged with .range()). Invoices: invoices with invoice_lines. Payments: payments. Money fields are numeric strings; format with Intl.NumberFormat and never parse to float for sums (use the DB's totals).
- Create or edit invoices and payments by inserting into these tables (RLS allows pay users). Each row has sync_status (pending/synced/error/conflict) and sync_error; show a small status dot and the error on hover.
- QuickBooks card: rpc('qbo_sync_status', { p_school_id }) returns status, company_name, last_sync_at, last_error, queued, failed, dead, refresh_expires_at.
  - "Connect QuickBooks" (owner/admin only): supabase.functions.invoke('qbo-connect', { body: { school_id, action: 'connect' } }) returns { url }. Do window.location.assign(url). Intuit sends the user back to {LL_DASHBOARD_URL}/settings?qbo=connected | error | cancelled | expired; show a toast for each (put the QuickBooks card on /settings, or add a redirect).
  - "Disconnect": invoke('qbo-connect', { body: { school_id, action: 'disconnect' } }) with a confirm dialog.
  - If dead > 0, show "Some items couldn't sync"; if refresh_expires_at is within 30 days, show "Reconnect QuickBooks soon".
```

### A8. Hardening pass

```
Audit the dashboard: (1) grep for service_role or any secret and remove it; (2) every list query has pagination; (3) no supabase.channel()/realtime; (4) the error boundary maps 42501 → "You don't have access", 23505 → "Already exists", 23P01 → "Time conflict"; (5) PWA caching never caches /functions/v1/export-report responses or signed URLs; (6) sign-out clears cached school data.
```

---

## B. Flutter app (Student + Family)

### B1. Setup, auth and account type

```
Add supabase_flutter. Initialize it in main() with const String.fromEnvironment('SUPABASE_URL') / ('SUPABASE_ANON_KEY'); never hardcode keys. Build sign-up/sign-in/reset screens (email + password, min 10 chars with letters and digits). After the first sign-in, if profiles.account_type is 'unset', ask "I'm a student" / "I'm a parent or guardian" and call supabase.rpc('set_account_type', params: {'p_type': 'student' | 'family'}). Configure the auth deep link (e.g. licenselogger://login-callback) for email confirmation and password reset.
```

### B2. Onboarding and linking to students

```
After set_account_type, students get one question: "Do you take lessons with a driving school?"
  • "Yes — enter school code": the code the school gave them (6 characters). Call rpc('claim_student_profile', params: {'p_join_code': code}). It returns {status, student_id, school_id, school_name?}.
      - ok → done.
      - has_independent_profile → the student already practises on their own. Show "Bring your drive history to {school_name}? Your school will see your drives and hours while you're enrolled." On Yes, call rpc('join_school_with_code', params: {'p_student_id': status.student_id, 'p_join_code': code}). Results: ok / already_linked / invalid / rate_limited / needs_school_link (the school already logged drives for you: show your LicenseLogger code, from students.join_code, and ask the school to "Link existing student").
      - invalid / rate_limited / needs_account → friendly text.
  • "No, I'm practicing with family": ask first name, last name, birthday (optional) and state (a US state picker, default TX). Call rpc('create_independent_student', params: {'p_first_name', 'p_last_name', 'p_birthday', 'p_state_code', 'p_for': 'self'}). It returns {status: ok|exists, student_id, join_code}. Then go straight to the home screen and offer "Invite a parent" (B2-family below).
Parents can set up first: in the family app, "Add a student who isn't with a school" → create_independent_student(..., p_for: 'family'). Show the returned join_code: "Give this to your teen; they enter it in their app to take over the profile."
Settings for independent students: edit name, birthday, permit date and state via rpc('update_my_student', params: {'p_student_id', 'p_first_name', 'p_last_name', 'p_birthday', 'p_state_code', 'p_permit_on'}). If the student is at a school this raises "Your school manages this profile": hide the form and show the school's name instead. Show "Your LicenseLogger code: {join_code}" (from students) with copy and share, for joining a school later.
School requests: on app start and on pull-to-refresh, call rpc('my_school_requests'). For each request show a card: "{school_name} ({school_city}) wants to add {student_first_name}. They will see the full drive history and hours while enrolled." If currently_at_school is not null, add "This moves you from {currently_at_school}." Accept / Decline → rpc('respond_school_request', params: {'p_request_id', 'p_accept': true|false}). Students and family members can both answer.
Leaving: in Settings for school students, "Leave {school_name}" → confirm ("You keep your profile and all drives. The school keeps lessons, invoices and drives signed while you were enrolled. Future lessons are cancelled.") → rpc('leave_school', params: {'p_student_id'}).
Family accounts: an "Enter invite code" screen (format LL-XXXX-XX; accept lowercase, spaces or missing dashes) calls supabase.functions.invoke('family-invite', body: {'action': 'redeem', 'code': code}). The result status is ok / invalid / expired / rate_limited / own_code / needs_account. For rate_limited show "Too many tries, wait an hour".
Both: a student switcher fed by rpc('my_students') → student_id, first_name, last_name, school_id, school_name, state_code, relation ('self' or the family relationship), can_sign. Family members can have several students. school_id and school_name are null for independent students: show "Practicing with family", and hide school-only features (lessons, school messages, invoices).
Family invites work the same for every student: supabase.functions.invoke('family-invite', body: {'action': 'create', 'student_id': id, 'relationship': 'parent', 'email': optional}). The response includes the code, shown once.
```

### B3. Recording a drive (offline-safe, batched GPS)

```
Implement drive recording:
- When the drive starts, generate a UUID v4 on the device. Insert into public.drives { id, student_id, kind: 'practice', source: 'gps', status: 'in_progress', started_at (UTC ISO), tz (device IANA zone, e.g. America/Chicago), app_version }. Don't send school_id; the server fills it in (null for independent students). Use upsert on id so retries are safe.
- Collect GPS points locally (sqlite/drift), about 1 point every 5 s, dropping points under 5 m apart. Do NOT write points one by one. Every 5 minutes, and at the end, encode the new points as a Google encoded polyline (precision 5) and insert into public.drive_route_chunks { drive_id, chunk_no (0,1,2...), polyline, point_count (<=2000), first_at, last_at }. A duplicate chunk_no means it was already uploaded; treat that as success.
- When the drive ends, update the drive: ended_at, duration_minutes, night_minutes (computed with the state's night_rule from my_rule_resources().requirements.night_rule: sunset_sunrise, half_hour_after_sunset, after_sunset, darkness (use civil dusk to dawn), clock_window, or unspecified (use sunset to sunrise); night_minutes <= duration_minutes), weather_minutes (0..duration; ask "Any rain, snow, ice or fog? About how many minutes?" on the end-of-drive screen when the rule has weather_minutes, and also tag conditions[] e.g. {'Rain'}; it locks at sign-off), distance_miles (2 decimals), start_label, end_label, conditions[], skills[], notes, route_polyline (simplified whole route, <= 2000 points), route_point_count, status: 'pending'.
- Everything goes through a persistent outbox that retries with backoff when offline. Never block the UI on the network.
- No background "presence"/heartbeat writes. Location is only collected during an active drive. Show the OS permission rationale.
```

### B4. Supervisor sign-off on the student's phone

```
After a drive is 'pending', show the "Supervisor sign-off" screen: pick a supervisor (from public.supervisors where student_id = current and can_sign = true, active = true; allow "Add supervisor" → insert {student_id, name, relationship, can_sign: true}). The supervisor types their initials (2–4 letters) and ticks "I supervised this drive". Call rpc('sign_drive', params: {'p_drive_id': id, 'p_method': 'on_device', 'p_supervisor_id': supId, 'p_initials': initials, 'p_device': {'platform': ..., 'model': ..., 'app_version': ..., 'signed_at_local': ...}}). The result is {status:'signed', signoff_id, snapshot_sha256}; show a lock badge. After signing, the drive can't be edited or deleted. On "Add supervisor" also ask for birth_date and licensed_since (optional; explain "Your state requires supervisors to be {supervisor.min_age}+ / licensed {min_years_licensed} years" using my_rule_resources().supervisor). If sign_drive fails with 22023 and a message starting "In XX the supervisor must", show that message and let them pick another supervisor. Hide edit buttons when locked_at is set, and if the server rejects an edit, show "This drive is signed and locked".
```

### B5. Family app: approve drives and see progress

```
For family accounts: a "Needs your sign-off" list from rpc('pending_signoffs', params: {'p_limit': 50}). Tapping one shows the drive (map from route_polyline, minutes, night, miles) with "Approve" → rpc('sign_drive', params: {'p_drive_id': id, 'p_method': 'family_account'}) and "Reject" → rpc('reject_drive', params: {'p_drive_id': id, 'p_reason': reason}). Only show the buttons where my_students().can_sign is true. Family members also see each linked student's progress (B6) and drive history (B7).
```

### B6. Progress screen

```
Use rpc('student_rule_progress', params: {'p_student_id': id}) (shape: docs/STATE_RULES_SCHEMA.md section 6; mirror it as Dart classes with json_serializable). It works the same with or without a school. Show one ring per item in requirements[] (total, night, and weather or "challenging" when present). Show pending_minutes separately as "waiting for signature". Show the still_needed[] sentences, a stages[] stepper (IA, MI) with an "estimated" chip when milestone_assumed is true, and the caps line ("max 2 h a day" / "max 10 h a week"). When rule.log_unit is 'minutes' (MN, NV), show minutes, not hours. Badge rule.status (partly verified / unconfirmed); when rule is null or requirements is empty, show still_needed[0]. Under the rings, show the school goal only if rpc('student_hours_summary').school_goal_minutes is not null. Add a calendar strip from rpc('student_hours_by_day', ...) that marks capped days.
For stages: a "I got my intermediate license / reached Segment 2" button → rpc('set_rule_milestone', params: {'p_student_id': id, 'p_key': stage.milestone ?? stage.key, 'p_reached_on': date}). For alternatives (OR driver ed, MD 25+, MN parent class, ...): a "Does one of these apply?" picker from my_rule_resources().requirements.alternatives → rpc('set_rule_alternative', params: {'p_student_id': id, 'p_key': key or null}). Changing the state or permit date in profile (update_my_student) changes the rule, so refresh afterwards.
```

### B6b. "My state" resources screen

```
Add a "Requirements & forms" screen. For the signed-in student, use rpc('my_rule_resources', params: {'p_student_id': id}). Before a profile exists (state picker in onboarding), use rpc('state_resources', params: {'p_state_code': 'TX', 'p_permit_on': date or null}). Shape: docs/STATE_RULES_SCHEMA.md section 7. Show:
- summary at the top
- checklist[] as numbered steps, with a checkbox stored locally only
- form (name, number, a "Get the official PDF" button opening pdf_url, notarization and digital_log notes)
- links[] as tappable rows (label, url), opened with url_launcher in the external browser
- a "How to use your LicenseLogger log" card from how_to_use_licenselogger_log: submit_printout, official_form_only, copy_to_official_form, records_only, none, unconfirmed (write friendly text for each)
- other_rules in an expandable section
- "Last checked {last_checked}"
- a warning when status is not 'verified' or field_status is not empty
- a heads-up banner when pending_change is set
Cache the response for 7 days and refresh on pull-to-refresh. Never hard-code any state's text.
```

### B7. Drive history and exports

```
Drive history uses rpc('list_drives', params: {'p_student_id': id, 'p_before_started_at': lastStartedAt, 'p_before_id': lastId, 'p_limit': 30}) with infinite scroll (keyset, not offset). Each row shows status and a lock icon. "Export log" → supabase.functions.invoke('export-report', body: {'student_id': id, 'format': 'pdf'}). Open the returned url (valid 10 minutes) with url_launcher or share the downloaded file. Never store the url.
```

### B8. Hardening pass

```
Audit the Flutter app: no screen assumes a school (independent students have none); no secrets in code or assets; keys come only via --dart-define; all lists paginated; no realtime/presence; GPS only while recording; the offline outbox survives an app restart; signed drives are read-only in the UI; errors 42501/23505 map to friendly text; sign-out clears the local cache (except unsent drives, which stay queued for that user only).
```
