"""Independent mention-finder (CV-S05d).

A deliberately simple scanner that shares no code with the extent reader
(no RefList, Parts, Forms, Units): it reads a sentence into segments (the
head and each lettered item), and each segment into the law's own
provisions it names, the places it names, its verb (extend / apply /
same extent), whether it is negated and whether it is qualified.

The law's structure (which sections a Part or Chapter holds, which
paragraphs a Schedule holds) is read here from the stored CLML, again
without the reader's code.
"""

import gzip
import re
import xml.etree.ElementTree as ET
from pathlib import Path

CLML = Path("/var/home/jason/Desktop/sertantai-legal/backend/data/cache/clml")

# ---------------------------------------------------------------- structure

P1_ID = re.compile(r"^(section|regulation|article|rule)-(\w+?)$")
SCH_ID = re.compile(r"^schedule-(\w+?)(?:-part-(\w+?))?(?:-paragraph-(\w+?))?$")


class Structure:
    """Which provisions each container of a law holds, in document order."""

    def __init__(self, law):
        self.members = {}  # container id -> [ref]
        self.order = []  # top-level refs in document order
        _, t, y, n = law.split("_", 3)
        for f in sorted((CLML / t / y / n).glob("*/data.xml.gz")):
            self._read(f)

    def _read(self, f):
        stack = []
        try:
            for ev, el in ET.iterparse(gzip.open(f), events=("start", "end")):
                if ev == "start":
                    stack.append(el.get("id"))
                    i = el.get("id") or ""
                    ref = top_ref(i)
                    if ref and ref not in self.order:
                        self.order.append(ref)
                        for c in stack[:-1]:
                            if c and re.match(r"^(part|schedule)-", c):
                                self.members.setdefault(c, []).append(ref)
                else:
                    stack.pop()
                    el.clear()
        except ET.ParseError:
            pass

    def held(self, cid):
        return list(self.members.get(cid, []))

    def container_of(self, ref, kind):
        """The id of the Part ("part") or Chapter ("chapter") holding ref."""
        best = None
        for cid, refs in self.members.items():
            if ref in refs and re.fullmatch(r"part-\w+(?:-chapter-\w+)?", cid):
                is_ch = "-chapter-" in cid
                if (kind == "chapter") == is_ch:
                    best = cid
        return best

    def between(self, a, b):
        """Top-level refs from a to b inclusive, by document order."""
        if a in self.order and b in self.order:
            i, j = self.order.index(a), self.order.index(b)
            if i <= j:
                return self.order[i : j + 1]
        return None


def top_ref(i):
    m = P1_ID.match(i)
    if m:
        return ("s." if m.group(1) == "section" else "reg.") + m.group(2)
    m = SCH_ID.match(i)
    if m and not m.group(2):
        return f"sch.{m.group(1)}" + (f".para.{m.group(3)}" if m.group(3) else "")
    return None


# ------------------------------------------------------------------ words

PLACES = [
    (r"(?:the\s+)?United\s+Kingdom", {"E", "W", "S", "NI"}),
    (r"Great\s+Britain", {"E", "W", "S"}),
    (r"Northern\s+Ireland", {"NI"}),
    (r"England", {"E"}),
    (r"Wales", {"W"}),
    (r"Scotland", {"S"}),
]
PLACE_RE = re.compile("|".join(f"(?:{p})" for p, _ in PLACES))
TITLE = re.compile(
    r"(?<=\bthe\s)(?!(?:Parts?|Chapters?|Schedules?|Sections?|Regulations?|Articles?|Paragraphs?)\b)[A-Z](?:(?!\bof\s+the\b)[A-Za-z(),'’ .&-])*?\b(?:Act|Regulations|Order|Rules|Measure)(?:\s+\(Northern\s+Ireland\))?(?:\s+\d{4})?\b(?!\s+(?:extends?|appl|shall|does|do\b))"
)
VERB = re.compile(
    r"\b(?:extends?|extending|appl(?:y|ies)|ha(?:s|ve)\s+effect|ha(?:s|ve)\s+the\s+same\s+extent|same\s+extent)\b",
    re.I,
)
NEG = re.compile(r"\b(?:do(?:es)?|shall|will|is|are)\s+not\s+(?:\w+\s+)?(?:extend|apply|so\s+extend)", re.I)
SAME = re.compile(r"\bsame\s+extent\b", re.I)
QUAL = re.compile(r"\b(?:so\s+far\s+as|in\s+so\s+far|insofar|to\s+the\s+extent\s+that|so\s+much\s+of|as\s+relates?\s+to)\b", re.I)
EXCEPT = re.compile(r"\b(?:except|excluding|other\s+than|apart\s+from|with\s+the\s+exception\s+of)\b", re.I)
WHOLE = re.compile(r"\b(?:this\s+(?:Act|Order|instrument)|these\s+Regulations|these\s+Rules|they|it)\b", re.I)


