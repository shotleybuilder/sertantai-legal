#!/usr/bin/python3
"""CV-S05c step 2: each item shape's bucket for review, from items.tsv and verdicts.tsv.

  skip        plain shape (provisions only) and every occurrence read
  read_qualified  every occurrence read, but the shape qualifies (other than, so far as, except ...)
  misread_plain / misread_qualified   some occurrence partial, missing, unread, unparsed or no_refs in a sentence read as a list
  in_unread   the sentence is classed unread (withheld; counted in the catalogue)
  not_list    no list statement (other items, defaults, instructions)

usage: /usr/bin/python3 review.py   (in the run folder) -> review.tsv, review.json
"""
import collections, csv, json, re

items = list(csv.reader(open("items.tsv"), delimiter="\t", quoting=csv.QUOTE_NONE))
ver = {int(r["items_line"]): r for r in csv.DictReader(open("verdicts.tsv"), delimiter="\t", quoting=csv.QUOTE_NONE)}
QUAL = re.compile(r"\b(other than|except|excluding|including|so far|insofar|in so far|relating|relates|together|with|but|save|apart|subject|WORDS|GAP|THIS_|THAT_|in )|^in\b")
BAD = {"partial", "missing", "unread", "unparsed", "no_refs"}

shapes = collections.defaultdict(lambda: {"n": 0, "laws": set(), "v": collections.Counter(), "cls": collections.Counter(), "ex": []})
for ln, r in ver.items():
    it = items[ln - 1]
    law, ref, cls, kind, _l, shape, _f, text = it
    e = shapes[shape]
    e["n"] += 1; e["laws"].add(law); e["v"][r["verdict"]] += 1; e["cls"][cls.split(":")[0]] += 1
    if r["verdict"] in BAD and len(e["ex"]) < 3:
        e["ex"].append(f'{law} {ref} [{r["verdict"]}: {r["own_refs"] or "-"}] {text[:200]}')
    elif len(e["ex"]) < 1:
        e["ex"].append(f'{law} {ref} [{r["verdict"]}] {text[:200]}')

def bucket(s, e):
    if any(e["v"][b] for b in BAD) and e["cls"]["list"]:
        return "misread_qualified" if QUAL.search(s) else "misread_plain"
    if e["v"]["read"] == e["n"]:
        return "read_qualified" if QUAL.search(s) else "skip"
    if e["cls"]["unread"] and not e["cls"]["list"]:
        return "in_unread"
    if e["v"]["read"] and all(v in ("read", "no_list_statement") for v in e["v"]):
        return "read_qualified" if QUAL.search(s) else "skip"
    if e["v"]["no_list_statement"] == e["n"]:
        return "not_list"
    return "misread_qualified" if QUAL.search(s) else "misread_plain"

rows = []
for s, e in shapes.items():
    rows.append((bucket(s, e), e["n"], len(e["laws"]), s, e))
order = {"misread_plain": 0, "misread_qualified": 0.5, "read_qualified": 1, "in_unread": 2, "skip": 3, "not_list": 4}
rows.sort(key=lambda r: (order[r[0]], -r[1], r[3]))
with open("review.tsv", "w") as f:
    f.write("bucket\tcount\tlaws\tverdicts\tclasses\tshape\texamples\n")
    for b, n, nl, s, e in rows:
        f.write(f'{b}\t{n}\t{nl}\t{"; ".join(f"{k}×{v}" for k, v in e["v"].most_common())}\t{"; ".join(f"{k}×{v}" for k, v in e["cls"].most_common())}\t{s}\t{" || ".join(e["ex"])}\n')
summ = collections.defaultdict(lambda: {"shapes": 0, "items": 0, "one_law_shapes": 0})
for b, n, nl, s, e in rows:
    summ[b]["shapes"] += 1; summ[b]["items"] += n; summ[b]["one_law_shapes"] += nl == 1
json.dump(summ, open("review.json", "w"), indent=2)
print(json.dumps(summ, indent=2))
