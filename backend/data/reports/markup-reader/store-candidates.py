# candidate laws per class across every stored body (one law at a time)
import sys, gzip, glob, re, collections, json
import xml.etree.ElementTree as ET
L='{http://www.legislation.gov.uk/namespaces/legislation}'
CH={L+'Addition',L+'Substitution',L+'Repeal'}
out=collections.defaultdict(list); cnt=collections.Counter()
for p in sorted(glob.glob('data/cache/clml/*/*/*/body/data.xml.gz')):
    t,y,n=p.split('/')[3:6]; law=f'UK_{t}_{y}_{n}'
    try: root=ET.fromstring(gzip.open(p).read())
    except Exception: continue
    ids=collections.Counter(e.get('id') for e in root.iter() if e.get('id'))
    rep={i for i,c in ids.items() if c>1}
    hits=collections.Counter()
    for e in root.iter():
        if e.get('id') in rep:
            pn=e.find(L+'Pnumber')
            if pn is not None and not re.search(r'\w',''.join(pn.itertext())): hits['dots-number']+=1
        if e.tag in CH and e.get('ChangeId'):
            cid=e.get('ChangeId'); cr=e.get('CommentaryRef') or ''
            if not cr and e.find(L+'CommentaryRef') is not None: hits['child-commentaryref']+=1
            if not cid.startswith('key-') and cr.startswith('key-'): hits['key-in-commentaryref']+=1
            if e.tag==L+'Addition':
                for a in e.iter(L+'Addition'):
                    if a is not e and a.get('ChangeId') and a.get('ChangeId')!=cid: hits['nested-addition']+=1
    for cm in root.iter(L+'Commentary'):
        txt=''.join(cm.itertext())
        if re.search(r'\b(arts?|regs?|ss?|paras?|Sch(?:s|edules?)?)\.\s*\d+[A-Z]*(\([^)]*\))*\s*(,|and)\s*\(?\d',txt): hits['plural-note']+=1
    for h,v in hits.items(): out[h].append(law); cnt[h]+=v
json.dump(out,open(sys.argv[1],'w'))
for h in cnt: print(h, cnt[h], 'in', len(out[h]), 'laws')