def place_code(text):
    """The places a text names, as a code ("E+W+S"), or None."""
    t = TITLE.sub("TITLE", text)
    found = set()
    for m in PLACE_RE.finditer(t):
        for p, code in PLACES:
            if re.fullmatch(p, m.group(0)):
                found |= code
                break
    if not found:
        return None
    return "+".join(c for c in ["E", "W", "S", "NI"] if c in found)


# -------------------------------------------------------------- mentions

KW = r"(?:sections?|subsections?|regulations?|articles?|rules?|sub-paragraphs?|paragraphs?|Parts?|Chapters?|Schedules?)"
NUM = r"(?:\d+[A-Z]*(?:\d+[A-Z]*)?|[IVXL]+\b)"
SUB = r"\((?:[a-z]{1,4}|\d+[A-Z]*)\)"
ITEM = rf"(?:{NUM}(?:\s?{SUB})*|{SUB}(?:{SUB})*)"
SEP = r"(?:\s*,\s*(?:and\s+|or\s+)?|\s+and\s+|\s+or\s+|\s+to\s+|\s*[-–]\s*(?=\d))"
GROUP = re.compile(rf"\b({KW})\s+({ITEM}(?:{SEP}{ITEM})*)", re.I)
SELF = re.compile(r"\bthis\s+(section|regulation|article|rule|Part|Chapter|Schedule|paragraph)\b", re.I)
FOREIGN = re.compile(
    r"^\s*(?:\([^()]*\)\s*)?(?:,\s*)?(?:of|to|in|under)\s+(?:the\s+(?:Schedule\s+to\s+the\s+)?(?:Ztitle\s+Act|\d{4}\s+(?:Act|Regulations|Order)|principal\s+(?:Act|Regulations|Order)|[A-Z][\w ]*?\b(?:Code|Convention|Treaty)\b)|that\s+(?:Act|Order)|those\s+Regulations|Regulation\s+\((?:EU|EC|EEC)\)|Directive)"
)
OF_SCH = re.compile(r"^\s*of\s+(?:Schedule\s+(\w+)|this\s+Schedule|the\s+Schedule)\b(?!\s+to\s+the\b)")
OF_PART = re.compile(r"^\s*of\s+(?:Part\s+(\w+)|this\s+Part)\b")
CHAIN = re.compile(rf"^\s*(?:,\s*|\s+)(?:and\s+|of\s+)?{KW}\s+{ITEM}", re.I)


def items_of(numbers):
    """ "1, 2(1), (4) and (5), 7" -> [("1",[]), ("2",["1"]), ("2",["4"]), ...]
    with ranges as ("a", [], "to", "b")."""
    toks = re.findall(rf"{ITEM}|\bto\b|-", numbers)
    out, last = [], None
    pending_range = False
    for t in toks:
        if t in ("to", "-"):
            pending_range = True
            continue
        m = re.match(rf"^({NUM})?((?:\s?{SUB})*)$", t)
        if not m:
            continue
        num, subs = m.group(1), re.findall(r"\((\w+)\)", m.group(2) or "")
        if num is None:
            if last is None:
                num = ""
            else:
                # a continuation: (4) after 2(1) is 2(4); (b) after 18(8)(b)?
                num = last[0]
                lv = levels(last[1])
                new = "n" if subs[0].isdigit() else ("r" if re.fullmatch(r"[ivx]+", subs[0]) and "r" in lv else "a")
                idx = next((k for k, x in enumerate(lv) if x == new), len(lv))
                subs = last[1][:idx] + subs
        cur = (num, subs)
        if pending_range and out:
            out[-1] = ("range", out[-1], cur)
            pending_range = False
        else:
            out.append(cur)
        last = cur
    return out


