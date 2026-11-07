#!/usr/bin/python3
"""The bracketed-container store scan (Maritime Safety: Switch-over, 2026-11-06),
recovered from its session as the reference for `mix lat.store_scan` (#192).

Changes from the original, so a port can be compared with it byte for byte:
files in sorted order (the original took the filesystem's glob order), and
every match listed (law, effect id, type, class, provisions text), sorted,
in place of 12 examples per class. The rule is the original's.

usage (from backend/): /usr/bin/python3 data/reports/store-scan/bracketed_container.py LIST.tsv
"""
import collections, glob, gzip, re, sys

eff = re.compile(r'<ukm:Effect ([^>]*)>(.*?)</ukm:Effect>', re.S)
attr = re.compile(r'(\w+)="([^"]*)"')
ref = re.compile(r'<ukm:Section [^>]*Ref="([^"]*)"')
cont = re.compile(r'\((?:Pt|Ch|Title|Sub-Pt|Section)\.?\s*[^)]*\)')
container = re.compile(r'(part|chapter|title|crossheading)-')

seen = set(); dup_laws = 0; matches = []; forms = collections.Counter(); laws = collections.defaultdict(set)
for f in sorted(glob.glob('data/cache/clml/changes/affected/*/*/*/data.feed.page-*.gz')):
    law = 'UK_' + '_'.join(f.split('/')[5:8])
    t = gzip.open(f, 'rt', errors='ignore').read()
    for m in eff.finditer(t):
        a = dict(attr.findall(m.group(1)))
        eid = a.get('EffectId')
        if eid in seen:
            continue
        seen.add(eid)
        ap = a.get('AffectedProvisions', '')
        refs = ref.findall(m.group(2).split('</ukm:AffectedProvisions>')[0])
        crefs = [r for r in refs if container.match(r)]
        prefs = [r for r in refs if not container.match(r)]
        if not crefs or not prefs:
            continue
        surv = [c for c in crefs if not any(p.startswith(c + '-') for p in prefs)]
        if not surv:
            continue
        k = 'bracketed' if cont.search(ap) else 'unbracketed'
        forms[k] += 1; laws[k].add(law)
        matches.append((law, eid, a.get('Type', ''), k, ap))

with open(sys.argv[1], 'w') as out:
    for row in sorted(matches):
        out.write('\t'.join(row) + '\n')
print(len(seen), 'effects;', {k: forms[k] for k in sorted(forms)}, {k: len(laws[k]) for k in sorted(laws)})
