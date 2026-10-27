#!/usr/bin/python3
"""CV-S05c shape mining, prototype (run-01).

Reads sentences.tsv (dump.exs: law, ref, class, sentence), splits each
sentence into its lead and its lettered items, masks every reference,
place, law title and description, and counts the resulting shapes.

usage: /usr/bin/python3 mine.py sentences.tsv OUTDIR
writes: OUTDIR/items.tsv (one row per item), OUTDIR/shapes.tsv (shapes
ranked by count, with laws, classes and examples), OUTDIR/stats.json
"""
import collections
import csv
import json
import re
import sys

# ── splitting ───────────────────────────────────────────────────────────
# lettered items as flattened from CLML: "—a the …;b …; andc …", ", butb"
MARK = re.compile(r"(?:[;—–:]\s*(?:(?:and|or|but)\s?)?|,(?=[a-z]{1,2}\s)|,?\s*\b(?:and|or|but)(?=[a-z]{1,4}\s))(z?[a-z]|[ivxl]{1,4})\s+(?=\S)")


def split(sentence):
    """The lead and the items, in order (items [] when not lettered)."""
    parts = MARK.split(sentence)
    lead, rest = parts[0], parts[1:]
    items = [(rest[i], rest[i + 1]) for i in range(0, len(rest) - 1, 2)]
    return lead, items


# ── masking ─────────────────────────────────────────────────────────────
NUM = r"(?:[\dIVXL]+[A-Z]*|\([a-zA-Z\d]+\))(?:\s*\([a-zA-Z\d]+\))*"
NUMLIST = rf"{NUM}(?:\s*(?:,|and|or|to|-|–)\s*(?:{NUM}|\([a-zA-Z\d]+\)))*"
KINDS = {
    "section": "SEC", "regulation": "REG", "article": "ART", "rule": "RULE",
    "paragraph": "PARA", "sub-paragraph": "SUBPARA", "subparagraph": "SUBPARA",
    "subsection": "SUBSEC", "part": "PART", "chapter": "CHAPTER",
    "schedule": "SCH", "article": "ART", "annex": "ANNEX", "title": "TITLE",
}
KIND_RE = r"(sub-?paragraph|subparagraph|subsection|section|regulation|article|rule|paragraph|part|chapter|schedule|annex)(s?)"
PLACE = r"(?:England and Wales|the United Kingdom|Great Britain|Northern Ireland|Scotland|England|Wales|the Isle of Man|the Channel Islands|Gibraltar)"

SUBS = [
    (re.compile(r"\.\s\.\s\.(?:\s\.)*|…"), " GAP "),
    # another law by title
    (re.compile(r"\bthe\s+(?:[A-Z][\w'’,()-]*\s+(?:of\s+|and\s+|for\s+|the\s+|to\s+|in\s+)*)+(?:Act|Order|Regulations|Rules|Measure)(?:\s+\(Northern Ireland\))?\s+\d{4}(?:\s*\(c\.\s*\d+\)|\s*\(S\.I\.\s*[\d/]+\))?"), " OTHER_LAW "),
    (re.compile(r"\bthe\s+\d{4}\s+(?:Act|Order|Regulations)\b"), " OTHER_LAW "),
    (re.compile(r"\bthis\s+(?:Act|Order|Regulations|Rules|Measure)\b"), " THIS_LAW "),
    (re.compile(r"\bthese\s+(?:Regulations|Rules)\b"), " THIS_LAW "),
    (re.compile(r"\b(this|that)\s+(Part|Chapter|section|Schedule|regulation|article|paragraph|subsection|sub-paragraph|rule)\b", re.I),
     lambda m: f" {m.group(1).upper()}_{KINDS.get(m.group(2).lower(), m.group(2).upper())} "),
    # a reference, singular or a list
    (re.compile(rf"\b{KIND_RE}\s+({NUMLIST})", re.I),
     lambda m: " " + KINDS[m.group(1).lower()] + ("S" if m.group(2) or re.search(r",|\band\b|\bor\b|\bto\b", m.group(3)) else "") + " "),
    (re.compile(r"\bthe\s+Schedule\b"), " THE_SCH "),
    (re.compile(PLACE), " PLACE "),
    (re.compile(r"\bPLACE(?:\s*(?:,|and|or)\s*PLACE)+"), " PLACES "),
    (re.compile(r"\d+"), " N "),
]


def mask(text):
    t = text
    for rx, rep in SUBS:
        t = rx.sub(rep, t)
    # a bracket left with only words is a description
    t = re.sub(r"\((?:[^()]|\([^()]*\))*\)", lambda m: m.group(0) if re.search(r"\b[A-Z_]{2,}\b", m.group(0)) and re.search(r"\b(?:other than|except|so far|and|with|including|but)\b", m.group(0)) else " (DESC) ", t)
    t = re.sub(r"\s+", " ", t).strip()
    return t.rstrip(" .;,")


