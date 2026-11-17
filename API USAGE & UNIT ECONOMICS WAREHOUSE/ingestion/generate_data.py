"""Deterministic synthetic generator for the Nexora API usage & unit-economics warehouse.

Produces the eleven `raw` tables defined in TAD.md section 15.1 as CSV seeds.
No financial value here is observed; all of it is modelled for demonstration.
"""
import csv, hashlib, json, random
from datetime import datetime, timedelta
from pathlib import Path

SEED = 42
rng = random.Random(SEED)
AS_OF = datetime(2026, 11, 8, 0, 0, 0)          # warehouse watermark ("today")
WINDOW_START = datetime(2026, 6, 1)
WINDOW_END = datetime(2026, 11, 7)
OUT = Path("/home/user/nexora/seeds")
OUT.mkdir(parents=True, exist_ok=True)


def dt(x):
    return None if x is None else x.strftime("%Y-%m-%d %H:%M:%S")


def sha(payload):
    return hashlib.sha256(json.dumps(payload, sort_keys=True, default=str).encode()).hexdigest()


def write(name, cols, rows):
    with open(OUT / f"{name}.csv", "w", newline="", encoding="utf-8") as fh:
        w = csv.writer(fh, quoting=csv.QUOTE_MINIMAL, lineterminator="\n")
        w.writerow(cols)
        for r in rows:
            w.writerow(["" if r.get(c) is None else r.get(c) for c in cols])
    print(f"  {name:<30} {len(rows):>6} rows")


# ---------------------------------------------------------------- batches
BATCHES = []
batch_specs = [
    ("2026-06-01 07:00:00", "succeeded", 0),
    ("2026-07-01 07:00:00", "succeeded", 1),
    ("2026-08-01 07:00:00", "succeeded", 2),
    ("2026-09-01 07:00:00", "succeeded", 3),
    ("2026-10-01 07:00:00", "succeeded", 4),
    ("2026-11-08 06:00:00", "partially_succeeded", 5),
]
for i, (started, status, idx) in enumerate(batch_specs, start=1):
    BATCHES.append({
        "batch_id": f"00000000-0000-4000-8000-0000000000{i:02d}",
        "source_name": "nexora_api_simulator",
        "source_file_name": f"batch_{idx:02d}_export.jsonl",
        "generator_seed": SEED,
        "started_at": started,
        "completed_at": dt(datetime.fromisoformat(started) + timedelta(minutes=4)),
        "batch_status": status,
        "created_at": started,
        "code_version": "nexora-generator@1.0.0",
    })
BATCH_IDS = [b["batch_id"] for b in BATCHES]

# ---------------------------------------------------------------- reference
SEGMENTS = ["startup", "mid_market", "enterprise"]
COUNTRIES = ["US", "GB", "DE", "IN", "BR", "JP", "CA", "AU", "SG", "NL"]
accounts = []
for i in range(1, 101):
    aid = f"acct_{i:04d}"
    created = datetime(2026, 1, 1) + timedelta(days=rng.randint(0, 148), hours=rng.randint(0, 23))
    status = "active" if i <= 92 else ("suspended" if i <= 97 else "closed")
    accounts.append({
        "account_id": aid,
        "account_name": f"Synthetic Account {i:03d}",
        "account_created_at": dt(created),
        "account_status": status,
        "account_segment": SEGMENTS[i % 3] if i % 3 != 2 else "enterprise",
        "country_code": COUNTRIES[i % len(COUNTRIES)],
        "source_updated_at": dt(AS_OF - timedelta(days=1)),
    })

MODELS = [
    ("model_text_01", "Nexora Text 1", "text_generation", "prov_nimbus", "Nimbus Compute", (3.00, 15.00), (1.80, 9.00)),
    ("model_text_02", "Nexora Text 2", "text_generation", "prov_nimbus", "Nimbus Compute", (1.00, 5.00), (0.60, 3.00)),
    ("model_text_03", "Nexora Text 3 Nano", "text_generation", "prov_atlas", "Atlas Inference", (0.50, 2.50), (0.30, 1.50)),
    ("model_reason_01", "Nexora Reason 1", "text_generation", "prov_atlas", "Atlas Inference", (8.00, 32.00), (4.80, 19.20)),
    ("model_embed_01", "Nexora Embed 1", "embedding", "prov_nimbus", "Nimbus Compute", (0.10, 0.00), (0.06, 0.00)),
]
models = []
for mid, mname, fam, pid, pname, _, _ in MODELS:
    models.append({
        "model_id": mid, "model_name": mname, "model_family": fam,
        "provider_id": pid, "provider_name": pname, "model_status": "active",
        "input_unit": "tokens", "output_unit": "tokens",
        "model_created_at": dt(datetime(2025, 10, 1)), "retired_at": None,
        "source_updated_at": dt(AS_OF - timedelta(days=1)),
    })

