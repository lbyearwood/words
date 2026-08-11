-- Curate Max's requested sophisticated workplace vocabulary as audited batch 19.
-- Every term receives a separate learner-owned item, including Infer, whose
-- existing Tia version must remain unchanged.
do $$
declare
  max_user constant uuid := '8b57ddf0-1152-4b2a-85cd-ead229c3f075';
  v_batch_number constant integer := 19;
  v_manifest_id constant text := 'max-v2-curated-additions-019';
  requested jsonb := $terms$
  [
    {
      "term":"Precarious","normalized_term":"precarious","definition":"Not securely established or safe, and therefore at risk of worsening or failing.",
      "example_sentence":"The programme remains in a precarious position because two key suppliers have not confirmed their delivery dates.",
      "part_of_speech":"adjective","pronunciation":"pri-CARE-ee-us","sense_label":"uncertain or unstable","difficulty":"advanced","importance":0.800,
      "categories":[{"slug":"sophisticated_speaker","is_primary":true,"importance":0.880},{"slug":"professional_communication","is_primary":false,"importance":0.740},{"slug":"general_vocabulary","is_primary":false,"importance":0.700},{"slug":"critical_thinking_logic","is_primary":false,"importance":0.680}],
      "evidence":[{"type":"source","url":"https://dictionary.cambridge.org/dictionary/english/precarious","note":"Spelling and current sense verified."},{"type":"learner_fit","note":"Useful for precise assessment of unstable projects, plans and positions."}]
    },
    {
      "term":"Nuanced","normalized_term":"nuanced","definition":"Showing or taking account of subtle but important differences, rather than treating something as simple or absolute.",
      "example_sentence":"Her nuanced assessment acknowledged the team's strong results while identifying where the new process was increasing pressure.",
      "part_of_speech":"adjective","pronunciation":"NYOO-ahnst","sense_label":"attentive to subtle differences","difficulty":"advanced","importance":0.920,
      "categories":[{"slug":"sophisticated_speaker","is_primary":true,"importance":0.980},{"slug":"critical_thinking_logic","is_primary":false,"importance":0.940},{"slug":"professional_communication","is_primary":false,"importance":0.880},{"slug":"academic_language_writing","is_primary":false,"importance":0.850}],
      "evidence":[{"type":"source","url":"https://dictionary.cambridge.org/dictionary/english/nuanced","note":"Spelling and current sense verified."},{"type":"learner_fit","note":"Central to balanced workplace judgement and precise communication."}]
    },
    {
      "term":"Cogent","normalized_term":"cogent","definition":"Clear, logical and convincing.",
      "example_sentence":"He presented a cogent case for delaying the launch until the security risks had been addressed.",
      "part_of_speech":"adjective","pronunciation":"KOH-junt","sense_label":"convincing and well reasoned","difficulty":"advanced","importance":0.880,
      "categories":[{"slug":"sophisticated_speaker","is_primary":true,"importance":0.960},{"slug":"critical_thinking_logic","is_primary":false,"importance":0.950},{"slug":"professional_communication","is_primary":false,"importance":0.900},{"slug":"academic_language_writing","is_primary":false,"importance":0.840}],
      "evidence":[{"type":"source","url":"https://dictionary.cambridge.org/dictionary/english/cogent","note":"Spelling and current sense verified."},{"type":"learner_fit","note":"Useful for evaluating arguments and presenting recommendations."}]
    },
    {
      "term":"Judicious","normalized_term":"judicious","definition":"Showing careful thought and sound judgement, especially when making a decision.",
      "example_sentence":"A judicious reallocation of staff protected the deadline without exhausting the team.",
      "part_of_speech":"adjective","pronunciation":"joo-DISH-us","sense_label":"showing sound judgement","difficulty":"advanced","importance":0.850,
      "categories":[{"slug":"leadership_management","is_primary":true,"importance":0.950},{"slug":"sophisticated_speaker","is_primary":false,"importance":0.900},{"slug":"critical_thinking_logic","is_primary":false,"importance":0.880},{"slug":"professional_communication","is_primary":false,"importance":0.800}],
      "evidence":[{"type":"source","url":"https://dictionary.cambridge.org/dictionary/english/judicious","note":"Spelling and current sense verified."},{"type":"learner_fit","note":"Directly relevant to measured leadership decisions."}]
    },
    {
      "term":"Salient","normalized_term":"salient","definition":"Most important or relevant to the matter being considered.",
      "example_sentence":"The salient point for the board is that demand is rising faster than our capacity.",
      "part_of_speech":"adjective","pronunciation":"SAY-lee-unt","sense_label":"most relevant or important","difficulty":"advanced","importance":0.870,
      "categories":[{"slug":"sophisticated_speaker","is_primary":true,"importance":0.940},{"slug":"professional_communication","is_primary":false,"importance":0.920},{"slug":"academic_language_writing","is_primary":false,"importance":0.860},{"slug":"critical_thinking_logic","is_primary":false,"importance":0.820}],
      "evidence":[{"type":"source","url":"https://dictionary.cambridge.org/dictionary/english/salient","note":"Spelling and current sense verified."},{"type":"learner_fit","note":"Supports concise emphasis in briefings and analysis."}]
    },
    {
      "term":"Prudent","normalized_term":"prudent","definition":"Careful and sensible in order to avoid unnecessary risk.",
      "example_sentence":"It would be prudent to test the revised process with one team before extending it across the organisation.",
      "part_of_speech":"adjective","pronunciation":"PROO-dunt","sense_label":"careful about risk","difficulty":"advanced","importance":0.830,
      "categories":[{"slug":"leadership_management","is_primary":true,"importance":0.920},{"slug":"business_economics","is_primary":false,"importance":0.860},{"slug":"sophisticated_speaker","is_primary":false,"importance":0.820},{"slug":"critical_thinking_logic","is_primary":false,"importance":0.780}],
      "evidence":[{"type":"source","url":"https://dictionary.cambridge.org/dictionary/english/prudent","note":"Spelling and current sense verified."},{"type":"learner_fit","note":"Useful for responsible decisions about risk and resources."}]
    },
    {
      "term":"Astute","normalized_term":"astute","definition":"Quick to understand a situation and recognise how best to respond.",
      "example_sentence":"Her astute reading of the stakeholders' concerns helped the team secure support for the proposal.",
      "part_of_speech":"adjective","pronunciation":"uh-STYOOT","sense_label":"perceptive and strategically aware","difficulty":"advanced","importance":0.840,
      "categories":[{"slug":"sophisticated_speaker","is_primary":true,"importance":0.910},{"slug":"leadership_management","is_primary":false,"importance":0.900},{"slug":"business_economics","is_primary":false,"importance":0.800},{"slug":"critical_thinking_logic","is_primary":false,"importance":0.760}],
      "evidence":[{"type":"source","url":"https://dictionary.cambridge.org/dictionary/english/astute","note":"Spelling and current sense verified."},{"type":"learner_fit","note":"Relevant to strategic awareness and stakeholder judgement."}]
    },
    {
      "term":"Reconcile","normalized_term":"reconcile","definition":"To find a way for conflicting ideas, demands or facts to be compatible.",
      "example_sentence":"We need to reconcile the demand for faster delivery with our commitment to quality.",
      "part_of_speech":"verb","pronunciation":"REK-un-syle","sense_label":"make competing demands compatible","difficulty":"advanced","importance":0.890,
      "categories":[{"slug":"leadership_management","is_primary":true,"importance":0.950},{"slug":"critical_thinking_logic","is_primary":false,"importance":0.920},{"slug":"professional_communication","is_primary":false,"importance":0.880},{"slug":"sophisticated_speaker","is_primary":false,"importance":0.820},{"slug":"social_communication","is_primary":false,"importance":0.800}],
      "evidence":[{"type":"source","url":"https://dictionary.cambridge.org/dictionary/english/reconcile","note":"Spelling and current sense verified."},{"type":"learner_fit","note":"Useful for resolving competing organisational demands."}]
    },
    {
      "term":"Extrapolate","normalized_term":"extrapolate","definition":"To use known information or an observed pattern to estimate what is likely beyond the available data.",
      "example_sentence":"We should not extrapolate company-wide savings from a four-week pilot involving one team.",
      "part_of_speech":"verb","pronunciation":"ik-STRAP-uh-layt","sense_label":"project beyond known data","difficulty":"advanced","importance":0.840,
      "categories":[{"slug":"research_methods_evidence","is_primary":true,"importance":0.960},{"slug":"mathematics_statistics","is_primary":false,"importance":0.930},{"slug":"critical_thinking_logic","is_primary":false,"importance":0.900},{"slug":"academic_language_writing","is_primary":false,"importance":0.820},{"slug":"sophisticated_speaker","is_primary":false,"importance":0.700}],
      "evidence":[{"type":"source","url":"https://dictionary.cambridge.org/dictionary/english/extrapolate","note":"Spelling and current sense verified."},{"type":"learner_fit","note":"Supports careful interpretation of pilots, trends and evidence."}]
    },
    {
      "term":"Infer","normalized_term":"infer","definition":"To reach a conclusion from available evidence or clues rather than from a direct statement.",
      "example_sentence":"From the repeated delays, we can infer that the approval process, not the team's effort, is the main constraint.",
      "part_of_speech":"verb","pronunciation":"in-FUR","sense_label":"reach an evidence-based conclusion","difficulty":"intermediate","importance":0.850,
      "categories":[{"slug":"critical_thinking_logic","is_primary":true,"importance":0.950},{"slug":"research_methods_evidence","is_primary":false,"importance":0.900},{"slug":"academic_language_writing","is_primary":false,"importance":0.850},{"slug":"sophisticated_speaker","is_primary":false,"importance":0.800}],
      "evidence":[{"type":"source","url":"https://dictionary.cambridge.org/dictionary/english/infer","note":"Spelling and current sense verified."},{"type":"learner_fit","note":"Max receives a workplace-specific item isolated from Tia's school-context version."}]
    },
    {
      "term":"Ascertain","normalized_term":"ascertain","definition":"To find out or establish a fact with confidence by checking or investigating.",
      "example_sentence":"Before committing the budget, I asked the team to ascertain whether the supplier could meet the revised deadline.",
      "part_of_speech":"verb","pronunciation":"ass-uh-TAYN","sense_label":"establish a fact","difficulty":"advanced","importance":0.740,
      "categories":[{"slug":"research_methods_evidence","is_primary":true,"importance":0.900},{"slug":"critical_thinking_logic","is_primary":false,"importance":0.850},{"slug":"professional_communication","is_primary":false,"importance":0.760},{"slug":"sophisticated_speaker","is_primary":false,"importance":0.720}],
      "evidence":[{"type":"source","url":"https://dictionary.cambridge.org/dictionary/english/ascertain","note":"Spelling and current sense verified."},{"type":"learner_fit","note":"Useful for evidence-based decisions and due diligence."}]
    },
    {
      "term":"Precedent","normalized_term":"precedent","definition":"An earlier action or decision that becomes an example for handling a similar situation later.",
      "example_sentence":"Approving this exception without clear criteria could set a precedent for future funding requests.",
      "part_of_speech":"noun","pronunciation":"PRESS-i-dunt","sense_label":"earlier guiding example","difficulty":"advanced","importance":0.800,
      "categories":[{"slug":"leadership_management","is_primary":true,"importance":0.900},{"slug":"critical_thinking_logic","is_primary":false,"importance":0.820},{"slug":"business_economics","is_primary":false,"importance":0.780},{"slug":"professional_communication","is_primary":false,"importance":0.760},{"slug":"sophisticated_speaker","is_primary":false,"importance":0.740}],
      "evidence":[{"type":"source","url":"https://dictionary.cambridge.org/dictionary/english/precedent","note":"Spelling and current sense verified."},{"type":"learner_fit","note":"Relevant to consistent organisational decisions and policy exceptions."}]
    },
    {
      "term":"Ostensible","normalized_term":"ostensible","definition":"Presented as the apparent reason or purpose, although the real one may be different.",
      "example_sentence":"The ostensible reason for the restructure was efficiency, although the timing suggested a broader strategic shift.",
      "part_of_speech":"adjective","pronunciation":"oss-TEN-suh-bul","sense_label":"apparently but perhaps not actually","difficulty":"advanced","importance":0.650,
      "categories":[{"slug":"sophisticated_speaker","is_primary":true,"importance":0.880},{"slug":"critical_thinking_logic","is_primary":false,"importance":0.820},{"slug":"academic_language_writing","is_primary":false,"importance":0.700},{"slug":"professional_communication","is_primary":false,"importance":0.600}],
      "evidence":[{"type":"source","url":"https://dictionary.cambridge.org/dictionary/english/ostensible","note":"Spelling and current sense verified."},{"type":"learner_fit","note":"Supports careful distinction between stated and underlying reasons."}]
    },
    {
      "term":"Unequivocal","normalized_term":"unequivocal","definition":"Expressed so clearly and firmly that it leaves no room for doubt or competing interpretations.",
      "example_sentence":"The board gave unequivocal support to the revised safeguarding policy.",
      "part_of_speech":"adjective","pronunciation":"un-i-KWIV-uh-kul","sense_label":"clear and unambiguous","difficulty":"advanced","importance":0.830,
      "categories":[{"slug":"professional_communication","is_primary":true,"importance":0.930},{"slug":"leadership_management","is_primary":false,"importance":0.890},{"slug":"sophisticated_speaker","is_primary":false,"importance":0.860},{"slug":"academic_language_writing","is_primary":false,"importance":0.700}],
      "evidence":[{"type":"source","url":"https://dictionary.cambridge.org/dictionary/english/unequivocal","note":"Spelling and current sense verified."},{"type":"learner_fit","note":"Useful for expressing firm support, expectations and conclusions."}]
    },
    {
      "term":"Conversely","normalized_term":"conversely","definition":"Used to introduce an opposite or reversed relationship to the one just described.",
      "example_sentence":"A concise briefing can sharpen a decision; conversely, excessive detail can obscure the central issue.",
      "part_of_speech":"adverb","pronunciation":"KON-vurs-lee","sense_label":"introduce the opposite relationship","difficulty":"advanced","importance":0.760,
      "categories":[{"slug":"academic_language_writing","is_primary":true,"importance":0.940},{"slug":"critical_thinking_logic","is_primary":false,"importance":0.880},{"slug":"sophisticated_speaker","is_primary":false,"importance":0.820},{"slug":"professional_communication","is_primary":false,"importance":0.740}],
      "evidence":[{"type":"source","url":"https://dictionary.cambridge.org/dictionary/english/conversely","note":"Spelling and current sense verified."},{"type":"learner_fit","note":"Supports clear comparison in reports, briefings and recommendations."}]
    },
    {
      "term":"Tactful","normalized_term":"tactful","definition":"Careful and considerate when dealing with a sensitive issue, so as to avoid unnecessary offence.",
      "example_sentence":"Her tactful feedback addressed the missed targets without undermining the manager's confidence.",
      "part_of_speech":"adjective","pronunciation":"TAKT-ful","sense_label":"considerate in sensitive situations","difficulty":"intermediate","importance":0.860,
      "categories":[{"slug":"social_communication","is_primary":true,"importance":0.960},{"slug":"leadership_management","is_primary":false,"importance":0.920},{"slug":"professional_communication","is_primary":false,"importance":0.920},{"slug":"sophisticated_speaker","is_primary":false,"importance":0.760}],
      "evidence":[{"type":"source","url":"https://dictionary.cambridge.org/dictionary/english/tactful","note":"Spelling and current sense verified."},{"type":"learner_fit","note":"Directly relevant to feedback, conflict and performance conversations."}]
    },
    {
      "term":"Systemic","normalized_term":"systemic","definition":"Built into, or affecting, an entire system rather than one isolated part.",
      "example_sentence":"The repeated handover failures point to a systemic process problem, not an isolated mistake.",
      "part_of_speech":"adjective","pronunciation":"sis-TEM-ik","sense_label":"affecting the whole system","difficulty":"advanced","importance":0.850,
      "categories":[{"slug":"critical_thinking_logic","is_primary":true,"importance":0.940},{"slug":"leadership_management","is_primary":false,"importance":0.900},{"slug":"business_economics","is_primary":false,"importance":0.820},{"slug":"research_methods_evidence","is_primary":false,"importance":0.780},{"slug":"sophisticated_speaker","is_primary":false,"importance":0.760}],
      "evidence":[{"type":"source","url":"https://dictionary.cambridge.org/dictionary/english/systemic","note":"Spelling and current sense verified."},{"type":"learner_fit","note":"Useful for distinguishing organisational causes from isolated incidents."}]
    },
    {
      "term":"Notwithstanding","normalized_term":"notwithstanding","definition":"Despite the fact, condition or objection mentioned.",
      "example_sentence":"Notwithstanding the budget constraints, the programme delivered its most important outcomes.",
      "part_of_speech":"preposition","pronunciation":"not-with-STAN-ding","sense_label":"despite what was mentioned","difficulty":"advanced","importance":0.620,
      "categories":[{"slug":"academic_language_writing","is_primary":true,"importance":0.860},{"slug":"sophisticated_speaker","is_primary":false,"importance":0.820},{"slug":"professional_communication","is_primary":false,"importance":0.700},{"slug":"critical_thinking_logic","is_primary":false,"importance":0.620}],
      "evidence":[{"type":"source","url":"https://dictionary.cambridge.org/dictionary/english/notwithstanding","note":"Spelling and current sense verified."},{"type":"learner_fit","note":"Useful formal connector for reports and qualified conclusions."}]
    }
  ]
  $terms$::jsonb;
  entry jsonb;
  categories_json jsonb;
  full_manifest jsonb;
  source_id uuid;
  learner_family_id uuid;
  learning_id uuid;
  category_count integer;
  approved_count integer;
  liked_count integer;
