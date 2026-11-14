import sys,gzip,json,collections,glob,re
import xml.etree.ElementTree as ET
L='{http://www.legislation.gov.uk/namespaces/legislation}'
M='{http://www.legislation.gov.uk/namespaces/metadata}'
d=json.load(open(sys.argv[1])); c=collections.Counter(); fam=collections.Counter()
for law in d['key-in-commentaryref']:
    _,t,y,n=law.split('_',3)
    feed=set()
    for p in glob.glob(f'data/cache/clml/changes/affected/{t}/{y}/{n}/data.feed.page-*.gz'):
        feed|={e.get('EffectId') for e in ET.fromstring(gzip.open(p).read()).iter(M+'Effect')}
    root=ET.fromstring(gzip.open(f'data/cache/clml/{t}/{y}/{n}/body/data.xml.gz').read())
    keyed=set(); per=collections.defaultdict(set)
    for e in root.iter():
        cid=e.get('ChangeId')
        if not cid: continue
        m=re.match(r'key-[0-9a-f]{32}',cid)
        if m: keyed.add(m.group(0))
        cr=e.get('CommentaryRef') or ''
        if not m and cr.startswith('key-'): per[cr].add(cid)
    for k,cids in per.items():
        c['notes']+=1; c['changeids']+=len(cids)
        if len(cids)>1: c['note shared by >1 ChangeId']+=1
        if k in keyed: c['key also a ChangeId key']+=1
        c['in feed' if k in feed else 'not in feed']+=1
print(c)
