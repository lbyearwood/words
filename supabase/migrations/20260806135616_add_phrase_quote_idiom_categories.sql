alter table public.categories
  drop constraint categories_sort_order_check;

alter table public.categories
  add constraint categories_sort_order_check
  check (sort_order between 1 and 28);

-- Keep the catch-all category last while introducing the three requested
-- learner-facing expression categories immediately before it.
update public.categories
set sort_order = 28
where id = 'miscellaneous';

insert into public.categories (id, name, description, sort_order)
values
  (
    'phrases',
    'Phrases',
    'Multi-word expressions whose wording, meaning and use are learned as a unit.',
    25
  ),
  (
    'quotes',
    'Quotes',
    'Memorable attributed statements preserved for their wording, meaning or cultural value.',
    26
  ),
  (
    'idioms',
    'Idioms',
    'Established expressions whose meaning is not fully predictable from their individual words.',
    27
  );
