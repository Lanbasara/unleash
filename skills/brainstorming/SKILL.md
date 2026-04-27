---
name: brainstorming
description: "Use when starting Unleash design work — explores project context silently, then leads a grounded dialogue to capture the user's harness intent in committed brainstorm notes."
---

# Unleash: Brainstorming

> Capture the user's harness intent by exploring project context silently first, then asking grounded questions.

<HARD-GATE>
Do NOT ask the user any question before Phase A (silent context exploration) is complete.
Do NOT ask the user any question before Phase B (hypothesis formation) is complete.
This applies even when: the user has described the project verbally, the project appears small or obvious, or you believe you already know what it contains. Phase A always happens first.

Every question in Phase C must demonstrably reference an observation from Phase A or B, or explicitly acknowledge uncertainty. Grounded questions only.
</HARD-GATE>

## Contract

- **Consumes:** User intent in natural language; read-only access to the working tree.
- **Produces:** `docs/unleash/brainstorm/<YYYY-MM-DD>-<name>.md` — open exploration notes covering: observed project context summary, target harness description, case-type hypothesis (coding / metric / hybrid / freeform), 5-element applicability sketch, candidate starter patterns considered, open questions carried forward to debating.
- **Precondition:** User has invoked the skill in a Claude Code session within a project directory.
- **Postcondition:** Brainstorm notes committed to git; user has reviewed and agreed the document captures both the project context and the user's intent.

## Anti-patterns: "this project is obvious"

The following rationalizations are traps. Each one feels true in the moment and produces worse outcomes when acted on. Recognize them and reject them.

> **Thought:** "User said what they want, I don't need to read the code."
> **Rebuttal:** The user's stated intent describes their goal, not their codebase — without reading the code, questions in Phase C will be framed around generic concepts rather than actual project structure, producing brainstorm notes that don't survive debate review because they fail to connect the harness design to the specific constraints, conventions, and quirks already present in the project.

> **Thought:** "Exploring takes tokens; I'll save them for dialogue."
> **Rebuttal:** Saving tokens at Phase A forces Phase C to spend more of them on clarifying questions that could have been answered by reading one file — the net token cost is higher, and the dialogue is shallower because questions ask for information that was available silently, signaling to the user that the skill didn't look before asking.

> **Thought:** "I already know what this kind of project looks like."
> **Rebuttal:** Category recognition (Python ML project, Node web app, Rust CLI) is not the same as knowing this project — assumptions about directory conventions, test framework choice, active branches, and module boundaries diverge from reality often enough that a harness designed on category assumptions will require expensive revision when implementation encounters the actual codebase.

> **Thought:** "I can ask for the facts faster than I can read them."
> **Rebuttal:** Asking the user for facts the code already contains shifts cognitive load to the user unnecessarily and inverts the skill's responsibility — the result is a brainstorm note where the "Project Context" section reflects what the user remembers rather than what the code actually shows, which means Phase A's grounding guarantee is absent even when the section is present.

> **Thought:** "The project is tiny, context reading is overkill."
> **Rebuttal:** Small projects have less tolerance for harness misfit, not more. A wrong constraint boundary on a three-file project derails the entire harness immediately — there is no other code for the skill to work around. Read the tiny project anyway; it takes 60 seconds and prevents a systemic design mistake.

> **Thought:** "The user already described the project to me verbally — I have what I need."
> **Rebuttal:** User narration reflects the user's mental model, not the code's actual state. Branch conventions, active refactoring, debt patterns, and test coverage do not survive narration accurately. Read the code; the user is describing what they remember, not what exists.

## Operating Protocol

### Phase A — Silent context exploration (no user-facing questions)

Phase A is mandatory and precedes all dialogue. Do not ask the user anything during this phase. Read first; form questions later.

Perform each of the following in order. Attempt each read; note absences explicitly — absence is also an observation.

1. Read `README.md` / `README.*` if present — note the project's stated purpose, primary language, and any explicit constraints or goals mentioned
2. Read any `CLAUDE.md` at the project root — if present, this describes conventions that override defaults and must inform every Phase C question
3. Read the package manifest (`package.json` / `pyproject.toml` / `Cargo.toml` / `go.mod` / `Gemfile`) to identify language, runtime, dependency profile, and test tooling already in use
4. Run `ls -la` at the project root and `find . -maxdepth 2 -type d` to map the directory structure — note top-level organization, presence of `docs/`, `tests/`, `scripts/`, and any unusual directories
5. Run `git log --oneline -20` to understand the shape of recent activity — note whether commits cluster around one subsystem, whether there is active refactoring in progress, and how many contributors appear
6. Read 1–3 representative source files chosen to reveal conventions — pick files that show naming style, module layering, and test approach (e.g., one core module, one test file, one utility or config file)
7. If a `docs/` directory exists, sample its contents — prior design decisions, ADRs, API contracts, or existing harness notes here carry strong constraints on what this brainstorm should produce
8. If a `.harness/` or `.unleash/` directory exists, read it fully — the user may be extending or replacing a prior harness, and its contents define strong constraints on what this brainstorm should produce
9. Read `/Users/HaokunGuo/unleash/references/unleash-knowledge.md` §1 (5-Element Framework) and §2 (Common Starter Patterns) — this is the canonical source for the vocabulary you will use in Phase B and in the brainstorm notes; do not answer from training data

The output of Phase A is an **internal mental model**, not yet a user-facing artifact. Nothing is shown to the user during this phase.

### Phase B — Hypothesis formation (no user-facing questions)

Before asking the user anything, answer these four questions internally. They anchor every Phase C question to observable reality and prevent the dialogue from drifting into generic territory.

