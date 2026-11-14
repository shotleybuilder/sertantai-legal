import sys,gzip,json,collections,re
import xml.etree.ElementTree as ET
L='{http://www.legislation.gov.uk/namespaces/legislation}'
d=json.load(open(sys.argv[1])); c=collections.Counter(); ex={}
def year(cm):
    if cm is None: return None
    ci=cm.find('.//'+L+'Citation')
    if ci is not None:
        m=re.search(r'/id/[a-z]+/(\d{4})/',ci.get('URI') or '')
        if m: return int(m.group(1))
    return None
def verb(cm):
    t=''.join(cm.itertext()) if cm is not None else ''
    m=re.search(r'\b(inserted|added|substituted|repealed|revoked|omitted|ceases?|cease to have effect|modified|applied|amended|renumbered|excluded)',t,re.I)
    return m.group(1).lower() if m else 'other'
for law in d['nested-addition']:
    _,t,y,n=law.split('_',3)
    root=ET.fromstring(gzip.open(f'data/cache/clml/{t}/{y}/{n}/body/data.xml.gz').read())
    notes={cm.get('id'):cm for cm in root.iter(L+'Commentary')}
    for pn in root.iter(L+'Pnumber'):
        chain=[]; e=pn
        while True:
            a=[x for x in e if x.tag==L+'Addition' and x.get('ChangeId')]
            if not a: break
            e=a[0]; chain.append((e.get('ChangeId'),e.get('CommentaryRef')))
        if len(chain)<2: continue
        iid,inote=chain[-1]
        if iid.startswith('key-'): continue
        kind='M_F_' if iid.startswith('M_F_') else 'dNNp' if re.match(r'd\d+p',iid) else 'other'
        iy=year(notes.get(inote)); v=verb(notes.get(inote))
        oy=[year(notes.get(nn)) for i,nn in chain[:-1]]
        earlier=any(o is not None and iy is not None and o<iy for o in oy)
        k=(kind,'outer earlier' if earlier else 'not', 'insert-like' if v in('inserted','added','substituted') else v)
        c[k]+=1; ex.setdefault(k,law+' '+str(pn))
for k,v in sorted(c.items(), key=lambda x:-x[1]): print(k,v)