plans = [
    {"plan_id": "free", "plan_name": "Free", "plan_description": "Synthetic free tier; zero customer price.",
     "is_free_plan": "true", "is_active": "true", "source_updated_at": dt(AS_OF - timedelta(days=1))},
    {"plan_id": "starter", "plan_name": "Starter", "plan_description": "Synthetic pay-as-you-go tier.",
     "is_free_plan": "false", "is_active": "true", "source_updated_at": dt(AS_OF - timedelta(days=1))},
    {"plan_id": "business", "plan_name": "Business", "plan_description": "Synthetic volume tier.",
     "is_free_plan": "false", "is_active": "true", "source_updated_at": dt(AS_OF - timedelta(days=1))},
]

# plan assignment: 20 free / 45 starter / 35 business
plan_of = {}
order = list(range(1, 101))
rng.shuffle(order)
for pos, idx in enumerate(order):
    plan_of[f"acct_{idx:04d}"] = "free" if pos < 20 else ("starter" if pos < 65 else "business")

history = []
h = 0
plan_change_at = {}
for a in accounts:
    aid = a["account_id"]
    created = datetime.fromisoformat(a["account_created_at"])
    base_plan = plan_of[aid]
    upgrade = (base_plan == "starter" and rng.random() < 0.30)
    if upgrade:
        change = WINDOW_START + timedelta(days=rng.randint(20, 140))
        plan_change_at[aid] = change
        h += 1
        history.append({"account_plan_history_id": f"aph_{h:05d}", "account_id": aid, "plan_id": "starter",
                        "valid_from": dt(created), "valid_to": dt(change), "source_updated_at": dt(AS_OF - timedelta(days=1))})
        h += 1
        history.append({"account_plan_history_id": f"aph_{h:05d}", "account_id": aid, "plan_id": "business",
                        "valid_from": dt(change), "valid_to": None, "source_updated_at": dt(AS_OF - timedelta(days=1))})
        plan_of[aid] = "business"
    else:
        h += 1
        history.append({"account_plan_history_id": f"aph_{h:05d}", "account_id": aid, "plan_id": base_plan,
                        "valid_from": dt(created), "valid_to": None, "source_updated_at": dt(AS_OF - timedelta(days=1))})

