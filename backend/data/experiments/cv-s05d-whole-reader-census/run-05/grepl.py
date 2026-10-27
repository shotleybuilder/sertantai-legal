import json, sys, re
law, pat = "UK_"+sys.argv[1], re.compile(sys.argv[2])
for line in open("input.jsonl"):
    d=json.loads(line)
    if d["law"]!=law: continue
    print("application", d["application"])
    for s in d["sentences"]:
        m=pat.search(s["s"])
        if m: print(f"[{s['ref']} {s['class']}] …{s['s'][max(0,m.start()-250):m.end()+250]}…")
