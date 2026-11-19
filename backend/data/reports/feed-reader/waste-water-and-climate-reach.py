# Read-only reach of the parked Feed reader classes 1-4 over each scope's stored feeds
# (Waste, Water and Climate: Feed reader, 2026-11-18). Candidates by the feed's own words;
# a fix's exact reach is measured by the reader.
import sys, gzip, glob, re, collections
M='{http://www.legislation.gov.uk/namespaces/metadata}'
import xml.etree.ElementTree as ET
WORDS=re.compile(r'^(words?|sum|figure|entry|comma|semicolon|full stop|formula|number|label|definitions?)\b',re.I)
def detect(e):
    typ=(e.get('Type') or '').strip(); ap=(e.get('AffectedProvisions') or '').strip()
    aff=e.find(M+'AffectingProvisions'); afft=(e.get('AffectingProvisions') or '').strip()
    hits=[]
    rngs=0 if aff is None else len(list(aff.iter(M+'SectionRange')))
    if re.match(r'^(ss|regs|arts|paras|Schs|rr|rules)\.\s+\S+\s+\S',afft) or rngs>1 or (rngs==1 and re.search(r'-\s*\S+\s+\S',afft)):
        hits.append('1 affecting-plural-list')
    if (re.search(r'\b(Table|Form|Proviso|Notes?|footnote)\s*$',ap) and not WORDS.match(typ)) or re.match(r'title substituted',typ,re.I):
        hits.append('2 trailing-part-read-whole')
    if re.search(r'substituted for (words?|full stop|words in s)',typ,re.I):
        hits.append('3 substituted-for-left-whole')
    m=re.search(r'substituted for .*?\(([a-z]+)\)\s*-\s*\(([a-z]+)\)',typ,re.I)
    if m and (len(m.group(1))>1 or len(m.group(2))>1):
        hits.append('4 letter-range-ranked-as-text')
    return hits,ap,typ,afft
out=[]
for scope in sys.argv[1:]:
    tag=scope.split('/')[-1][:-4]
    c=collections.Counter(); laws=collections.defaultdict(set); ex={}
    for law in [l.strip() for l in open(scope) if l.strip()]:
        _,t,y,n=law.split('_',3)
        for p in sorted(glob.glob(f'data/cache/clml/changes/affected/{t}/{y}/{n}/data.feed.page-*.gz')):
            for e in ET.fromstring(gzip.open(p).read()).iter(M+'Effect'):
                hits,ap,typ,afft=detect(e)
                for h in hits:
                    c[h]+=1; laws[h].add(law); ex.setdefault(h,f'{law} {ap!r} {typ!r} by {afft!r}')
    print(f'== {tag}')
    for h in sorted(c): print(f'  {h}: {c[h]} effects, {len(laws[h])} laws; e.g. {ex[h]}')
