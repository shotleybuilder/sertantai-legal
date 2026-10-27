import csv, json, sys, re
import census as C, finder as F
csv.field_size_limit(10**8)
rows=[r for r in csv.DictReader(open("out/sentences.tsv"), delimiter="\t") if r["counted"]=="silent" and r["worst"] not in ("ok","none","withheld","scope")]
data={}
for line in open("input.jsonl"):
    d=json.loads(line); data[d["law"]]=d
for i,r in enumerate(rows,1):
    d=data[r["law"]]; st=F.Structure(r["law"]); s=C.Stored(d,st)
    print(f"#{i} {r['law'][3:]} {r['ref']} [{r['worst']}] class={r['class']} default={d['default']} app={d['application']}")
    print("   S:", r["sentence"][:900])
    seen=set()
    for fl in r["flags"].split("; "):
        if not fl: continue
        v,ref=fl.split(":",1)
        if ref in seen or len(seen) >= 6: continue
        seen.add(ref)
        ex,cov=s.where(ref)
        print(f"   {v} {ref}: exact={ex} cover={cov}")