# ---------------------------------------------------------------- pricing
REVISION_AT = datetime(2026, 9, 1)
pricing, prov_cost = [], []
pv = cv = 0
# deliberate gap: text_03/starter/output has no price 2026-07-01 .. 2026-07-04
GAP_FROM, GAP_TO = datetime(2026, 7, 1), datetime(2026, 7, 4)
for mid, _, _, pid, _, cust, cost in MODELS:
    for comp, ci in (("input", 0), ("output", 1)):
        for plan, mult in (("free", 0.0), ("starter", 1.25), ("business", 1.0)):
            base = 0.0 if plan == "free" else round(cust[ci] * mult, 6)
            revised = base if plan == "free" else round(cust[ci] * mult * 1.05, 6)
            has_rev = mid in ("model_text_01", "model_text_02")
            row_gap = (mid == "model_text_03" and plan == "starter" and comp == "output")
            pv += 1
            if row_gap:
                pricing.append({"customer_pricing_version_id": f"cpv_{pv:04d}", "model_id": mid, "plan_id": plan,
                                "usage_component": comp, "unit_of_measure": "tokens",
                                "price_per_million_tokens": f"{base:.6f}", "currency": "USD",
                                "valid_from": dt(WINDOW_START), "valid_to": dt(GAP_FROM),
                                "source_updated_at": dt(AS_OF - timedelta(days=1))})
                pv += 1
                pricing.append({"customer_pricing_version_id": f"cpv_{pv:04d}", "model_id": mid, "plan_id": plan,
                                "usage_component": comp, "unit_of_measure": "tokens",
                                "price_per_million_tokens": f"{base:.6f}", "currency": "USD",
                                "valid_from": dt(GAP_TO), "valid_to": None,
                                "source_updated_at": dt(AS_OF - timedelta(days=1))})
            elif has_rev:
                pricing.append({"customer_pricing_version_id": f"cpv_{pv:04d}", "model_id": mid, "plan_id": plan,
                                "usage_component": comp, "unit_of_measure": "tokens",
                                "price_per_million_tokens": f"{base:.6f}", "currency": "USD",
                                "valid_from": dt(WINDOW_START), "valid_to": dt(REVISION_AT),
                                "source_updated_at": dt(AS_OF - timedelta(days=1))})
                pv += 1
                pricing.append({"customer_pricing_version_id": f"cpv_{pv:04d}", "model_id": mid, "plan_id": plan,
                                "usage_component": comp, "unit_of_measure": "tokens",
                                "price_per_million_tokens": f"{revised:.6f}", "currency": "USD",
                                "valid_from": dt(REVISION_AT), "valid_to": None,
                                "source_updated_at": dt(AS_OF - timedelta(days=1))})
            else:
                pricing.append({"customer_pricing_version_id": f"cpv_{pv:04d}", "model_id": mid, "plan_id": plan,
                                "usage_component": comp, "unit_of_measure": "tokens",
                                "price_per_million_tokens": f"{base:.6f}", "currency": "USD",
                                "valid_from": dt(WINDOW_START), "valid_to": None,
                                "source_updated_at": dt(AS_OF - timedelta(days=1))})

    for comp, ci in (("input", 0), ("output", 1)):
        base = cost[ci]
        rev = round(base * 1.08, 6)
        has_rev = mid in ("model_text_01", "model_reason_01")
        row_gap = (mid == "model_embed_01" and comp == "input")
        cv += 1
        if row_gap:
            prov_cost.append({"provider_cost_version_id": f"pcv_{cv:04d}", "provider_id": pid, "model_id": mid,
                              "usage_component": comp, "unit_of_measure": "tokens",
                              "cost_per_million_tokens": f"{base:.6f}", "currency": "USD",
                              "valid_from": dt(WINDOW_START), "valid_to": dt(datetime(2026, 7, 15)),
                              "source_updated_at": dt(AS_OF - timedelta(days=1))})
            cv += 1
            prov_cost.append({"provider_cost_version_id": f"pcv_{cv:04d}", "provider_id": pid, "model_id": mid,
                              "usage_component": comp, "unit_of_measure": "tokens",
                              "cost_per_million_tokens": f"{base:.6f}", "currency": "USD",
                              "valid_from": dt(datetime(2026, 7, 20)), "valid_to": None,
                              "source_updated_at": dt(AS_OF - timedelta(days=1))})
        elif has_rev:
            prov_cost.append({"provider_cost_version_id": f"pcv_{cv:04d}", "provider_id": pid, "model_id": mid,
                              "usage_component": comp, "unit_of_measure": "tokens",
                              "cost_per_million_tokens": f"{base:.6f}", "currency": "USD",
                              "valid_from": dt(WINDOW_START), "valid_to": dt(REVISION_AT),
                              "source_updated_at": dt(AS_OF - timedelta(days=1))})
            cv += 1
            prov_cost.append({"provider_cost_version_id": f"pcv_{cv:04d}", "provider_id": pid, "model_id": mid,
                              "usage_component": comp, "unit_of_measure": "tokens",
                              "cost_per_million_tokens": f"{rev:.6f}", "currency": "USD",
                              "valid_from": dt(REVISION_AT), "valid_to": None,
                              "source_updated_at": dt(AS_OF - timedelta(days=1))})
        else:
            prov_cost.append({"provider_cost_version_id": f"pcv_{cv:04d}", "provider_id": pid, "model_id": mid,
                              "usage_component": comp, "unit_of_measure": "tokens",
                              "cost_per_million_tokens": f"{base:.6f}", "currency": "USD",
                              "valid_from": dt(WINDOW_START), "valid_to": None,
                              "source_updated_at": dt(AS_OF - timedelta(days=1))})

