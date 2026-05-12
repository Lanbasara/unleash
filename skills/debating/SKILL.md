---
name: debating
description: "Use after unleash:brainstorming produces committed brainstorm notes — reads notes, builds a cognitive gap map, and issues grounded challenges until the user's harness design is concrete enough to spec."
---

# Unleash: Debating

> Take brainstorm notes from intent to spec by surfacing gaps, not by running a question template.

<HARD-GATE>
Do NOT challenge a point that the brainstorm notes already made concrete. Every challenge must reference a specific passage in the brainstorm notes or a specific project-context observation. Asking pre-scripted questions from a fixed template is a skill failure.

A point is concrete when the notes name a specific command, path, tool, script, or procedure — even if surrounded by informal language.

Do NOT ask more than one challenge at a time. The protocol is one question per message, grounded in a specific gap.

This applies even when the brainstorm notes look "complete" at a glance, even when the user seems in a hurry, and even when the same challenge category appears in every harness you've seen. Gap-driven dialogue only.
</HARD-GATE>

## Precondition

Before proceeding with any debating activity, verify all three conditions below. If any condition fails, STOP and report the specific missing item to the user.

**Condition 1: Brainstorm notes file exists.**

The file must be present at:

```
docs/unleash/brainstorm/<YYYY-MM-DD>-<slug>.md
```

If the file is absent, STOP and tell the user:

> "No brainstorm notes found at `docs/unleash/brainstorm/`. Run `unleash:brainstorming` first to produce and commit brainstorm notes, then invoke `unleash:debating`."

**Condition 2: Brainstorm notes are committed.**

Run `git log --oneline -5 -- docs/unleash/brainstorm/<filename>` to confirm the notes file appears in the commit log. Alternatively, run `git status` and confirm the brainstorm file is not listed as modified or untracked. If the notes are dirty or untracked, STOP and tell the user:

> "The brainstorm notes at `docs/unleash/brainstorm/<filename>` are not committed. Commit them (and have the user approve them) before invoking `unleash:debating`. The debating session challenges a specific committed version — uncommitted notes cannot be cited reliably."

**Condition 3: User has explicitly invoked debating.**

`unleash:debating` must not be entered automatically from the end of `unleash:brainstorming`. The brainstorming skill's termination HARD-GATE prohibits auto-advance. If this skill is invoked without a clear user signal (e.g., the user typed "let's debate" or explicitly invoked `unleash:debating`), STOP and confirm with the user that they intend to start a debating session and have reviewed and approved the brainstorm notes.

## Contract

- **Consumes:** `docs/unleash/brainstorm/<YYYY-MM-DD>-<name>.md` (committed).
- **Produces:** `docs/unleash/specs/<YYYY-MM-DD>-<name>-spec.md` — the formal harness design spec. Required sections:
  - `case_type` (coding / metric / hybrid / freeform)
  - `five_element_analysis` — each element either filled in concretely or marked N/A with reason
  - `phase_machine` — ordered list of phases; each phase declares: name, type (from primitive vocabulary or user-named), allowlist (read/write patterns), entry gate, exit gate, artifacts consumed, artifacts produced
  - `guardian_design` — who the Runtime-Guardian reviews, what invariants it checks, what triggers rollback
  - `optional_hooks` — any hooks requested for irreversible operations; each with trigger condition and rationale
  - `out_of_scope` — explicit exclusions
- **Precondition:** Brainstorm notes exist and are user-approved.
- **Postcondition:** Spec file is committed; spec passes structural validation (all required sections present, no placeholders); user has reviewed and approved.

## Anti-patterns: "the template I learned"

The following rationalizations are traps. Each one feels reasonable in the moment and produces a weaker spec when acted on. Recognize them and reject them.

> **Thought:** "The user won't notice if I ask the standard 4 questions (reversibility / feedback / state / autonomy)."
> **Rebuttal:** The user will notice because they'll answer a question they already answered in the brainstorm. Template questions waste the user's 5–8 turn budget on ground that was already covered. The user's trust in the skill collapses the moment they feel they're being processed instead of heard.

