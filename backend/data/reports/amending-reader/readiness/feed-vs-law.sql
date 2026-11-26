-- Amending-law reader readiness review (2026-11-26): the law's text against
-- legislation.gov.uk (feed, then markup) on operation and level, per stored text change.
-- Read-only. Families: uk_lrt.family; the round = the six Waste, Water and Climate families.
-- Corrected 2026-11-26 (Amending-law reader: step procedures): the values were read as their whole JSON
-- text (#>> '{}'), so "<> 'commenced'" never held and commencements counted as text changes; now ->>'v'.
with c as (
  select pc.id, pc.law_name, l.family,
    max(cl.value->>'v') filter (where cl.source='law_text' and cl.attribute='operation') law_op,
    max(cl.value->>'v') filter (where cl.source='feed'     and cl.attribute='operation') feed_op,
    max(cl.value->>'v') filter (where cl.source='markup'   and cl.attribute='operation') markup_op,
    max(cl.value->>'v') filter (where cl.source='law_text' and cl.attribute='level') law_lv,
    max(cl.value->>'v') filter (where cl.source='feed'     and cl.attribute='level') feed_lv,
    max(cl.value->>'v') filter (where cl.source='markup'   and cl.attribute='level') markup_lv
  from provision_changes pc
  join provision_change_claims cl on cl.change_id = pc.id
  left join uk_lrt l on l.name = pc.law_name
  where cl.attribute in ('operation','level')
  group by pc.id, pc.law_name, l.family
), t as (
  select *, coalesce(feed_op, markup_op) gov_op, coalesce(feed_lv, markup_lv) gov_lv,
    case when regexp_replace(family,'^\S+\s+','') in ('WASTE','WATER & WASTEWATER','CLIMATE CHANGE','POLLUTION','AIR QUALITY','NOISE')
         then 'Waste, Water and Climate (round)' else coalesce(family,'(none)') end grp
  from c
  where coalesce(law_op, feed_op, markup_op) is not null and coalesce(law_op, feed_op, markup_op) <> 'commenced'
)
select grp,
  count(*) text_changes,
  count(*) filter (where law_op is not null) law_speaks,
  count(*) filter (where gov_op is not null) gov_speaks,
  count(*) filter (where law_op is not null and gov_op is not null and law_op = gov_op) op_agree,
  count(*) filter (where law_op is not null and gov_op is not null and law_op <> gov_op) op_differ,
  count(*) filter (where law_op is not null and gov_op is null) op_law_only,
  count(*) filter (where law_op is null and gov_op is not null) op_gov_only,
  count(*) filter (where law_lv is not null and gov_lv is not null and law_lv = gov_lv) lv_agree,
  count(*) filter (where law_lv is not null and gov_lv is not null and law_lv <> gov_lv) lv_differ
from t
group by rollup(grp)
order by text_changes desc;