def levels(subs):
    """Each sub's level: n (number), a (letter), r (roman after a letter)."""
    out = []
    for x in subs:
        if x.isdigit():
            out.append("n")
        elif re.fullmatch(r"[ivx]+", x) and "a" in out:
            out.append("r")
        else:
            out.append("a")
    return out


def mentions(seg, own, law_type, st, sch_lead=None):
    """The law's own provisions a segment names: a list of
    (refs:set, text, foreign:bool, excepted:bool, qualified:bool)."""
    seg = TITLE.sub("Ztitle Act", seg)
    seg = re.sub(r"“[^”]*”", "Q", seg)
    top = own.split("(")[0]
    sch_of_own = re.match(r"^(sch\.\w+)", own)
    res = []
    def excepted_at(pos):
        # within a bracket opened by an exception word, or after an
        # unbracketed one with no ";" (or next item) between
        depth, opener = 0, []
        for i, ch in enumerate(seg[:pos]):
            if ch == "(":
                opener.append(bool(re.match(r"\(\s*(?:except|excluding|other\s+than|apart\s+from|but\s+not)\b", seg[i:], re.I)))
            elif ch == ")" and opener:
                opener.pop()
        if any(opener):
            return True
        tail = seg[:pos]
        # unbracketed, outside any bracket
        flat, prev = tail, None
        while flat != prev:
            prev, flat = flat, re.sub(r"\([^()]*\)", lambda m: " " * len(m.group(0)), flat)
        flat = re.sub(r"\([^()]*$", lambda m: " " * len(m.group(0)), flat)
        e = None
        for e in EXCEPT.finditer(flat):
            pass
        return (e is not None and ";" not in flat[e.end():]
                and not re.search(r"\b(?:but\s+)?including\b", flat[e.end():], re.I)
                and not re.search(r"\bsee\b", flat[e.start() - 10 : e.start()]))

    def seen(pos):
        # inside a describing bracket ("(which inserts …)", "(Part 7:
        # consequential …)"), never one that adds provisions ("(and
        # Schedule 1)", "(except …)", "(together with this section)")
        opener = []
        for i, ch in enumerate(seg[:pos]):
            if ch == "(":
                opener.append(i)
            elif ch == ")" and opener:
                opener.pop()
        for i in opener:
            if not re.match(r"\(\s*(?:and|with|including|together\s+with|except|excluding|other\s+than|apart\s+from|but\s+not|so\s+far|in\s+so\s+far|insofar)\b", seg[i:], re.I):
                return True
        # a reference, not a subject: "subject to …", "(but) see …",
        # "under regulation 4(1)", "the entry in Schedule 2"
        clause = re.split(r"[,;—–]", seg[:pos])[-1]
        return re.search(
            r"\b(?:see(?:\s+also)?|subject\s+to|in\s+relation\s+to|(?:as\s+)?described\s+in|modified\s+by|required\s+by|(?:as\s+)?provided\s+(?:by|in|for\s+in)|under|by\s+virtue\s+of|in\s+accordance\s+with|mentioned\s+in|referred\s+to\s+in|specified\s+in|set\s+out\s+in|within\s+the\s+meaning\s+of|for\s+the\s+purposes\s+of|(?:entry|entries)\s+(?:\w+\s+){0,2}in)\b(?:\s+(?:any\s+)?(?:express\s+)?(?:provision\s+(?:in|of)\s+)?)?\s*(?:the\s+)?$",
            clause, re.I) is not None
    for m in GROUP.finditer(seg):
        kw = m.group(1).lower().rstrip("s")
        if kw == "sub-paragraph":
            kw = "subparagraph"
        tail = seg[m.end() :]
        # a locator: "in regulation 16, paragraphs (4) and (5)"; "in Part 10—"
        before = seg[max(0, m.start() - 4) : m.start()]
        if re.search(r"(?<!much )\bof\s+$", before + "", re.I) or re.search(r"(?<!much )\bof\s+$", seg[max(0, m.start() - 8) : m.start()]):
            continue
        if re.search(r"\bin\s+$", before, re.I) and kw in ("section", "regulation", "article", "rule") and re.match(
            r"^\s*(?:,\s*(?:sub)?(?:paragraphs?|subsections?)\s+\(|(?:\([^()]*\)\s*)?[—–])", tail, re.I
        ):
            continue
        loc = re.match(r"^\s*,\s*(?:sub)?(?:paragraphs?|subsections?)\s+", tail)
        if re.search(r"\bin\s+$", before, re.I) and kw in ("part", "chapter", "schedule") and re.match(
            r"^\s*(?:of\s+\w+\s+\w+\s*)?(?:\([^()]*\)\s*)?[,—–:]", tail
        ):
            if kw == "schedule":
                sch_lead = f"sch.{m.group(2).split()[0]}"
            continue
        foreign = False
        t2 = tail
        mo = OF_SCH.match(t2) or OF_PART.match(t2)
        if mo:
            t2 = t2[mo.end() :]
        while True:
            c = CHAIN.match(t2)
            if not c:
                break
            t2 = t2[c.end() :]
        if FOREIGN.match(t2) or FOREIGN.match(tail):
            foreign = True
        refs = set()
        if not foreign:
            refs = resolve(kw, m.group(2), tail, own, top, sch_of_own, st, sch_lead, loc, seg, m)
        qual = qualified(seg, m.start(), m.end())
        res.append(
            {
                "refs": refs,
                "text": m.group(0),
                "foreign": foreign,
                "excepted": excepted_at(m.start()),
                "qualified": qual,
                "seen": seen(m.start()),
                "kind": kw,
            }
        )
    for m in SELF.finditer(seg):
        kw = m.group(1).lower()
        if re.search(r"\b(?:of|to)\s+$", seg[max(0, m.start() - 4) : m.start()]):
            continue  # "subsections (1) … of this section": an owner
        if kw in ("section", "regulation", "article", "rule"):
            refs = {top} if not top.startswith("sch.") else set()
        elif kw == "paragraph":
            refs = {top}
        elif kw == "schedule":
            refs = {sch_of_own.group(1)} if sch_of_own else set()
        else:
            c = st.container_of(top, kw.lower())
            refs = set(st.held(c)) if c else set()
        res.append(
            {"refs": refs, "text": m.group(0), "foreign": False,
             "excepted": excepted_at(m.start()), "seen": seen(m.start()),
             "qualified": qualified(seg, m.start(), m.end()), "kind": "self"}
        )
    return res, sch_lead


