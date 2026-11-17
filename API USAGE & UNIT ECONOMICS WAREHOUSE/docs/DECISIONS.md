# Architecture decisions and specification defects resolved

The PRD (`NEX-PRD-001`) and TAD (`NEX-TAD-001`) are the sources of truth. This file records every
place where the two documents did not fully determine the implementation, and what was built.

## ADR-013 — `mart_pipeline_health` and `mart_data_quality_summary`

**Defect (F-01).** PRD §20–21 require dashboards to disclose quarantined and backfill-required record
counts, while TAD §39 restricts the BI role to five marts and forbids raw reads. Quarantine state lives
only in `raw.event_delivery_log`, `raw.quarantined_events` and `raw.ingestion_batches`, so the requirement
was unimplementable as written.

**Decision.** Two additional marts publish the audit layer at governed grains
(`mart_pipeline_health` = one row per batch, `mart_data_quality_summary` = one row for the warehouse).
The BI role still never reads `raw`. This is why the project has 7 marts instead of the TAD's 5.

## ADR-014 — `usage_date` in `mart_unit_economics` is not a matched cohort

**Defect (F-02).** Revenue is dated by `request_created_at`; cost by `attempt_started_at`. A request
created 23:58 and retried at 00:03 splits across two daily rows, so a single day's margin can be
meaningless even when every input is complete.

**Decision.** Keep the documented column, but state plainly that daily margin mixes two populations and
certify **monthly** economics as the trustworthy grain (`mart_account_performance`,
`mart_model_performance`). The monthly margins in the README are computed from aggregated revenue and
cost, never averaged from daily percentages.

## ADR-015 — `month_is_complete` and the growth formula

**Defect (F-04).** PRD §18 defines usage growth only between *complete* months and forbids the partial
current month, but neither document defines completeness or provides the flag.

**Decision.** `month_is_complete` = the month ended before the current UTC month **and** every
contributing request has complete usage. `usage_growth_pct` is row-level month-over-month against the
immediately preceding spine row, and is NULL when either side is incomplete or the prior total is zero.
Zero-activity months are kept in the spine so the prior row always exists.

## ADR-016 — Terminal attempts

**Defect (F-05).** TAD §31 creates cost lines for "terminal" attempts but never enumerates the set.
Cancelled attempts were ambiguous.

**Decision.** `terminal := attempt_status <> 'pending'`. Cancelled attempts can carry cost when
`resource_consumption_status = 'consumed'`; pending attempts produce no cost line and are never implied
to be zero-cost (asserted by `tests/provider_cost_business_rules.sql`).

## ADR-017 — Unresolved plans stay visible

**Defect (F-06).** `plan_id` is nullable in the facts but `NOT NULL` in the plan-keyed marts, so a
NULL-plan line could be dropped while `revenue_is_complete` still reported TRUE.

**Decision.** Facts coalesce a missing plan to the `plan_unresolved` sentinel dimension member
(`dim_plan.is_sentinel`), and `mart_data_quality_summary.requests_unresolved_plan` counts them. On this
build the count is 0, but the failure mode can no longer be silent.

## ADR-018 — Free-plan lines never block revenue completeness

Free schedules are explicit zero-price rows, so a Free line is deterministically $0. A Free line with
unknown usage therefore blocks *usage* completeness but not *revenue* completeness.

## ADR-019 — Aggregates are rebuilt, facts are incremental

**Defect (F-09).** Propagating affected daily keys through five mart layers is where subtle
double-counting hides. At MVP volume (4,100 requests → 3,948 daily rows) this is not worth the risk.

**Decision.** The four incremental fact models carry the seven-day logic
(`is_incremental()`, `unique_key`, event-time affected-entity re-read, `delete+insert`).
`fct_usage_daily` and all marts are tables that recompute in full, so a late event cannot leave a stale
aggregate behind.

## Known deviation from the TAD

The TAD specifies PostgreSQL. This implementation runs on **DuckDB** so a reviewer or CI job needs no
database server. All SQL constructs used (`filter (where …)`, `date_trunc`, half-open interval joins,
`generate_series`, `interval`) are PostgreSQL-compatible; switching is a `profiles.yml` change plus the
`raw` DDL, not a model rewrite. This is a deliberate reproducibility trade-off, stated rather than hidden.
