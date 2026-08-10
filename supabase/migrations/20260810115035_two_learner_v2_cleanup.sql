-- Apply only after the v2 collection snapshot/backfill counts have been
-- verified. Hosted WordNet tables are empty and no longer serve the product.
drop table if exists private.wordnet_curation_categories cascade;
drop table if exists private.wordnet_curation_records cascade;
drop table if exists private.wordnet_curation_batches cascade;
drop table if exists private.wordnet_sense_relations cascade;
drop table if exists private.wordnet_synset_relations cascade;
drop table if exists private.wordnet_frames cascade;
drop table if exists private.wordnet_examples cascade;
drop table if exists private.wordnet_pronunciations cascade;
drop table if exists private.wordnet_senses cascade;
drop table if exists private.wordnet_entries cascade;
drop table if exists private.wordnet_synsets cascade;
drop table if exists private.wordnet_releases cascade;

drop type if exists private.wordnet_batch_status;
drop type if exists private.wordnet_curation_status;
drop type if exists private.wordnet_import_status;
