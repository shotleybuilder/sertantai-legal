"""rdiff.py OLD NEW: per law, the stored extent reading's changes (default, application, rows, sentence classes)."""
import json, sys, collections
def load(p):
    out = {}
    for line in open(p):
        d = json.loads(line); out[d["law"]] = d
    return out
old, new = load(sys.argv[1]), load(sys.argv[2])
def rows(d):
    s = set()
    for r in d["lists"] + d["applies"]:
        for x in r["refs"]: s.add((r["kind"], r["place"], x))
    return s
def classes(d):
    return collections.Counter(s["class"] for s in d["sentences"])
n = 0
for law in sorted(set(old) | set(new)):
    a, b = old.get(law), new.get(law)
    if a is None or b is None:
        print(f"## {law}: {'added' if a is None else 'gone'}"); n += 1; continue
    out = []
    if a["default"] != b["default"]: out.append(f"  default {a['default']} -> {b['default']}")
    if a["application"] != b["application"]: out.append(f"  application {a['application']} -> {b['application']}")
    ra, rb = rows(a), rows(b)
    gone, added = sorted(ra - rb), sorted(rb - ra)
    def fmt(xs):
        g = collections.defaultdict(list)
        for k, p, r in xs: g[(k, p)].append(r)
        return "; ".join(f"{k} {p}: {','.join(v[:12])}{'…+'+str(len(v)-12) if len(v)>12 else ''}" for (k, p), v in g.items())
    if gone: out.append("  - " + fmt(gone))
    if added: out.append("  + " + fmt(added))
    ca, cb = classes(a), classes(b)
    if ca != cb:
        diff = {k: cb[k] - ca[k] for k in set(ca) | set(cb) if cb[k] != ca[k]}
        out.append("  classes " + ", ".join(f"{k}{v:+d}" for k, v in sorted(diff.items())))
    if out:
        n += 1; print(f"## {law}"); print("\n".join(out))
print(f"\n{n} laws changed of {len(new)}", file=sys.stderr)