> **Thought:** "The knowledge base lists challenge categories, so I should cover them all to be thorough."
> **Rebuttal:** The knowledge base §6 lists categories for gap DISCOVERY (Phase B), not as questions to ask. Thoroughness in debating means every gap in THIS brainstorm is closed, not that every category is pinged regardless of relevance.

> **Thought:** "Asking generic questions is safer than missing something."
> **Rebuttal:** Safety comes from reading the brainstorm closely enough to know what's actually missing. Generic questions produce generic answers that don't sharpen the spec. A missed gap is easier to catch in validation (skill §5.5) than a spec that was never sharpened.

> **Thought:** "The brainstorm looks mostly concrete — I can skip to drafting the spec."
> **Rebuttal:** Concrete-at-a-glance is how most spec drift originates. Run Phase B properly: build the gap map for THIS brainstorm, and only skip a challenge category when you can explicitly say "element N is already concrete in passage X." If you can't point to the passage, the gap is real.

## Operating Protocol

### Phase A — Absorption

Read before challenging. Every challenge in Phase C must be grounded in something read during this phase.

- Read the brainstorm notes file in full, including the Phase A Summary section — this contains the skill's own project-context observations from brainstorming and must be treated as an audit record, not a summary
- Re-read any project context files referenced in the brainstorm's Phase A Summary — do not assume they are still accurate; if time has passed since the brainstorm was committed, re-verify by reading the referenced files directly
- Acknowledge the brainstorm's commit SHA in your first response (run `git log --oneline -5 -- <brainstorm-file-path>` to obtain it) — this tells the user exactly which version you are debating against and confirms that Phase A actually read the committed state
- Read `references/unleash-knowledge.md` §1 (5-element framework) and §6 (common pitfalls) — this file sits in the same plugin directory as this skill (`unleash/references/unleash-knowledge.md` relative to the plugin root). You'll use these for gap discovery in Phase B; do not rely on training data for these definitions

The output of Phase A is an internal understanding of the brainstorm's content and project context. Nothing is shown to the user during this phase.

### Phase B — Cognitive gap map (INTERNAL)

Build an internal list of gaps before engaging the user. This list is the skill's working set; progress is measured by gaps closed. The gap map is NOT presented to the user yet — it is internal scaffolding for Phase C. Do not present this map yet — **Phase C's first action is to make it externally visible.** Keep it internal for now.

**General rule — concreteness closes gaps:** If a passage contains a named command, file path, tool, script, or procedure (e.g., `git reset --hard HEAD~1`, `pytest tests/`, `docs/harness/state.json`), that concrete element CLOSES any gap on the related element, even if the surrounding language is informal or casual. Do not flag an element as vague when the sentence contains a specific, actionable reference.

> Example of what to do: the brainstorm says "git can handle rollback (I commit often, so any bad change can be reverted with `git reset --hard HEAD~1`)". The concrete command `git reset --hard HEAD~1` closes the Reversibility gap. The informal "I commit often" is not a gap — it's context around the concrete command.
>
> Example of a real gap: "feedback is some kind of score" — no concrete reference to a test command, a metric name, or a rubric. The gap is the absence of any actionable reference.

Categories of gap to look for. For each category, inspect the brainstorm text and project context for concrete vs. vague claims:

