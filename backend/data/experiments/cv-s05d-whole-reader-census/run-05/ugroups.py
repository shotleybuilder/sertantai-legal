import csv, json, sys, re
skip=set(sys.argv[1].split(","))
data={}
for line in open("input.jsonl"):
    d=json.loads(line); data[d["law"]]=d
g={}
for r in csv.DictReader(open("out/unnamed.tsv"),delimiter="\t"):
    g.setdefault((r["law"],r["kind"],r["place"]),[]).append(r["ref"])
for (law,k,p),refs in g.items():
    if law[3:] in skip: continue
    print(f"## {law[3:]} {k} {p}: {','.join(refs)[:200]}")
    for s in data[law]["sentences"]:
        c=s["class"]
        if c.startswith("sweep:noise"): continue
        want = (k=="same" and ("same" in c)) or (k in ("applies","applies_not") and c.startswith("applies")) or (p and p in c) or c.startswith("default")
        if want and (k!="same" or "same" in c):
            print(f"   [{s['ref']} {c}] {s['s'][:600]}")
