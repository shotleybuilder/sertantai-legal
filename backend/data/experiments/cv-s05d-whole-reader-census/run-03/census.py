"""Whole-reader census (CV-S05d): every catalogue and sweep sentence of
every held law checked against the stored reading by the independent
mention-finder (`finder.py`).

Per statement segment (a head or lettered item with an extend/apply verb
and a place, or "same extent"), each own provision it names:
  ok           stored in a row of the segment's place (or same / not)
  withheld     stored in an unread row
  broader      only an ancestor stored (s.34 for s.34(f)): a wrong bound
  place        stored only in rows of other places
  missing      in no row at all
  q_read       qualified, yet read in a row of the place (KX/KQ known)
  q_missing    qualified, and in no row (should be withheld)
  exc_held     named as excepted, yet stored in the place's positive row
A whole-law statement ("this Act extends to …", "They apply in relation
to …") is checked against the stored default or application.
Per law, each positive stored ref that no statement of its place names
is `unnamed` (over-reach).

usage: census.py all.jsonl OUTDIR
"""

import collections
import json
import re
import sys

import finder as F

POSITIVE = {"only", "named", "also", "not", "same", "applies", "applies_not"}
APPLY = re.compile(r"\bappl(?:y|ies)\b", re.I)
WHOLE_SUBJ = re.compile(
    r"^\s*(?:(?:Subject\s+to|Except\s+as|Save\s+as|Without\s+prejudice\s+to|With\s+the\s+exception\s+of)\b[^,]*,\s*|(?:[;,]?\s*but\s+)?(?:,\s*)?save\s+as\s+(?:aforesaid|otherwise\s+provided)\s*,?\s*|In\s+this\s+\w+\s*[—–]\s*)?(?:this\s+(?:Act|Order|instrument)|these\s+(?:Regulations|Rules)|they|it)\b(?:\s*,[^,]*,)?\s+(?:\w+\s+){0,3}?(?P<verb>extends?|appl(?:y|ies)|shall|does|do|is|are|also)\b",
    re.I,
)
NOT_STATEMENT = re.compile(r"^\s*(?:If|Where|When)\b|\bwith\s+the\s+following\s+modifications\b|\bconsult\b|\bas\s+if\b|\bmeans\b|\bmay\s+by\b|\bmay\s+(?:make|provide)\b|\bpower\b|\bOrder\s+in\s+Council\b", re.I)


# "This Act, except— (a) …, does not extend to NI"; "Except for the
# following provisions …— … this Act does not extend to NI"; "This Act does
# not extend to Scotland, with the exception of— …": the items extend there
EXC_LIST = re.compile(
    r"^\s*(?:(?:This|These)\s+\w+\s*,\s*(?:except|apart\s+from)\b(?=.*?(?P<tail>(?:does|do|shall)\s+not\s+extend\b))|Except\s+for\b(?=.*?(?P<tail2>(?:does|do|shall)\s+not\s+extend\b))|(?:This|These)\s+\w+\s+(?:does|do|shall)\s+not\s+extend\s+to\s+[^,—–]+?,?\s+(?:with\s+the\s+exception\s+of|except)\b)",
    re.I | re.S,
)
EXT_EXC = re.compile(r"^\s*(?:This|These)\s+\w+\s+(?:shall\s+)?extends?\s+to\s+(?P<places>[^—–]+?)\s+with\s+the\s+exception\s+of\s*[—–:]", re.I)
LEAD = re.compile(r"^\s*(?:Subject\s+to|Except\s+as\s+(?:provided|otherwise|mentioned|specified|stated)|Without\s+prejudice\s+to|Save\s+as)\b[^,—–]*,")


def expand(ref, st):
    m = re.fullmatch(r"(.+)\.\.(.+)", ref)
    if m:
        span = st.between(m.group(1), m.group(2))
        if span:
            i = st.order.index(span[-1]) + 1
            while i < len(st.order) and re.fullmatch(re.escape(m.group(2)) + r"\d+[A-Z]*", st.order[i]):
                span.append(st.order[i])
                i += 1
            return span
    return [ref]


def ancestors(r):
    out = []
    while "(" in r:
        r = r[: r.rindex("(")]
        out.append(r)
    m = re.match(r"^(sch\.[^.]+)\.(?:para|pt)\.", r)
    if m:
        out.append(m.group(1))
    return out


