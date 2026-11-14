import sys,gzip,json,collections,glob,re
import xml.etree.ElementTree as ET
L='{http://www.legislation.gov.uk/namespaces/legislation}'
M='{http://www.legislation.gov.uk/namespaces/metadata}'
d=json.load(open(sys.argv[1])); c=collections.Counter(); ex={}
for law in d['nested-addition']:
    _,t,y,n=law.split('_',3)
    year={}; typ={}
    for p in glob.glob(f'data/cache/clml/changes/affected/{t}/{y}/{n}/data.feed.page-*.gz'):
        for e in ET.fromstring(gzip.open(p).read()).iter(M+'Effect'):
            year[e.get('EffectId')]=int(e.get('AffectingYear') or 0); typ[e.get('EffectId')]=e.get('Type')
    root=ET.fromstring(gzip.open(f'data/cache/clml/{t}/{y}/{n}/body/data.xml.gz').read())
    parent={ch:pa for pa in root.iter() for ch in pa}
    for pn in root.iter(L+'Pnumber'):
        chain=[]; e=pn
        while True:
            a=[x for x in e if x.tag==L+'Addition' and x.get('ChangeId')]
            if not a: break
            e=a[0]; m=re.match(r'key-[0-9a-f]{32}',e.get('ChangeId'))
            if m and (not chain or chain[-1]!=m.group(0)): chain.append(m.group(0))
        for o,i in zip(chain,chain[1:]):
            if o in year and i in year:
                k='inner later' if year[i]>year[o] else 'same year' if year[i]==year[o] else 'inner EARLIER'
                c[k]+=1; ex.setdefault(k,f'{law} {parent[pn].get("id")} {year[o]} {typ[o]!r} / {year[i]} {typ[i]!r}')
            else: c['not in feed']+=1
print(c.most_common()); 
for k,v in ex.items(): print(k,':',v)
