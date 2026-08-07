alter type public.collection_state
  add value if not exists 'preference';

comment on type public.collection_state is
  'Tracks whether a Knowledge Item is saved or only has a user preference attached. The legacy hidden value is retained for migration compatibility but is no longer written by the app.';