class Stored:
    def __init__(self, d, st):
        self.rows = []
        for r in d["lists"] + d["applies"]:
            refs = set()
            for x in r["refs"]:
                refs |= set(expand(x, st))
            self.rows.append((r["kind"], r["place"], refs))
        self.default = d["default"]
        self.application = d["application"]

    def where(self, ref):
        exact = [(k, p) for k, p, refs in self.rows if ref in refs or "*" in refs and k == "same"]
        cover = [(k, p) for k, p, refs in self.rows for a in ancestors(ref) if a in refs]
        return exact, cover


def place_ok(kind, place, seg):
    if seg["same"]:
        return kind == "same"
    if seg["neg"]:
        return kind in ("not", "applies_not", "unread") and place == seg["places"]
    return kind not in ("not", "applies_not", "same", "except", "unread") and place == seg["places"]


def judge(ref, men, seg, stored):
    exact, cover = stored.where(ref)
    if men["excepted"]:
        if any(place_ok(k, p, seg) for k, p in exact) and not seg["neg"]:
            return "exc_held"
        return "ok"
    if any(k == "unread" for k, _ in exact + cover):
        return "withheld"
    good = [x for x in exact if place_ok(*x, seg)]
    if men["qualified"]:
        return "q_read" if good else ("q_missing" if not exact and not cover else "ok")
    if good:
        return "ok"
    if (not seg["neg"] and not seg["same"] and seg["places"] == stored.default
            and not any(k in ("only", "named", "also") for k, _ in exact)):
        return "ok"
    if any(place_ok(k, p, seg) for k, p in cover):
        return "broader?"
    if exact or cover:
        return "place"
    return "missing"


def whole(seg, stored):
    """A whole-law statement against the stored default / application: the
    places of its own clause (after the subject; never a "which shall
    apply to …" aside), extend and apply parts each against their own."""
    if seg["same"]:
        return None
    text = re.sub(r"\bwhich\s+(?:shall\s+)?(?:extends?|appl(?:y|ies))\b[^,]*,", " ", seg["text"])
    m = WHOLE_SUBJ.search(text)
    main = text[m.end() - len(m.group("verb")):] if m else text
    parts = re.split(r"\band\s+(?:shall\s+|does\s+|do\s+)?(?=(?:not\s+|only\s+)?appl(?:y|ies)\b)", main, maxsplit=1)
    out = []
    for k, part in enumerate(parts):
        places = F.place_code(F.first_clause(part))
        if not places:
            continue
        apply = (k == 1) or (APPLY.search(part) is not None and not re.search(r"\bextends?\b", part))
        neg = F.NEG.search(F.first_clause(part)) is not None
        held = stored.application if apply else stored.default
        if held is None:
            out.append("whole_missing")
            continue
        hs, ss = set(held.split("+")), set(places.split("+"))
        if neg:
            out.append("ok" if not (hs & ss) else "whole_mismatch")
        elif re.search(r"\balso\b", part, re.I):
            out.append("ok")
        else:
            out.append("ok" if hs == ss or (ss <= hs and not re.search(r"\bonly\b", part, re.I)) else "whole_mismatch")
    bad = [v for v in out if v != "ok"]
    return bad[0] if bad else ("ok" if out else None)


PLACE_WORDS = r"(?:England|Wales|Scotland|Northern\s+Ireland|Great\s+Britain|(?:the\s+)?United\s+Kingdom)"
DIRECT = re.compile(
    rf"^\s*(?:only\s+)?(?:(?:to\s+and\s+)?(?:in\s+relation\s+to|to|in|as\s+respects|within)\s*)?(?:only\s+)?(?:[—–:]\s*\(?[a-z]\)?\s*)?(?:the\s+whole\s+of\s+)?(?:the\s+sea\s+adjacent\s+to\s+)?(?:the\s+)?{PLACE_WORDS}\b(?!\s+(?:ships?|vessels?|fishing|aeroplanes?|aircraft|licen[cs]es?|nationals?|citizens?|companies|registered)\b)",
    re.I,
)
# a carve-out of things, not provisions ("other than an excepted energy
# building"; never "except for paragraph 1 of Schedule 3", "except as provided")
THING_CARVE = re.compile(
    r"\b(?:other\s+than|except|excluding|apart\s+from)\b(?!\s*(?:for\s+)?(?:as\b|this\b|that\b|in\s|where\b|so\b|(?:the\s+)?(?:regulations?|articles?|sections?|paragraphs?|sub-paragraphs?|Parts?|Schedules?|Chapters?|rules?|subsections?|provisions?)\b))",
    re.I,
)
CARVE = re.compile(r"\b(?:other\s+than|except|excluding|apart\s+from|unless)\b", re.I)
APPLY_VERB = re.compile(r"\b(?:do(?:es)?\s+not\s+|shall\s+(?:not\s+)?|only\s+)?appl(?:y|ies)\b", re.I)


