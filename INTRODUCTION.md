# Unleash — A Skill Suite for Harness Development

> Design the harness once, let the AI run.

---

Unleash is a Claude Code skill suite — 8 skills plus a queryable knowledge base — that helps developers design, build, verify, and archive bespoke harnesses for their AI-assisted work. The central insight is this: in 2026, AI coding assistance falls over when stakes get real, and the gap is not in the model. The gap is in the design discipline *around* using the model. Unleash industrializes that design discipline. It does not run harnesses. It helps developers build the right harness for their specific project, and ensures that harness is verified before any real work runs through it.

---

## 背景 — The Problem and the Gap

### Demo-ware vs. production engineering

AI coding assistants in 2026 still behave like demo-ware in one consistent way: a request goes in, a diff comes out, applause. In a greenfield prototype this is fine. In production engineering — where a bad merge costs hours of debugging, a bad migration corrupts data, and a misunderstood spec wastes a sprint — the demo-ware pattern trades understanding for throughput, and it falls over the moment stakes get real.

The failure modes are consistent. The AI interprets a vague request generously and produces plausible-looking code that doesn't satisfy the actual requirement. The AI adds scope ("while I'm here, I'll also refactor this") that introduces regressions the developer doesn't notice until review. The AI "implements" something it cannot actually test, so the implementation looks correct in isolation but fails against the real system. None of these are model failures. They are harness failures: the model was given no constraint on scope, no feedback signal to test against, no rollback path when things went wrong.

The community has answered with two complementary movements.

