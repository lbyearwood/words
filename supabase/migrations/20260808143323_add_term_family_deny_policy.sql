create policy "term_families_no_direct_access"
on public.term_families
as restrictive
for all
to public
using (false)
with check (false);

comment on policy "term_families_no_direct_access" on public.term_families is
  'Term families are internal grouping metadata. Learners receive the family id only through visible Knowledge Items.';