def scope_kind(seg):
    """An "apply" statement's kind (Jason 2026-10-27, skill class KA):
    "territorial" — the place is what is said ("apply in relation to
    Wales", with or without provisions excepted); "scope" — which things,
    persons or conditions, not where ("do not apply in relation to any
    building in Wales other than …", "applies if …", "apply to United
    Kingdom ships", "outside Great Britain"): fitness scope, fractalaw's;
    "both" — a place bound with a scope ("apply to lessors of social homes
    in England"). None for an extend statement."""
    if seg["same"] or re.search(r"\bextends?\b", seg["text"], re.I):
        return None
    v = APPLY_VERB.search(seg["text"])
    if not v or not seg["places"]:
        return None
    after = seg["text"][v.end():]
    if seg.get("inherited"):
        own_words = seg["text"]
        if F.place_code(own_words) and not DIRECT.match(own_words) and re.search(r"\b(?:buildings?|persons?|premises|ships?|vessels?|undertakers?|land)\b", own_words, re.I):
            return "scope"
        return "territorial"
    if re.match(r"^\s*(?:only\s+)?(?:if|where|when|unless)\b", after, re.I):
        return "scope"
    if DIRECT.match(after):
        return "scope" if THING_CARVE.search(after) else "territorial"
    if re.search(rf"\boutside\s+(?:the\s+)?{PLACE_WORDS}", after, re.I) or seg["neg"] or THING_CARVE.search(after):
        return "scope"
    if not re.search(rf"\bin\s+(?:relation\s+to\s+)?(?:the\s+)?{PLACE_WORDS}", after, re.I):
        return "scope"  # the place names no where ("United Kingdom ships")
    return "both"


def respectively(seg, own_ms, named, plain, stored, res):
    """ "Regulations 60, 61 and 62 apply in relation to Scotland, Wales and
    Northern Ireland respectively": each ref its own place."""
    refs = [r for m in own_ms for r in sorted(m["refs"], key=lambda x: [int(n) if n.isdigit() else n for n in re.findall(r"\d+|\D+", x)])]
    v = F.VERB.search(F.unrelative(seg["text"]))
    places = [F.place_code(p.group(0)) for p in F.PLACE_RE.finditer(F.TITLE.sub("T", seg["text"][v.end():] if v else ""))]
    places = [p for p in places if p]
    if len(refs) != len(places):
        return own_ms
    for r, pl in zip(refs, places):
        one = dict(seg, places=pl)
        key = ("neg" if seg["neg"] else "pos") + ":" + pl
        named[key].add(r)
        plain[key].add(r)
        res["verdicts"].append((judge(r, {"excepted": False, "qualified": False}, one, stored), r, "respectively", pl))
    return []


# "Part 1, which extends to England and Wales only": a statement about that provision
WHICH = re.compile(r"^\s*(?:\((?:[^()]|\([^()]*\))*\)\s*)?,?\s*(?:which\s+)?(?:shall\s+)?(?:extends?|appl(?:y|ies))\s+(?:only\s+)?(?:to|in(?:\s+relation\s+to)?)\b([^;.]*)", re.I)


def which_statements(seg, own, st, named, plain):
    ms, _ = F.mentions(seg["text"], own, "", st, None)
    for m in ms:
        if m["foreign"] or not m["refs"]:
            continue
        at = seg["text"].find(m["text"])
        w = WHICH.match(seg["text"][at + len(m["text"]):]) if at >= 0 else None
        pl = F.place_code(w.group(1)) if w else None
        if pl:
            named["pos:" + pl] |= m["refs"]
            plain["pos:" + pl] |= m["refs"]