- **Vagueness:** where the user's statement is concrete vs. where it's woolly ("some kind of feedback signal", "probably 5 phases", "something in the auth directory"). A statement is concrete when you could write the spec section directly from it without inventing details. A statement is woolly when you must invent at least one detail to write the spec section.
- **Unstated assumptions:** what the design is silently assuming that might not hold (e.g., "assumes tests pass in under 30 seconds", "assumes only one developer", "assumes the fixture stays the same size"). Look for decisions that the user made implicitly without acknowledging them as decisions.
- **Reconstruction holes:** what you cannot fully picture from the notes alone — if you cannot draw the harness on a whiteboard from the notes alone, the spec cannot drive the implementation. Each phase's entry gate, exit gate, and allowlist must be derivable from the notes; any that cannot be derived is a reconstruction hole.
- **User-intent vs. project-reality tension:** where the user's preference as stated in the notes conflicts with observable codebase facts. For example: user wants read-only `src/` but the brainstorm's Phase A Summary shows an ongoing refactor branch is editing `src/`. These tensions, if unresolved, will produce a spec that conflicts with the actual project.
- **5-element blind spots:** for each of the 5 elements, is there enough information to write the spec section? For each element marked applicable, confirm the brainstorm provides concrete enough content. For each element marked N/A, confirm the reason for N/A is explicit — an implicit N/A is not a decision, it is an omission.

Structure each gap entry as:

```
[element or area] → [specific passage or observation] → [gap type] → [what would close this]
```

Example gap entry:

```
Quantifiable Feedback → "some kind of score from the existing tests" → vagueness → need to know: is the score pass/fail count, percentage, or a named metric; and whether "existing tests" means all tests or a named subset
```

Do NOT flag items as gaps when the brainstorm already contains a concrete, actionable statement for them. Challenging content that is already concrete wastes turns and signals to the user that the skill didn't read carefully.

### Phase C — Grounded challenges (one at a time)

Only now do you engage the user. The gap map is complete and guides every challenge.

**Rules:**

- ONE question per message — the same discipline as brainstorming; two questions in one message means the user can answer only one cleanly, and the other drifts
- Each challenge MUST reference a specific passage from the brainstorm notes or a specific project-context observation — quote or near-verbatim-paraphrase the passage; pure category labels ("your feedback signal is vague") are not grounded challenges
- Each challenge targets ONE gap from the gap map and aims to close it — when the user answers, update your internal gap map to reflect what is now closed
- Multiple-choice preferred: 3–5 options, last option always "other / describe yourself"
- Each challenge produces one of three outcomes: (A) the notes can be updated with new concrete content, (B) the user explicitly acknowledges a known trade-off that will be documented in the spec, or (C) the element is explicitly marked N/A with a stated reason
- **After the user responds and before closing the gap, perform a Drift Check against the original brainstorm notes.** This is not optional. For every user answer that closes a gap, classify the relationship between the answer and the brainstorm baseline:
  - **DERIVED** — the answer is consistent with or elaborates on a specific brainstorm passage; cite the passage
  - **OVERRIDES** — the answer replaces or contradicts an earlier decision recorded in the brainstorm; cite both the original and the overriding statement
  - **NARROWS** — the answer scopes down a broader intent expressed in the brainstorm; cite what was broad and what it became
  - **NEW_GROUND** — the answer introduces a constraint or decision with no basis in the brainstorm; flag this explicitly
  - Record all OVERRIDES and NARROWS entries; they become mandatory input for Phase E
  - A gap closure without a Drift Check is a skill failure: the model has not demonstrated that it read the brainstorm before accepting the user's answer

**Make the gap map externally visible in your first user-facing message.** Before issuing the first challenge, share the gap map (at least 3 specific gaps, each cited to a specific passage). This demonstrates Phase B ran and gives the user an overview of what the session will close. Do not interleave gap-map listing and challenges — show the map first, then issue the first challenge.

**Example of the difference:**

- Bad (generic, template-like): "What's your Quantifiable Feedback?"
- Good (grounded, closes a specific gap): "You wrote 'some kind of score from the existing tests' in the 5-Element Applicability Sketch. The existing tests in this project appear to emit pass/fail only. For the harness, is the score: (A) pass/fail from all tests, (B) pass/fail from a specific subset, (C) a derived number (e.g., % passing), or (D) something else you'd design?"

The bad question could be asked without reading the brainstorm. The good question could only be asked after reading the passage and verifying the project's test output format.

### Phase D — Convergence check

After each challenge cycle (one question, user responds), perform a convergence check:

