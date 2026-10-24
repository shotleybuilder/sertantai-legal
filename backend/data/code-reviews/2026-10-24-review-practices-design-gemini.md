# Review: review-practices session doc — design standard (Gemini 2.5 Pro, --standard)

Target: .claude/sessions/2026-10-24-review-practices.md (commit 3b4491ca)

### Alternatives not considered — Blocker
- Where: Item 5 design: gemini-review --standard
- Finding: The design proposes a single implementation (a `--standard` flag) without discussing other workable options and why they were rejected, as required by "The alternatives rule". For example, alternatives could include a separate, dedicated skill (e.g., `gemini-standard-review`) or using a configuration file.
- Fix: Add an "Alternatives considered" section to the design for item 5. Outline at least one other workable path and explain why the chosen approach is superior based on criteria like complexity, cost, or fit with existing code.

### Unfalsifiable success measure — Major
- Where: Todo, item 5; Item 5 design: gemini-review --standard
- Finding: The "Done" check for item 5 is "one run on this doc saved to `backend/data/code-reviews/`". This is a measure of completion, not quality, and cannot fail. The standard requires flagging "a measure that can't fail, or that the design's own output defines." The design does not specify how to determine if the generated review is good.
- Fix: Define what a successful output looks like before building. For example, specify that the output from a trial run on a test document must identify a seeded, non-trivial flaw, or that its findings must be judged "actionable" by a human reviewer.

### Unmitigated tool risk — Major
- Where: Item 4 design: reviewer subagent
- Finding: The design gives the subagent the `Bash` tool but relies only on a prompt instruction to prevent writes or other destructive actions. Large language models can fail to adhere to prompt constraints, creating a significant wrong-data or system integrity risk. The design does not acknowledge or mitigate this.
- Fix: Add the risk to a "Risks and limits" section. Propose a mitigation, such as replacing the general `Bash` tool with more specific, read-only tools (e.g., `git_show`, `sqlite_query`) or running the tool in a sandboxed, read-only environment.

### Vague success measure — Nit
- Where: Todo, item 4
- Finding: The "Done" check for the reviewer subagent is based on a one-off, historical test ("reproduces the dogfood Blocker class"). This does not provide a clear, repeatable measure for what constitutes a successful review by the agent in general operation.
- Fix: Clarify the success criteria with a more general and testable measure. For example: "The agent is considered successful if, when tested on a sample of 3 documents with known flaws, it identifies at least 80% of the Major or Blocker-level issues."

### Missing "Backing Out" sections — Nit
- Where: Item 4 design: reviewer subagent; Item 5 design: gemini-review --standard
- Finding: The designs for items 4 and 5 omit the "Backing out" section required by the standard. While backing out is trivial in these cases (deleting generated files), the section's absence means this aspect has not been explicitly documented as considered.
- Fix: Add a "Backing out" sub-section to both designs, stating that the changes are additive (creating new files) and can be undone by deleting the generated files.