# ---------------------------------------------------------------- events
MODEL_WEIGHTS = [("model_text_01", 30), ("model_text_02", 25), ("model_text_03", 20),
                 ("model_reason_01", 15), ("model_embed_01", 10)]
mw_models = [m for m, _ in MODEL_WEIGHTS]
mw_vals = [w for _, w in MODEL_WEIGHTS]
ACTIVE_ACCTS = [a["account_id"] for a in accounts if a["account_status"] == "active"]

MONTH_COUNTS = [(2026, 6, 620), (2026, 7, 680), (2026, 8, 740), (2026, 9, 800), (2026, 10, 860), (2026, 11, 400)]
PENDING_DAYS = (datetime(2026, 11, 4), datetime(2026, 11, 6, 23, 59))

req_events, att_events = [], []
deliveries, quarantined = [], []
req_seq = att_seq = ev_seq = dl_seq = q_seq = 0
late_candidates, backfill_candidates = [], []


def add_delivery(source_event_id, entity_type, phash, outcome, received_at, reason_code=None, reason_detail=None,
                 batch_index=5):
    global dl_seq
    dl_seq += 1
    deliveries.append({
        "delivery_id": f"dlv_{dl_seq:07d}", "batch_id": BATCH_IDS[batch_index], "source_event_id": source_event_id,
        "entity_type": entity_type, "payload_hash": phash, "received_at": dt(received_at),
        "delivery_outcome": outcome, "reason_code": reason_code, "reason_detail": reason_detail,
    })
    return f"dlv_{dl_seq:07d}"


def batch_for(month_start):
    return max(0, min(5, month_start.month - 6))


def ingest_ts(month_start, seconds):
    base = datetime.fromisoformat(BATCHES[batch_for(month_start)]["completed_at"])
    return base + timedelta(seconds=seconds)


def push_request_event(rid, version, action, supersedes, acct, mid, created, resolved, ev_ts,
                       status, itok, otok, reason=None, outcome="accepted", batch_index=None):
    global req_seq
    req_seq += 1
    sid = f"req_ev_{req_seq:07d}"
    ph = sha({"id": rid, "v": version, "s": status, "i": itok, "o": otok})
    bi = batch_for(created.replace(day=1)) if batch_index is None else batch_index
    ing = ingest_ts(created.replace(day=1), req_seq % 900)
    req_events.append({
        "source_event_id": sid, "logical_request_id": rid, "entity_version": version, "event_action": action,
        "supersedes_event_id": supersedes, "account_id": acct, "model_id": mid,
        "request_created_at": dt(created), "request_resolved_at": dt(resolved), "event_timestamp": dt(ev_ts),
        "request_status": status, "input_tokens": itok, "output_tokens": otok,
        "source_system": "nexora_api_simulator", "correction_reason": reason, "payload_hash": ph,
        "batch_id": BATCH_IDS[bi], "ingested_at": dt(ing),
    })
    add_delivery(sid, "logical_request", ph, outcome, ing,
                 "OUTSIDE_AUTOMATIC_WINDOW" if outcome == "backfill_required" else None,
                 "event_timestamp older than the seven-day automatic window" if outcome == "backfill_required" else None,
                 bi)
    return sid


def push_attempt_event(aid, rid, version, action, supersedes, num, mid, started, completed, ev_ts,
                       status, itok, otok, rcs, reason=None, outcome="accepted", batch_index=None):
    global att_seq
    att_seq += 1
    sid = f"att_ev_{att_seq:07d}"
    ph = sha({"id": aid, "v": version, "s": status, "i": itok, "o": otok, "rcs": rcs})
    bi = batch_for(started.replace(day=1)) if batch_index is None else batch_index
    ing = ingest_ts(started.replace(day=1), 1200 + att_seq % 900)
    att_events.append({
        "source_event_id": sid, "attempt_id": aid, "logical_request_id": rid, "entity_version": version,
        "event_action": action, "supersedes_event_id": supersedes, "attempt_number": num, "model_id": mid,
        "attempt_started_at": dt(started), "attempt_completed_at": dt(completed), "event_timestamp": dt(ev_ts),
        "attempt_status": status, "input_tokens": itok, "output_tokens": otok,
        "resource_consumption_status": rcs, "source_system": "nexora_api_simulator",
        "correction_reason": reason, "payload_hash": ph, "batch_id": BATCH_IDS[bi],
        "ingested_at": dt(ing),
    })
    add_delivery(sid, "execution_attempt", ph, outcome, ing,
                 "OUTSIDE_AUTOMATIC_WINDOW" if outcome == "backfill_required" else None,
                 "event_timestamp older than the seven-day automatic window" if outcome == "backfill_required" else None,
                 bi)
    return sid


