create temporary table starter_knowledge_items (
  term text not null,
  meaning text not null,
  example_sentence text not null,
  legacy_category text not null,
  difficulty text not null,
  source text not null
);

insert into starter_knowledge_items
  (term, meaning, example_sentence, legacy_category, difficulty, source)
values
  ('Articulate', 'Able to express ideas clearly and effectively.', 'Mina was articulate when she explained her proposal.', 'everyday_communication', 'beginner', 'seeded'),
  ('Candid', 'Open and honest; not hiding the truth.', 'He gave a candid answer about what went wrong.', 'everyday_communication', 'beginner', 'seeded'),
  ('Concise', 'Using few words while still being clear.', 'Her concise message covered every important point.', 'everyday_communication', 'beginner', 'seeded'),
  ('Empathetic', 'Able to understand and share another person''s feelings.', 'An empathetic reply helped him feel understood.', 'everyday_communication', 'beginner', 'seeded'),
  ('Clarify', 'To make something easier to understand.', 'Could you clarify what you mean by urgent?', 'everyday_communication', 'beginner', 'seeded'),
  ('Assertive', 'Confident and direct without being aggressive.', 'She was assertive when she stated her boundaries.', 'everyday_communication', 'intermediate', 'seeded'),
  ('Attentive', 'Listening or watching with careful interest.', 'The attentive audience noticed every detail.', 'everyday_communication', 'intermediate', 'seeded'),
  ('Considerate', 'Careful not to inconvenience or upset others.', 'It was considerate of Max to call before visiting.', 'everyday_communication', 'intermediate', 'seeded'),
  ('Deliberate', 'Done consciously and with careful thought.', 'His deliberate pause showed that he was choosing his words.', 'everyday_communication', 'intermediate', 'seeded'),
  ('Perceptive', 'Quick to notice and understand subtle things.', 'Tia made a perceptive comment about the mood in the room.', 'everyday_communication', 'intermediate', 'seeded'),
  ('Nuanced', 'Showing subtle differences or shades of meaning.', 'The discussion offered a nuanced view of the problem.', 'everyday_communication', 'advanced', 'seeded'),
  ('Pragmatic', 'Focused on practical results rather than theory.', 'They chose a pragmatic solution that could work today.', 'everyday_communication', 'advanced', 'seeded'),
  ('Resilient', 'Able to recover well after difficulty.', 'The resilient team adapted after the setback.', 'everyday_communication', 'advanced', 'seeded'),
  ('Tactful', 'Careful to avoid embarrassing or upsetting someone.', 'Her tactful response kept the conversation calm.', 'everyday_communication', 'advanced', 'seeded'),
  ('Validate', 'To recognise that a feeling or idea is understandable.', 'You can validate someone''s feelings without agreeing with them.', 'everyday_communication', 'advanced', 'seeded'),

  ('Hypothesis', 'A suggested explanation that can be tested.', 'The class designed an experiment to test the hypothesis.', 'school_subjects', 'beginner', 'seeded'),
  ('Analyse', 'To examine something carefully by looking at its parts.', 'We will analyse the poem one stanza at a time.', 'school_subjects', 'beginner', 'seeded'),
  ('Evidence', 'Information that supports or challenges a claim.', 'The writer used evidence from the text to support her answer.', 'school_subjects', 'beginner', 'seeded'),
  ('Context', 'The circumstances that help explain an event or idea.', 'Historical context made the speech easier to understand.', 'school_subjects', 'beginner', 'seeded'),
  ('Infer', 'To reach a conclusion using evidence and reasoning.', 'From the dark clouds, we can infer that rain is likely.', 'school_subjects', 'beginner', 'seeded'),
  ('Coherent', 'Logical, consistent, and easy to follow.', 'His essay had a coherent argument from start to finish.', 'school_subjects', 'intermediate', 'seeded'),
  ('Contrast', 'To compare things in order to show their differences.', 'The question asks you to contrast the two characters.', 'school_subjects', 'intermediate', 'seeded'),
  ('Evaluate', 'To judge quality or value using evidence.', 'You should evaluate whether the source is reliable.', 'school_subjects', 'intermediate', 'seeded'),
  ('Methodology', 'The organised system of methods used in a study.', 'The report explains its methodology before presenting results.', 'school_subjects', 'intermediate', 'seeded'),
  ('Synthesis', 'The combination of ideas into a new whole.', 'Her conclusion was a synthesis of evidence from three sources.', 'school_subjects', 'intermediate', 'seeded'),
  ('Corroborate', 'To provide additional evidence that confirms something.', 'A second witness helped corroborate the account.', 'school_subjects', 'advanced', 'seeded'),
  ('Empirical', 'Based on observation or experiment rather than theory alone.', 'The claim needs empirical evidence before it can be accepted.', 'school_subjects', 'advanced', 'seeded'),
  ('Extrapolate', 'To estimate an unknown value from known information.', 'Scientists extrapolate future trends from the current data.', 'school_subjects', 'advanced', 'seeded'),
  ('Paradigm', 'A model or pattern that shapes how something is understood.', 'The discovery created a new paradigm for medical research.', 'school_subjects', 'advanced', 'seeded'),
  ('Ubiquitous', 'Present or appearing almost everywhere.', 'Smartphones have become ubiquitous in modern life.', 'school_subjects', 'advanced', 'seeded'),

  ('Agenda', 'A list of topics to discuss or tasks to complete.', 'The first item on the agenda is the project timeline.', 'work', 'beginner', 'seeded'),
  ('Collaborate', 'To work with others toward a shared result.', 'The two teams will collaborate on the presentation.', 'work', 'beginner', 'seeded'),
  ('Deadline', 'The latest time by which something must be finished.', 'Our deadline for the report is Friday afternoon.', 'work', 'beginner', 'seeded'),
  ('Feedback', 'Comments intended to help someone improve.', 'The manager gave useful feedback on my first draft.', 'work', 'beginner', 'seeded'),
  ('Prioritise', 'To decide what is most important and do it first.', 'We need to prioritise the tasks that affect customers.', 'work', 'beginner', 'seeded'),
  ('Accountable', 'Responsible for actions and expected to explain results.', 'Each team lead is accountable for the final delivery.', 'work', 'intermediate', 'seeded'),
  ('Delegate', 'To give a task or responsibility to someone else.', 'A good leader knows when to delegate specialist work.', 'work', 'intermediate', 'seeded'),
  ('Efficient', 'Achieving a result without wasting time or resources.', 'The new process is more efficient than the old one.', 'work', 'intermediate', 'seeded'),
  ('Initiative', 'The ability to act without waiting to be told.', 'Tia showed initiative by solving the issue early.', 'work', 'intermediate', 'seeded'),
  ('Stakeholder', 'A person or group affected by a project or decision.', 'We asked each stakeholder to review the proposal.', 'work', 'intermediate', 'seeded'),
  ('Consensus', 'General agreement among the members of a group.', 'The team reached a consensus after a thoughtful discussion.', 'work', 'advanced', 'seeded'),
  ('Contingency', 'A plan or provision for a possible future problem.', 'Our contingency is to use the backup venue if it rains.', 'work', 'advanced', 'seeded'),
  ('Facilitate', 'To make an action or process easier.', 'Max will facilitate the planning workshop.', 'work', 'advanced', 'seeded'),
  ('Mitigate', 'To reduce the seriousness or harmful effect of something.', 'Extra testing can mitigate the risk of a failed launch.', 'work', 'advanced', 'seeded'),
  ('Strategic', 'Designed to support an important long-term aim.', 'Hiring a designer was a strategic decision for the product.', 'work', 'advanced', 'seeded'),

  ('Break the ice', 'To make people feel more relaxed when they first meet.', 'A simple game helped break the ice at the workshop.', 'idioms_phrases', 'beginner', 'seeded'),
  ('On the same page', 'Sharing the same understanding or aim.', 'Let us confirm the scope so we are on the same page.', 'idioms_phrases', 'beginner', 'seeded'),
  ('Hit the nail on the head', 'To describe the exact cause or truth of something.', 'You hit the nail on the head when you mentioned unclear priorities.', 'idioms_phrases', 'beginner', 'seeded'),
  ('Once in a blue moon', 'Very rarely.', 'We order takeaway once in a blue moon.', 'idioms_phrases', 'beginner', 'seeded'),
  ('Under the weather', 'Feeling slightly ill.', 'I am under the weather, so I will rest today.', 'idioms_phrases', 'beginner', 'seeded'),
  ('A blessing in disguise', 'Something that seems bad at first but later proves helpful.', 'Missing that train was a blessing in disguise because I met an old friend.', 'idioms_phrases', 'intermediate', 'seeded'),
  ('Cut to the chase', 'To get to the main point without delay.', 'We only have ten minutes, so let us cut to the chase.', 'idioms_phrases', 'intermediate', 'seeded'),
  ('Get the ball rolling', 'To start an activity or process.', 'I will send the first draft to get the ball rolling.', 'idioms_phrases', 'intermediate', 'seeded'),
  ('In the long run', 'Over a long period of time.', 'Regular practice will help in the long run.', 'idioms_phrases', 'intermediate', 'seeded'),
  ('Think outside the box', 'To consider creative or unusual solutions.', 'We may need to think outside the box to solve this cheaply.', 'idioms_phrases', 'intermediate', 'seeded'),
  ('Bite the bullet', 'To face a difficult or unpleasant task with courage.', 'I decided to bite the bullet and make the difficult call.', 'idioms_phrases', 'advanced', 'seeded'),
  ('Read between the lines', 'To find a meaning that is suggested but not directly stated.', 'If you read between the lines, the email sounds uncertain.', 'idioms_phrases', 'advanced', 'seeded'),
  ('The tip of the iceberg', 'A small visible part of a much larger issue.', 'Those delays were only the tip of the iceberg.', 'idioms_phrases', 'advanced', 'seeded'),
  ('Throw in the towel', 'To stop trying because success seems impossible.', 'They refused to throw in the towel after the first setback.', 'idioms_phrases', 'advanced', 'seeded'),
  ('Weather the storm', 'To survive a difficult period.', 'Careful saving helped the business weather the storm.', 'idioms_phrases', 'advanced', 'seeded'),

  ('Knowledge is power', 'Learning gives people greater ability to act and decide.', 'Knowledge is power reminds us why education matters.', 'quotes', 'beginner', 'seeded'),
  ('Practice makes progress', 'Repeated effort leads to steady improvement.', 'Practice makes progress is a kinder goal than perfection.', 'quotes', 'beginner', 'seeded'),
  ('Actions speak louder than words', 'What people do is stronger evidence than what they say.', 'Actions speak louder than words when promises are repeatedly broken.', 'quotes', 'beginner', 'seeded'),
  ('The only way out is through', 'A difficulty often has to be faced rather than avoided.', 'The only way out is through encouraged her to begin the hard task.', 'quotes', 'beginner', 'seeded'),
  ('Small steps add up', 'Modest repeated actions can create a large result.', 'Small steps add up when you practise a little every day.', 'quotes', 'beginner', 'seeded'),
  ('Fortune favours the bold', 'People willing to take sensible risks may gain opportunities.', 'Fortune favours the bold inspired him to share the idea.', 'quotes', 'intermediate', 'seeded'),
  ('Less is more', 'Simplicity can be more effective than excess.', 'Less is more guided the clean design of the page.', 'quotes', 'intermediate', 'seeded'),
  ('Time is the wisest counsellor', 'Time and experience often improve judgement.', 'Time is the wisest counsellor suggests waiting before a rushed decision.', 'quotes', 'intermediate', 'seeded'),
  ('Well begun is half done', 'A strong start makes completion much easier.', 'Well begun is half done encouraged us to plan carefully.', 'quotes', 'intermediate', 'seeded'),
  ('What we think, we become', 'Repeated thoughts can shape identity and behaviour.', 'What we think, we become is a reminder to notice our inner voice.', 'quotes', 'intermediate', 'seeded'),
  ('The unexamined life is not worth living', 'Reflection is essential to a meaningful life.', 'The unexamined life is not worth living challenges us to question our choices.', 'quotes', 'advanced', 'seeded'),
  ('In the middle of difficulty lies opportunity', 'Hard situations can contain the possibility of growth.', 'In the middle of difficulty lies opportunity helped the team reframe the setback.', 'quotes', 'advanced', 'seeded'),
  ('No wind favours the sailor who has no port', 'Without a clear goal, circumstances cannot be used effectively.', 'No wind favours the sailor who has no port reminds us to choose a direction.', 'quotes', 'advanced', 'seeded'),
  ('We are what we repeatedly do', 'Habits shape ability and character over time.', 'We are what we repeatedly do connects daily practice with lasting change.', 'quotes', 'advanced', 'seeded'),
  ('The journey of a thousand miles begins with one step', 'Large achievements begin with a single manageable action.', 'The journey of a thousand miles begins with one step makes a difficult goal feel possible.', 'quotes', 'advanced', 'seeded');

insert into public.knowledge_items (
  term, meaning, example_sentence, difficulty, source
)
select
  term,
  meaning,
  example_sentence,
  difficulty::public.knowledge_difficulty,
  source::public.knowledge_source
from starter_knowledge_items;

select private.remap_starter_categories();