KEEP = {
    "of", "and", "or", "to", "in", "other", "than", "except", "excluding", "including", "so", "far", "as",
    "insofar", "relating", "relates", "relate", "extend", "extends", "apply", "applies", "only", "not",
    "amendments", "amendment", "repeals", "repeal", "revocations", "made", "by", "same", "extent",
    "those", "that", "with", "together", "but", "it", "they", "relation", "the", "following", "provisions",
    "provision", "paragraphs", "paragraph", "sections", "section", "does", "do", "also", "save", "apart", "from", "subject", "has", "have", "effect", "this", "any",
}
TOKEN = re.compile(r"^(?:[A-Z_]{2,}S?|GAP|N|\(DESC\)|PLACES?)$")
LIST_WORDS = re.compile(r"\b(?:extends?|appl(?:y|ies)|same extent|so far as|in so far|insofar|other than|except|excluding|including)\b")


def coarse(fine):
    out = []
    for w in re.findall(r"\(DESC\)|[A-Z_]{2,}S?\b|\w+|[,;()“”\"]", fine):
        if TOKEN.match(w) or w.lower() in KEEP or w in ",;()":
            out.append(w if TOKEN.match(w) else w.lower())
        elif not out or out[-1] != "WORDS":
            out.append("WORDS")
    return re.sub(r"\s+([,;)])", r"\1", " ".join(out)).replace("( ", "(")


def listish(fine):
    """An item that names provisions or says where they extend or apply."""
    return bool(re.match(r"^(?:in\s+)?(?:THIS_|THAT_|THE_SCH|GAP|[A-Z]{2,}S?\b)", fine)) or bool(LIST_WORDS.search(fine))


# ── main ────────────────────────────────────────────────────────────────
def main(src, out):
    rows = list(csv.DictReader(open(src), delimiter="\t", quoting=csv.QUOTE_NONE))
    items = []
    for r in rows:
        lead, its = split(r["sentence"])
        kind = "lead" if its else "sentence"
        items.append((r, kind, "", lead))
        for letter, it in its:
            items.append((r, "item", letter, it))

    shapes = collections.defaultdict(lambda: {"n": 0, "laws": set(), "classes": collections.Counter(), "ex": []})
    with open(f"{out}/items.tsv", "w") as f:
        f.write("law\tref\tclass\tkind\tletter\tshape\tfine\ttext\n")
        for r, kind, letter, text in items:
            fine = mask(text)
            s = coarse(fine)
            if kind == "item" and not listish(fine):
                kind = "other_item"
            key = (kind, s)
            e = shapes[key]
            e["n"] += 1
            e["laws"].add(r["law"])
            e["classes"][r["class"]] += 1
            if len(e["ex"]) < 3 and r["law"] not in {x[0] for x in e["ex"]}:
                e["ex"].append((r["law"], r["ref"], text.strip()[:300]))
            f.write("\t".join([r["law"], r["ref"], r["class"], kind, letter, s, fine, text.strip()]) + "\n")

    ranked = sorted(shapes.items(), key=lambda kv: (-kv[1]["n"], kv[0]))
    with open(f"{out}/shapes.tsv", "w") as f:
        f.write("rank\tkind\tcount\tlaws\tclasses\tshape\texamples\n")
        for i, ((kind, s), e) in enumerate(ranked, 1):
            cls = "; ".join(f"{c}×{n}" for c, n in e["classes"].most_common())
            ex = " || ".join(f"{l} {r}: {t}" for l, r, t in e["ex"])
            f.write(f"{i}\t{kind}\t{e['n']}\t{len(e['laws'])}\t{cls}\t{s}\t{ex}\n")

    stats = {"scope": "occurrences whose sentence class is not 'none'"}
    for kind in ("sentence", "lead", "item", "other_item"):
        counts = [e["n"] - e["classes"]["none"] for (k, _), e in shapes.items() if k == kind]
        counts = [c for c in counts if c > 0]
        n, S = sum(counts), len(counts)
        f1 = sum(1 for c in counts if c == 1)
        f2 = sum(1 for c in counts if c == 2)
        chao1 = S + (f1 * f1 / (2 * f2) if f2 else f1 * (f1 - 1) / 2)
        stats[kind] = {
            "occurrences": n, "shapes": S, "singletons": f1, "doubletons": f2,
            "chao1_estimated_shapes": round(chao1), "good_turing_unseen_mass": round(f1 / n, 3) if n else None,
            "top10_share": round(sum(sorted(counts, reverse=True)[:10]) / n, 3) if n else None,
        }
    stats["sentences"] = len(rows)
    stats["laws"] = len({r["law"] for r in rows})
    json.dump(stats, open(f"{out}/stats.json", "w"), indent=2)
    print(json.dumps(stats, indent=2))


if __name__ == "__main__":
    main(sys.argv[1], sys.argv[2])
