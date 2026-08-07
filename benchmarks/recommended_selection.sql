explain (analyze, buffers, timing, summary)
with candidates as (
  select
    value,
    md5('recommended-benchmark-' || value)::uuid item_id,
    ((value % 1000)::double precision / 1000::double precision) curriculum,
    case when value % 5 = 0 then (value % 8)::double precision else 0::double precision end repetitions,
    case when value % 11 = 0 then (value % 5)::double precision else 0::double precision end lapses,
    case when value % 5 = 0 then 1::double precision + (value % 90)::double precision else null end stability,
    case when value % 13 = 0 then 1 else 3 end last_rating,
    case when value % 3 = 0 then 0.80::double precision else 0::double precision end retrievability,
    case when value % 4 = 0 then 0.05::double precision else 1::double precision end recency_multiplier
  from generate_series(1, 100000) value
), scored as (
  select *,
    0.86::double precision + 0.08::double precision * curriculum desired_retention,
    1::double precision / (1::double precision + exp(-(((0.86::double precision + 0.08::double precision * curriculum) - retrievability) / 0.04::double precision))) urgency,
    case when stability is null then 1::double precision else exp(-stability / 14::double precision) end learning_gap,
    least(lapses / 4::double precision, 1::double precision) lapse_factor,
    1::double precision / sqrt(repetitions + 1::double precision) uncertainty
  from candidates
), weighted as (
  select item_id,
    (0.02::double precision + power(curriculum, 1.5::double precision) *
      (0.55::double precision * urgency + 0.25::double precision * learning_gap + 0.10::double precision * lapse_factor + 0.10::double precision * uncertainty)) *
    recency_multiplier weight
  from scored
)
select item_id
from weighted
order by -ln(((hashtextextended(
  '00000000-0000-0000-0000-000000000001' || item_id::text, 0
) & 9223372036854775807)::double precision + 1::double precision) / 9223372036854775808::double precision)
  / greatest(weight, 0.000001::double precision)
limit 15;