- What kind of project is this? (library, application, research sandbox, tool, monorepo, …) — be specific; "Python ML project" is not specific enough; "a neural translation pipeline with a BLEU-based eval script and active work on tokenizer and beam search" is.
- Given the project shape, what is the user plausibly wanting to harness? Form at least one concrete hypothesis — it may be wrong, but having a hypothesis allows Phase C questions to be confirmatory or corrective rather than exploratory from scratch.
- What constraints does this codebase impose on any harness design? Consider test framework already chosen, branching conventions, directory conventions established by prior commits, and any active refactoring that would affect allowlist design.
- Which parts of the 5-element framework (see `references/unleash-knowledge.md` §1) are likely applicable vs. likely N/A here? Draft an initial applicability sketch — it will be refined through Phase C dialogue but should not start from a blank slate.

### Phase C — Grounded dialogue

Only now does the skill ask the user questions. Phase C does not begin until Phase A is complete and Phase B hypotheses are formed.

> **Every question in this phase must demonstrably reference observations from A or B, or explicitly acknowledge uncertainty** (e.g. "I couldn't determine X from the code — could you tell me: …?").

A question that cannot point to a Phase A observation or a Phase B hypothesis is a generic question. Generic questions produce generic answers. Generic answers produce brainstorm notes that do not survive debate review.

**Example of the difference:**

- Bad: "What is your constraint boundary?"
- Good: "I see your `src/auth/` module has roughly 40 files and recent commits suggest you're mid-refactor there. For this harness, is the constraint boundary the auth module as a whole, or a specific subtree of it?"

The bad question could be asked with zero knowledge of the project. The good question could only be asked after reading the git log and the directory structure. Phase C questions must be of the second kind.

## Interaction principles

- One question per message
- Multiple-choice preferred (typically 3–5 options, last option always "other / describe yourself")
- Context window budget: after 5–8 grounded Q&A turns, begin drafting the brainstorm notes even if the dialogue feels unresolved — the draft will expose which questions are still open and can be closed in the final review loop. Treat turn count, not utilization percentage, as the operative signal. Never let dialogue exhaust the window.
- After 5–8 grounded Q&A turns, draft the brainstorm notes and show them to the user for correction before committing
- When user answers are short or generic, follow up with a clarifying question rather than accept at face value
- Short-circuiting the protocol (skipping Phase A or B) is a **skill failure** — the brainstorm notes must include the Phase A observation summary so this can be audited after the fact

## Output artifact

**Filename:** `docs/unleash/brainstorm/<YYYY-MM-DD>-<slug>.md`

The file must contain all six of the following sections. A brainstorm document missing any section is incomplete and must not be committed.

### `## Project Context (Phase A Summary)`

Must include what was read and specific observations from each source — not summaries of what the user said, but what the skill observed directly. Required content:

- Which files were read (list them)
- Specific observations from each: file content highlights, key dependencies identified, commit themes and activity patterns, directory structure patterns, any `.harness/` or `.unleash/` content found

This section is the audit record that Phase A exploration actually occurred. If this section is thin or generic, it means Phase A was skipped or performed superficially.

### `## Harness Intent`

The user's articulated goal in their own terms, as refined through Phase C dialogue. Include both the user's initial statement and the more precise version that emerged from dialogue, noting where the two differ.

### `## Case-Type Hypothesis`

One of: coding / metric / hybrid / freeform — plus a paragraph explaining why this case type fits the project context and the user's stated goal. If the case type is uncertain, note which two candidates remain and what would resolve the ambiguity.

### `## 5-Element Applicability Sketch`

For each of the five elements (Constraint Boundary, Quantifiable Feedback, State Persistence, Reversibility, Autonomy): one of likely applicable / maybe applicable / likely N/A, followed by a one-sentence reason grounded in the observed project context. Elements are not forced — a legitimate N/A with an explicit reason is better than a forced applicability that adds no information.

### `## Candidate Starter Patterns`

Which patterns from `references/unleash-knowledge.md` §2 were considered, which was recommended, and what modifications the user signaled during Phase C dialogue. If the user rejected all starter patterns, note that here along with the primitives they want to compose from instead.

### `## Open Questions for Debating`

Gaps the skill and user identified during Phase C but did not resolve — items that need the challenge mode of `unleash:debating` to close. Be specific: "the feedback signal hasn't been defined yet" is specific enough to drive a debating challenge; "more discussion needed" is not.

## Termination

<HARD-GATE>
Do NOT invoke unleash:debating automatically. Present the brainstorm notes to the user, commit them to git, and then tell the user to invoke unleash:debating when they are ready.
</HARD-GATE>

The brainstorm notes represent the user's intent and the skill's project observations — they are not guaranteed to be complete or correct until the user reviews them. Auto-advancing to `unleash:debating` before the user has read and approved the brainstorm document erodes the trust that Phase A exploration was accurate: if the user discovers in the middle of a challenge round that the project context summary was wrong, debating must be abandoned and restarted anyway. The cost of the auto-advance is not saved time — it is an invalidated challenge round. Present the notes, commit on approval, and stop. The user invokes debating when they are ready.

## Checklist

Complete these items in order. Use TodoWrite to track progress.

1. Phase A: read project context files AND the Unleash knowledge doc sections §1 and §2 (READ and Bash tool calls; no Edit/Write, no user-facing questions)
2. Phase A: form internal mental model of project
3. Phase B: answer internal hypothesis questions
4. Phase C: ask first grounded question to user
5. Phase C: continue 5–8 turn dialogue, one question at a time
6. Draft brainstorm notes with all 6 required sections
7. Present to user, commit on approval, then STOP (do not invoke debating)
