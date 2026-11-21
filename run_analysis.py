"""Loads all raw CSVs into SQLite, builds the clean view, runs every query in queries.sql,
and exports clean_tickets.csv (use that file as the Power BI source)."""
import csv, glob, os, re, sqlite3
HERE = os.path.dirname(__file__); RAW = os.path.join(HERE, "..", "data", "raw")
db = sqlite3.connect(os.path.join(HERE, "tickets.db"))
db.execute("DROP TABLE IF EXISTS raw_tickets")
db.execute("""CREATE TABLE raw_tickets(ticket_id TEXT, opened_at TEXT, resolved_at TEXT, priority TEXT,
              category TEXT, assignment_group TEXT, reopen_count INTEGER)""")
for fn in sorted(glob.glob(os.path.join(RAW, "tickets_*.csv"))):
    with open(fn, newline="") as f:
        db.executemany("INSERT INTO raw_tickets VALUES (?,?,?,?,?,?,?)",
                       [tuple(r[c] for c in ["ticket_id","opened_at","resolved_at","priority","category","assignment_group","reopen_count"]) for r in csv.DictReader(f)])
sql = open(os.path.join(HERE, "queries.sql")).read()
for name, body in re.findall(r"-- name: (\w+)\n(.*?)(?=\n-- name:|\Z)", sql, re.S):
    print(f"\n=== {name} ===")
    for stmt in [s for s in body.split(";") if s.strip()]:
        cur = db.execute(stmt)
        if cur.description:
            print(" | ".join(d[0] for d in cur.description))
            for row in cur.fetchall(): print(" | ".join(str(x) for x in row))
cur = db.execute("SELECT * FROM clean_tickets")
with open(os.path.join(HERE, "clean_tickets.csv"), "w", newline="") as f:
    w = csv.writer(f); w.writerow([d[0] for d in cur.description]); w.writerows(cur)
print("\nExported clean_tickets.csv")
