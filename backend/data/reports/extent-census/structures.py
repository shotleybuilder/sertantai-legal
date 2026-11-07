"""structures.py IN.jsonl OUT.json [--all]: finder.Structure of each law
(with sentences or a range ref, or every law with --all) as {law: {order, members}}."""
import json, sys, time
sys.path.insert(0, ".")
import finder as F
src, out = sys.argv[1], sys.argv[2]
every = "--all" in sys.argv
res, t = {}, time.time()
for line in open(src):
    d = json.loads(line)
    if every or d["sentences"] or any(".." in x for r in d["lists"] + d["applies"] for x in r["refs"]):
        st = F.Structure(d["law"])
        res[d["law"]] = {"order": st.order, "members": [[c, r] for c, r in st.members.items()]}
json.dump(res, open(out, "w"), separators=(",", ":"))
print(f"{len(res)} laws in {time.time()-t:.1f}s")