def check_law(d, st):
    stored = Stored(d, st)
    found = []  # per sentence
    named = collections.defaultdict(set)  # (kindgroup, place) -> refs named
    plain = collections.defaultdict(set)  # … named unqualified
    for x in d["sentences"]:
        s, own, cls = x["s"], x["ref"], x["class"]
        lead = None
        modification = re.search(r"^\s*(?:If|Where|When)\b|\bsubject\s+to\s+the\s+modifications\b|\bcease\s+to\s+have\s+effect\b|\bas\s+if\b|\bis\s+to\s+be\s+read\b|\b(?:is|are)\s+inserted\b|\bwith\s+the\s+substitution\b|\bsubstitute\b|\bthere\s+(?:is|are|were)\s+(?:inserted|substituted)\b", s, re.I) is not None
        res = {"law": d["law"], "ref": own, "class": cls, "s": s, "verdicts": [], "scope": []}
        exc_list = EXC_LIST.search(s)
        if exc_list:
            # the list's own exception word is no exception of an item
            s = re.sub(r"^(\s*(?:This|These)\s+\w+\s*,\s*)(?:except|apart\s+from)\b", r"\1plus  ", s, count=1, flags=re.I)
            s = re.sub(r"^(\s*)Except(\s+for\b)", r"\1Plus  \2", s, count=1, flags=re.I)
            s = re.sub(r"\b(?:with\s+the\s+exception\s+of|except)(?=\s*[—–:])", lambda m: "plus".ljust(len(m.group(0))), s, count=1, flags=re.I)
            exc_list = EXC_LIST.search(x["s"])
        segs = F.segments(s)
        ext_exc = EXT_EXC.search(s)
        if ext_exc and not exc_list:
            pl = F.place_code(ext_exc.group("places"))
            for seg in segs[1:]:
                if seg["item"]:
                    seg.update(verb=True, neg=True, same=False, places=pl)
        if exc_list:
            g = "tail" if exc_list.group("tail") else ("tail2" if exc_list.group("tail2") else None)
            tail = F.place_code(F.first_clause(x["s"][exc_list.start(g):])[:80]) if g else F.place_code(exc_list.group(0))
            for seg in segs:
                if seg["item"] or seg is segs[0]:
                    seg.update(verb=True, neg=False, same=False, places=tail, exc_list=True)
        excepting = False
        foreign_head = re.search(r"\bprovisions\s+of\s+the\s+[A-Z][^—–]*?\b(?:Act|Regulations|Order)\b(?:\s+\d{4})?[^—–]*[—–]", s[:300]) is not None
        for seg in segs:
            ms, lead = F.mentions(seg["text"], own, "", st, lead)
            if foreign_head and seg["item"]:
                for m in ms:
                    m["foreign"] = True
            roman = bool(re.fullmatch(r"[ivx]{1,4}", seg.get("label") or ""))
            if seg["item"] and excepting and roman:
                for m in ms:
                    m["excepted"] = True
            if seg["item"] and not roman:
                excepting = bool(re.search(r"\bexcept\s*(?:for\s*)?[—–:]\s*$", seg["text"]))
            statement = seg["verb"] and (seg["places"] or seg["same"]) and not NOT_STATEMENT.search(F.unbracket(seg["text"])) and not modification
            if not statement:
                continue
            which_statements(seg, own, st, named, plain)
            sk = scope_kind(seg)
            if sk:
                res["scope"].append((sk, seg))
            if sk == "scope":
                res["verdicts"].append(("scope", "*", seg["text"][:60], seg["places"]))
                continue
            lead_end = LEAD.match(seg["text"]).end() if LEAD.match(seg["text"]) else 0
            own_ms = [m for m in ms if not m["foreign"] and m["refs"] and not m["seen"] and seg["text"].find(m["text"]) >= lead_end]
            again = re.search(r"\band\s+th(?:ose|at|e\s+said)\s+(?:paragraphs?|provisions?|sections?|regulations?|Schedules?)\b", seg["text"], re.I)
            own_ms = [m for m in own_ms if m["qualified"] != "object" or again]
            for m in own_ms:
                if m["qualified"] == "object":
                    m["qualified"] = False
            exc = set().union(*[m["refs"] for m in own_ms if m["excepted"]]) if own_ms else set()
            for m in own_ms:
                if not m["excepted"]:
                    m["refs"] = {r for r in m["refs"] if r not in exc and not any(a in exc for a in ancestors(r))}
            key = "same" if seg["same"] else ("neg" if seg["neg"] else "pos") + ":" + (seg["places"] or "")
            if re.search(r"\brespectively\b", seg["text"], re.I):
                own_ms = respectively(seg, own_ms, named, plain, stored, res)
            for m in own_ms:
                if not m["excepted"] and not m["qualified"]:
                    plain[key] |= m["refs"]
                if not m["excepted"]:
                    named[key] |= m["refs"]
                elif not seg["neg"]:
                    named["neg:" + (seg["places"] or "")] |= m["refs"]
                for r in sorted(m["refs"]):
                    if r.startswith("part-"):
                        continue
                    v = judge(r, m, seg, stored)
                    res["verdicts"].append((v, r, m["text"], seg["places"] or ("same" if seg["same"] else None)))
            if (not own_ms and WHOLE_SUBJ.search(seg["text"]) and not seg["item"] and not F.QUAL.search(seg["text"])) or seg.get("save"):
                v = whole(seg, stored)
                if v:
                    res["verdicts"].append((v, "*law*", seg["text"][:60], seg["places"]))
        found.append(res)
    # broader only where no statement of the place names the ancestor
    for res in found:
        vs = []
        for v, r, t, pl in res["verdicts"]:
            if v == "broader?":
                key = "same" if pl == "same" else None
                pools = [refs for k, refs in named.items() if key is None or k == key]
                v = "ok" if any(a in p for a in ancestors(r) for p in pools) else "broader"
            if v == "q_read" and any(r in p for p in plain.values()):
                v = "ok"
            vs.append((v, r, t, pl))
        res["verdicts"] = vs
    # over-reach: positive stored refs no statement of their place names
    unnamed = []
    for k, p, refs in stored.rows:
        if k not in POSITIVE or "*" in refs:
            continue
        key = "same" if k == "same" else ("neg" if k in ("not", "applies_not") else "pos") + ":" + (p or "")
        pool = named.get(key, set())
        if k in ("not", "applies_not"):
            # an exception to a positive list keeps the default: "not" the list's other places
            pool = pool | set().union(*[v for kk, v in named.items() if kk.startswith("neg:")] or [set()])
        for r in sorted(refs):
            if r in pool or any(a in pool for a in ancestors(r)):
                continue
            unnamed.append((k, p, r))
    return found, unnamed