- **Gap map empty (or remaining items explicitly deferred/out-of-scope)?** Draft the spec. Do not delay drafting once the map is clear.
- **Gaps remain and user gave a clear decision?** Update the gap map (close the gap), and loop back to Phase C for the next gap.
- **Gaps remain and user's answer is unclear or partial?** Loop back to Phase C on those specific items — do not accept a non-answer and advance. If a user gives a non-answer ("it depends", "I'll figure it out later"), follow up: "For the spec to be concrete enough to drive implementation, this gap needs a decision now. Could you choose one of the options, or describe a criterion for making the call?"
- **Never draft the spec with a gap that the user hasn't explicitly closed or deferred.** A spec section written with invented details is not a spec — it is a placeholder that will be wrong.

### Phase E — Adversarial Audit (Drift Diff)

After the spec draft is structurally complete but **BEFORE presenting it to the user for approval**, run a mandatory adversarial audit. Phase E is a HARD-GATE: the spec must not be shown to the user until the audit passes.

**Trigger:** Phase D indicates the gap map is empty (or all remaining items explicitly deferred/out-of-scope) and the spec draft has passed structural validation.

**Input:**
- `docs/unleash/brainstorm/<YYYY-MM-DD>-<name>.md` (committed version from Phase A; re-read from disk, do not rely on memory)
- `docs/unleash/specs/<YYYY-MM-DD>-<name>-spec.md` (current draft)
- The Drift Check records collected during Phase C (all OVERRIDES and NARROWS entries)

**Execution:** Dispatch a fresh-context subagent (the auditor) with:
- The full text of the brainstorm notes
- The full text of the spec draft
- The Drift Check records (OVERRIDES and NARROWS)

**Auditor task:**
1. Compare every requirement, decision, and constraint in the spec draft against the brainstorm notes.
2. Produce a Drift Audit with three categories:
   - **OVERRIDE** — spec contains a decision that contradicts or replaces a decision recorded in the brainstorm
   - **NARROWING** — spec scopes down a broader intent expressed in the brainstorm without explicit rationale
   - **NEW_GROUND** — spec contains requirements with no basis in the brainstorm
3. For each OVERRIDE and NARROWING: cite the exact brainstorm passage and the exact spec passage.
4. For NEW_GROUND: flag whether it is a legitimate elaboration (filling detail the brainstorm left open) or an invention (introducing constraints the user never agreed to).

**Blocking rule:**
- If the Drift Audit contains any unconfirmed OVERRIDE or NARROWING: **STOP. Do not present the spec to the user.** Return to Phase C and re-open the corresponding gap with an explicit challenge: "The spec draft says X, but the brainstorm recorded Y. Is this override intentional?"
- Only when all OVERRIDEs and NARROWINGs are either (a) confirmed by the user as intentional, or (b) removed from the spec, may the audit pass.
- NEW_GROUND items must be reviewed: legitimate elaborations may remain; inventions must be removed or moved to Out of Scope with user approval.

**Output artifact:** `docs/unleash/specs/.draft-audit.md` (temporary; deleted after spec is committed; exists only to record the audit trail)

## Challenge categories as reminders (NOT a script)

> The knowledge base enumerates weak points. Use these for gap DISCOVERY in Phase B, not as prefab questions to ask. Only ask about a category when the brainstorm actually surfaces a gap in it.