Q_AFTER = re.compile(
    r"^\s*(?:\([^()]*\)\s*)?(?:above|below)?\s*(?:(?:of|to)\s+this\s+\w+\s*)?,?\s*(?:but\s+only\s+|only\s+)?(?:so\s+far\s+as|in\s+so\s+far|insofar|to\s+the\s+extent)\b",
    re.I,
)
Q_BEFORE = re.compile(r"(?:so\s+far\s+as|in\s+so\s+far\s+as|insofar\s+as|to\s+the\s+extent\s+that)\b[^;]*$", re.I)


def qualified(seg, start, end):
    """A qualifier directly after the mention, or a leading one ("In so far
    as regulations 4 … apply", "and, so far as relating to …, sections 59")."""
    if Q_AFTER.match(seg[end:]):
        return True
    before = seg[:start]
    prev = max([x.end() for x in GROUP.finditer(before)] + [0])
    gap = before[prev:]
    if not Q_BEFORE.search(gap) or re.search(r"(?:extends?|appl(?:y|ies))\b", gap, re.I):
        return False
    g = gap.rstrip()
    # "In so far as regulations 4 …", "and, so far as relating to those
    # provisions, sections 59 …": a qualified subject; "so far as relating
    # to paragraphs 81 …": the qualifier's object
    if re.search(r"(?:so\s+far\s+as|insofar\s+as|to\s+the\s+extent\s+that)$", g, re.I) or g.endswith(","):
        return True
    return "object"