begin
  -- Production contains Max. Schema-only local resets intentionally do not.
  if not exists (
    select 1 from public.profiles profile
    where profile.id = max_user and lower(profile.display_name) = 'max'
  ) then
    raise notice 'Max profile is absent; skipping Max-specific curated content.';
    return;
  end if;

  if not exists (
    select 1 from private.personalised_content_manifests manifest
    where manifest.manifest_id = v_manifest_id
  ) then
    full_manifest := jsonb_build_object(
      'manifest_id', v_manifest_id,
      'user_id', max_user,
      'batch_number', v_batch_number,
      'items', '[]'::jsonb
    );

    for entry in select value from jsonb_array_elements(requested)
    loop
      if exists (
        select 1 from public.learner_term_families family
        where family.user_id = max_user
          and family.normalized_term = entry->>'normalized_term'
      ) then
        raise exception 'Requested term already exists for Max: %', entry->>'term';
      end if;

      select jsonb_agg(
        jsonb_build_object(
          'category_id', category.id,
          'is_primary', (mapping->>'is_primary')::boolean,
          'importance', (mapping->>'importance')::numeric
        )
        order by (mapping->>'is_primary')::boolean desc, category.sort_order
      ), count(*)
      into categories_json, category_count
      from jsonb_array_elements(entry->'categories') mapping
      join public.learner_categories category
        on category.user_id = max_user
       and category.slug = mapping->>'slug';

      if category_count <> jsonb_array_length(entry->'categories') then
        raise exception 'A requested category is not available to Max for %', entry->>'term';
      end if;

      source_id := gen_random_uuid();
      learner_family_id := gen_random_uuid();
      learning_id := gen_random_uuid();

      insert into public.knowledge_items (
        id, term, meaning, example_sentence, difficulty, source, owner_id,
        default_importance, part_of_speech, pronunciation, sense_label
      ) values (
        source_id,
        entry->>'term',
        entry->>'definition',
        entry->>'example_sentence',
        (entry->>'difficulty')::public.knowledge_difficulty,
        'user_added',
        max_user,
        (entry->>'importance')::numeric,
        entry->>'part_of_speech',
        entry->>'pronunciation',
        entry->>'sense_label'
      );

      insert into public.knowledge_item_categories (
        knowledge_item_id, category_id, is_primary, importance
      )
      select
        source_id,
        category.id,
        (mapping->>'is_primary')::boolean,
        (mapping->>'importance')::numeric
      from jsonb_array_elements(entry->'categories') mapping
      join public.categories category on category.id = mapping->>'slug';

      insert into public.learner_term_families (
        id, user_id, normalized_term, display_term
      ) values (
        learner_family_id, max_user, entry->>'normalized_term', entry->>'term'
      );

      insert into public.learning_items (
        id, user_id, item_type, source_knowledge_item_id, difficulty,
        importance, origin, qa_status, practice_enabled
      ) values (
        learning_id,
        max_user,
        'vocabulary',
        source_id,
        (entry->>'difficulty')::public.knowledge_difficulty,
        (entry->>'importance')::numeric,
        'curated',
        'pending',
        false
      );

      insert into public.vocabulary_items (
        learning_item_id, user_id, term_family_id, definition,
        example_sentence, part_of_speech, pronunciation, sense_label,
        sense_order, evidence
      ) values (
        learning_id,
        max_user,
        learner_family_id,
        entry->>'definition',
        entry->>'example_sentence',
        entry->>'part_of_speech',
        entry->>'pronunciation',
        entry->>'sense_label',
        1,
        entry->'evidence'
      );

      insert into private.content_review_records (
        learning_item_id, user_id, batch_number, before_content, drafted_at
      ) values (
        learning_id, max_user, v_batch_number, '{}'::jsonb, now()
      );

      full_manifest := jsonb_set(
        full_manifest,
        '{items}',
        (full_manifest->'items') || jsonb_build_array(jsonb_build_object(
          'learning_item_id', learning_id,
          'decision', 'keep',
          'reason', 'Spelling, meaning, example, metadata and learner fit were reviewed before approval.',
          'term', entry->>'term',
          'definition', entry->>'definition',
          'example_sentence', entry->>'example_sentence',
          'part_of_speech', entry->>'part_of_speech',
          'pronunciation', entry->>'pronunciation',
          'sense_label', entry->>'sense_label',
          'difficulty', entry->>'difficulty',
          'importance', (entry->>'importance')::numeric,
          'categories', categories_json,
          'evidence', entry->'evidence'
        ))
      );
    end loop;

    perform private.apply_personalised_content_manifest(full_manifest);
  end if;

  insert into public.user_collections (
    user_id, knowledge_item_id, learning_item_id, state, is_liked, is_disliked
  )
  select
    max_user,
    learning.source_knowledge_item_id,
    learning.id,
    'saved'::public.collection_state,
    true,
    false
  from public.learner_term_families family
  join public.vocabulary_items vocabulary
    on vocabulary.user_id = max_user
   and vocabulary.term_family_id = family.id
  join public.learning_items learning
    on learning.id = vocabulary.learning_item_id
   and learning.user_id = max_user
  where family.user_id = max_user
    and family.normalized_term = any (array[
      'precarious','nuanced','cogent','judicious','salient','prudent','astute',
      'reconcile','extrapolate','infer','ascertain','precedent','ostensible',
      'unequivocal','conversely','tactful','systemic','notwithstanding'
    ])
  on conflict (user_id, knowledge_item_id) do update
  set learning_item_id = excluded.learning_item_id,
      state = 'saved'::public.collection_state,
      is_liked = true,
      is_disliked = false,
      updated_at = now();

  select count(distinct family.normalized_term)
  into approved_count
  from public.learner_term_families family
  join public.vocabulary_items vocabulary
    on vocabulary.user_id = max_user
   and vocabulary.term_family_id = family.id
  join public.learning_items learning
    on learning.id = vocabulary.learning_item_id
   and learning.user_id = max_user
  where family.user_id = max_user
    and family.normalized_term = any (array[
      'precarious','nuanced','cogent','judicious','salient','prudent','astute',
      'reconcile','extrapolate','infer','ascertain','precedent','ostensible',
      'unequivocal','conversely','tactful','systemic','notwithstanding'
    ])
    and learning.qa_status = 'approved'
    and learning.practice_enabled
    and learning.archived_at is null;

  select count(distinct family.normalized_term)
  into liked_count
  from public.learner_term_families family
  join public.vocabulary_items vocabulary
    on vocabulary.user_id = max_user
   and vocabulary.term_family_id = family.id
  join public.learning_items learning
    on learning.id = vocabulary.learning_item_id
   and learning.user_id = max_user
  join public.user_collections collection
    on collection.user_id = max_user
   and collection.learning_item_id = learning.id
  where family.user_id = max_user
    and family.normalized_term = any (array[
      'precarious','nuanced','cogent','judicious','salient','prudent','astute',
      'reconcile','extrapolate','infer','ascertain','precedent','ostensible',
      'unequivocal','conversely','tactful','systemic','notwithstanding'
    ])
    and collection.state = 'saved'
    and collection.is_liked
    and not collection.is_disliked;

  if approved_count <> 18 then
    raise exception 'Expected 18 approved requested terms, found %', approved_count;
  end if;
  if liked_count <> 18 then
    raise exception 'Expected 18 saved and liked requested terms, found %', liked_count;
  end if;
end;
$$;