- **Reversibility:** Does the brainstorm name a recovery procedure for phase N failure? A procedure is concrete when it names a specific command, git operation, or script — not when it says "git can handle it." *If a specific command IS named even within informal language, the Reversibility gap is closed — do not flag it.*
- **Feedback sharpness:** Is the success signal a number, a test result, or human judgment? A signal is sharp when it can be evaluated by a script or pinned rubric without further interpretation. **Whenever Quantifiable Feedback is being concretized for a coding-case harness, surface this 4-option testing-mode probe to the user (multiple-choice, one question per message):** "(A) Standard red-green TDD — write failing tests first, then make them pass; (B) Logical/manual checklist — I'll write a sharp checklist and you run it manually because unit tests aren't feasible here; (C) Skip testing entirely — I'll judge by reading the code, no test artifacts; (D) Other — describe what you want." The chosen mode must be recorded in the spec's Quantifiable Feedback section as `testing_mode: A | B | C | other`. For mode B, the spec must additionally name what concrete checklist items the user expects (so planning can write them sharply, not vaguely). For mode C, the spec must explicitly state "no Test phase will be planned." Do NOT default to mode A without asking.
- **State persistence under concurrency:** What happens if two runs write to the same state directory? Even single-developer harnesses can have accidental concurrent runs from CI triggers or backgrounded processes.
- **Human-in-the-loop failure modes (3am):** What happens when the human who was supposed to be watching is asleep? Which phases assume human presence, and is that assumption explicit in the spec?
- **Allowlist completeness:** Are read/write allowlists specified per-phase? Are they cross-phase compatible — does phase N's write allowlist overlap with phase N+1's read allowlist for every artifact that transfers between them?
- **Loop termination:** Does the brainstorm name a max-iters / early-stop / external signal for any Loop phase? A loop with no declared exit condition is unbounded by definition and cannot be specced.
- **Guardian scope alignment:** Does the guardian see everything the phase is allowed to do? A guardian that checks file writes but not shell commands has a blind spot if the phase is also permitted to run scripts.
- **Irreversibility identification:** Which operations, if any, need hook enforcement because post-hoc rollback is insufficient? The key question: if this operation runs and produces a bad result, can the harness undo it with a `git reset` — or does the damage persist outside the project tree?

Each bullet is a reminder about what gap to look for in Phase B. None are questions to ask in sequence. Ask about a category only when the brainstorm shows an actual gap in it.

## Output artifact

**Filename:** `docs/unleash/specs/<YYYY-MM-DD>-<name>-spec.md`

The spec must contain all six of the following required sections. A spec missing any section is incomplete and must not be committed.

### `## Case Type`

One of: coding / metric / hybrid / freeform. Include a one-paragraph rationale explaining why this case type was chosen, grounded in the project context and the user's stated goal. If the case type was ambiguous during brainstorming, note what the debating session resolved.

### `## 5-Element Analysis`

One subsection per element (`### Constraint Boundary`, `### Quantifiable Feedback`, `### State Persistence`, `### Reversibility`, `### Autonomy`). Each subsection must be one of:

- **Concrete:** specific enough that the implementation subagent could act on it without inventing details. Per-phase allowlists for Constraint Boundary. Named signal and evaluation method for Quantifiable Feedback. Named file or directory and format for State Persistence. Named command or procedure for Reversibility. Named oversight model and human-presence assumption for Autonomy.
- **Explicit N/A with reason:** states which element is N/A, gives the specific reason (e.g., "single-shot harness; no loop; restart from scratch on failure; run time under 60 seconds"), and confirms that the N/A was an explicit decision reached during debating, not an omission.

There are no other valid states. An element that is neither concretely filled nor explicitly N/A is an incomplete spec.

### `## Phase Machine`

Ordered list of phases. Each phase must declare:

- **Name:** a specific, descriptive name (not "Phase 1")
- **Primitive type:** one of Read-Only / Restricted-Write / Script / Human-Check / AI-Judge / Loop, or a user-named custom type with an explicit behavior description
- **Allowlist:** read patterns and write patterns, expressed as specific paths or glob patterns; not "work in the relevant directory"
- **Entry gate:** the condition that must be true before this phase may start; must reference a specific artifact or git state
- **Exit gate:** the condition that must be true before this phase may be considered complete; must be externally verifiable (not self-declared by the implementing agent)
- **Artifacts consumed:** the specific files this phase reads as inputs; must match a prior phase's artifacts-produced or be declared as external harness inputs
- **Artifacts produced:** the specific files this phase writes as outputs; must appear in a subsequent phase's artifacts-consumed or be declared as final harness outputs