def resolve(kw, numbers, tail, own, top, sch_of_own, st, sch_lead, loc, seg, m):
    pre = "s." if top.startswith("s.") else "reg."
    refs = set()
    of_sch = OF_SCH.match(tail)
    of_part = OF_PART.match(tail)
    in_sch = top.startswith("sch.")
    for it in items_of(numbers):
        rng = it[0] == "range"
        a, b = (it[1], it[2]) if rng else (it, it)
        if kw in ("section", "regulation", "article", "rule"):
            if in_sch and kw in ("regulation", "article") and False:
                pass
            if rng and not a[1] and not b[1]:
                span = st.between(pre + a[0], pre + b[0])
                refs |= set(span) if span else {f"{pre}{a[0]}..{pre}{b[0]}"}
            elif rng:
                refs |= {fmt(pre + a[0], a[1]), fmt(pre + b[0], b[1])} | sub_range(pre + a[0], a[1], b[1])
            else:
                refs.add(fmt(pre + a[0], a[1]))
        elif kw in ("subsection",) or (kw in ("paragraph",) and not in_sch and pre == "reg." and a[0] == "" and a[1] and a[1][0].isdigit()):
            # own provision's: "subsection (4)", "paragraph (2)" in an SI
            base = locator_base(seg, m) or top
            for x in ([a, b] if rng else [a]):
                refs.add(fmt(base, x[1] if a[0] == "" else [a[0]] + x[1]))
            if rng:
                refs |= sub_range(base, a[1], b[1])
        elif kw == "paragraph":
            if not a[0] or not a[0][0].isdigit():
                continue  # "(a)": the sentence's own items
            sch = (f"sch.{of_sch.group(1)}" if of_sch and of_sch.group(1) else
                   (sch_of_own.group(1) if of_sch and sch_of_own else None)) or sch_lead or (
                sch_of_own.group(1) if sch_of_own and not of_sch else None)
            if not sch:
                continue  # a paragraph of no Schedule we can tell
            if rng and not a[1] and not b[1]:
                span = st.between(f"{sch}.para.{a[0]}", f"{sch}.para.{b[0]}")
                refs |= set(span) if span else {f"{sch}.para.{a[0]}..{sch}.para.{b[0]}"}
            else:
                refs.add(fmt(f"{sch}.para.{a[0]}", a[1]))
                if rng:
                    refs.add(fmt(f"{sch}.para.{b[0]}", b[1]))
        elif kw == "subparagraph":
            if in_sch:
                refs.add(fmt(top, (a[1] if a[0] == "" else [a[0]] + a[1])))
        elif kw == "schedule":
            for x in expand_alpha(a[0], b[0] if rng else None):
                refs.add(f"sch.{x}")
        elif kw == "part":
            sch = (f"sch.{of_sch.group(1)}" if of_sch and of_sch.group(1) else None) or sch_lead or (
                sch_of_own.group(1) if in_sch else None)
            for x in expand_alpha(a[0], b[0] if rng else None):
                if sch:
                    refs.add(f"{sch}.pt.{x}")
                else:
                    refs |= set(st.held(f"part-{x}")) or {f"part-{x}"}
        elif kw == "chapter":
            part = of_part.group(1) if of_part and of_part.group(1) else None
            if of_part and not part:
                c = st.container_of(top, "part")
                part = c.split("-")[1] if c else None
            if part is None:
                c = st.container_of(top, "chapter")
                part = c.split("-")[1] if c else None
            for x in expand_alpha(a[0], b[0] if rng else None):
                refs |= set(st.held(f"part-{part}-chapter-{x}")) or {f"part-{part}-chapter-{x}"}
    return refs