req_idx = 0
for (yr, mo, count) in MONTH_COUNTS:
    for _ in range(count):
        req_idx += 1
        rid = f"req_{req_idx:06d}"
        acct = rng.choice(ACTIVE_ACCTS)
        mid = rng.choices(mw_models, weights=mw_vals, k=1)[0]
        day = rng.randint(1, 28 if mo != 11 else 6)
        created = datetime(yr, mo, day, rng.randint(0, 23), rng.randint(0, 59), rng.randint(0, 59))
        if created >= WINDOW_END:
            created = WINDOW_END - timedelta(minutes=rng.randint(1, 600))
        is_pending = (PENDING_DAYS[0] <= created <= PENDING_DAYS[1]) and rng.random() < 0.42
        if is_pending:
            status = "pending"
        else:
            status = rng.choices(["succeeded", "failed", "timed_out", "cancelled"],
                                 weights=[78, 9, 5, 3], k=1)[0]

        in_tok = rng.randint(180, 4200)
        out_tok = 0 if mid == "model_embed_01" else rng.randint(20, 1600)
        missing = rng.random() < 0.025 and status != "pending"
        if missing:
            if rng.random() < 0.5:
                in_tok = None
            else:
                out_tok = None

        resolved = None if status == "pending" else created + timedelta(seconds=rng.randint(2, 240))
        ev_ts = created + timedelta(seconds=rng.randint(1, 30))
        outcome = "accepted"
        if rng.random() < 0.008:
            late_candidates.append(rid)
        # 10 earliest requests become the backfill-required set
        if req_idx <= 10:
            outcome = "backfill_required"
        sid = push_request_event(rid, 1, "initial", None, acct, mid, created, resolved, ev_ts,
                                 status, in_tok, out_tok, outcome=outcome)

        # corrections (~2%): resolve a pending request, or repair a failure / token count
        if rng.random() < 0.02 and status != "pending":
            new_status = "succeeded" if status in ("failed", "timed_out") and rng.random() < 0.5 else status
            new_in = in_tok if in_tok is not None else rng.randint(150, 3800)
            new_out = out_tok if out_tok is not None else rng.randint(20, 1400)
            corr_at = (resolved or created) + timedelta(days=rng.randint(1, 5))
            if corr_at > WINDOW_END:
                corr_at = WINDOW_END - timedelta(hours=rng.randint(1, 30))
            push_request_event(rid, 2, "correction", sid, acct, mid, created,
                               created + timedelta(seconds=rng.randint(5, 300)) if new_status != "pending" else None,
                               corr_at, new_status, new_in, new_out,
                               reason="late_resolution_and_usage_repair")
            status, in_tok, out_tok = new_status, new_in, new_out

        # attempts
        if status == "pending":
            n_att = 1 if rng.random() < 0.75 else 0
            att_statuses = ["pending"] * n_att
        elif status == "succeeded":
            n_att = rng.choices([1, 2, 3], weights=[85, 12, 3], k=1)[0]
            att_statuses = ["failed"] * (n_att - 1) + ["succeeded"]
        elif status == "failed":
            n_att = rng.choices([1, 2], weights=[70, 30], k=1)[0]
            att_statuses = ["failed"] * n_att
        elif status == "timed_out":
            n_att = rng.choices([1, 2], weights=[60, 40], k=1)[0]
            att_statuses = ["failed"] * (n_att - 1) + ["timed_out"]
        else:
            n_att = rng.choices([0, 1], weights=[35, 65], k=1)[0]
            att_statuses = ["cancelled"] * n_att

        started = created
        for k, st in enumerate(att_statuses, start=1):
            aid = f"att_{req_idx:06d}_{k}"
            started = started + timedelta(seconds=rng.randint(1, 40))
            if st == "pending":
                completed, rcs, a_in, a_out = None, "unknown", None, None
            else:
                completed = started + timedelta(seconds=rng.randint(1, 180))
                if st == "succeeded":
                    rcs = "consumed"
                    a_in = in_tok if in_tok is not None else None
                    a_out = out_tok if out_tok is not None else None
                elif st in ("failed", "timed_out"):
                    r = rng.random()
                    if r < 0.60:
                        rcs, a_in, a_out = "consumed", max(1, int((in_tok or 200) * 0.35)), max(0, int((out_tok or 60) * 0.3))
                    elif r < 0.80:
                        rcs, a_in, a_out = "not_consumed", 0, 0
                    else:
                        rcs, a_in, a_out = "unknown", None, None
                else:
                    r = rng.random()
                    if r < 0.30:
                        rcs, a_in, a_out = "consumed", max(1, int((in_tok or 200) * 0.15)), 0
                    elif r < 0.80:
                        rcs, a_in, a_out = "not_consumed", 0, 0
                    else:
                        rcs, a_in, a_out = "unknown", None, None
            a_ev = started + timedelta(seconds=3)
            att_sid = push_attempt_event(aid, rid, 1, "initial", None, k, mid, started, completed, a_ev,
                                         st, a_in, a_out, rcs)
            if rng.random() < 0.012 and st != "pending":
                push_attempt_event(aid, rid, 2, "correction", att_sid, k, mid, started, completed,
                                   (completed or started) + timedelta(days=1),
                                   st, (a_in or 100) + 7, (a_out or 10) + 3, rcs,
                                   reason="provider_usage_metering_correction")
            if st != "pending":
                started = completed

