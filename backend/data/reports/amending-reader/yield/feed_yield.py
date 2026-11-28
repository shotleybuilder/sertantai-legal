"""Amending-law reader: yield (2026-11-27). Every legislation.gov.uk text
change on a held law's body (not its Schedules, which have no rows), matched
against a fresh reading of every amending law by the reader's own pointers
(dump_pointers.exs). Classes per scope (round + switched families / every
family); "not located" by pointer form; "read, no rule" by the provision's
opening words. Run from backend/:
    /usr/bin/python3 data/reports/amending-reader/yield/feed_yield.py POINTERS.jsonl FRESH.jsonl OUT.txt [--examples EX.txt]
"""
import json, re, sys, gzip, os, subprocess, collections

PSQL = '/home/linuxbrew/.linuxbrew/opt/libpq/bin/psql'
IN = ('WASTE', 'WATER & WASTEWATER', 'CLIMATE CHANGE', 'ENVIRONMENTAL PROTECTION',
      'OH&S: Occupational', 'Maritime Safety', 'FIRE')


def q(sql):
    o = subprocess.run([PSQL, '-h', 'localhost', '-p', '5436', '-U', 'postgres', '-d', 'sertantai_legal_dev',
                        '-AtF', '\t', '-c', sql], capture_output=True, text=True,
                       env={'PGPASSWORD': 'postgres', 'PATH': '/usr/bin:/bin'})
    if o.returncode:
        sys.exit(o.stderr)
    return [l.split('\t') for l in o.stdout.splitlines() if l]


FAM = {n: f for n, f in q("select name, coalesce(family,'') from legal_register")}


def scope(law):
    return 'round' if any(x in FAM.get(law, '') for x in IN) else 'other'


pointers_f, fresh_f, out_f = sys.argv[1:4]
ex_f = sys.argv[sys.argv.index('--examples') + 1] if '--examples' in sys.argv else None

FRESH = {}
for line in open(fresh_f):
    d = json.loads(line)
    rules = collections.defaultdict(set)
    for amends, ref, _targets, _op in d['rules'] or []:
        rules[amends].add(ref or '')
    FRESH[d['law']] = (rules, set(d['ids'] or []) if d['ids'] is not None else None)


EARLIER = re.compile(r'\bby (?:virtue of )?(?:S\.I\.|S\.S\.I\.|S\.R\.|W\.S\.I\.|\d{4} c\.)|\(as (?:substituted|inserted|amended)\)', re.I)
MODIFY = re.compile(r'\b(?:is|are) to (?:be read|have effect) as if\b|\bhave effect subject to the modifications\b|\bshall have effect as if\b', re.I)


def sch_file(law):
    _, t, y, n = law.split('_', 3)
    return os.path.exists(f'data/cache/clml/{t}/{y}/{n}/schedules/data.xml.gz')


def under(ref, i):
    return ref == i or ref.startswith(i + '-') or i.startswith(ref + '-')


TEXTS = {}


def text_of(law, i, headings=True):
    if law not in TEXTS:
        TEXTS.clear()  # one law at a time: the dump is grouped by amending law
        _, t, y, n = law.split('_', 3)
        x = ''
        for p in ('body', 'schedules'):
            f = f'data/cache/clml/{t}/{y}/{n}/{p}/data.xml.gz'
            if os.path.exists(f):
                x += gzip.open(f, 'rt').read()
        TEXTS[law] = x
    x = TEXTS[law]
    m = re.search(r'<(\w+)\b[^>]*\bid="' + re.escape(i) + r'"[^>]*>', x)
    if not m:
        return ''
    tag, depth, pos, t = m.group(1), 1, m.end(), None
    for t in re.finditer(r'<(/?)' + tag + r'\b[^>]*?(/?)>', x[pos:pos + 200000]):
        if t.group(2):
            continue
        depth += -1 if t.group(1) else 1
        if depth == 0:
            break
    body = x[pos:pos + t.start()] if depth == 0 else x[pos:pos + 3000]
    body = re.sub(r'<(Commentary|Pnumber)\b.*?</\1>', ' ', body, flags=re.S)
    if not headings:  # a Schedule's number, title and reference are no amending words
        body = re.sub(r'<(Number|Title|TitleBlock|Reference)\b.*?</\1>', ' ', body, flags=re.S)
    s = body
    s = re.sub(r'<[^>]+>', ' ', s)
    return re.sub(r'\s+', ' ', s).strip()


def form(s):
    s = re.sub(r'[“"‘][^”"’]*[”"’]', 'Q', s)
    s = re.sub(r'\([0-9A-Za-z]+\)', '()', s)
    s = re.sub(r'\b\d+[A-Z]*\b', 'N', s)
    w = s.split()[:5]
    return ' '.join(w).lower()


def kind(ap):
    a = ap.lower()
    if re.search(r'cross-heading|heading|title', a):
        return 'heading'
    return 'provision'


c = collections.Counter()
laws = collections.defaultdict(set)
ex = collections.defaultdict(list)
forms = collections.defaultdict(collections.Counter)
form_laws = collections.defaultdict(set)
form_ex = collections.defaultdict(list)
NOTLOC = collections.Counter()
NOTLOC_ex = collections.defaultdict(list)

