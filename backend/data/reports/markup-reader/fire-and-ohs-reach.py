import sys, gzip, os, re, collections
import xml.etree.ElementTree as ET
L='{http://www.legislation.gov.uk/namespaces/legislation}'
laws=[l.strip() for l in open(sys.argv[1]) if l.strip()]
c=collections.Counter(); lb=collections.defaultdict(set); ex={}
CH={L+'Addition',L+'Substitution',L+'Repeal'}
def hit(h,law,e):
    c[h]+=1; lb[h].add(law); ex.setdefault(h,f'{law} {e}')
for law in laws:
    _,t,y,n=law.split('_',3)
    p=f'data/cache/clml/{t}/{y}/{n}/body/data.xml.gz'
    if not os.path.exists(p): c['no body']+=1; continue
    root=ET.fromstring(gzip.open(p).read())
    parent={ch:pa for pa in root.iter() for ch in pa}
    def near_id(e):
        while e is not None:
            if e.get('id') and e.tag!=L+'Commentary': return e.get('id')
            e=parent.get(e)
    for e in root.iter():
        if e.tag not in CH: continue
        cid=e.get('ChangeId') or ''; cr=e.get('CommentaryRef') or ''
        if not cid: continue
        if not cr and e.find(L+'CommentaryRef') is not None: hit('child-commentaryref',law,cid[-6:]+' '+str(near_id(e)))
        if not cid.startswith('key-') and cr.startswith('key-'): hit('key-only-in-commentaryref (#188)',law,str(near_id(e)))
        if e.tag==L+'Addition':
            a=parent.get(e)
            while a is not None:
                if a.tag==L+'Addition' and a.get('ChangeId') and a.get('ChangeId')!=cid:
                    # a row id between outer and inner?
                    b=parent.get(e); rowid=False
                    while b is not None and b is not a:
                        if b.get('id'): rowid=True
                        b=parent.get(b)
                    hit('nested-addition'+(' (row id between)' if rowid else ''),law,str(near_id(e)))
                    break
                a=parent.get(a)
        ni=near_id(e) or ''
        if re.match(r'schedule-\d+[A-Z]*-part-\d+[A-Z]*$',ni): hit('schedule-part-wrapper',law,ni)
        if t.startswith('eu'):
            a=parent.get(e)
            while a is not None and a.tag!=L+'ListItem' and not a.get('id'): a=parent.get(a)
            if a is not None and a.tag==L+'ListItem' and not a.get('id'): hit('eu-unnumbered-listitem',law,ni)
    for cm in root.iter(L+'Commentary'):
        if (cm.get('id') or '').startswith('key-'): continue
        for ci in cm.iter(L+'Citation'):
            pass
        ops=[s for s in cm.iter(L+'CitationSubRef') if s.get('Operative')=='true']
        txt=''.join(cm.itertext())
        if re.search(r'\b(arts?|regs?|ss?)\.\s*\d+[A-Z]?,\s*\d',txt): hit('legacy-note-plural-affecting',law,cm.get('id'))
for h,v in c.most_common(): print(f'{h}: {v}, {len(lb[h])} laws; e.g. {ex.get(h)}')
