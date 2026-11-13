import sys, gzip, glob, re, collections
import xml.etree.ElementTree as ET
NS={'ukm':'http://www.legislation.gov.uk/namespaces/metadata'}
M='{http://www.legislation.gov.uk/namespaces/metadata}'
laws=[l.strip() for l in open(sys.argv[1]) if l.strip()]
c=collections.Counter(); lawsby=collections.defaultdict(set); ex={}
REM=re.compile(r'\b(repeal|revok|omit|delet|expire|ceas)',re.I)
for law in laws:
    _,t,y,n=law.split('_',3)
    for p in sorted(glob.glob(f'data/cache/clml/changes/affected/{t}/{y}/{n}/data.feed.page-*.gz')):
        root=ET.fromstring(gzip.open(p).read())
        for e in root.iter(M+'Effect'):
            typ=e.get('Type') or ''; ap=e.get('AffectedProvisions') or ''
            ifs=[i for i in e.iter(M+'InForce')]
            dated=[i for i in ifs if i.get('Date')]
            hits=[]
            if re.search(r'\bTitle\b',ap): hits.append('title-locator')
            for i in ifs:
                oq=i.get('OtherQualification') or ''
                if re.match(r'(for|in relation to|except)\s+(E|W|S|N\.?I|G\.?B|E\.?W)',oq,re.I) or re.match(r'for\s+[EWS]\.',oq): hits.append('other-qualification-territory'); break
            if REM.search(typ) and len(dated)>=2 and any(re.search(r'\bfor (E|W|S|N\.I)',(i.get('Qualification') or '')+(i.get('OtherQualification') or '')) for i in dated): hits.append('removal-stage-territory')
            ds=[i.get('Date') for i in dated]
            if len(ds)!=len(set(ds)): hits.append('same-date-stages')
            aff=e.find('ukm:AffectingProvisions',NS)
            if aff is not None and aff.find('ukm:SectionRange',NS) is not None: hits.append('feed-affecting-range')
            if re.search(r'\(as (inserted|substituted|added)( by)?\b',typ) or re.search(r'as inserted by',typ): hits.append('made-record')
            afp=e.find('ukm:AffectedProvisions',NS)
            if afp is not None and afp.find('ukm:SectionRange',NS) is not None: hits.append('affected-range (span candidates)')
            if re.search(r'in earlier amending',typ) and re.match(r'(words|word)',typ) is None and 'omitted' in typ: hits.append('P5 omitted-in-earlier')
            for h in hits:
                c[h]+=1; lawsby[h].add(law); ex.setdefault(h,f'{law} {ap!r} {typ!r}')
for h,v in c.most_common(): print(f'{h}: {v} effects, {len(lawsby[h])} laws; e.g. {ex[h]}')
