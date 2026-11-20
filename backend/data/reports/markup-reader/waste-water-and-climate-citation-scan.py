# Scan of the stored bodies for notes whose amending Citation is read
# wrongly (Markup reader fix 12, note-citation-not-amending). Reads only.
# For each Commentary under a change element: today's pick (first linked
# Citation outside a date-opening bracket), the rule's pick (first linked
# Citation after the first "by" outside brackets, before any ";" closing another law's pieces and
# outside any bracket but the instrument's own number bracket; unsettled
# where the "by" has Citations after it and none qualifies; the first
# Citation in an "(as inserted/substituted/added by" bracket after the
# "by" before either), and the feed's affecting law
# where the note or its change carries an effect id.
# Usage (from backend/): /usr/bin/python3 THIS OUT_TSV
import gzip, glob, re, sys, os, collections
import xml.etree.ElementTree as ET

OUT = sys.argv[1]
BAL = re.compile(r'\([^()]*\)')
DATE = re.compile(r'\(\s*\d{1,2}\.\s*\d{1,2}\.\s*\d{4}[^()]*$')
NUMBER = re.compile(r'^(?:[^(;]|\((?=\s*[A-Z]))*\(\s*(?:[A-Z][A-Z.\s]{0,10}|c\.|asp|anaw|asc|nia|mwa|No\.)?\s*$')
REMADE = re.compile(r'^([^(]*)\(as\s+(?:inserted|substituted|added)\b[^()]*\bby\b[^()]*(?:\(\s*(?:[A-Z][A-Z.\s]{0,10}|c\.|asp|anaw|asc|nia|mwa|No\.)?\s*)?$')
BY = re.compile(r'\bby\b', re.I)
KEY = re.compile(r'key-[0-9a-f]{32}')
CHANGE = {'Addition', 'Repeal', 'Substitution'}

def local(tag): return tag.rsplit('}', 1)[-1] if isinstance(tag, str) else ''

def unclosed(t):
    while True:
        s = BAL.sub('', t)
        if s == t: return t
        t = s

def walk(el, state):
    # state: [text, cited]
    if local(el.tag) == 'Citation':
        before = state[0]
        state[0] += ''.join(el.itertext())
        if el.get('URI'): state[1].append((el, before))
    else:
        state[0] += el.text or ''
        for ch in el:
            walk(ch, state)
            state[0] += ch.tail or ''
    return state

def law_of(uri):
    m = re.search(r'/id/([a-z]+)/(\d{4})/(\d+)', uri or '')
    return '_'.join(m.groups()) if m else None

def today(cited):
    for el, before in cited:
        if not DATE.search(unclosed(before)): return el
    return cited[0][0] if cited else None

def by_end(text):
    for m in BY.finditer(text):
        if '(' not in unclosed(text[:m.start()]): return m.end()
    return None

def own(between):
    u = unclosed(between)
    return not re.search(r'\d[^;]*;', u) and ('(' not in u or bool(NUMBER.match(u)))

def rule(text, cited):
    at = by_end(text)
    governed = [(el, before[at:]) for el, before in cited if at is not None and len(before) >= at]
    if not governed: return today(cited), ('no-by' if at is None else 'by-governs-none')
    for i, (el, between) in enumerate(governed):
        m = REMADE.match(unclosed(between))
        if m and not re.search(r'\d[^;]*;', m.group(1)):
            if len({e.get('URI') for e, _ in governed[:i]}) <= 1: return el, 'remade'
            break
    for el, between in governed:
        if own(between): return el, 'by'
    return None, 'unsettled'

def shape(text, cited, t_el):
    before = next(b for e, b in cited if e is t_el)
    u = unclosed(before)
    at = by_end(text)
    if '(' in u and not NUMBER.match(u[max(at or 0, 0):] if False else u):
        return 'nested-in-date-bracket' if DATE.search(u[:u.rfind('(')] + '(' ) or re.search(r'\(\s*\d{1,2}\.\s*\d{1,2}\.\s*\d{4}', u) else 'bracket-not-date-opening'
    if at is not None and len(before) < at: return 'before-by'
    if at is None: return 'no-by'
    return 'ok'

