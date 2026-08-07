alter table private.wordnet_entries
  drop constraint wordnet_entries_part_of_speech_check;

alter table private.wordnet_entries
  add constraint wordnet_entries_part_of_speech_check
  check (part_of_speech ~ '^[nvars](-[12])?$');