The phase machine must have at least one phase. Every artifact must have both a producer and a consumer (or be explicitly declared as a harness input / final output). Circular dependencies are forbidden (the dependency graph must be a DAG).

### `## Guardian Design`

Specify:

- Which phases the Runtime-Guardian reviews (typically all phases with a write allowlist)
- What evidence the guardian receives (git diff, tool-call log, output artifact presence, shell command log)
- What invariants the guardian checks per phase (write-allowlist compliance, artifact presence, exit-gate verification)
- What triggers rollback (specific invariant violations)
- The rollback mechanism (specific git command or procedure)

The guardian's scope must be a superset of every action each phase is permitted to take. Any permitted action not in the guardian's view is a blind spot and must be either closed (widen guardian scope) or moved to hook enforcement.

### `## Optional Hooks`

If no irreversible operations were identified during debating, state: "No hooks required — all phase operations are reversible via git reset."

If hooks are required, list each with:

- **Operation:** the specific operation being gated (e.g., `git push`, `curl` to an external API, `npm publish`)
- **Trigger condition:** when exactly the hook fires
- **Rationale:** why this operation is irreversible and cannot be left to the guardian
- **Fallback:** what happens if the hook blocks the operation

Hooks are for irreversible operations only. A hook gating a reversible operation is the Hook-Over-Guardian pitfall (knowledge base §6.7).

### `## Out of Scope`

Explicit exclusions — items that came up during brainstorming or debating but were deliberately excluded from this harness design. Each exclusion should name the item and give a one-sentence reason for exclusion. This section prevents scope creep during implementation by making the boundary explicit.

**Structural validation.** The spec passes structural validation when:

- All six sections are present
- No section contains placeholder text ("TBD", "TODO", "to be decided", "implement later", or similar)
- The phase machine has at least one phase
- Each phase references artifacts that are either produced by a prior phase or declared as external harness inputs
- Guardian scope covers all phases that have a write allowlist

A spec that fails structural validation must not be committed. Fix the failing sections and re-present to the user before committing.

## Termination

<HARD-GATE>
Do NOT write implementation code or scaffold files in this skill. Your terminal state is a committed spec.md + user approval. Once approved, tell the user: "spec ready — invoke unleash:planning next (available in Plan 2 of the Unleash roadmap; until then, use the spec as input to superpowers:writing-plans or a similar plan-authoring workflow)."
</HARD-GATE>

The spec represents the user's harness design in its most precise form — it is not code, not a plan, and not an implementation. Auto-advancing to planning before the user has reviewed the spec erodes the purpose of the structural validation check: the user must confirm the spec captures their intent correctly before any implementation work begins. Present the spec, commit on approval, and stop.

## Checklist

Complete these items in order. Use TodoWrite to track progress.

1. Phase A: read brainstorm notes in full, re-verify project context files referenced in the Phase A Summary, note the brainstorm's commit SHA, and read `references/unleash-knowledge.md` §1 and §6
2. Phase B: build the cognitive gap map internally (do not show yet) — for each gap, record element or area, specific passage, gap type, and what would close it
3. Phase C: make the gap map externally visible in the first user-facing message (at least 3 specific gaps, each cited to a specific passage from the brainstorm notes), then issue the first grounded challenge
4. Phase C: continue one challenge at a time, each grounded in a specific passage or observation; perform Drift Check after each user response; update the gap map as gaps close; record all OVERRIDES and NARROWS
5. Phase D: convergence check after each challenge — loop to Phase C if gaps remain; never advance with an open gap the user hasn't explicitly closed or deferred
6. Phase E: when gap map is clear and spec draft passes structural validation, dispatch fresh-context auditor with brainstorm + spec draft + Drift Check records; run adversarial audit; if unconfirmed OVERRIDE/NARROWING found, return to Phase C; if audit PASS, proceed
7. Draft `docs/unleash/specs/<YYYY-MM-DD>-<name>-spec.md` with all 6 required sections; run structural validation; present to user; commit on approval; STOP (do not invoke planning)