for line in open(pointers_f):
    if not line.strip():
        continue
    e = json.loads(line)
    law, src, ap = e['law'], e['amending'], e['affected'] or ''
    if re.match(r'\s*(Sch|Annex|Appendix|App\.)', ap, re.I):
        continue  # the amended law's Schedules: no rows
    if src == law:
        k = 'amends itself'
    elif e['ids'] is None:
        k = 'amending law not held'
    elif src not in FRESH or FRESH[src][1] is None:
        k = 'amending law not read'
    elif not e['refs']:
        k = 'no pointer parsed'
    elif not e['ids'] and any(r.startswith('{:schedule') for r in e['refs']) and not sch_file(src):
        k = 'Schedules not held'
    elif not e['ids']:
        k = 'pointer not located'
    else:
        rules, read = FRESH[src]
        if any(under(r, i) for r in rules.get(law, ()) for i in e['ids']):
            k = 'rule for this law'
        elif not any(i in read for i in e['ids']):
            k = 'located, not read'
        elif any(under(r, i) for a, rs in rules.items() for r in rs for i in e['ids']):
            k = 'rules for another law only'
        else:
            k = 'read, no rule'
    if k in ('read, no rule', 'located, not read', 'rules for another law only') and \
            all(re.fullmatch(r'[.\s…]*', text_of(src, i, headings=False)) for i in e['ids']):
        k = 'amending words gone'  # its own text repealed: dots in the revised text
    elif k in ('read, no rule', 'rules for another law only') and EARLIER.search(e['type'] or ''):
        k = 'amends an earlier amending law'  # by design: "… by S.I. 2019/720 (as substituted)"
    elif k in ('read, no rule', 'rules for another law only') and \
            any(MODIFY.search(text_of(src, i)) for i in e['ids']):
        k = 'a modification'  # by design: not a text change (rule 9)
    s = scope(law)
    for sc in (s, 'every'):
        c[(sc, k)] += 1
        laws[(sc, k)].add(src)
    key = (s, k)
    if len(ex[key]) < 4:
        ex[key].append(f"{src} {e['affecting']} → {law} {ap} [{e['type']}]")
    if k in ('pointer not located', 'no pointer parsed'):
        f = re.sub(r'\d+', 'N', e['affecting'] or '')
        NOTLOC[(s, k, f)] += 1
        if len(NOTLOC_ex[(s, k, f)]) < 3:
            NOTLOC_ex[(s, k, f)].append(f"{src} {e['affecting']} → {law} {ap} refs {e['refs']}")
    if k == 'read, no rule':
        i = e['ids'][0]
        fm = kind(ap) + ' | ' + form(text_of(src, i))
        forms[s][fm] += 1
        forms['every'][fm] += 1
        form_laws[(s, fm)].add(src)
        form_laws[('every', fm)].add(src)
        if len(form_ex[fm]) < 4:
            form_ex[fm].append(f"{src} {i} → {law} {ap} [{e['type']}] «{text_of(src, i)[:160]}»")

out = open(out_f, 'w')


def p(*a):
    print(*a, file=out)


ORDER = ['rule for this law', 'read, no rule', 'located, not read', 'rules for another law only', 'amending words gone', 'amends an earlier amending law', 'a modification',
         'Schedules not held', 'pointer not located', 'no pointer parsed', 'amending law not read', 'amending law not held',
         'amends itself']
for sc, name in (('round', 'Round and switched families'), ('other', 'Other families'), ('every', 'Every family')):
    tot = sum(v for (a, _), v in c.items() if a == sc)
    p(f"\n== {name}: {tot} text changes on held laws' bodies")
    for k in ORDER:
        v = c[(sc, k)]
        if v:
            p(f"  {k:28} {v:6} ({100 * v / tot:4.1f}%)  amending laws {len(laws[(sc, k)]):5}")
            for x in ex.get((sc, k), [])[:3] if sc != 'every' else []:
                p(f"       e.g. {x}")

p("\n== Not located / not parsed, by the feed's affecting-provisions form (round, then other; top 40)")
for (s, k, f), v in sorted(NOTLOC.items(), key=lambda x: (x[0][0] != 'round', -x[1]))[:80]:
    p(f"  [{s}] {k:20} {v:5}  {f[:70]}")
    for x in NOTLOC_ex[(s, k, f)][:2]:
        p(f"         {x}")

p("\n== Read, no rule: by the provision's opening words (round; changes, amending laws)")
for fm, v in forms['round'].most_common(60):
    p(f"  {v:5} {len(form_laws[('round', fm)]):4}  {fm}   (every family {forms['every'][fm]})")
p("\n== Read, no rule: by the provision's opening words (every family; top 60)")
for fm, v in forms['every'].most_common(60):
    p(f"  {v:5} {len(form_laws[('every', fm)]):4}  {fm}   (round {forms['round'][fm]})")
out.close()

if ex_f:
    with open(ex_f, 'w') as fh:
        for fm, v in forms['every'].most_common(200):
            fh.write(f"\n== {fm}: {v} changes, round {forms['round'][fm]}\n")
            for x in form_ex[fm]:
                fh.write(f"   {x}\n")
print(open(out_f).read()[:4000])
