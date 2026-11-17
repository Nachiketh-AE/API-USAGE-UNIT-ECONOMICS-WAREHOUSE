"""Print the certified unit-economics summary from the marts. Read-only."""
import duckdb

con = duckdb.connect("nexora_warehouse.duckdb", read_only=True)
row = con.execute("""
    select round(sum(known_estimated_revenue_usd), 4),
           round(sum(known_estimated_provider_cost_usd), 4),
           round(sum(estimated_gross_profit_usd), 4),
           round(100.0 * sum(estimated_gross_profit_usd) / sum(estimated_revenue_usd), 4),
           sum(case when revenue_is_complete then 1 else 0 end),
           sum(case when cost_is_complete then 1 else 0 end),
           count(*)
    from analytics.mart_unit_economics
""").fetchone()

print(f"known revenue     ${row[0]:,.4f}")
print(f"known cost        ${row[1]:,.4f}")
print(f"gross profit      ${row[2]:,.4f}")
print(f"gross margin      {row[3]:.2f}%   (aggregate, never averaged from daily %)")
print(f"certified rows    revenue {row[4]:,}/{row[6]:,}   cost {row[5]:,}/{row[6]:,}")
print()
for r in con.execute("select * from analytics.mart_data_quality_summary").fetchall():
    cols = [d[0] for d in con.description]
    for k, v in zip(cols, r):
        print(f"  {k:<38} {v}")