def locator_base(seg, m):
    """ "in regulation 16, paragraphs (4) and (5)" -> "reg.16"."""
    lead = seg[: m.start()]
    x = re.search(r"\bin\s+(section|regulation|article|rule)\s+(\d+[A-Z]*)\s*(?:,\s*$|(?:\([^()]*\)\s*)?[—–][^;]*?$)", lead, re.I)
    if x:
        return ("s." if x.group(1).lower() == "section" else "reg.") + x.group(2)
    return None


def fmt(base, subs):
    return base + "".join(f"({s})" for s in subs)


def sub_range(base, sa, sb):
    """ "(4) to (6)": the numbered ones between."""
    if len(sa) == 1 and len(sb) == 1 and sa[0].isdigit() and sb[0].isdigit():
        return {fmt(base, [str(i)]) for i in range(int(sa[0]), int(sb[0]) + 1)}
    return set()


ROMAN = {"I": 1, "V": 5, "X": 10, "L": 50, "C": 100}


def roman(s):
    v = 0
    for i, ch in enumerate(s):
        x = ROMAN[ch]
        v += -x if i + 1 < len(s) and ROMAN[s[i + 1]] > x else x
    return v


def to_roman(n):
    out = ""
    for v, r in [(50, "L"), (40, "XL"), (10, "X"), (9, "IX"), (5, "V"), (4, "IV"), (1, "I")]:
        while n >= v:
            out += r
            n -= v
    return out


def expand_alpha(a, b):
    if b is None:
        return [a]
    if a.isdigit() and b.isdigit():
        return [str(i) for i in range(int(a), int(b) + 1)]
    if re.fullmatch(r"[IVXL]+", a) and re.fullmatch(r"[IVXL]+", b):
        return [to_roman(i) for i in range(roman(a), roman(b) + 1)]
    return [a, b]


# --------------------------------------------------------------- segments

LABEL = re.compile(
    r"(?:(?<=[—–:;,])|(?<=;\s)|(?<=\band)|(?<=\bor)|(?<=,\s)|(?<=—\s))\s*\(?((?:[a-h]|z?[a-z])|[ivx]{1,4})\)?\s+(?=[A-Z(]|the\b|this\b|in\b|any\b|an\b|so\b|sections?\b|paragraphs?\b|regulations?\b|articles?\b|subsections?\b|Parts?\b|Schedules?\b|Chapters?\b)"
)
SAVE = re.compile(r"[;,]?\s*but\s+(?:,\s*)?save\s+as\s+(?:aforesaid|otherwise\s+provided)\b.*$", re.I)