# late events: business timestamp old, event timestamp inside the seven-day window
late_set = set(late_candidates[:18])
_late_sid = set()
for e in req_events:
    if e["logical_request_id"] in late_set:
        e["event_timestamp"] = dt(datetime(2026, 11, 5, 9, 0, 0) + timedelta(minutes=hash(e["source_event_id"]) % 600))
        e["batch_id"] = BATCH_IDS[5]
        e["ingested_at"] = dt(AS_OF + timedelta(minutes=6, seconds=hash(e["source_event_id"]) % 900))
        _late_sid.add(e["source_event_id"])
for d in deliveries:
    if d["source_event_id"] in _late_sid:
        d["batch_id"] = BATCH_IDS[5]
        d["received_at"] = dt(AS_OF + timedelta(minutes=6))

# duplicate redeliveries (same ID + same hash -> duplicate, no new event row)
dup_pool = rng.sample([d for d in deliveries if d["delivery_outcome"] == "accepted"], 15)
for d in dup_pool:
    add_delivery(d["source_event_id"], d["entity_type"], d["payload_hash"], "duplicate",
                 AS_OF + timedelta(minutes=30), "IDENTICAL_REPLAY", "identical payload hash already accepted", 5)

# quarantined deliveries: rejected, therefore absent from raw event tables
bad = [
    ("req_ev_9001", "logical_request", "NEGATIVE_TOKEN_COUNT", "input_tokens = -12 violates non-negative rule", 101),
    ("req_ev_9002", "logical_request", "UNKNOWN_STATUS", "request_status = 'retrying' is not an accepted value", 102),
    ("att_ev_9001", "execution_attempt", "CONSUMPTION_CONTRACT_VIOLATION",
     "resource_consumption_status = not_consumed requires explicit zero tokens", 103),
    ("att_ev_9002", "execution_attempt", "MISSING_PARENT_REFERENCE",
     "logical_request_id req_999999 does not exist in raw.api_request_events", 104),
    ("req_ev_9003", "logical_request", "IDENTITY_CONFLICT", "same source_event_id delivered with a different payload hash", 105),
]
for sid, etype, code, detail, n in bad:
    ph = sha({"bad": sid, "n": n})
    did = add_delivery(sid, etype, ph, "quarantined", AS_OF + timedelta(minutes=31), code, detail, 5)
    q_seq += 1
    quarantined.append({
        "quarantine_id": f"qtn_{q_seq:05d}", "delivery_id": did, "batch_id": BATCH_IDS[5],
        "entity_type": etype, "source_event_id": sid,
        "raw_payload": json.dumps({"source_event_id": sid, "violation": code, "sequence": n}),
        "error_codes": code, "quarantined_at": dt(AS_OF + timedelta(minutes=31)),
        "resolved_at": None, "resolution_note": None,
    })

