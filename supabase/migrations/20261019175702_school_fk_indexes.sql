create index if not exists schools_created_by_idx on public.schools (created_by);
create index if not exists school_invites_invited_by_idx on public.school_invites (invited_by);

drop policy if exists profiles_select_own on public.profiles;
drop policy if exists profiles_select_schoolmates on public.profiles;

create policy profiles_select_visible
  on public.profiles for select
  to authenticated
  using (
    id = (select auth.uid())
    or exists (
      select 1
      from public.school_members mine
      join public.school_members theirs
        on theirs.school_id = mine.school_id
      where mine.user_id = (select auth.uid())
        and theirs.user_id = profiles.id
    )
  );