def segments(s):
    """The head and each lettered item, each with its own verb and places
    or, where it states none, its head's."""
    out = []
    s = re.sub(r"“[^”]*”|\"[^\"]*\"", "Q", s)
    s = re.sub(r"(?:\s*\.\s*){3,}", " ", s)  # repealed words (". . .")
    s = re.split(r"\.(?=[A-Z])", s, maxsplit=1)[0]
    save = SAVE.search(s)
    body = s[: save.start()] if save else s
    cuts = [m for m in LABEL.finditer(body) if is_label(body, m)]
    pieces, labels, at = [], [None], 0
    for c in cuts:
        pieces.append(body[at : c.start()])
        labels.append(c.group(1))
        at = c.end()
    pieces.append(body[at:])
    # an item leading a sub-list ("d subsections (4) and (5) … so far as
    # they relate to— i …; ii …; iii …, extend to Northern Ireland"): its
    # verb is in its last sub-item, one statement
    merged, k = [], 0
    while k < len(pieces):
        p = pieces[k]
        if k > 0 and not VERB.search(p) and re.search(r"[—–]\s*$", p):
            j = k + 1
            while j < len(pieces) and re.fullmatch(r"[ivx]{1,4}", labels[j] or ""):
                p += " " + pieces[j]
                j += 1
            merged.append(p)
            k = j
        else:
            merged.append(p)
            k += 1
    split = []
    for p in merged:
        bits = re.split(r"\s*[;,]?\s*\bbut\b,?\s*(?=.*\b(?:extends?|appl(?:y|ies))\b)", p, maxsplit=1)
        if len(bits) == 2 and VERB.search(unrelative(bits[0])) and place_code(bits[1]) and VERB.search(unrelative(bits[1])):
            split += bits
            labels_extra = True
        else:
            split.append(p)
    pieces = merged if len(split) == len(merged) else split
    head = pieces[0]
    for i, p in enumerate(pieces):
        out.append({"text": p, "item": i > 0})
    if save:
        out.append({"text": save.group(0), "item": False, "save": True})
    # "They apply in relation to— (a) England …, and (b) Wales": the items
    # are the head's places, one statement
    hv = VERB.search(unrelative(head))
    if hv and not SAME.search(head) and not after_verb_places(head) and len(out) > 1 and not any(VERB.search(o["text"]) for o in out[1:]):
        whole = {"text": s, "item": False, "verb": True, "neg": NEG.search(head) is not None,
                 "same": SAME.search(head) is not None, "places": place_code(" ".join(o["text"] for o in out[1:]))}
        return [whole]
    parent = None
    for o in out:
        o["verb"] = VERB.search(unrelative(o["text"])) is not None
        o["neg"] = NEG.search(first_clause(o["text"])) is not None
        o["same"] = SAME.search(o["text"]) is not None
        o["places"] = after_verb_places(o["text"])
        # an item's sub-items take its statement ("a the following
        # provisions extend to England and Wales— i …; ii …"), else the head's
        src = parent["text"] if parent else (head if hv else None)
        if o["item"] and src and (not o["verb"] or (not o["places"] and not o["same"])):
            o["verb"], o["neg"], o["same"] = True, NEG.search(src) is not None, SAME.search(src) is not None
            o["places"] = after_verb_places(src)
            o["inherited"] = True
        elif o["item"] and o["verb"] and (o["places"] or o["same"]) and re.search(r"[—–]\s*$", o["text"]):
            parent = o
        elif o["item"] and o["verb"]:
            parent = None
    return out


RELATIVE = re.compile(r"\b(?:which|who)\b[^,;—–]{0,60}?\b(?:extends?|extending|appl(?:y|ies)|ha(?:s|ve)\s+effect)\b|\b(?:that|as)\s+(?:\w+\s+){0,2}?(?:extends?|extending|appl(?:y|ies)|ha(?:s|ve)\s+effect)\b|\bextending\s+to\b|\bto\s+(?:continue\s+to\s+)?(?:have\s+effect|extend|apply)\b", re.I)


def unrelative(text):
    """ "an enactment which extends to Scotland": no statement's verb."""
    return RELATIVE.sub(" ", text)


def first_clause(text):
    text = re.sub(r"^\s*[;,]?\s*but\b", "", text)
    return re.split(r"[;,]?\s*\bbut\b|,\s*(?:save|except|subject)\b", text)[0]


def is_label(body, m):
    lab = m.group(1)
    pre = body[: m.start()].rstrip()
    # a label follows a dash, a semicolon, a comma (before a, b), "and"/"or"
    if not pre:
        return False
    if pre[-1] in "—–:;":
        return True
    if re.search(r"(?:\band|\bor)$", pre) and len(lab) <= 4:
        return lab in "abcdefghijklmnopqrstuvwxyz" or re.fullmatch(r"[ivx]{1,4}", lab) is not None
    if pre[-1] == "," and len(lab) == 1 and lab not in "ai":
        return True
    return False


def after_verb_places(text):
    v = VERB.search(text)
    t = text[v.end() :] if v else text
    t = re.split(r"\bbut\b|;", t)[0] if v else t
    return place_code(t) or (place_code(text) if not v else None)