# ---------------------------------------------------------------- batch counts
for b in BATCHES:
    mine = [d for d in deliveries if d["batch_id"] == b["batch_id"]]
    if not mine:
        mine = []
    b["accepted_delivery_count"] = sum(1 for d in mine if d["delivery_outcome"] == "accepted")
    b["duplicate_delivery_count"] = sum(1 for d in mine if d["delivery_outcome"] == "duplicate")
    b["quarantined_delivery_count"] = sum(1 for d in mine if d["delivery_outcome"] == "quarantined")
    b["backfill_required_count"] = sum(1 for d in mine if d["delivery_outcome"] == "backfill_required")
    b["input_record_count"] = len(mine)
    b["error_message"] = "5 quarantined deliveries require operator review" if b["quarantined_delivery_count"] else None

# ---------------------------------------------------------------- write
print("writing seeds")
write("accounts", ["account_id", "account_name", "account_created_at", "account_status", "account_segment",
                   "country_code", "source_updated_at"], accounts)
write("models", ["model_id", "model_name", "model_family", "provider_id", "provider_name", "model_status",
                 "input_unit", "output_unit", "model_created_at", "retired_at", "source_updated_at"], models)
write("plans", ["plan_id", "plan_name", "plan_description", "is_free_plan", "is_active", "source_updated_at"], plans)
write("account_plan_history", ["account_plan_history_id", "account_id", "plan_id", "valid_from", "valid_to",
                               "source_updated_at"], history)
write("customer_pricing_schedules", ["customer_pricing_version_id", "model_id", "plan_id", "usage_component",
                                     "unit_of_measure", "price_per_million_tokens", "currency", "valid_from",
                                     "valid_to", "source_updated_at"], pricing)
write("provider_cost_schedules", ["provider_cost_version_id", "provider_id", "model_id", "usage_component",
                                  "unit_of_measure", "cost_per_million_tokens", "currency", "valid_from",
                                  "valid_to", "source_updated_at"], prov_cost)
write("api_request_events", ["source_event_id", "logical_request_id", "entity_version", "event_action",
                             "supersedes_event_id", "account_id", "model_id", "request_created_at",
                             "request_resolved_at", "event_timestamp", "request_status", "input_tokens",
                             "output_tokens", "source_system", "correction_reason", "payload_hash", "batch_id",
                             "ingested_at"], req_events)
write("api_attempt_events", ["source_event_id", "attempt_id", "logical_request_id", "entity_version",
                             "event_action", "supersedes_event_id", "attempt_number", "model_id",
                             "attempt_started_at", "attempt_completed_at", "event_timestamp", "attempt_status",
                             "input_tokens", "output_tokens", "resource_consumption_status", "source_system",
                             "correction_reason", "payload_hash", "batch_id", "ingested_at"], att_events)
write("ingestion_batches", ["batch_id", "source_name", "source_file_name", "generator_seed", "started_at",
                            "completed_at", "batch_status", "input_record_count", "accepted_delivery_count",
                            "duplicate_delivery_count", "quarantined_delivery_count", "backfill_required_count",
                            "error_message", "code_version", "created_at"], BATCHES)
write("event_delivery_log", ["delivery_id", "batch_id", "source_event_id", "entity_type", "payload_hash",
                             "received_at", "delivery_outcome", "reason_code", "reason_detail"], deliveries)
write("quarantined_events", ["quarantine_id", "delivery_id", "batch_id", "entity_type", "source_event_id",
                             "raw_payload", "error_codes", "quarantined_at", "resolved_at", "resolution_note"],
      quarantined)
print(f"\nlogical requests = {req_idx}, request events = {len(req_events)}, attempt events = {len(att_events)}")
print(f"deliveries = {len(deliveries)}, quarantined = {len(quarantined)}")
