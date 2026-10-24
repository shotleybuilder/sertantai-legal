# Naive-Reader Standard

For guides (`docs/*GUIDE*`), skills, design docs, and session docs that another session will pick up.

## Rule

A document passes if a reader who has just joined, with no history and no memory of past conversations, can understand it and act on it without guessing.

## Checks

- **Terms**: every project term (DRRP, LAT, LRT, CLML, golden set, fold, reader, lane, a K or M pattern code) is defined where first used, or linked to where it is defined. Search the rest of the document before flagging.
- **Steps**: no step assumes setup the document doesn't state: which directory, which service running, which data loaded.
- **Defaults**: options, thresholds and limits are stated, not left for the reader to infer from code.
- **Vague hand-offs**: "handled automatically", "as usual", "the normal way": say how, or link to where.
- **History leaks**: reasoning that only makes sense if you were there ("as agreed", "the earlier problem") without the agreement or problem written down.
- **Plain words**: say what happens directly. No promotional adjectives (*robust*, *seamless*).

## Re-implementation variant

Use when a document claims to specify behaviour (a guide's rules, a skill's "intended behaviour" section). It passes only if a fresh session could write code that behaves the same from the document alone: inputs, outputs, edge cases, errors and limits all stated. Internal helper names and code layout are out of scope.
