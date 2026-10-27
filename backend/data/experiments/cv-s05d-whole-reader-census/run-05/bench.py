"""Recall bench (CV-S05d): each agent NEW of rounds 9–12, on the law's
stored reading — the live one where the defect is still open, else the
reading with the faulty rows the agent recorded put back (the CV-S05
session's round notes). The census must flag each.

usage: bench.py all.jsonl
"""

import copy
import json
import sys

import census as C
import finder as F


def drop(d, refs):
    for r in d["lists"] + d["applies"]:
        r["refs"] = [x for x in r["refs"] if x not in refs]


def add(d, kind, place, refs):
    for r in d["lists"]:
        if r["kind"] == kind and r["place"] == place:
            r["refs"] += refs
            return
    d["lists"].append({"kind": kind, "place": place, "refs": refs})


CASES = [
    # (round/NEW, law, mutate, expect: (sentence ref, verdict) or ("unnamed", ref))
    ("r9 NEW-1 default E+W+NI", "UK_ukpga_2002_30",
     lambda d: d.update(default="E+W+NI"), [("s.108", "whole_mismatch")]),
    ("r10 NEW-1 Sch.13 applies dropped", "UK_uksi_2014_1638",
     lambda d: d.update(applies=[]), [("reg.3", "place")]),
    ("r10 NEW-2 other-than read as items", "UK_ukpga_2009_23",
     lambda d: add(d, "also", "S", ["s.146", "sch.8.para.1", "sch.11"]), [("s.323", "exc_held")]),
    ("r10 NEW-2 'in Chapter 1 of Part 6' read whole", "UK_ukpga_2009_23",
     lambda d: add(d, "also", "S", ["s.150", "s.151"]), [("unnamed", "s.150")]),
    ("r10 NEW-2 Chapters 1 to 5 of Part 8 (live)", "UK_ukpga_2009_23", None, [("unnamed", "s.293")]),
    ("r10 NEW-3 'this Chapter' dropped (live)", "UK_ukpga_2017_3", None, [("s.182", "missing")]),
    ("r11 NEW-1 1977/45 s.65(10) items dropped", "UK_ukpga_1977_45",
     lambda d: d.update(lists=[r for r in d["lists"] if r["kind"] != "unread"]), [("s.65", "q_missing")]),
    ("r12 NEW-1 locator read whole (live)", "UK_uksi_2020_818", None, [("reg.1A", "broader")]),
    ("r12 NEW-2 'They apply …' in noise (live)", "UK_uksi_2016_1154", None, [("reg.1", "whole_missing")]),
    ("r12 NEW-3 '34 (f)' read whole (live)", "UK_uksi_2013_1506", None, [("reg.3", "broader")]),
]


def main(src):
    laws = {}
    for line in open(src):
        d = json.loads(line)
        laws[d["law"]] = d
    ok = 0
    for name, law, mutate, expect in CASES:
        d = copy.deepcopy(laws[law])
        if mutate:
            mutate(d)
        found, unnamed = C.check_law(d, F.Structure(law))
        hits = []
        for ref, verdict in expect:
            if ref == "unnamed":
                hits.append(any(r == verdict for _, _, r in unnamed))
            else:
                hits.append(any(f["ref"] == ref and any(v[0] == verdict for v in f["verdicts"]) for f in found))
        ok += all(hits)
        print(("FLAGGED " if all(hits) else "MISSED  ") + name)
    print(f"{ok}/{len(CASES)} flagged")


if __name__ == "__main__":
    main(sys.argv[1])