def refs(el, inside, out):
    t = local(el.tag)
    inside = inside or t in CHANGE
    if t in CHANGE:
        if el.get('CommentaryRef'): out[el.get('CommentaryRef')].add(el.get('ChangeId') or '')
        inside = el.get('ChangeId') or True
    if t == 'CommentaryRef' and inside and el.get('Ref'):
        out[el.get('Ref')].add(inside if isinstance(inside, str) else '')
    for ch in el: refs(ch, inside, out)

def feed(path):
    eff = {}
    for f in glob.glob(path + '/data.feed.page-*.gz'):
        x = gzip.open(f, 'rt', encoding='utf8').read()
        for m in re.finditer(r'<ukm:Effect [^>]*>', x):
            a = m.group(0)
            i = re.search(r'EffectId="([^"]+)"', a); u = re.search(r'AffectingURI="([^"]+)"', a)
            if i and u: eff[i.group(1)] = law_of(u.group(1))
    return eff

tot = collections.Counter(); laws = collections.defaultdict(set)
with open(OUT, 'w', encoding='utf8') as io:
    io.write('law\tnote\tshape\thow\ttoday\trule\tfeed\ttext\n')
    for path in sorted(glob.glob('data/cache/clml/*/*/*/body/data.xml.gz')):
        p = path.split('/'); law = 'UK_%s_%s_%s' % (p[3], p[4], p[5])
        try: root = ET.parse(gzip.open(path)).getroot()
        except Exception: tot['unparsed'] += 1; continue
        used = collections.defaultdict(set); refs(root, False, used)
        eff = None
        for c in root.iter():
            if local(c.tag) != 'Commentary' or c.get('id') not in used: continue
            text, cited = walk(c, ['', []])
            if not cited: continue
            tot['notes'] += 1
            t_el = today(cited); r_el, how = rule(text, cited)
            sh = shape(text, cited, t_el)
            tl, rl = law_of(t_el.get('URI')), (law_of(r_el.get('URI')) if r_el is not None else None)
            keys = set(KEY.findall(c.get('id'))) | {k for ch in used[c.get('id')] for k in KEY.findall(ch)}
            fl = None
            if keys:
                if eff is None: eff = feed('data/cache/clml/changes/affected/%s/%s/%s' % (p[3], p[4], p[5]))
                fls = {eff[k] for k in keys if k in eff}
                fl = '|'.join(sorted(x for x in fls if x)) if fls else None
            if fl:
                tot['feed'] += 1
                tot['feed-agree-today'] += tl in fl.split('|'); tot['feed-agree-rule'] += (rl in fl.split('|')) if rl else 0
                tot['feed-rule-unknown'] += rl is None
            if how == 'remade':
                tot['remade notes'] += 1
                if fl: tot['remade feed'] += 1; tot['remade feed-agree-today'] += tl in fl.split('|'); tot['remade feed-agree-rule'] += rl in fl.split('|')
                sh = 'remade'
            if sh == 'ok' and tl == rl: continue
            if t_el is r_el: tot['same pick, ' + sh] += 1; continue
            moved = 'unsettled' if r_el is None else 'moved'
            tot[sh + ' ' + moved] += 1; laws[sh + ' ' + moved].add(law)
            if fl:
                tot[sh + ' ' + moved + ' feed'] += 1
                tot[sh + ' ' + moved + ' feed-agree-today'] += tl in fl.split('|')
                tot[sh + ' ' + moved + ' feed-agree-rule'] += (rl in fl.split('|')) if rl else 0
            nid = KEY.sub(lambda m: m.group(0)[:12], c.get('id'))
            io.write('\t'.join([law, nid, sh + ' ' + moved, how, str(tl), str(rl), str(fl), ' '.join(text.split())[:420]]) + '\n')
    io.write('\nTOTALS\n')
    for k in sorted(tot): io.write('%s\t%d\t%s\n' % (k, tot[k], ('laws %d' % len(laws[k])) if k in laws else ''))
for k in sorted(tot): print(k, tot[k], len(laws[k]) if k in laws else '')