**Harness engineering** (the canonical example being Karpathy's `autoresearch`) treats the runtime environment as a first-class artifact. Rather than trusting the model to "do the right thing," harness engineering designs explicit constraints, quantifiable feedback, and state persistence so an agent can run reliably with minimal supervision. The model's behavior is shaped by its environment — what it can read, what it can write, what metric it is optimizing — not only by its prompt. This is optimization-oriented: the harness is designed so the agent can run unattended, for many iterations, against a frozen oracle.

**Disciplined workflow frameworks** (the canonical example being the `superpowers` skill suite) enforce spec-first, test-first, verification-first workflows so that AI output meets the same bar as human engineering. Rather than constraining the runtime environment, they constrain the process: you cannot implement without a spec, you cannot merge without review, you cannot ship without a plan. This is correctness-oriented: the discipline is in the handoffs, not the execution loop.

Both movements point at the same underlying gap: **AI assistance is only as reliable as the design discipline around it.** And both require the developer to design a bespoke harness for their specific task.

### The design work is currently artisanal

That design work is high-leverage. A well-designed harness changes what the AI can accomplish — it turns an agent that would otherwise hallucinate, scope-creep, or drift into one that runs predictably against a clear contract. But the work of designing a harness is currently artisanal: every developer starts from a blank page, rediscovers the same failure modes (vague allowlists, unspecified feedback signals, unexamined irreversibilities), and produces inconsistent artifacts that cannot be audited or transferred.

### The F1 analogy

This gap has a useful analogy, which emerged from a conversation about harness engineering in April 2026 (recorded in `harness.md`). Designing a harness is like building a Formula 1 car before the race season: you are constructing the track (constraint boundary), defining the timing system (quantifiable feedback), building the pit-lane infrastructure (state persistence), designing the Parc Fermé rules (reversibility), and setting the race strategy (autonomy). None of this is the race itself — it is all preparation so that when the race starts, the driver can push hard without endangering the team.

The analogy is precise in an important way. In Formula 1:

- The Parc Fermé locks the car configuration before qualifying — certain things become physically unmodifiable, not merely discouraged
- The feedback signal is a single scalar (lap time), chosen deliberately over competing metrics
- The weekend structure (FP1, FP2, FP3, qualifying, race) is a staged process of "run manually, observe, lock, then unleash"
- Once the race starts, the goal is minimum human intervention — safety car and red flag are failure modes, not features

A harness built with the same discipline has the same shape: explicit per-phase allowlists that are enforced (not just requested), a feedback signal sharp enough to drive decisions, a staged first-run walkthrough before any unattended operation, and a runtime guardian that handles violations so the human doesn't have to.

The current state of tooling makes you reinvent this discipline each time. Unleash exists to industrialize it.

**Unleash is for developers who want production-grade discipline around AI-assisted coding without reinventing the design effort each time.**

The toolkit is not for everyone. If you want a fast answer to a bounded question, ask the model directly. Unleash is for the work that matters enough to design: the multi-week refactor, the metric-optimization loop that will run 100 iterations, the coding workflow that needs to onboard other people, the task where a hallucinated implementation would cost real time to unwind.

### Two canonical scenarios

The design spec defines two canonical scenarios that motivated the toolkit's scope. These are worth reading as concrete examples before the abstract architecture description.

**Scenario A — Coding-process harness.** A developer wants to refactor authentication code with discipline. Brainstorming surfaces that the developer manually verifies each change in the running app rather than writing unit tests — so debating replaces the Test phase with a Human-Check phase and challenges the developer to write the verification checklist explicitly before the harness runs. Planning produces a guardian prompt that checks for the checklist artifact before allowing the Impl phase to advance. Validating flags that the Human-Check phase's exit gate doesn't specify how the user records the check outcome — the developer and skill add a checklist-output requirement and re-validate. Archiving (after the refactor merges) produces a review noting that the checklist grew informally during use and suggesting a more structured format for next time — a concrete lesson for the next coding harness.

**Scenario B — Metric-optimization harness.** A developer wants to optimize a model's BLEU score on a private eval set. Debating surfaces that the developer's Decide logic is non-trivial: they want to keep a run even if BLEU drops slightly, if latency improves significantly. Rather than accepting "I'll decide manually" as the answer, debating probes: "is that a linear combination, a Pareto filter, or a human call?" The developer decides: an AI-Judge phase that applies a written rubric. Planning includes a baseline-establishment phase and a max-iters bound that validating later flags as missing. Archiving (after iteration 120) produces a review noting that the AI-Judge rubric drifted in emphasis across iterations and flags this as a finding — the spec should have pinned the rubric or required a documented change log.

Both scenarios illustrate the same arc: design discipline surfaces assumptions the user hadn't made explicit, and the harness's artifacts make those assumptions verifiable after the fact.

---

## 命名 — Why "Unleash"

### The naming arc: from harness to Formula to Unleash

The word *harness* is literally a leash: a system of reins, straps, and bits that constrains an animal's movement and channels its strength. Karpathy's choice of "harness" as a name for `autoresearch`'s runtime structure is apt — the harness constrains what the agent can do, channels its outputs through a feedback loop, and makes its behavior predictable. The metaphor is honest: a harness is a control system.

The conversation that eventually produced the name "Unleash" started from this same etymological observation. In April 2026, the original author (ghk) explored the F1 analogy with an AI collaborator (claw), tracing the evolution from horse racing — where "harness" as a word and as a practice both live — to Formula 1, where the discipline is fully engineering-grade. The F1 circuit's design philosophy maps cleanly onto harness engineering: `规则 (constraints)`, `反馈 (feedback)`, `可逆性 (reversibility)`, `自主性 (autonomy)`, `积分赛 (the real run)`.

From that conversation, the AI suggested a family of names in the "Formula" direction — Formula A, Formula X, and related variants — all evoking the "design the rules, let the agent race" philosophy. The early proposal's tagline read: *"Design the Formula, Unleash the Agent."*

The name **Formula** was ultimately chosen in that conversation as the name for the philosophy: a harness is a formula (a precise, rule-bound specification) within which the agent competes. The conversation ended there, at "Formula," with the understanding that this was the name for the discipline — the set of rules and constraints that make agent behavior predictable.

But the toolkit built to help developers construct those harnesses took a different name. The naming conversation had surfaced one phrase that captured the arc better than "Formula" did: *"Design the Formula, Unleash the Agent."* The action at the end of the discipline is what the user actually wants. **Unleash** became the toolkit name. **Unleash** captures the *outcome* of the work, not the mechanism. The mechanism is harness design — constraint, rigor, discipline. The outcome, once that work is done, is that you have earned the right to let the AI run with confidence.

### Mechanism-naming vs. outcome-naming

There is a deliberate philosophical inversion in the name. The entire content of the toolkit is constraint-building: sharper allowlists, more specific feedback signals, tighter guardian prompts. The toolkit's daily experience is restriction. But restriction is not the point — it is the means. The point is confidence: after all that restriction is designed and verified, you can actually trust the agent to run.

- `harness` as a name implies "we constrain you." It describes what the system *is*.
- `unleash` as a name implies "we set you free." It describes what the system *enables*, once the prior work is in place.

A toolkit named `harness-builder` would attract developers who want to build constraints. A toolkit named `unleash` attracts developers who want to let their AI do real work. Both are the same developer — the framing just changes which half of the work feels primary.

The `superpowers` skill suite (from which Unleash draws several design patterns) uses the same outcome-naming logic: the name describes the capability the user gains, not the engineering discipline underneath.

For Unleash, the inversion is especially pointed. The toolkit's entire purpose is to build better leashes — more explicit allowlists, sharper feedback signals, more verifiable guardian prompts. Everything it does increases constraint. But it does this so that once the constraints are right, you can trust the agent enough to actually let it run. The name picks the endpoint, not the journey.

### Naming comparison

| Name | Implies | Describes | Where focus lands |
|------|---------|-----------|-------------------|
| `harness` | "we constrain you" | the mechanism | the leash |
| `harness-builder` | "we build constraints for you" | the tool | the leash-construction process |
| `Formula` | "we give you the rules" | the philosophy | the rule-set |
| `unleash` | "we set you free" | the outcome | what you earn after the discipline |

The name is also a claim: if you do the design work, the autonomy is earned. The word "unleash" without the prior work would be reckless. With it, it is accurate.

### Tagline

> *Design the harness once, let the AI run.*

This tagline captures both halves: the up-front design discipline ("design the harness once") and the autonomous operation it enables ("let the AI run"). Neither half works without the other.

---

## 技术框架 — The Architecture

Unleash's architecture is shaped by five load-bearing design principles. Every decision in the skill design traces back to one or more of these. Understanding the principles is the fastest path to understanding why the toolkit works the way it does.

### 3.1 Skill-first, not template-first

Unleash contains no hard-coded harness templates, no pre-filled phase configurations, no starter scaffolding that you copy and edit. What might look like a "coding pipeline with five phases" is not a template the toolkit emits — it is a conversational suggestion that the brainstorming skill offers because it noticed your project has a test suite and a bounded feature scope. You may accept it verbatim, modify any phase, or reject it and design from primitive vocabulary.

The rationale is that templates train users to fill in blanks rather than design. If the toolkit hard-codes structure, deviating from it requires hacking the template; the AI has no reason to be in the design conversation at all. If the toolkit ships knowledge — vocabulary, patterns, anti-patterns, applicability probes — and asks the AI to apply that knowledge to *this project*, every harness that emerges is genuinely specific to the work it governs.

Knowledge guides the AI; the AI does the design. No fill-in-the-blank.

### 3.2 B-layer + C-layer dual output

Every harness Unleash helps produce has two distinct output layers.

The **B-layer** is soft guidance: `spec.md`, `plan.md`, per-phase markdown documentation, guardian prompt files. These are addressed *to* the AI that will use the harness; they give it structure, vocabulary, context, and the reasoning behind each constraint. A B-layer artifact does not prevent the AI from doing the wrong thing — it persuades and orients.

The **C-layer** is hard enforcement: Claude Code hooks, `settings.local.json` entries, pre-commit scripts. These artifacts bind what the AI can actually do — they are addressed at the AI's tool calls, not at the AI's intentions. A C-layer hook that blocks a `git push --force` does not ask the AI to reconsider; it prevents the operation from completing.

Critically, both layers are written as real code by a subagent during implementation, informed by the spec. A `.claude/hooks/` script that ships pre-written with the Unleash toolkit would be a template — and a violation of the skill-first principle. A hook written by an implementer who read the user's spec, understood which operations are irreversible in this specific project, and produced concrete blocking logic for exactly those operations is not a template; it is a harness artifact.

The distinction matters because B-layer-only harnesses (where the workflow is the harness) and C-layer-inclusive harnesses (where runtime machinery is installed) have different end-of-life paths. More on this in §3.5 and the skill walkthrough.

### 3.3 AI-first runtime enforcement

Hard enforcement (C-layer) is not the default. The default is a **Runtime Guardian**: an independent AI subagent that reviews each batch of harness activity post-hoc and triggers a `git reset --hard` rollback on violation.

Hooks are reserved for a specific, narrow case: **truly irreversible operations** — destructive bash commands, outbound API calls, email sends, package publishes. For these, post-hoc review is too late. A guardian that notices a bad `git push --force` after it has already propagated to the remote is not a useful safety net. For irreversible operations, the toolkit falls back to pre-hoc blocking at the tool-call level.

This is a deliberate philosophy, not an omission. If every AI decision needed a technical block at the OS level to be safe, that would not be a harness — it would be a cage. A harness is designed with enough trust in its constraints that the guardian can handle violations after they happen (because they are reversible), reserving pre-hoc blocking for the genuinely non-reversible edge.

The philosophical cost is acknowledged: some violations slip past the guardian before it can review them. This cost is accepted because most violations are reversible (a bad file edit is a `git reset`), because the guardian handles nuance that hooks cannot (a hook cannot read context; a guardian can), and because "physically prevent all possible misbehavior" is inconsistent with what a harness is for.

A side effect of this principle is that the guardian prompt is a first-class design artifact, not an afterthought. The debating skill has a dedicated challenge category for guardian scope: "what operations during phase N would the guardian NOT see, and is that acceptable?" Planning reviews the guardian prompt as a first-class artifact with its own quality check. Validating checks that the guardian's review scope covers the phase's entire action surface. Walking-through verifies the guardian actually fires on a real violation. Four separate checkpoints on a single artifact — because a guardian with a blind spot is worse than no guardian, in the sense that it creates a false sense of coverage.

### 3.4 The 5-element framework as questioning backbone

The five foundational conditions of a harness design are: **constraint boundary** (what the agent can read, write, and execute, per phase), **quantifiable feedback** (how the harness knows it's making progress), **state persistence** (how history survives interruption and restart), **reversibility** (how each phase's actions can be undone, and what triggers that), and **autonomy** (how much the harness runs unattended, and what governs unattended execution).

These five elements are used as a **questioning backbone** during brainstorming and debating — probes for finding what a harness needs to be reliable — not as a checklist of required fields. The key discipline: if a given harness has no meaningful expression of a particular element, that element is explicitly marked **N/A with a stated reason** in the spec and skipped in all downstream artifacts. A coding harness where a human is present at every phase transition may legitimately mark Autonomy N/A. A single-shot transformation with no loops may legitimately mark State Persistence N/A. But the N/A must be deliberate and stated, not implicit.

Elements are never forced. A spec that includes five filled-in element sections for a harness that genuinely only needs three is producing boilerplate — the design discipline collapsed back into template-filling.

The knowledge base (`references/unleash-knowledge.md`) contains detailed applicability probes and example dialogue for each element — concrete questions grounded in real project observations, with two answer shapes showing how the conversation diverges based on the user's response. This is the knowledge that the brainstorming and debating skills draw on. It is not a questionnaire to fill out; it is a reference for designing the right question for this specific project context.

### 3.5 Explicit interface contracts

Every skill in the chain declares a four-part contract in its header: **Consumes** (what upstream artifact it requires), **Produces** (what downstream artifact it delivers), **Precondition** (what must be true before it can start), and **Postcondition** (what must be true when it completes).

This addresses a fragility the toolkit's authors observed in `superpowers`: inter-skill contracts in that suite are implicit and can drift over releases without anyone noticing until a downstream skill receives unexpected input. Unleash's chain is engineered to be verifiable at every handoff. If `unleash:implementing` says it produces `.unleash/manifest.json`, then `unleash:validating` can explicitly check for that file in its precondition. Nothing is assumed; every handoff is inspectable.

The contract language is the same across all eight skills. Reading a skill's header section is sufficient to know exactly what it needs from upstream, what it delivers to downstream, and what must be true for it to start and stop. This makes the chain debuggable: if something goes wrong, you know which skill's postcondition was not met and what artifact is missing.

---

### 3.6 The two harness shapes

Unleash's chain explicitly supports two distinct shapes of harness, which have different end-of-life paths.

**Runtime harness.** The harness produces runtime artifacts in `.unleash/` — phase configuration files, guardian prompt files, optional hooks, settings patches. The harness is built to be used repeatedly: a metric-optimization loop that runs nightly, a coding discipline that governs an ongoing refactor. The manifest (`/.unleash/manifest.json`) tracks every file Unleash created or modified. End-of-life for a runtime harness is `unleash:archiving`, which bundles all lifecycle artifacts and dispatches a fresh independent reviewer for an end-of-life audit.

**Single-task harness (B-layer only).** The harness is entirely the dialogue itself: brainstorm → debate → plan → implement drives one bug fix or one feature. No runtime machinery is installed. The `.unleash/manifest.json` either does not exist or contains no runtime artifacts. End-of-life is `unleash:reporting`, which dispatches a fresh reviewer to cold-audit the git diff against the spec.

Both shapes are first-class. The toolkit explicitly supports both with mutually-exclusive end-of-life skills: each of the two skills detects the wrong harness shape and redirects to the other. A user who completes a single bug fix using Unleash's dialogue chain and then invokes `unleash:archiving` will be redirected to `unleash:reporting`, because no manifest exists.

The shapes also differ in what "end of life" means. A runtime harness has a lifecycle: it is built, run repeatedly, and eventually retired. The end-of-life question is "what did this harness accomplish over its lifetime, and what does a reviewer who has never seen the build process think of its design?" A single-task harness has no lifecycle: it drove one implementation, produced one diff, and is done. The end-of-life question is "does the diff match what the spec committed to, and what would a reviewer notice on a cold read?" Different questions require different reviewers with different inputs.

---

### 3.7 Discipline mechanisms

Several specific mechanisms appear across multiple skills to enforce discipline at the edges where AI rationalization is most tempting.

**HARD-GATE markers.** Each skill includes `HARD-GATE` blocks — imperative "do NOT" instructions that close specific rationalization paths the skill author anticipated. `unleash:brainstorming`'s HARD-GATE: "do NOT ask questions before completing Phase A silent context exploration." `unleash:implementing`'s HARD-GATE: "the terminal message must be strictly literal; do NOT add deployment steps or manual e2e instructions beyond invoking `unleash:validating`." These gates exist because the most common failures in AI-driven workflows are not random — they are predictable extrapolations that feel helpful in context.

**Anti-pattern Thought/Rebuttal pairs.** Each skill lists specific failure modes as paired thoughts and rebuttals. "This project is simple enough to skip debating" → "Complexity is not the criterion for skipping design. Skipping debating means the spec is not committed; implementing a harness from uncommitted brainstorm notes is a plan failure." These pairs preempt the specific rationalizations that have been observed to appear in AI-driven workflow sessions.

**Fresh-context cross-validation.** Validation runs as an independent agent with zero context from the implementing session — it receives only the harness artifacts and the original spec. Archiving dispatches a fresh reviewer that never saw the build, the validation report, or the plan. Reporting dispatches a fresh reviewer that sees only the spec and a filtered git diff. Fresh-context isolation appears at three independent points in the chain precisely because an agent that inherits the implementer's framing will tend to validate the implementer's assumptions rather than challenge them.

**Phase primitive vocabulary.** Harness phases are composed from six named primitives: `Read-Only`, `Restricted-Write`, `Script`, `Human-Check`, `AI-Judge`, and `Loop`. Each primitive has defined behavior, a typical allowlist shape, and typical gate conditions. This vocabulary is not a constraint on what harnesses can do — it is a shared language for designing and communicating them. A spec that says "phase 3 is a `Restricted-Write` phase writing only to `src/auth/`" is unambiguous; a spec that says "phase 3 does the implementation work" is not.

**The manifest as authoritative inventory.** `.unleash/manifest.json` is the single source of truth for what Unleash has installed. It records every file created or modified (with original-content SHAs for modified files), the install timestamp, and the skill version. `unleash:validating` uses it to check for orphaned artifacts. `unleash:walking-through` uses it to confirm every artifact is tracked. `unleash:archiving` uses it to scope the implementation snapshot. The uninstall script (`scripts/unleash-uninstall.sh`) reads it to reverse all changes, refusing to revert hand-edited files without explicit confirmation.

---

## 8 个 Skill 如何构成一套 Harness 开发系统

### 4.1 The chain at a glance

Two shapes, one shared core:

```
                     intent ("I want to harness X")
                                │
                                ▼
                       unleash:brainstorming
                  (silent context exploration → grounded
                   dialogue → committed brainstorm notes)
                                │
                                ▼
                        unleash:debating
                  (gap-driven challenge → committed spec.md)
                                │
                                ▼
                        unleash:planning
                  (Artifact Dependency Map + harness-construct
                   task groups → committed plan.md)
                                │
                                ▼
                       unleash:implementing
                  (fresh subagent per task → real harness code
                   + .unleash/manifest.json)
                                │
                                ▼
            ┌─────── decision: runtime artifacts installed? ───────┐
            │                                                       │
      YES (.unleash/manifest                               NO (manifest
      exists with runtime                                  absent or
      artifacts)                                          B-layer only)
            │                                                       │
            ▼                                                       ▼
    unleash:validating                                   unleash:reporting
    (harness-aware audit,                            (cold-review report from
     6 invariant checks)                              fresh reviewer)
            │                                        [end of single-task chain]
            ▼
    unleash:walking-through
    (first real run + intentional
     violation smoke test)
            │
            ▼
    [user runs harness for real work — indefinite duration]
            │
            ▼
    unleash:archiving
    (lifecycle bundle + fresh
     independent reviewer audit)
            │
            ▼
    [optional: scripts/unleash-uninstall.sh]
```

The left branch is the runtime harness path; the right branch is the single-task (B-layer only) path. Skills on both branches enforce mutual exclusion: if you try to run `unleash:archiving` on a B-layer harness, it stops and redirects to `unleash:reporting`.

User-approval gates separate every skill in the chain. No skill auto-invokes the next. The postcondition of each skill (artifact committed to git, user reviewed and approved) is the precondition of the next.

---

### 4.2 Per-skill walkthrough

#### 1. `unleash:brainstorming`

The entry point. Its defining discipline is sequencing: the skill runs three phases in strict order before any user-facing question is asked.

**Phase A (silent context exploration):** Read `README.md`, `CLAUDE.md`, package manifests, `git log --oneline -20`, top-level directory structure, representative source files, any existing `.unleash/` directory. This phase produces no user-facing output — only an internal model of the project. Asking questions before this phase completes is an explicit HARD-GATE violation.

**Phase B (hypothesis formation):** Based on Phase A observations, form hypotheses: what kind of project is this, what is the user plausibly wanting to harness, which of the 5 elements are likely applicable. Still internal.

**Phase C (grounded dialogue):** Only now does the skill ask questions. Every question must demonstrably reference a Phase A observation. "What is your constraint boundary?" (bad — context-free). "I see `src/auth/` has 40 files and recent commits suggest an active refactor there — is the constraint boundary the whole auth module, or a specific subtree?" (good — grounded). One question per turn, multiple-choice preferred, last option always "other / describe yourself."

**Produces:** `docs/unleash/brainstorm/<YYYY-MM-DD>-<name>.md` — brainstorm notes including the Phase A observation summary (so the silent exploration can be audited later), the harness intent, a case-type hypothesis (coding / metric / hybrid / freeform), a 5-element applicability sketch, and open questions carried forward to debating.

**Does not do:** produce a spec, propose phases, make design commitments. Brainstorming is generative (divergent). Design commitments are debating's job.

The separation between brainstorming and debating is not arbitrary. Generative mode (open exploration, hypothesis formation, question-asking) and critical mode (gap-driven challenge, convergence on commitments) benefit from distinct prompts and distinct states of mind. Mixing them in one skill produces sessions that feel productive but produce vague specs — the generative energy keeps reopening questions the critical energy should be closing. Keeping them separate means brainstorming can end with "here is what we know and what remains open" and debating can begin with "here is the map of gaps I need to close before writing the spec."

---

#### 2. `unleash:debating`

The convergence skill. Its defining discipline is that it is **gap-driven**, not template-driven. It does not iterate through a standard list of harness questions. It reads the brainstorm notes carefully, builds a cognitive gap map of what is concrete versus vague, and issues challenges grounded in specific passages.

The gap map has four categories: *vagueness* (where the user's statements are woolly vs. precise), *unstated assumptions* (design premises that might not hold), *reconstruction holes* (anything the skill cannot draw from the notes), and *5-element blind spots* (elements marked applicable but not yet specified concretely). Progress is measured by gaps closed, not questions asked.

Each challenge references a specific passage in the brainstorm notes and aims to produce one of three outcomes: concrete new content, explicit acknowledgment of a trade-off, or an explicit N/A with reason. The skill never accepts "I'll figure that out later" as an answer to a gap.

**Produces:** `docs/unleash/specs/<YYYY-MM-DD>-<name>-spec.md` — the formal harness design spec, with required sections: `case_type`, `five_element_analysis`, `phase_machine` (ordered phases, each with name, type, allowlist, entry gate, exit gate, artifacts consumed/produced), `guardian_design`, `optional_hooks`, and `out_of_scope`. No section may contain placeholders.

Debating is also the skill that captures `testing_mode`. When it probes the Quantifiable Feedback element for a coding-case harness, it surfaces a four-option question: (A) standard red-green TDD, (B) logical/manual checklist for human verification, (C) skip testing entirely, (D) other. The mode is recorded in the spec and propagates through planning's Test phase shape and implementing's subagent instructions. Without this probe, planning would default to TDD for every coding harness, which is wrong for the significant category of users whose work doesn't fit the automated test mold.

**Does not do:** produce a plan, propose implementation approaches, or lock in any artifact filenames. The spec is a design document — it specifies what the harness should do and why, not how to implement it.

The quality gate on the spec is structural: every required section must be present and non-placeholder. A section that says "guardian design: TBD" fails the gate. This is not bureaucratic formalism — it is the mechanism by which debating's rigor is preserved through to implementing. If the spec contains a gap, the plan will paper over it, and the implementing subagent will fill in the gap with a reasonable-but-wrong guess. Closing gaps in debating is cheaper than discovering them during a validation failure.

---

#### 3. `unleash:planning`

The implementation planning skill, built on `superpowers:writing-plans` discipline with harness-specific extensions. It inherits two non-negotiable iron laws from its parent: the zero-placeholder rule ("TBD", "TODO", "implement later", and "similar to Task N" are plan failures), and the 2–5-minute task granularity requirement (tasks that cannot be completed in 2–5 minutes are too coarse; tasks that are trivial sub-steps are too fine).

The harness-specific extensions are:

**Artifact Dependency Map.** A table that makes explicit, for every artifact the harness will produce, which task creates it and which downstream tasks consume it. This catches orphaned artifacts (produced but never consumed) and consumption gaps (consumed but never produced) before a single line of code is written.

**Task groups organized by harness construct.** Rather than a flat task list, the plan organizes tasks into: Group A (Phase Machine — config files, state file, phase entry/exit logic), Group B (Runtime Guardian — prompt file, invocation glue, rollback mechanism), Group C (Optional Hooks — only present if the spec declared irreversible operations), Group D (Walkthrough Scripts — for `unleash:walking-through` to execute). This structure makes the relationship between plan and harness architecture explicit.

**`testing_mode` branching** (added in v0.3.2). The plan extracts `testing_mode` from the spec's Quantifiable Feedback section and shapes the Test phase accordingly: mode A (TDD) produces a `Restricted-Write` test-writing task; mode B (manual checklist) produces a `Human-Check` task with a specific markdown checklist at a documented path and an explicit halt step; mode C (skip) omits the Test phase entirely; mode D (other) follows the spec's specification or stops if it is ambiguous.

**Produces:** `docs/unleash/plans/<YYYY-MM-DD>-<name>-plan.md`.

**Does not do:** implement anything, make decisions not in the spec, or mix multiple independent subsystems in one plan. If the spec governs a bounded harness, the plan governs the implementation of exactly that harness.

The plan's self-review (Phase D) is explicit about what it checks: Spec Coverage (does every spec requirement map to a plan task?), Placeholder Scan (zero "TBD" or "TODO"), Type Consistency (every artifact type is correct), Artifact Dependency Closure (no producing task without a consuming task, no consuming task without a producing task), Guardian Prompt Quality (the guardian prompt is reviewed as a first-class artifact, not "just a string"), and Testing-Mode Honored Check (the plan's Test phase matches the spec's `testing_mode`). This self-review is what separates a plan that will implement cleanly from a plan that will produce a validation failure two steps later.

---

#### 4. `unleash:implementing`

The controller skill. It dispatches **one fresh subagent per plan task** — not one subagent for the whole plan, not batches of related tasks. Each subagent receives the full task text pasted verbatim into its prompt. Subagents never read plan files; the controller reads the plan and delivers the text. This prevents the subagent from "reading ahead" and making decisions based on tasks it has not yet been assigned.

Each subagent also receives scene-setting: the harness case type, the guardian role summary (one sentence), and any upstream artifacts it should be aware of. The subagent reports DONE, BLOCKED, or NEEDS-CONTEXT. No deep review happens at this stage — that is validating's job.

As each task group is committed, the skill appends entries to `.unleash/manifest.json`. The manifest grows incrementally; each commit is a verifiable checkpoint. If implementing is interrupted mid-chain, the manifest reflects exactly what has been installed, allowing validating to audit the partial state.

**Produces:** Real harness code in the user's project — phase config files, guardian prompt files, optional hook scripts, settings patches, walkthrough scripts — plus `.unleash/manifest.json`.

**Does not do:** deep review, deployment, CI/CD configuration, or anything past the boundary of "committed code in the user's project." The HARD-GATE on the terminal message is explicit: no "next steps beyond invoking `unleash:validating`."

The one-subagent-per-task dispatch pattern has two key properties worth understanding. First, each subagent starts with zero context from prior tasks — it has no memory of what previous subagents decided or what code they wrote, except through the shared repository state. This means each subagent must be given complete, self-contained instructions; it cannot rely on "you know what the previous task did." The controller (implementing) takes responsibility for ensuring each task's prompt is complete. Second, subagents never read the plan file — they receive the task text pasted directly. This prevents the failure mode where a subagent reads adjacent tasks and "helpfully" combines them or skips ahead. Task N's subagent implements task N; tasks N+1 through N+M are not its concern.

The cost of this pattern is overhead: N tasks means N subagent invocations, each with a fresh context load. The benefit is predictability and debuggability: each task's implementation is isolatable, each subagent's commit is traceable, and a failure in task N does not contaminate tasks N+1 through N+M. For harness implementation — where correctness is the goal, not throughput — this is the right trade-off.

---

#### 5. `unleash:validating`

The build-time audit skill. It runs as an independent agent with a fresh context — it receives the harness artifacts and the original spec, and nothing from the implementing session. This isolation is the point: an agent that inherits the implementer's framing will tend to confirm the implementer's assumptions.

The skill runs eight checks, six of which are harness-specific invariants:

1. **Allowlist cross-phase consistency** — phase N's output paths are included in phase N+1's readable paths. No silent handoff gaps.
2. **Guardian-phase alignment** — the guardian's review scope is a superset of the phase's action surface. No blind spots.
3. **Irreversibility gating** — every operation the spec declared irreversible is hook-gated, not guardian-gated. Post-hoc review is not sufficient for irreversible actions.
4. **Artifact contract closure** — every artifact has both a producer and a consumer. No orphans.
5. **Loop termination** — all Loop-typed phases have bounded exit conditions (max iterations, early-stop criteria, external signal). Unbounded loops are a spec failure.
6. **Decide determinism** — all Decide phases specify whether the decision is script, AI-judge, or human-check, and who executes the resulting git operation.

Plus two generic checks: spec coverage (every requirement maps to an artifact) and code quality (artifacts have clear single responsibility).

The skill reports findings without modifying anything. It is re-runnable at any time — the user can edit a phase config after initial implementation, re-invoke `unleash:validating`, and get a regression audit without re-running the full chain. This re-runnability is deliberate: a harness is a living artifact during its operational lifetime, and the user should be able to edit it (add a phase, adjust an allowlist, refine a guardian prompt) and verify the edit without going back through the full build chain.

**Produces:** `docs/unleash/validation/<YYYY-MM-DD>-<name>-validation.md` — pass/fail on each check, specific issue locations, suggested fixes.

**Does not do:** fix issues, edit harness files, or auto-advance to walking-through. Its scope is audit-only.

In real-world testing, `unleash:validating` caught a 4th invariant violation in a session where only 3 had been deliberately seeded — an unplanned bonus that demonstrated the value of having a fresh-context auditor who reads the harness with no prior framing. The validator found what the implementer missed because the implementer knew what they intended; the validator only knew what was written.

---

#### 6. `unleash:walking-through`

The first-run skill. Static validation is necessary but not sufficient; a harness that passes all invariant checks can still fail in practice if the guardian prompt is misunderstood, if the allowlist has an edge case, or if the hook trigger condition is wrong. Walking-through is the step that **drops on the safety net** to verify it holds weight.

The skill drives a real phase 0 → phase 1 transition on an actual task (not a toy fixture). It then deliberately attempts a known allowlist violation — editing a file outside the configured allowlist — and verifies that the guardian fires and `git reset --hard` rolls back. If an irreversible hook is installed, it scripted-attempts the hook trigger and verifies the block. These are not optional: a harness whose guardian has never been shown to fire is not a validated harness.

The first-run record captures: what task was used, what violation was attempted, whether the guardian fired correctly, whether rollback succeeded, and whether the hook (if present) blocked as expected. If any test fails, the skill returns to validating for remediation before proceeding.

**Produces:** `docs/unleash/walkthroughs/<YYYY-MM-DD>-<name>-first-run.md`.

**Does not do:** run multiple iterations, evaluate the harness on real work, or hand off to the user until all smoke tests pass.

The walking-through skill occupies an unusual position in the chain: it is the only skill that interacts with a running harness rather than a harness-under-construction. All prior skills operate on specs, plans, and implementation artifacts as static documents. Walking-through operates on the harness as a live system — it invokes the phase machine, triggers the guardian, and observes behavior. This is why it is a distinct skill and not merged into validating. Static code analysis (validating) and dynamic behavior verification (walking-through) are different claims. A harness that passes all six invariant checks may still have a guardian prompt that the guardian misinterprets at runtime. Walking-through catches that; validating cannot.

---

#### 7. `unleash:archiving`

The runtime-harness end-of-life skill. Triggered by the user when a runtime harness has fulfilled its purpose. It bundles all lifecycle artifacts — brainstorm notes, spec, plan, validation report, walkthrough record, and an implementation snapshot of every harness file as of archival — into `.unleash/archives/<YYYY-MM-DD>-<name>/`.

The defining discipline is the **fresh reviewer**. The review agent is dispatched as a fresh subagent with zero context from any prior Unleash stage. It receives only: the archived spec and the implementation snapshot. It does not receive the plan, the implementer's reasoning, the validator's prior report, the validation findings, or the walkthrough record. This is the strictest isolation the toolkit offers, and it is deliberate: the goal is an end-of-life perspective that cannot be contaminated by the build-time framing.

The reviewer writes `review.md` as narrative markdown (not a checklist), covering six dimensions: faithfulness (does implementation fulfill spec, and where it deviates, is the deviation an improvement or regression?), quality (code cleanliness, guardian prompt clarity), guardian robustness (were there blind spots the validator didn't catch?), hook appropriateness (were hooks used where guardian would have sufficed?), observability (can a future maintainer understand this harness from its artifacts alone?), and lessons learned (what specific patterns would the reviewer recommend or warn against for next time?).

**Produces:** archive bundle at `.unleash/archives/<YYYY-MM-DD>-<name>/` + `review.md`.

**Does not do:** uninstall harness files (that is `scripts/unleash-uninstall.sh`'s job), modify the live harness, or perform any of validating's build-time checks. Archive is preservative; uninstall is destructive. They compose: archive then uninstall = "keep the record, remove the machinery."

---

#### 8. `unleash:reporting`

The single-task end-of-life skill — the B-layer-only counterpart to archiving. Used when Unleash drove the dialogue (brainstorm → debate → plan → implement) but no runtime harness was installed. The mutual exclusion is enforced: this skill stops and redirects to `unleash:archiving` if a manifest is present.

The fresh reviewer here receives only the spec and a **pathspec-filtered git diff** — filtered using `git diff -- ':!docs/unleash/'` to exclude Unleash's own documentation commits from the diff, retaining only the code changes the plan produced. The filtering uses git pathspec syntax, not grep on commit messages — an important distinction captured in the skill's anti-patterns, because a commit whose message mentions `docs/unleash/specs/...` in prose but only touches `src/logger.py` should be included, not excluded.

The reviewer covers four dimensions: faithfulness (diff matches spec commitments), quality (code is clean, no scope creep), completeness (nothing the spec required is missing from the diff), and open questions (what the reviewer would probe if doing a follow-up code review). The output is 300–600 words — substantive but lightweight, appropriate for a single coding task rather than a multi-week harness lifecycle.

**Produces:** `docs/unleash/reports/<YYYY-MM-DD>-<name>-report.md`.

**Does not do:** lifecycle bundling, implementation snapshots, or any of the six guardian/hook audit dimensions that archiving covers. Reporting is a diff-audit; archiving is a lifecycle-audit.

---

#### Skill interactions: what the table of contracts looks like

The following table captures the full chain in contract form:

| Skill | Consumes | Produces |
|-------|----------|----------|
| `unleash:brainstorming` | User intent + project tree | `docs/unleash/brainstorm/<date>-<name>.md` |
| `unleash:debating` | `brainstorm.md` (committed) | `docs/unleash/specs/<date>-<name>-spec.md` |
| `unleash:planning` | `spec.md` (committed, validated) | `docs/unleash/plans/<date>-<name>-plan.md` |
| `unleash:implementing` | `plan.md` (committed) | Harness code + `.unleash/manifest.json` |
| `unleash:validating` | Manifest + harness + `spec.md` | `docs/unleash/validation/<date>-<name>-validation.md` |
| `unleash:walking-through` | Validated harness + walkthrough scripts | `docs/unleash/walkthroughs/<date>-<name>-first-run.md` |
| `unleash:archiving` | User signal + manifest + all prior artifacts | `.unleash/archives/<date>-<name>/` + `review.md` |
| `unleash:reporting` | User signal + `spec.md` + filtered git diff | `docs/unleash/reports/<date>-<name>-report.md` |

Every "committed" qualifier in the Consumes column is a gate: the skill explicitly checks that the upstream artifact is committed to git before proceeding. An artifact that exists on disk but hasn't been committed is not sufficient — the commitment is what makes the artifact a verifiable checkpoint.

---

### 4.3 Why this composition works

The chain is **linear with mandatory user-approval gates** between every skill. No skill auto-advances. The user must approve the brainstorm notes before debating starts, approve the spec before planning starts, approve the plan before implementing starts, and so on. This is not merely workflow hygiene — it is the mechanism by which the user remains the authoritative designer. The AI executes; the user approves. Every artifact that crosses a gate is git-committed, so context compression cannot silently lose a design decision.

Each skill's HARD-GATE makes scope boundaries unambiguous. The AIs executing these skills are not relying on good judgment to know where to stop — they have explicit, imperative instructions that close the most tempting extrapolation paths. The gates were identified empirically: each one closes a rationalization that appeared in at least one real-world test session.

**Cross-validation by fresh-context agents appears at three independent points:** validating (build-time, no implementing context), archiving's reviewer (end-of-life for runtime harnesses, no build context), and reporting's reviewer (end-of-life for single-task work, only spec + diff). Three independent reads at different lifecycle stages, each without the prior read's framing, is the toolkit's core reliability guarantee. The independence is strict: the archiving reviewer explicitly does not receive the validation report — not because the report is secret, but because an end-of-life reviewer who has already read the build-time auditor's conclusions will tend to adjudicate those conclusions rather than form independent ones.

The manifest is the **spine** of the runtime-harness path. Implementing produces it (growing it with each task commit). Validating reads it to check for artifact closure. Walking-through reads it to confirm all installed files are tracked. Archiving reads it to scope the implementation snapshot. Uninstall reads it to reverse every change. Every skill that touches a runtime harness touches the manifest; no skill invents its own inventory.

The two-shape design (runtime harness vs. single-task) is intentional rather than accidental. When Unleash was designed, the dominant mental model of "harness" was the autoresearch-style runtime machine. But in practice, a significant portion of the work developers actually want to do with AI is bounded: fix this bug carefully, implement this feature with discipline, don't drift. For that work, there is no machine to install — only the dialogue. Making the B-layer-only path a first-class citizen rather than an afterthought meant designing `unleash:reporting` as a genuine end-of-life skill with its own fresh reviewer, not simply skipping archiving. The v0.3.1 release made this path explicit. The v0.3.1 release note captures the motivation: a real-world user test discovered the gap when the user tried to invoke `unleash:archiving` on a B-layer task and correctly got redirected — but had nowhere to go. `unleash:reporting` filled that gap.

---

### Attribution and lineage

Unleash internalizes patterns from two external sources:

**Superpowers (Obra Labs)** — the workflow discipline patterns: skill structure, HARD-GATE markers, anti-pattern Thought/Rebuttal pairs, the spec → plan → execute chain, and subagent-driven development. Unleash does not import superpowers as a dependency — it internalizes the patterns into its own skill implementations. The design goal was zero runtime dependency on external skill packages at the user-facing layer.

**Karpathy's autoresearch** — the minimal harness design philosophy: frozen oracle, minimal action surface, single scalar metric, git atomic keep/discard, TSV long-term memory. These five design choices are the canonical example of a metric-optimization harness done with elegance. They serve as the reference implementation for the metric-case starter pattern in `references/unleash-knowledge.md §2`.

**creative-agents-harness (haokun, 2026)** — a production-grade autoresearch implementation for PPT optimization. Source of practical lessons on phase-level tool allowlists, per-iteration artifact organization, and graceful shutdown. This is the harness that motivated several of the allowlist-consistency and loop-termination checks in `unleash:validating`.

The knowledge base (`references/unleash-knowledge.md`) synthesizes these sources into eight sections of reference material: the 5-element framework (§1), common starter patterns (§2), phase primitive vocabulary (§3), runtime guardian design patterns (§4), hook vs guardian decision guide (§5), common pitfalls (§6), vocabulary (§7), and project filesystem layout (§8). This knowledge document is read by skills throughout the chain; it is the conceptual substrate that makes skill-first design possible.

---

**A note on what the chain is not.** The chain is not a project management tool. It does not track tasks, assign tickets, or manage sprints. It governs the design and construction of a single harness, from intent to first verified run. After walking-through, the harness belongs to the user and runs under the user's control. Unleash has no opinion about what the harness does, how many times it runs, or what the user does with the results. Its scope ends at "the harness is built and verified." What happens next is the user's.

Similarly, the chain is not a replacement for code review, test suites, or CI/CD. It is a discipline layer that sits *above* those things — it ensures the harness is designed with intention before any of those downstream processes run through it. A well-designed harness that enforces TDD discipline still relies on the developer's test suite to catch functional bugs. Unleash designs the constraint; the constraint governs the AI; the AI produces code; the code still needs to pass the project's existing quality gates.

---

---

## The Journey and What's Left

The design for Unleash was written in a single spec — `2026-04-24-unleash-toolkit-design.md` — and built across three implementation plans over the following 24 hours: Plan 1 produced the first two skills (brainstorming and debating) at v0.1.0; Plan 2 produced planning and implementing at v0.2.0; Plan 3 produced validating, walking-through, and archiving at v0.3.0. Three follow-up patches followed over the next day, two of which came directly from real-world test feedback.

**v0.2.1** tightened implementing's terminal message after a test exposed that the AI was helpfully appending deployment steps the spec didn't authorize. The implementing skill's scope is "committed code in the user's project." Deployment, push, CI/CD, and release tagging are explicitly out of scope — the spec governs the plan's reach, and the plan ends at the git boundary. The HARD-GATE on the terminal message was added to make this unambiguous.

**v0.3.1** added the reporting skill after a user completed a bug fix through the full dialogue chain, tried to archive it, and discovered the gap: `unleash:archiving` correctly stopped because no manifest existed, but there was nowhere to go. The dialogue had value — the brainstorm → debate → plan → implement chain had disciplined the entire implementation — but that value had no end-of-life artifact to show for it. `unleash:reporting` filled that gap with a lightweight cold-review report.

**v0.3.2** closed a specific misalignment in the planning → implementing handoff. v0.2.1 had added a `testing_mode` probe to debating so the spec would capture whether the user wanted TDD, a manual checklist, no testing, or something else. But planning still treated all Test phases as TDD — it wrote pytest tasks regardless of what the spec said. For users doing UI flows, browser integration tests, or judgment-call verification — the users most likely to need harness discipline precisely because their testing doesn't fit the automated mold — this meant spec captured intent that the plan silently ignored. v0.3.2 closed the loop: spec → plan → implement now respects `testing_mode` end-to-end, verified on a live `testing_mode: B` fixture (a Flask login UI bug) with 5/5 rubric checks.

The design held up under use. None of the three patches required revisiting the core philosophy. All were scope refinements at the edges — boundaries that the spec's core principles clearly implied but that the initial implementation hadn't made explicit enough for the AI to enforce reliably. This is the expected pattern for a toolkit of this kind: the philosophy is stable; the edges sharpen with use.

**Current state:** 8 skills, 6 git tags (v0.1.0 through v0.3.2), a knowledge base with 8 sections, a `scripts/unleash-uninstall.sh` for manifest-driven mechanical uninstall, and stress-test scenarios covering the main invariant-violation paths for validating, the guardian-fires-on-violation path for walking-through, and the fresh-reviewer-blind path for archiving. The full-chain integration scenario at `tests/scenarios/integration/full-chain.md` serves as the manual end-to-end verification fixture — a complete runbook for a first-time user who wants to verify the toolkit behaves as specified before building their first real harness. One open question from the original spec remains unresolved: §10.4 (marketplace publishing — how the `unleash:` namespace is distributed to other users). Everything else in §10's open-question list was resolved during the three build plans.

**Future:** as real users hit new edge cases, more patches. The pattern is established: discover a gap, write a test scenario for it, patch the relevant skill, verify the patch closes the gap. No redesigns unless the philosophy proves wrong. And eventually, marketplace publication — so that other developers who have the same problem of "I want to harness X and I'm starting from a blank page" can pick up the toolkit without being the original author. The spec's §10.4 open question on marketplace distribution is the last remaining design decision; everything else shipped.

---

### Going deeper

If the architecture description above raises questions about specific mechanisms — what exactly constitutes a well-formed guardian prompt, how allowlists should be written for a phase that invokes shell scripts, what the difference is between a Human-Check and an AI-Judge phase — the knowledge base (`references/unleash-knowledge.md`) is the right place to go. It is organized as a reference document, not a tutorial, so reading it linearly is not required; jump to the section you need.

The sections most useful before a first invocation of `unleash:brainstorming`:

- **§1 (The 5-Element Framework)** — understand the five elements and their N/A criteria before brainstorming; the skill will use these as probes and the conversation goes faster if you've read the vocabulary
- **§2 (Common Starter Patterns)** — the coding pipeline and metric loop patterns, so you recognize them when brainstorming offers them as suggestions
- **§3 (Phase Primitive Vocabulary)** — the six phase types; knowing these makes debating's phase_machine section much more concrete

The sections most useful before invoking `unleash:debating`:

- **§6 (Common Pitfalls)** — the seven harness anti-patterns; knowing what they look like helps you recognize when debating is challenging you toward avoiding one

The sections most useful after `unleash:implementing` completes:

- **§5 (Hook vs Guardian Decision Guide)** — review this before validating if you are uncertain whether any operations in your harness should have been hook-gated
- **§8 (Project Filesystem Layout)** — the canonical `.unleash/` and `docs/unleash/` directory conventions; verify your implementation follows them before invoking validating

---

The toolkit is documented and maintained at `https://github.com/haokun/unleash` (not yet public). The design spec lives in the `present-tools` repository at `docs/superpowers/specs/2026-04-24-unleash-toolkit-design.md`. The CHANGELOG captures every release decision, including the rationale and verification status for each patch. If you want to understand *why* a specific HARD-GATE or anti-pattern exists, the CHANGELOG for the relevant version usually has the real-world test that motivated it.

---

If you've gotten this far and want to try Unleash, see `README.md` for installation and your first invocation of `unleash:brainstorming`.
