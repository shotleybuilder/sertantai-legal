"""show.py LAW [REF ...]: a law's stored default/application and the rows holding each ref (CV-S05d triage)."""
import json, sys
import census as C, finder as F
law, refs = sys.argv[1], sys.argv[2:]
law = law if law.startswith("UK_") else "UK_" + law
for line in open("input.jsonl"):
    d = json.loads(line)
    if d["law"] != law:
        continue
    st = F.Structure(law)
    s = C.Stored(d, st)
    print("default", d["default"], "application", d["application"])
    if not refs:
        for r in d["lists"] + d["applies"]:
            print(" ", r["kind"], r["place"], ",".join(r["refs"])[:300])
    for ref in refs:
        ex, cov = s.where(ref)
        print(f"  {ref}: exact {ex} cover {cov}")