SEVERE = ["broader", "exc_held", "missing", "q_missing", "place", "whole_missing", "whole_mismatch", "q_read", "withheld", "scope", "ok"]


def worst(vs):
    keys = {v[0] for v in vs}
    for k in SEVERE:
        if k in keys:
            return k
    return "none"


def counted(cls):
    return cls.startswith("unread") or cls.startswith("sweep:count")


def main(src, out):
    import os

    os.makedirs(out, exist_ok=True)
    rows, over = [], []
    for line in open(src):
        d = json.loads(line)
        st = F.Structure(d["law"])
        found, unnamed = check_law(d, st)
        for f in found:
            w = worst(f["verdicts"])
            f["worst"] = w
            rows.append(f)
        for k, p, r in unnamed:
            over.append((d["law"], k, p, r))
    with open(f"{out}/sentences.tsv", "w") as fh:
        fh.write("law\tref\tclass\tworst\tcounted\tflags\tsentence\n")
        for f in rows:
            flags = "; ".join(f"{v}:{r}" for v, r, _, _ in f["verdicts"] if v not in ("ok", "withheld"))
            fh.write("\t".join([f["law"], f["ref"], f["class"], f["worst"], "counted" if counted(f["class"]) else "silent", flags, f["s"]]) + "\n")
    with open(f"{out}/scope.tsv", "w") as fh:
        fh.write("law\tref\tclass\tkind\tpolarity\tplace\tcarve_out\tsentence\n")
        for f in rows:
            for sk, seg in f["scope"]:
                if sk == "territorial":
                    continue
                c = THING_CARVE.search(seg["text"]) or CARVE.search(seg["text"])
                carve = seg["text"][c.start():][:160] if c else ""
                fh.write("\t".join([f["law"], f["ref"], f["class"], sk, "does not apply" if seg["neg"] else "applies",
                                     seg["places"] or "", carve, f["s"][:800]]) + "\n")
    with open(f"{out}/unnamed.tsv", "w") as fh:
        fh.write("law\tkind\tplace\tref\n")
        for o in over:
            fh.write("\t".join(str(x) for x in o) + "\n")
    c = collections.Counter((f["worst"], "counted" if counted(f["class"]) else "silent") for f in rows)
    stats = {"sentences": len(rows), "by_worst": {f"{a}/{b}": n for (a, b), n in sorted(c.items())},
             "unnamed_refs": len(over), "unnamed_laws": len({o[0] for o in over})}
    json.dump(stats, open(f"{out}/stats.json", "w"), indent=1)
    print(json.dumps(stats, indent=1))


if __name__ == "__main__":
    main(sys.argv[1], sys.argv[2])
