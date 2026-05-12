# Unleash Knowledge Base

> **Nature:** This is a reference document, not a template library. Skills
> read from it to enrich conversations with the user. Nothing in here is
> meant to be "applied" to a user's harness mechanically — every section is
> descriptive knowledge that informs conversation.

## Table of Contents

1. The 5-Element Framework
2. Common Starter Patterns
3. Phase Primitive Vocabulary
4. Runtime Guardian Design Patterns
5. Hook vs Guardian Decision Guide
6. Common Pitfalls
7. Vocabulary
8. Project Filesystem Layout

---

## 1. The 5-Element Framework

The 5-element framework is the questioning backbone of harness design — not a checklist to complete, not a schema to fill in. When a skill engages a user in brainstorming or debating, it uses the five elements as lenses for probing what the harness needs to be reliable. Crucially, the elements are never "applied" wholesale: each element is interrogated for applicability first, and if a given harness has no meaningful expression of that element, it is marked N/A with an explicit reason and skipped in all downstream artifacts. Forcing an element onto a harness design that doesn't need it produces boilerplate rather than useful specification. The five elements in order are: Constraint Boundary, Quantifiable Feedback, State Persistence, Reversibility, and Autonomy.

---

### 1.1 Constraint Boundary

**Definition**

The constraint boundary is the explicit specification of what the AI agent running the harness is permitted to read, write, and execute during each phase. It answers the question "what is the harness's action surface?" at the level of real file paths, tool categories, and system calls. A constraint boundary is not a vague statement like "work in the auth module" — it is a per-phase allowlist: the set of file paths the agent may write, the set it may only read, and whether it may invoke arbitrary shell commands or only a named whitelist. The boundary is dynamic across phases (a property sometimes called "L2 dynamism"): phase 1 may permit reads everywhere but writes only to `docs/spec.md`, while phase 2 permits writes to `src/` but not `tests/`, and phase 3 opens `tests/` as well. Each phase has its own boundary shape, and the full constraint boundary of the harness is the union of all per-phase boundaries with their temporal scoping.

**Why it matters**

An under-specified constraint boundary produces a harness that is nominally constrained but practically unconstrained. If the spec says "work in `src/auth/`" without distinguishing read vs write and without scoping to phases, the guardian cannot determine whether a write to `src/config.py` is a violation or a legitimate side-effect of the assigned work. Ambiguity at this level propagates: the guardian prompt cannot be precise, the allowlist cross-phase consistency check cannot be run, and when something goes wrong, no one can say definitively whether the agent violated the harness or the harness was simply under-specified. An even more serious failure mode is allowlist drift: phase N writes to a path that phase N+1's read allowlist doesn't include, creating a silent gap where produced artifacts become invisible to the next phase.

**Applicability probes**

- Are there directories or files in this project that the agent must not touch under any circumstances during this harness's run?
- Does the set of permitted writes change from one phase to the next, or is the agent's write surface the same throughout?
- Does the harness involve any shell command execution beyond reading and writing files (e.g., running tests, invoking a build system, calling an external API)?
- If two phases run back-to-back, does phase N+1 need to read everything phase N wrote — or only a specific subset?

**Typical N/A reasons**

N/A for Constraint Boundary is almost never legitimate. Every harness where an AI agent acts on a real project has an action surface, and leaving it unspecified is not a design choice — it is a design omission. The only arguable N/A case is a harness where the agent is entirely read-only and produces no artifacts (for example, an analysis skill that only emits a spoken summary). Even then, specifying "write allowlist: empty" is better than marking it N/A, because it makes the read-only constraint explicit and enforceable. If a user says "the agent can just work wherever it needs to," that is a gap to close in debating, not a valid N/A.

**Example probe question with two answer shapes**

Probe: "I can see your project has a `src/` directory and a `tests/` directory at the top level. During the implementation phase of this harness, should the agent be allowed to write to both, or only to `src/` while keeping `tests/` read-only until a later phase?"

- *User says: "It should only touch `src/auth/` — tests are written by a human first in this workflow."* This surfaces a Restricted-Write constraint on `src/auth/` for the implementation phase, a Read-Only constraint on `tests/`, and implies a Human-Check or separate Test phase where the human writes tests before the agent touches source. The allowlist for implementation is now concrete.
- *User says: "I haven't thought about that. It can probably work wherever it needs to."* This is a non-answer that the skill must not accept at face value. Follow up: "The reason I'm asking is that if the agent writes tests first and then implementation, or vice versa, the order matters for the guardian to know which writes are expected at each step. Which comes first in your mental model of this workflow?" The goal is to converge on a concrete per-phase write allowlist, not to accept vague permission.

---

### 1.2 Quantifiable Feedback

**Definition**

Quantifiable feedback is the signal the harness uses to determine whether a phase or iteration produced progress. It answers the question "how does the harness know it's getting better?" The signal must be defined precisely enough that either a script or an AI judge can evaluate it deterministically or near-deterministically on each run. Feedback signals come in several forms: scalar (a single numeric value, like a BLEU score or test pass percentage), binary (pass/fail, typically from a test suite), multi-dimensional (a vector of metrics, which may require a weighting scheme or Pareto filter), and human-judgment (a human evaluates the output and records a structured verdict). The key distinction is between a feedback signal that is machine-evaluable and one that requires human interpretation. Both are valid, but they imply very different harness designs — a machine-evaluable signal enables a fully autonomous metric loop, while a human-judgment signal requires explicit Human-Check phases and cannot support unattended iteration.

**Why it matters**

Without a concrete feedback signal, the harness has no basis for a Decide phase — the agent cannot know whether to accept or discard a run, and the human cannot verify that progress is happening. The most common failure mode is a user who says "I'll know it when I see it" as their feedback description. This is not a valid feedback signal; it is an acknowledgment that the feedback signal hasn't been designed yet. A harness built on "I'll know it when I see it" will require human intervention on every iteration, which is fine if that's the intended design, but then it must be encoded as a Human-Check phase with a specific structured output (e.g., a checklist the human fills in), not treated as implicit. Another common failure: a feedback signal that looks scalar but is secretly multi-dimensional (e.g., "test pass rate" hides the fact that some tests matter more than others, and a run that breaks a critical test while fixing minor ones looks like progress by raw count).

**Applicability probes**

- After one iteration of this harness completes, what will you look at to decide whether to keep the result or roll it back?
- Is that signal something a script can compute automatically, or does it require you to look at it and make a judgment call?
- If the signal improves by 1% but a different quality dimension gets worse, is that still a "keep" decision?
- Are you willing to write down the exact criteria for a "keep" decision before the harness runs, or does it depend on context each time?

**Typical N/A reasons**

N/A for Quantifiable Feedback is legitimate when the user explicitly wants "human feels it" as the only signal — meaning the harness is intentionally not trying to automate the judgment, and every iteration terminates at a Human-Check phase where the human decides. This is a coherent design, but it must be stated explicitly: the N/A rationale must say "feedback is human-only judgment; no machine-evaluable signal is intended; all decision phases are Human-Check." This distinguishes a deliberate human-in-loop design from a harness where the feedback signal simply hasn't been defined yet. The phrase "I'll know it when I see it" is never a valid N/A reason — it is a gap to close, not a design decision.

**Example probe question with two answer shapes**

Probe: "You mentioned the goal is to improve the quality of the generated summaries. If I asked you to write down, right now, what a 'good' summary looks like versus a 'bad' one, could you give me three concrete criteria?"

- *User says: "Yes — the summary should be under 100 words, cover all three key topics from the source, and not introduce facts not present in the source."* This is a machine-evaluable multi-dimensional signal: word count is scriptable, topic coverage could be an AI-Judge rubric, hallucination detection is an AI-Judge task. The harness can use an AI-Judge phase with a pinned rubric covering all three criteria.
- *User says: "Not really — it's more of a feel thing. Different summaries work for different purposes."* This is a human-judgment signal. The skill should follow up: "That's a valid choice, but it means every iteration needs you to evaluate the output personally. Is that workable for how many iterations you're expecting to run? And can we write down even a loose checklist that captures your 'feel' criteria so the human-check phase has a structured artifact?" The goal is either to convert "feel" into a rubric, or to explicitly commit to a Human-Check design.

---

### 1.3 State Persistence

**Definition**

State persistence describes how the harness maintains information across phases, across iterations of a loop, and across restarts. It addresses three distinct sub-questions: durability (if the harness is interrupted and restarted, what state survives and what is lost?), indexability (can the harness query its own history — e.g., "show me the last 10 iteration results" — or is state write-once and opaque?), and concurrency (if two harness runs happen simultaneously — either by accident or by design — does state become corrupted or ambiguous?). A harness where state is a single file written and overwritten on each iteration has poor indexability but simple recovery. A harness where each iteration writes to a timestamped directory has good indexability but requires a naming convention and a reading discipline. A harness with no persistence mechanism at all must either be single-shot (no retries, no history) or relies entirely on git history as its state store.

**Why it matters**

Under-specified state persistence leads to harnesses that are fragile on interruption and opaque to their operators. The most common failure is a harness that "works" during a clean run but becomes unrecoverable after any interruption — the guardian doesn't know which iteration was in progress, the human can't tell whether the last committed state is consistent, and restarting from scratch wastes all prior progress. A subtler failure is a harness where state accumulates indefinitely with no cleanup plan, consuming disk or making the history database so large that indexing becomes slow. Concurrency is frequently overlooked: users who run harnesses manually assume single-runner semantics, but automated harnesses (e.g., triggered by CI or by a cron job) may run in parallel, and without explicit concurrency handling, state files become a race condition.

**Applicability probes**

- If this harness is interrupted mid-run, what should happen when it resumes: start over from scratch, or pick up from the last completed phase?
- Does the harness need to look back at results from previous iterations to make decisions in the current one?
- Is it ever possible for two instances of this harness to run at the same time, even accidentally?
- How long should state be kept: indefinitely, until the harness completes, or for some fixed rolling window?

**Typical N/A reasons**

N/A for State Persistence is legitimate only when the harness is genuinely single-shot and never retries. "Single-shot" means: it runs once on a bounded task, it is not part of a loop, there is no concept of resuming from a checkpoint, and the user has explicitly confirmed that if it fails, they will restart from the beginning without needing any prior state. An example where this is true: a one-time spec-writing phase that transforms a requirements document into a spec file. If it fails, the user simply re-invokes it. There is no state to persist because there is no history to consult and no partial progress to resume. If there is any ambiguity about whether the task might retry or iterate, state persistence should be marked applicable, not N/A.

**Example probe question with two answer shapes**

Probe: "If this harness is running an optimization loop and crashes at iteration 47, would you want to restart from iteration 1 or from iteration 47?"

- *User says: "Definitely from iteration 47 — I don't want to re-run 46 iterations."* This means the harness needs durable per-iteration state: each iteration's result must be committed to a persistent store (e.g., a `runs/iter-N/` directory structure) before the next iteration begins. The guardian must verify that iteration N's artifacts are present and well-formed before allowing iteration N+1 to start. The spec needs a state schema and a recovery procedure.
- *User says: "I'd restart from scratch — each run is fast and I don't care about prior results."* This is a legitimate single-shot semantics even within a loop, but the skill should probe: "How fast is a run? If it's under 30 seconds, restarting is fine. But if it ever takes 5+ minutes, you might change your mind at iteration 47." If the user confirms, N/A is acceptable with the rationale "single-shot semantics; restart from scratch on failure; run time is sufficiently short."

---

### 1.4 Reversibility

**Definition**

Reversibility describes the degree to which each phase's actions can be undone if something goes wrong, and the mechanism by which that undoing happens. A reversibility specification must cover three aspects: the rollback mechanism (how do you undo a phase's outputs — git reset, file backup, snapshot, database transaction rollback, or none?), atomicity (is each phase atomic — either fully applied or fully reverted — or can a phase leave the system in a partial state?), and the recovery procedure (what does the human or guardian do when a rollback is triggered — what commands, in what order, and what is the expected resulting state?). Reversibility applies per-phase, not to the harness as a whole: some phases may be fully reversible (file edits under git), while others may not be (sending an email, publishing a package). Irreversible phases require special treatment (see §5 Hook vs Guardian Decision Guide).

**Why it matters**

A harness with unspecified reversibility is a harness where failures are handled ad hoc. When an agent produces a bad output and the guardian triggers rollback, "rollback" must mean something precise and executable — not a vague gesture toward git. If the spec says "git can handle rollback" without specifying which branch, which commit, and who runs the command, the guardian prompt cannot include a concrete rollback instruction, and the human will be left wondering what state the repository is in. Atomicity matters because partial-state failures are often the hardest to recover from: if a phase writes to 10 files and crashes after writing 5, is the harness in a valid state? If not, what is the rollback target?

**Applicability probes**

- If the agent produces a bad output in any phase, what is the exact sequence of commands you would run to undo it?
- Does this harness interact with anything outside the git repository (an API, a database, an external service)? If so, can those interactions be undone?
- Is it possible for a phase to partially complete — writing some but not all of its intended outputs — and if so, is a partial output recoverable or must it be discarded?
- Have you identified any operations in this harness that are irreversible by nature (deletes, external calls, publishes)?

**Typical N/A reasons**

N/A for Reversibility is legitimate when all operations in the harness are either purely read-only or commutative — meaning applying them again after a failure produces the same result as the first application, so there is nothing to roll back. An example: a harness that only reads files and produces an analysis document. If the analysis is wrong, you simply re-run it. The output file is overwritten, not accumulated, so there is no rollback to perform. Another example: a harness where every write is idempotent and re-running any phase from the beginning produces a clean state. In these cases, the N/A rationale should say "all operations are idempotent/read-only; rollback is equivalent to re-run."

**Example probe question with two answer shapes**

Probe: "When you say 'git can handle rollback,' what exactly does that look like in practice? If the agent writes a bad implementation in the Impl phase, what is the exact git command you'd run, and from which branch?"

- *User says: "I'd run `git reset --hard HEAD` to undo the last commit, since each phase commits its work."* This is a concrete rollback mechanism. The harness is designed with one commit per phase, and the rollback target is the previous commit. The guardian can include the specific rollback command. The atomicity model is: each phase is a single commit, and a partial phase produces no commit (the agent is instructed to commit only on phase completion). This is a fully specified reversibility design.
- *User says: "I'd just discard the changes manually — I haven't thought about committing per phase."* This reveals that the commit structure hasn't been designed. The skill should follow up: "If you're relying on manual recovery rather than a script, the guardian can't automate rollback. Two options: (a) we define a commit-per-phase discipline so `git reset --hard` is unambiguous, or (b) we accept that rollback requires human intervention and document that explicitly in the spec. Which is more consistent with how you work?" This surfaces a real design choice rather than papering over it.

---

### 1.5 Autonomy

**Definition**

Autonomy describes how much the harness is designed to run without human intervention, and what safeguards govern unattended execution. A fully autonomous harness runs from start to finish (or through an entire optimization loop) without pausing for human input, governed only by the guardian and any hooks. A fully attended harness pauses at every phase transition for human review and approval. Most real harnesses fall somewhere between these extremes: autonomous within phases, human-approved at phase boundaries. The autonomy specification must cover: the intended runtime mode (fully unattended, attended at phase boundaries, or attended at specific decision points), the human-in-loop fallback (what happens if the harness reaches a state that its automation cannot resolve — does it halt and wait, alert the human, retry with a default decision, or abort?), and the resource budget (maximum iterations, time budget, cost budget, or early-stop criteria that bound how long the harness can run without human oversight).

**Why it matters**

An under-specified autonomy element produces harnesses that are either dangerously overpowered or frustratingly timid. The "3am scenario" is the canonical failure: a harness designed for attended use starts running at 11pm, the human goes to sleep, it reaches a decision point it can't resolve, and by 3am it has either been spinning on retries, has made a large number of irreversible bad decisions, or has consumed all available API budget. Conversely, an over-cautious autonomy spec that requires human approval for every micro-decision defeats the purpose of a harness. The autonomy element forces an explicit decision about where human oversight is genuinely necessary versus where it is habitual caution.

**Applicability probes**

- Is there any phase in this harness where you expect the agent to run without you watching?
- If the harness reaches a point where its next decision is ambiguous (e.g., two options look equally valid), should it pick one and continue, pause and ask you, or abort?
- Have you set a budget for how many iterations or how much time this harness is allowed to run before it must halt and report?
- What happens if you lose connectivity or fall asleep while the harness is running — is there a safe default behavior?

**Typical N/A reasons**

N/A for Autonomy is explicitly legitimate for coding-case harnesses where a human is always present. In a coding pipeline where the developer is sitting at the keyboard approving each phase transition, there is no "unattended runtime" to govern, no 3am scenario, and no max-iters to bound. The N/A rationale should say "human always present; no unattended runtime; all phase transitions require explicit human approval; autonomy element does not apply." This is distinct from marking Autonomy N/A because the developer hasn't thought about it — the rationale must confirm that the harness is intentionally attended. A harness with even one loop phase should have Autonomy specified, because a loop by definition can run multiple iterations without a per-iteration human gate.

**Example probe question with two answer shapes**

Probe: "If the optimization loop runs overnight and at iteration 30 the evaluation script returns an error — not a bad score, but an actual crash — what should the harness do: keep trying, wait for you, or shut down safely and leave a record?"

- *User says: "It should shut down and leave a record. I don't want it retrying if something is actually broken."* This defines an early-stop condition: the harness must distinguish between "bad score" (keep running, possibly discard this iteration) and "evaluation script failure" (halt, record the failure, wait for human). The spec needs an explicit early-stop trigger for script errors, a record-and-halt procedure, and a guardian rule that script-error halts do not get auto-retried.
- *User says: "I hadn't thought about that — I assumed it would just run through."* This is an unexamined assumption. The skill should surface the risk: "Without an early-stop condition, a script error at iteration 30 could mean 70 more iterations of wasted compute or, worse, 70 more iterations of silently corrupted state. Let's define what 'halt safely' looks like before this runs unattended."

---

## 2. Common Starter Patterns

Starter patterns are **conversational suggestions** offered during brainstorming — they are never applied automatically. A skill may describe a pattern, explain why it might fit the user's context, and offer it as a starting point. The user may accept the pattern verbatim, modify any phase, rename or reorder phases, or reject the pattern entirely and design from the primitive vocabulary in Section 3. The reason starter patterns are suggestions rather than templates is that every real project has context-specific constraints that a generic pattern cannot anticipate — test framework conventions, directory structure requirements, existing automation, team preferences. A harness designed by accepting a starter pattern wholesale, without critically examining whether each phase fits the actual project, is a harness that will surprise its operator the first time reality diverges from the pattern's assumptions.

---

### 2.1 Coding Pipeline

**Summary**

The Coding Pipeline pattern is a good fit when a developer wants to implement a bounded feature or refactor with disciplined phase separation: spec before code, tests before implementation, verification before merging. It assumes a human is present and approving at each phase transition, which makes it the lightest-weight pattern in terms of autonomy requirements. The pattern works best when the unit of work is well-defined enough to spec up front (a single feature, a specific refactor scope, a bounded migration), the feedback signal is at least partially test-driven, and the developer has a pre-existing testing discipline or is willing to develop one. It is the natural starting point for developers coming from a spec-first or TDD background.

**Typical phase sequence**

1. A [Read-Only] phase (Spec) — the agent reads the codebase, existing docs, and any requirements, and writes a `spec.md` describing the planned change. No source files are written.
2. A [Restricted-Write] phase (Test) — the agent writes tests for the planned change, writing only to the test directory. Source files remain read-only.
3. A [Restricted-Write] phase (Impl) — the agent writes implementation code, writing only to the source directory. Tests remain read-only (the agent must not modify tests to make them pass).
4. A [Read-Only] phase (Verify) — the agent reads the implementation and the tests, runs the test suite (via a Script or Human-Check sub-phase), and confirms the implementation satisfies the spec. No further writes.

**Typical 5-element shape**

- **Constraint Boundary:** Present and load-bearing. Each phase has a distinct write allowlist: Spec writes only to `docs/`, Test writes only to `tests/`, Impl writes only to `src/`, Verify has an empty write allowlist. Read allowlists widen progressively.
- **Quantifiable Feedback:** Usually present. Binary (tests pass/fail) is the minimum. Multi-dimensional (coverage, lint score, manual checklist) is common.
- **State Persistence:** Often N/A or minimal. Single-shot task with phases committed to git; no iteration history needed.
- **Reversibility:** Present but lightweight. Git commit per phase; `git reset --hard HEAD~N` is the rollback mechanism. Atomicity is one-commit-per-phase.
- **Autonomy:** N/A — human always present, approving each phase transition.

**Concrete example scenario**

A developer is refactoring the authentication module of a Python web application to replace a deprecated JWT library with a newer one. They use the Coding Pipeline: the Spec phase produces a document describing which functions change and what the new API contract looks like; the Test phase writes tests against the new API (which initially fail); the Impl phase replaces the library and updates call sites until tests pass; the Verify phase confirms the full test suite passes and the developer reviews the diff manually before merging.

**When NOT to use it**

- If the task involves iterating on a quantifiable metric across many runs without a human reviewing each one, the Metric Loop (§2.2) or Hybrid (§2.3) pattern is more appropriate. The Coding Pipeline has no Loop primitive and no autonomous iteration.
- If the developer cannot write tests before implementation (e.g., the output is a visual artifact, a trained model, or a configuration whose correctness is inherently subjective), the Test phase collapses into a Human-Check phase, which may still work but pushes the harness toward a design that the Freeform pattern (§2.4) describes better.
- If the scope of work spans multiple independent subsystems and different phase sequences apply to each, the single Coding Pipeline sequence creates Allowlist Drift: one sub-pipeline's writes conflict with another's read-only constraints. Split into separate harnesses or redesign as a Hybrid.

---

### 2.2 Metric Loop

**Summary**

The Metric Loop pattern is a good fit when a developer wants to optimize a quantifiable signal through iterative search — the canonical case being Karpathy-style autoresearch, where each iteration proposes a change, evaluates it against a fixed metric, and decides to keep or discard based on the result. The defining feature of this pattern is that the feedback signal is machine-evaluable (scalar, binary, or rubric-driven by an AI-Judge), which makes it possible to run without a human reviewing every iteration. The pattern requires a well-designed Decide phase — the logic for "keep or discard" must be specified precisely in the harness design, not left as an informal judgment. It also requires explicit loop termination conditions, because without them, the harness will run indefinitely.

**Typical phase sequence**

1. A [Script] phase (Baseline) — runs the evaluation function on the unmodified codebase and records the starting score. This establishes the comparison baseline for the keep/discard decision.
2. A Loop containing:
   a. A [Read-Only] phase (Plan) — the agent reads the current state and prior iteration results, and writes a plan for what change to attempt in this iteration.
   b. A [Restricted-Write] phase (Code) — the agent implements the planned change, writing only within the permitted source scope.
   c. A [Script] or [AI-Judge] phase (Eval) — evaluates the change using the machine-evaluable feedback signal, producing a score artifact.
   d. A [Script] or [AI-Judge] phase (Decide) — compares the new score against the baseline (or prior best), applies the keep/discard logic, and either commits the change or runs `git reset --hard` to discard it.

**Typical 5-element shape**

- **Constraint Boundary:** Present and critical. The Code phase must have a tightly scoped write allowlist; the Eval phase must have an empty write allowlist (it reads and scores, does not modify). Allowlist drift between Code and Eval is a common failure.
- **Quantifiable Feedback:** Present and machine-evaluable — this is what makes the pattern run autonomously. If the feedback signal requires human judgment, the Decide phase becomes a Human-Check, and the loop must pause on every iteration (which may still be the right design, but changes the autonomy profile significantly).
- **State Persistence:** Present and load-bearing. Each iteration's plan, code change, and score must be persisted (e.g., in `runs/iter-N/`) so the harness can resume from the last completed iteration after an interruption, and so the Decide phase can compare against the historical best rather than only the immediately prior run.
- **Reversibility:** Present and load-bearing. The `git reset --hard` in the Decide phase is the core reversibility mechanism. The harness depends on one-commit-per-iteration atomicity so that a single reset undoes exactly one iteration's worth of change.
- **Autonomy:** Present and fully specified. The harness is designed for unattended iteration. Must have: max-iters ceiling, early-stop on evaluation script error, optional early-stop on plateau (N consecutive iterations with no improvement above threshold), and a record-and-halt procedure that leaves the harness in a clean state.

**Concrete example scenario**

A researcher wants to improve the BLEU score of a neural machine translation model by iteratively modifying the beam search parameters and decoding strategy. The Baseline phase scores the current model; the Loop's Plan phase reads the prior iteration results and proposes a specific parameter change; the Code phase edits the decoder configuration; the Eval phase runs the evaluation script and records the BLEU score; the Decide phase keeps the change if BLEU improved, discards it otherwise. The loop runs for up to 100 iterations or stops early if 10 consecutive iterations produce no improvement above 0.1 BLEU.

**When NOT to use it**

- If each "Code" iteration involves disciplined multi-step work (spec → test → impl → verify) rather than a simple parameter tweak, the overhead of the Coding Pipeline discipline is warranted and the Hybrid pattern (§2.3) is the right choice. Squashing disciplined multi-step work into a single unrestricted Code phase risks creating a Guardian Blind Spot inside the loop.
- If the feedback signal is not machine-evaluable and requires human judgment on every iteration, the loop cannot run autonomously. The Decide phase becomes a Human-Check, which is fine but means the loop cannot run unattended — consider whether the Coding Pipeline with explicit Human-Check phases is a simpler design.
- If there is no clear Decide logic and the user plans to review every iteration manually, the loop structure creates an Unbounded Loop risk: without a concrete keep/discard criterion, it is easy to keep iterating without a termination condition in sight.

---

### 2.3 Hybrid

**Summary**

The Hybrid pattern is a good fit when a developer wants to run an optimization loop, but each iteration's "Code" step is complex enough to warrant its own disciplined sub-harness — spec, test, implement, verify — rather than a single unrestricted write phase. In the Hybrid, the outer shell is a Metric Loop, but the Code phase is replaced by a Coding Pipeline mini-harness that runs to completion before the Eval phase scores the result. This pattern acknowledges that when each iteration involves a meaningful feature-level change (not just a parameter tweak), the risk of a poorly-disciplined implementation accumulates across iterations: by iteration 20, the codebase may have 20 undisciplined changes that are individually valid but collectively incoherent. The inner Coding Pipeline enforces the spec → test → impl → verify discipline within each iteration, while the outer loop governs the metric-driven keep/discard decision.

**Typical phase sequence**

1. A [Script] phase (Baseline) — same as Metric Loop.
2. A Loop containing:
   a. A [Read-Only] phase (Plan) — reads prior iteration results, proposes the next feature-level change.
   b. An inner Coding Pipeline mini-harness:
      - A [Read-Only] phase (Spec) — specs the planned change for this iteration.
      - A [Restricted-Write] phase (Test) — writes tests for the planned change.
      - A [Restricted-Write] phase (Impl) — implements the change.
      - A [Read-Only] phase (Verify) — verifies implementation against tests.
   c. A [Script] or [AI-Judge] phase (Eval) — scores the iteration's output.
   d. A [Script] or [AI-Judge] phase (Decide) — keep or discard.

**Typical 5-element shape**

- **Constraint Boundary:** Present and complex. The inner Coding Pipeline has its own per-phase allowlists nested inside the outer loop's constraints. The key design question is whether the outer loop's Decide phase can reach inside the inner pipeline's artifacts (e.g., can it read the inner Spec documents?). Allowlist design must be explicit about outer vs inner scope.
- **Quantifiable Feedback:** Present and machine-evaluable at the outer loop level. The inner Coding Pipeline has its own binary feedback (tests pass/fail), but the outer Decide phase uses the metric-level score.
- **State Persistence:** Present and layered. Per-iteration persistence as in Metric Loop, plus within-iteration phase tracking for the inner pipeline.
- **Reversibility:** Present at both levels. The outer Decide phase can roll back an entire inner-pipeline iteration. The inner pipeline also has per-phase rollback.
- **Autonomy:** Partially present. The outer loop may run autonomously, but the inner Coding Pipeline's phase transitions typically require human approval (since it inherits the Coding Pipeline's attended-mode design). The autonomy spec must be clear about which parts are attended and which are autonomous.

**Concrete example scenario**

A developer is building a PPT optimization system that iteratively improves slide layouts. Each iteration involves a non-trivial code change to the layout algorithm — not just a parameter tweak, but a genuine feature implementation (e.g., implementing a new alignment strategy). The outer Metric Loop scores each layout version against a visual quality metric. The inner Coding Pipeline disciplines each layout feature implementation: spec the algorithm change, write tests for the layout logic, implement, verify. The Decide phase keeps iterations that improve the metric, discards those that don't.

**When NOT to use it**

- If each iteration's code change is small enough to fit in a single Restricted-Write phase without discipline risk (e.g., tuning a numeric constant, changing a config flag), the Hybrid adds unnecessary complexity. Use the Metric Loop instead.
- If the inner Coding Pipeline phases are being rushed through without genuine spec-first discipline (the human approves them too quickly to serve as a real gate), the Hybrid is a Phase Cycle risk in disguise: the inner spec will reference the outer loop's current state in a way that creates circular dependencies. Consider whether the discipline is actually being applied.
- If the outer loop's Decide logic is not machine-evaluable, the Hybrid has an Unbounded Loop risk at the outer level: without a concrete keep/discard criterion, neither the inner nor outer pipeline has a clear termination condition.

---

### 2.4 Freeform

**Summary**

The Freeform pattern is the right choice when a user's task doesn't fit the shape of any of the above patterns — either because the phase sequence is genuinely novel, the feedback signal doesn't fit the Metric Loop's evaluation model, or the user's workflow has domain-specific requirements that the other patterns cannot accommodate. In Freeform, the user composes a custom phase sequence directly from the primitive vocabulary in Section 3, without the outer structure of a predefined pattern. The role of the skill in a Freeform conversation is to help the user make each design decision explicit — what primitive does each phase use, what is the allowlist, what are the entry and exit gates, who or what runs the Decide logic — rather than to suggest a starting structure. Freeform is not a fallback for users who haven't thought about their harness design; it is a deliberate choice for users whose task is genuinely non-standard.

**Typical phase sequence**

There is no typical sequence — that is the definition of Freeform. The user defines the phase sequence from primitives: any combination of Read-Only, Restricted-Write, Script, Human-Check, AI-Judge, and Loop phases, in any order that serves their workflow. The only universal requirements are that the phase sequence is finite and terminable (no Unbounded Loop), that each phase's allowlist is specified, and that the guardian's scope covers the full action surface of all phases.

**Typical 5-element shape**

- **Constraint Boundary:** Present and fully user-designed. Each phase has a custom allowlist because there is no pattern-derived default.
- **Quantifiable Feedback:** Varies widely. May be machine-evaluable, human-judgment, or absent (for phases that are purely organizational, not evaluative).
- **State Persistence:** Varies by the task's needs. The user must explicitly design the state schema rather than inheriting a pattern's conventions.
- **Reversibility:** Present for any phase with write operations. The rollback mechanism is user-specified.
- **Autonomy:** Varies by design. Some Freeform harnesses are fully attended; others run autonomously within bounded phases. Must be explicitly specified for each phase that can run without human oversight.

**Concrete example scenario**

A data engineer is building a harness for a data pipeline validation workflow that has no analogue in standard patterns: it involves reading data from a frozen oracle, running a series of transformation scripts, comparing outputs against reference snapshots, flagging discrepancies for human triage, and only after human sign-off, promoting the output to production. This workflow has a Script phase (run transforms), a Human-Check phase (triage discrepancies), and a Restricted-Write phase (promote to production), but the sequencing and gating logic is domain-specific and cannot be cleanly mapped to a Coding Pipeline or Metric Loop.

**When NOT to use it**

- If the user's task actually fits one of the first three patterns but the user is unfamiliar with them and defaulting to Freeform because it feels less prescriptive, the skill should offer the appropriate starter pattern as a suggestion and let the user decide. Defaulting to Freeform out of familiarity avoids the knowledge embedded in the starter patterns — including the typical 5-element shapes and common pitfalls specific to each pattern.
- If a Freeform harness being designed starts to look exactly like a Metric Loop or Coding Pipeline with renamed phases, the skill should name that observation and ask whether the user would benefit from the pattern's known pitfalls and element shapes as a reference. There is no cost to acknowledging that a Freeform design converged on a known pattern — it just makes the debating phase more informed.
- If the user cannot articulate why none of the starter patterns fit their task, that is a signal that the brainstorming phase has not sufficiently explored the task shape. Freeform should not be chosen by default or by elimination without positive reasons; a Guardian Blind Spot is especially likely when Freeform phases are composed ad hoc without reference to the phase primitive vocabulary in Section 3.

---

## 3. Phase Primitive Vocabulary

Primitives are **behavior types** — abstract categories of what a phase does. When designing a harness, a user identifies which primitive each phase matches (or names a new one if none fit). Primitives are vocabulary, not implementations; the actual phase is built during implementation, informed by the primitive's semantics.

---

### 3.1 Read-Only

**Name and description**

A Read-Only phase is one where the agent reads any permitted files and produces exactly zero written files — or at most one explicitly named "output artifact" file (such as a spec document or analysis report). The agent's action surface is the read allowlist plus, optionally, a single write target.

**Typical allowlist shape**

Read allowlist: wide (often the full project tree, or a substantial portion). Write allowlist: empty, or limited to one explicitly named output path (e.g., `docs/spec.md`). No shell execution beyond read-oriented commands (`find`, `grep`, `cat`, `git log`). If the write allowlist is empty, the phase is strictly analysis-and-synthesis only; if it allows a single artifact path, the artifact's existence and content serve as the phase's exit signal.

**Typical entry gate**

Prior phase's output artifact (if any) is present and committed. For the first phase in a harness, the entry gate is simply that the harness has been invoked and the project tree is accessible.

**Typical exit gate**

The output artifact (if declared) is written and its contents satisfy a minimal structural check — e.g., it has the required sections, it is non-empty, or a guardian prompt confirms it is coherent. If no artifact is declared (purely analytic), the exit gate is the agent's explicit declaration that it is done reading and has nothing further to write.

**Commit behavior**

If the phase produces an output artifact, the artifact is committed as a single atomic commit when the phase completes. This commit serves as the rollback target if the next phase reveals a problem with the artifact. If the phase produces nothing, no commit occurs. Either way, the commit record is clean and phase-attributed.

**Guardian responsibility**

For a Read-Only phase, the guardian's primary check is that the write allowlist was not violated — that the agent did not write to any path other than the permitted output artifact path. Secondary check: if an artifact was expected, confirm it exists and has the required structure. The guardian does not need to validate the content quality of the artifact at this stage (that is the job of a subsequent AI-Judge or Human-Check phase, if one exists).

**When it DOESN'T fit**

If the phase's natural work requires writing to multiple files, or if it needs to execute shell commands that have side effects (modifying state beyond the project tree), Read-Only is the wrong primitive. A phase that "mostly reads but also makes a few small edits" is a Restricted-Write phase with a narrow allowlist — not a Read-Only phase with exceptions. The distinction matters because the guardian's write-violation check must be binary: any unexpected write is a failure.

---

### 3.2 Restricted-Write

**Name and description**

A Restricted-Write phase is one where the agent writes to a specific, explicitly enumerated set of paths — a scope that is deliberately narrower than the full project tree. This is the primary primitive for phases that modify source code, configuration, or other structured files.

**Typical allowlist shape**

Read allowlist: typically wider than the write allowlist (the agent needs to read the current codebase to write informed changes). Write allowlist: a specific path set such as `src/auth/`, `tests/unit/`, or a named list of files. Paths outside the write allowlist are read-only for this phase. Shell execution: allowed only if it is read-oriented (e.g., running the test suite to check current state, not to modify state). A Restricted-Write phase that needs to run commands that produce side effects should be decomposed: the write step is Restricted-Write, the command step is Script.

**Typical entry gate**

A prior phase's artifact (spec, test, plan document) is present and committed. The agent has been explicitly told what it is allowed to write this iteration — typically by the spec's allowlist declaration or by the guardian's phase-start check. If the prior phase produced tests (as in a Coding Pipeline), the test suite must be failing at entry (the implementation is not yet written) — this is the Red-Green discipline.

**Typical exit gate**

The write allowlist paths have been updated, committed, and a verification step (Script or Human-Check) confirms the work meets the phase's definition of done. In a Coding Pipeline, the exit gate is typically "test suite passes." In a Metric Loop, the exit gate is "change committed and Eval phase has a valid input." Exit is never self-declared by the agent alone; it requires an external check.

**Commit behavior**

One commit per phase completion. The commit should be a clean, atomic unit — not a partial state. If the agent cannot complete the phase in one coherent commit, the phase is under-specified or too large. The guardian checks commit atomicity: a phase that commits twice is a design violation (it means the agent treated it as two phases, potentially bypassing the exit gate check).

**Guardian responsibility**

The guardian checks that all writes fall within the declared write allowlist (no out-of-scope file modifications), that the commit is present and non-empty, and that any explicitly declared exit check (tests passing, lint clean) was actually run and passed. The guardian does not re-run the exit check itself — it verifies that the exit check artifact (test result log, lint output) is present and shows a pass status.

**When it DOESN'T fit**

If the work naturally requires writing to paths that vary per-iteration (e.g., writing to `runs/iter-N/` where N changes on every iteration), the allowlist must be expressed as a pattern (`runs/iter-*/`) rather than a fixed list. If the pattern is too wide to be meaningfully constraining, the primitive should be renamed by the user — "Iteration-Write" or similar — to flag that this is a non-standard case. A Restricted-Write phase whose allowlist covers most of the project is not meaningfully restricted; the user should re-examine whether the constraint boundary for that phase is serving any purpose.

---

### 3.3 Script

**Name and description**

A Script phase is one where no LLM action occurs: a shell command runs, its exit code determines success or failure, and the result is passed to the next phase. The Script primitive is used for baseline establishment, deterministic evaluation, pure-arithmetic decisions, and any other harness step that does not need AI judgment.

**Typical allowlist shape**

Write allowlist: restricted to exactly the output artifact path (e.g., `runs/iter-N/score.txt` where the script writes its result). Or empty, if the script only reads and returns an exit code. The script itself must be a named, version-controlled file — not an ad hoc command string — so the guardian can confirm which script ran. Shell execution: exactly the named script, no additional commands.

**Typical entry gate**

The named script exists and is executable. Required inputs (e.g., the code to evaluate, the dataset to score) are present at their expected paths. In a Metric Loop, the entry gate for the Eval Script phase is the Code phase having committed its output.

**Typical exit gate**

Script exits with code 0 (success) or non-zero (failure). The result artifact, if any, is written and readable. Non-zero exit triggers the harness's error-handling path — either a retry, a rollback, or a human alert, per the Autonomy element's specification.

**Commit behavior**

The Script phase itself does not commit anything — committing is the job of the phase that produces the changes being evaluated. The script's output artifact (score file, test result log) may be committed as a phase record if the harness is designed for indexable state persistence. This is optional and depends on whether the harness needs to query historical scores.

**Guardian responsibility**

The guardian checks that the correct named script was invoked (not an ad hoc command), that the output artifact is present at the expected path, and that the exit code was handled according to the spec's error path (i.e., a non-zero exit did not silently continue). The guardian does not re-interpret the script's output — it confirms the artifact exists and that the downstream phase received it correctly.

**When it DOESN'T fit**

If the evaluation logic requires contextual judgment (e.g., "this metric improvement is meaningful given the context of what was changed"), the Script primitive is insufficient — an AI-Judge phase is needed. A script that hard-codes a numeric threshold is a Script; a script that defers to a human or LLM for the final call is a Human-Check or AI-Judge. Trying to encode complex conditional judgment in a shell script produces a script that is either brittle (wrong thresholds) or secretly an AI-Judge (calls an LLM internally, which the guardian must know about and account for).

---

### 3.4 Human-Check

**Name and description**

A Human-Check phase is one where the LLM is idle: a human directly inspects an artifact, a running system, or a result, and records a structured response that the harness uses as the exit signal for that phase. Human-Check is the primitive for integrating human judgment into a harness without abandoning the harness's structure.

**Typical allowlist shape**

Write allowlist: exactly the structured response artifact path (e.g., `docs/unleash/human-checks/phase-N-check.md`). The human writes this file; the LLM does not write during this phase. The LLM's role before the check is to present the artifact being inspected (render it, summarize it if helpful) and to provide the checklist or rubric the human should use. The LLM's role after the check is to read the response artifact and proceed or halt based on its contents.

**Typical entry gate**

The artifact to be inspected is present and committed. The checklist or rubric for the human's response is pinned in the spec (not left to the human's interpretation). The human has been explicitly notified that their review is required — the harness does not silently wait.

**Typical exit gate**

The structured response artifact is present at the expected path, has the required structure (all checklist items filled in, no missing fields), and contains a net pass or net fail verdict. The guardian checks structure; it does not re-evaluate the human's verdict. A "fail" verdict triggers the harness's rollback or halt path.

**Commit behavior**

The human's response artifact is committed when the phase completes (either by the human or by the LLM after reading it). This commit records the human judgment for the historical state of the harness. If the verdict is "fail" and a rollback follows, the response artifact is still committed first — the rollback only affects the work under review, not the review record itself.

**Guardian responsibility**

The guardian's primary job for a Human-Check phase is to verify that the response artifact appeared and has the required structure — not to second-guess the human's verdict. If the artifact is missing or malformed, the guardian flags the phase as incomplete. If the artifact is present and well-formed, the phase is complete regardless of the verdict's content (the verdict is enforced by the downstream harness logic, not by the guardian). A common misconfiguration is making the guardian re-evaluate the human's judgment; this duplicates the human review and produces a Guardian Blind Spot for cases where the guardian and human disagree.

**When it DOESN'T fit**

If the human review is expected to happen on every iteration of a loop, and iterations are fast (under a minute each), the Human-Check phase will become a bottleneck and the harness will effectively require constant human presence. In that case, the user should consider whether an AI-Judge phase with a sufficiently detailed rubric could replace most of the human checks, with Human-Check reserved for disputed or ambiguous cases. If the human's structured response is always the same regardless of the artifact being reviewed (i.e., the check is pro forma), the Human-Check phase is not providing meaningful value and should be replaced with a Script or AI-Judge.

---

### 3.5 AI-Judge

**Name and description**

An AI-Judge phase is one where a separate LLM call — distinct from the implementing agent — reads one or more artifacts, applies a pinned rubric, and writes a decision artifact that the harness uses as the phase's exit signal. The "separate LLM call" is critical: the judge must not be the same agent context that produced the work being judged.

**Typical allowlist shape**

Read allowlist: the artifact(s) to be evaluated, plus the pinned rubric file. Write allowlist: exactly the decision artifact path (e.g., `docs/unleash/judgments/phase-N-decision.md`). No shell execution. The judge receives a tightly scoped context: rubric + artifacts, nothing else. It does not receive the implementing agent's reasoning, prior iteration history, or any other context that might bias its evaluation.

**Typical entry gate**

The artifact(s) to be evaluated are present and committed. The rubric is pinned at a specific version in the spec — the same rubric file that was agreed during debating. If the rubric has been modified since the spec was committed, the change must be deliberate and documented; silent rubric drift is one of the most common AI-Judge pitfalls (see Section 6).

**Typical exit gate**

The decision artifact is present, has the required structure (verdict field, reasoning field, rubric version field), and contains a parseable verdict. The verdict is binary (pass/fail) or graded with a defined scale. Unbounded qualitative verdicts ("it's pretty good") are not valid AI-Judge outputs — the rubric must constrain the output format. The decision artifact is committed before the harness acts on its verdict.

**Commit behavior**

The decision artifact is committed as its own atomic record when the phase completes. This allows the harness to track verdict history and to detect if the judge's behavior has changed across iterations (which may indicate rubric drift or model behavior change). If the verdict is "fail" and a rollback follows, the decision artifact commit is preserved as evidence.

**Guardian responsibility**

The guardian checks that the judge was invoked as a separate subagent (not inline), that the rubric version in the decision artifact matches the pinned version in the spec, and that the decision artifact has the required structure. The guardian does not re-evaluate the judge's verdict — that would require another judge and produces infinite regress. A practical check: the guardian confirms the rubric version field in the decision artifact, flagging any mismatch with the spec's pinned version as a potential drift event.

**When it DOESN'T fit**

If the rubric cannot be written down precisely enough for an LLM to apply consistently across runs, an AI-Judge is the wrong primitive — the feedback signal is inherently subjective and belongs in a Human-Check phase. A rubric that says "evaluate overall quality" is not a rubric; it is an instruction to the judge to improvise, which means each invocation may apply a different standard. AI-Judge is only appropriate when the rubric is specific enough that two independent judge invocations on the same artifact would likely agree. If they wouldn't, the rubric needs further specification or the primitive needs to change.

---

### 3.6 Loop

**Name and description**

A Loop phase is a composite primitive that wraps a sub-sequence of phases and repeats it until an exit condition is met. The Loop primitive is not a phase in itself — it is a container. Its sub-sequence can contain any combination of the other five primitives. The Loop primitive's defining constraint is that it MUST have a bounded exit: a maximum iteration count, an early-stop condition, or an external signal that terminates the loop.

**Typical allowlist shape**

The Loop phase's allowlist is the union of all its contained phases' allowlists, applied in the order they run. Allowlists do not reset between iterations — the write allowlist for iteration N+1 is the same as for iteration N, unless the loop design explicitly varies the allowlist per iteration (e.g., writing to `runs/iter-N/` with N incrementing). The guardian's scope must cover the full union allowlist across all iterations, not just the first.

**Typical entry gate**

The loop's initial state is established: a baseline exists (for a Metric Loop, the Baseline Script has run and produced a score), required input artifacts are present, and the loop's state persistence mechanism is initialized (e.g., `runs/` directory created, iteration counter set to 0). The loop must not start if any of these are missing.

**Typical exit gate**

One of the loop's declared exit conditions fires: (a) max-iters reached, (b) early-stop condition triggers (e.g., N consecutive iterations with no improvement above threshold), or (c) an external signal is received (e.g., a stop file is detected at a watched path). All three exit types must be declared in the spec; absence of any one is a design gap. On exit, the loop writes a summary artifact (final state, iteration count, exit reason) and commits it.

**Commit behavior**

Each iteration's work is committed atomically before the next iteration begins. This means the harness can roll back exactly one iteration at a time without touching any other iteration's work. The iteration commit record is the primary state persistence mechanism for loops that need resumption after interruption. If iterations are not individually committed, the harness cannot resume from mid-loop interruption — it must restart from iteration 0.

**Guardian responsibility**

The guardian checks that the loop's exit conditions are declared and reachable (at design time, this is a spec validation check; at runtime, this is checking that the max-iters counter is being decremented and the early-stop condition is being evaluated on each iteration). At runtime, the guardian also checks that each iteration's artifacts are present and committed before the next iteration begins — preventing a situation where the loop runs ahead of its own state persistence. An unbounded loop that runs without a guardian check on exit conditions is the canonical Unbounded Loop pitfall (see Section 6).

**When it DOESN'T fit**

If the "loop" is really just two sequential runs of the same phase with a manual decision in between, it is not a Loop — it is a Human-Check phase followed by a conditional re-invocation. The Loop primitive implies genuine automation: the decision to continue or stop is made by the harness, not by a human typing a command each time. If the user plans to manually re-invoke the harness on each iteration, the Loop primitive does not apply; the harness is attended, and the "loop" is a social convention, not a structural primitive. Additionally, if there is genuinely no exit condition the user is willing to commit to, the Loop primitive cannot be used — the harness cannot be specified without a bounded exit, and attempting to use Loop without one is the Unbounded Loop pitfall by definition.

---

## 4. Runtime Guardian Design Patterns

The Runtime Guardian is the default enforcement mechanism in Unleash. It is an independent subagent — not a hook — that reviews each batch of harness activity post-hoc and triggers git-reset rollback on violation. This is AI-first enforcement: we accept that occasional violations slip through, in exchange for flexibility that hard rules cannot provide.

---

### 4.1 Scoping the Guardian

The guardian's review scope must be at least as wide as the action surface of each phase it guards. A guardian that reviews only file writes but not shell command execution has a blind spot if the phase is also permitted to run scripts. A guardian that reviews only the output artifact but not the intermediate files has a blind spot if the phase produces side-files on the way to its declared output.

**What the guardian reviews**

In practice, the guardian receives one or more of the following inputs, depending on which the harness makes available:

- The **allowlist declaration** for the phase — what was the agent permitted to do?
- The **tool-call log** for the phase — what did the agent actually do? (file reads, file writes, shell invocations, external API calls)
- The **output artifacts** produced by the phase — do they exist? Do they have the required structure?
- The **git diff** since the phase started — which files were modified, and do those modifications fall within the declared write allowlist?

The guardian's scope must equal-or-exceed the action surface: if the phase's allowlist includes shell execution, the guardian must see the shell command log; if the allowlist includes external API calls, the guardian must see the API call log (or, more likely, those calls should be hook-gated instead — see Section 5).

**Probe question for brainstorming and debating**

When helping a user design their guardian, a skill can ask: "For phase X, list everything the phase is allowed to do — every file it can write, every tool it can call, every command it can run. Now, for each item on that list, does the guardian see evidence of what happened? If any item is not in the guardian's view, that is a Guardian Blind Spot." This probe surfaces scope gaps more reliably than asking "is the guardian sufficient?" — because "sufficient" is abstract while the allowlist is concrete.

**Scope design principle**

When in doubt, widen the guardian's scope rather than narrow it. A guardian that checks more than strictly necessary is more expensive but safer. A guardian that misses a violation class cannot be trusted. The philosophical cost of widening scope (more tokens per review cycle) is acceptable; the cost of a missed violation that produces a bad commit can be much higher.

---

### 4.2 Writing the Guardian Prompt

The guardian prompt is a first-class artifact — not a string embedded in code, not a comment, not an afterthought. It must be written with the same care as the spec itself, because it is the primary mechanism by which the harness's constraints are enforced at runtime.

Every guardian prompt must contain exactly these five sections, in this order:

**Role**

One paragraph establishing the guardian's identity and its relationship to the work it is reviewing. The key phrase: "You are an independent reviewer. You have not seen the work in progress, you have no context from the implementing agent, and you are reading these artifacts for the first time." This framing prevents the guardian from importing the implementing agent's assumptions and rationalizations. If the guardian's role section is missing or says something like "you are the same agent reviewing your own work," the independence guarantee is violated from the start.

**Instructions**

A precise description of what inputs the guardian receives for this review cycle. This section answers: which files will be passed to you, in what format, what you are being asked to check. The instructions must not be vague — "review the code" is not an instruction; "check that every modified file's path falls within the write allowlist declared in `phase-config.json`, and report any path that does not" is an instruction. The instructions section must be specific enough that the guardian's task is fully defined without any inference required.

**Decision Rubric**

The binary or graded criteria that determine the guardian's verdict. Binary is strongly preferred: pass or fail, with no middle ground. Each criterion in the rubric must be independently checkable — the guardian should be able to evaluate each one without reference to any criterion from a different harness or a prior review cycle. If the rubric is graded (e.g., severity levels), the scale must be explicitly defined and the threshold for "fail" must be stated. A rubric that says "use your judgment" is not a rubric; it is an instruction to improvise, which makes the guardian's behavior non-deterministic.

**Edge Cases**

Explicit handling of situations the rubric does not cleanly cover. This section is where the guardian prompt pays for itself: edge cases that are not pre-handled will be handled inconsistently across review cycles, and inconsistent enforcement is almost as bad as no enforcement. Common edge cases to pre-handle: "what if the agent wrote a file that is technically outside the allowlist but is a known safe-to-write location like a temp directory?", "what if a shell command produced a log file as a side effect — is the log file a violation?", "what if the output artifact is present but empty?" Each edge case should have an explicit decision (treat as pass, treat as fail, treat as warning-but-pass) with reasoning.

**Output Format**

The exact shape of the guardian's response, specified precisely enough to be parsed programmatically. At minimum: a `verdict` field (`PASS` or `FAIL`), a `criteria_results` list (one entry per rubric criterion, with the criterion name and its individual verdict), and a `reasoning` field (one sentence per criterion explaining the verdict). If the harness parses the guardian's output to trigger an automated rollback, the output format must be specified at the character level — the parser cannot handle variation in how the guardian expresses its verdict.

---

### 4.3 Rollback Triggers

When the guardian issues a FAIL verdict, the harness must take a concrete action. The options, with their appropriate use cases:

**`git reset --hard HEAD~N`**

The most common rollback mechanism for file-write violations. N is the number of commits to roll back — typically 1 for a single phase's commit, or more for a multi-commit phase. This is appropriate when: the violated state is entirely within the git-tracked project tree, no external side effects have been produced, and the rolled-back commits are known and bounded. This is the rollback mechanism used by the Coding Pipeline and Metric Loop starter patterns by default. The guardian prompt must specify the exact N for each phase — "roll back the last commit" is not specific enough if some phases produce multiple commits.

**Branch switch**

Rather than rolling back commits on the current branch, the harness switches to a clean branch (e.g., the branch before the phase started). This is appropriate when: the phase produces a large number of commits that would be tedious to count for `HEAD~N`, or when the harness is designed with a "feature branch per phase" discipline. The guardian triggers a branch switch, and the implementing agent starts fresh from the clean branch. This requires the harness to maintain a branch registry so the guardian knows which branch is the rollback target.

**Revert + notify**

Instead of discarding commits, the harness creates a revert commit and notifies the human. This is appropriate when: the violated state has been partially shared (e.g., the branch has been pushed, though not merged), or when the human wants to review the bad state before it is discarded. The revert commit preserves the evidence; the notification ensures the human knows the guardian fired. This is a weaker rollback than `git reset --hard` but safer when the violating commits may have already propagated.

**Halt + request human**

The harness stops all further execution and sends a notification requesting human intervention. This is appropriate when: the violation is severe enough that automated rollback might cause more damage than the violation itself (e.g., the violation involved a partial external API call that a git reset cannot undo), or when the guardian's confidence in its own verdict is not high enough to justify an automated rollback. Halt is the safest option when uncertain; it prevents accumulation of bad state at the cost of requiring human attention.

---

### 4.4 Guardian Independence

The guardian's value depends entirely on its independence from the implementing agent. A guardian that shares context with the implementer will, under pressure, tend to rationalize violations rather than flag them — not because it is dishonest, but because the shared context makes the violation "understandable" in a way that fresh context would not.

**Why independence matters**

The implementing agent has been embedded in the task for the duration of the phase. It has developed a mental model of "why things are the way they are" that may not match the spec's intent. When the agent writes to a file outside its allowlist, it typically has a reason — a reason that is coherent within its own mental model. If the guardian inherits that mental model, it will tend to accept the reason and pass the phase. The reason may be coherent but still a violation. Independence breaks this rationalization path.

**How to enforce independence in practice**

The guardian must be dispatched as a separate subagent — not as a continuation of the implementing agent's context, not as a system prompt addition to the implementing agent, not as an inline self-check. The subagent receives only: the guardian prompt, the artifacts it is asked to review, and nothing else. It does not receive the implementing agent's scratchpad, prior message history, or any narration of "what we were trying to do." The implementing agent's "intent" is irrelevant to the guardian; only the actual artifacts produced are relevant.

In practice, this means the harness must be designed with a clear boundary between the implementing phase and the guardian review phase. The implementing agent writes its artifacts and commits; the guardian subagent is then dispatched with only those artifacts as input. Any mechanism that allows the implementing agent to "explain itself" to the guardian before the guardian renders its verdict undermines independence.

**No shared scratchpad**

The implementing agent must not write to a log, scratchpad, or summary file that the guardian reads as part of its review. If the guardian can read the implementing agent's reasoning, it will be influenced by it. The only input the guardian receives is the hard evidence: the git diff, the output artifacts, the tool-call log. Narration is disallowed by design.

---

## 5. Hook vs Guardian Decision Guide

Hooks are reserved for **truly irreversible operations**. Guardian is the default for everything else. The central question: after this operation completes, can we undo it cheaply?

| Operation | Reversibility | Recommended enforcement |
|---|---|---|
| File edit within the project | Git can reset | Guardian |
| File create within the project | Git can untrack | Guardian |
| File delete within the project | Git can restore from history | Guardian |
| Local bash command (build, test, lint) | Side effects are on disposable state | Guardian |
| External API call (send email, create issue, post to Slack) | Recipient has already seen it | **Hook** |
| Destructive bash (`rm -rf` outside project, `dd`, format) | No reset path | **Hook** |
| Git push to remote | Cannot be un-pushed cleanly | **Hook** |
| Package publish (npm, pypi, cargo) | Once versioned, public | **Hook** |

---

### 5.1 How a User Identifies Irreversibility in Their Own Domain

When a user is designing a harness for an unfamiliar domain, or for operations that don't map cleanly onto the table above, the skills can use these probe questions to surface irreversibility:

**Probe 1: "After this operation completes and something goes wrong, what is the exact sequence of commands you would run to undo it?"**

If the user can describe a concrete undo sequence (a `git reset`, a database rollback, a snapshot restore), the operation is reversible and Guardian enforcement is appropriate. If the user says "I'm not sure" or "I'd have to contact someone," that is a signal of irreversibility — the undo path is either nonexistent or involves human coordination that cannot be automated. Default to Hook.

**Probe 2: "Does this operation affect anything outside your project tree — a remote system, another person's state, a published artifact?"**

Operations that affect only local state (files, databases, processes on the local machine) are generally reversible by some mechanism. Operations that affect remote state (another server, another user's inbox, a public registry) are generally irreversible once the remote system has acknowledged receipt. External side effects default to Hook.

**Probe 3: "If this operation runs and produces a bad result, is the badness contained to your machine, or does someone else see the bad result before you can stop it?"**

This probe catches operations that are technically reversible (e.g., you can delete the pushed commit from a git remote if you have force-push access) but irreversible in practice (the other developers have already pulled it, CI has already run, the release notification has already gone out). The relevant question is not whether the operation is theoretically undoable but whether it is practically undoable within the response time of the harness. Default to Hook if the answer is "someone else sees it."

---

### 5.2 When Uncertain: Default to Hook for Safety

If the reversibility of an operation is genuinely unclear, the correct choice is to default to Hook enforcement and document the reasoning explicitly in the spec. This is not a permanent decision — after the harness has been used and the operation's behavior is better understood, the user can revisit and move it to Guardian if reversibility turns out to be practical.

The cost of defaulting to Hook is that the operation requires a pre-check before it runs, which may add latency or require more careful specification of the hook's logic. The cost of defaulting to Guardian on a truly irreversible operation is that a violation slips through and produces a consequence that cannot be undone. The asymmetry is clear: the cost of a false Hook is inconvenience; the cost of a false Guardian is permanent damage.

Document the reasoning in the `optional_hooks` section of the spec: "Operation X is hook-gated because its reversibility is uncertain at design time. Rationale: [specific reason the user gave during debating]. Revisit when [condition that would clarify reversibility]."

---

### 5.3 When a Single Operation Needs Both

Occasionally, a single operation in a harness requires both a Hook (to block or control execution) and a Guardian (to check semantics). The typical case is a phase that calls an external service whose behavior is reversible in testing but irreversible in production — or more precisely, where the harness needs both pre-hoc blocking and post-hoc semantic validation.

**Example: a phase that calls `send_email`**

In a dry-run test environment, the `send_email` function is mocked — it writes to a local file instead of sending. The guardian can check the email body in that file and confirm it meets quality criteria before the harness advances. No hook is needed because nothing irreversible happens.

In a production run, the `send_email` function actually sends. A hook blocks the call until a pre-flight check passes — confirming the recipient list is correct, the subject line contains the required markers, and the body length is within bounds. The hook lifts only after these checks pass. The guardian then checks, post-send, that the email record (logged by the sending system) matches what was intended — providing a semantic audit trail even though the send itself cannot be undone.

In this design, the hook controls the timing and conditions of the irreversible action, while the guardian verifies the semantic correctness of the action's inputs and outputs. The two mechanisms are complementary: the hook prevents bad sends; the guardian detects and records anomalies in sends that the hook allowed through. The spec must explicitly declare both the hook's trigger condition and the guardian's post-hoc check scope, so neither mechanism implicitly depends on the other.

---

## 6. Common Pitfalls

These are failure modes observed in real harness designs. Each is a pattern — recognize it in your design before it costs you real time.

---

### 6.1 Phase Cycle

**What it looks like**

Phase N produces an artifact that an earlier phase K (where K < N) is supposed to read. The dependency runs backwards: the output of a later phase is listed as an input to an earlier phase, creating a circular chain in the phase graph. In a Coding Pipeline, this might look like: the Impl phase writes a file that the Spec phase is expected to read (because the spec says "spec is derived from the implementation"), which means the spec can't be written before the implementation, defeating the purpose of specifying first.

**Why it fails**

A dependency cycle makes the harness unexecutable: to start phase K, you need phase N's output; to start phase N, you need phase K's output. There is no valid starting point. If the cycle is only noticed at runtime (not at design time), the harness either deadlocks, silently reads stale artifacts from a prior run, or forces the human to manually break the cycle by providing a seed value — none of which is a designed behavior. Cycles also violate the rollback model: if phase K is rolled back, does that also invalidate phase N's output? The answer is always yes, but nothing in the harness spec says so, leading to inconsistent state.

**How to detect it during brainstorming/debating**

Draw the dependency graph: for each phase, list all artifacts it consumes and all artifacts it produces. An arrow points from the producing phase to the consuming phase. If the graph contains a cycle — a path that leads from any phase back to itself — a Phase Cycle exists. The probing question: "For each artifact your harness reads, which phase writes it? Can you trace a straight line from the first phase to the last without any arrow pointing backward?"

**How to fix it**

Re-order the phases so that the dependency graph is a directed acyclic graph (DAG): every arrow points from an earlier phase to a later phase. If re-ordering is impossible because both phases genuinely depend on each other, the cycle indicates that the two phases need to be merged into one (they are not actually separate phases) or that one phase needs to be split so that the cyclic portion is extracted as a new phase whose output can be provided as initial input to the harness. The most common fix is to identify which artifact is the "seed" — the simplest possible version of the cyclic artifact — and produce it manually as a harness input rather than as a phase output.

---

### 6.2 Orphan Artifact

**What it looks like**

An artifact is declared in a phase's "artifacts produced" list but never appears in any subsequent phase's "artifacts consumed" list — or the reverse: a phase declares an artifact as consumed but no preceding phase produces it. A produced-but-never-consumed artifact is a dead write: the agent spent work producing something that nothing reads. A consumed-but-never-produced artifact is a missing dependency: the phase will fail or read stale data from a prior run.

**Why it fails**

Produced-but-never-consumed orphans indicate a harness design that has accumulated phases without maintaining end-to-end artifact traceability. The agent spends time and tokens producing an artifact that the harness does not use, and the spec contains promises that are never fulfilled. More importantly, an orphan often signals a design gap: the artifact was intended to be consumed by a phase that was cut from the design without removing its producer. Consumed-but-never-produced orphans are immediately fatal at runtime: the consuming phase reads a missing file, crashes or silently reads from a prior run's stale state, and produces results that are based on outdated inputs. Neither failure is obvious without an explicit artifact traceability check.

**How to detect it during brainstorming/debating**

Perform an artifact dependency closure check: list every artifact produced by every phase, and list every artifact consumed by every phase. Take the set difference. Any artifact in the produced set but not the consumed set is a potential orphan (confirm it is not an intended final output of the harness). Any artifact in the consumed set but not the produced set is a missing producer. Probing question: "For each file your harness writes, can you point to the specific phase that reads it? For each file your harness reads as an input, can you point to the specific phase that wrote it?"

**How to fix it**

For a produced-but-never-consumed orphan: either add a phase that consumes it (if it was intended to be used), or remove the phase that produces it (if the artifact was a design vestige). For a consumed-but-never-produced orphan: either add a phase that produces it before the consuming phase runs, or replace it with a harness input that the human provides before the harness starts. In all cases, after the fix, re-run the dependency closure check to confirm the artifact set is balanced.

---

### 6.3 Allowlist Drift

**What it looks like**

Phase N writes to a path (e.g., `foo/bar.py`) but phase N+1's read allowlist does not include `foo/` — meaning the artifact phase N just produced is invisible to the next phase. The allowlists of adjacent phases are misaligned: the write scope of one phase and the read scope of the next do not overlap over the artifacts that need to transfer between them.

**Why it fails**

Allowlist drift is silent. The harness does not error; phase N+1 simply never reads the file phase N produced. If phase N+1 has a fallback (reading an older version of the file, using a default), the harness continues running with stale inputs and produces results that appear valid but are based on outdated data. If phase N+1 has no fallback, it fails with a missing-file error that looks like a phase N write failure, not an allowlist mismatch — making diagnosis difficult. Allowlist drift is especially common when phases are added or modified incrementally: each modification is locally correct but creates a gap with the adjacent phase's read scope.

**How to detect it during brainstorming/debating**

Perform a pairwise allowlist intersection check: for every pair of adjacent phases (N, N+1), take the set of paths phase N writes and verify that each one falls within phase N+1's read allowlist. If any written path is outside the next phase's read allowlist, that path is subject to allowlist drift. Probing question: "For each file phase N writes, does phase N+1's read allowlist explicitly include it — or at least include the directory it lives in? If you ran phase N and then phase N+1, would phase N+1 be able to see everything phase N produced?"

**How to fix it**

Widen phase N+1's read allowlist to include the paths phase N writes — if those paths were always intended to be readable. Or narrow phase N's write allowlist to exclude paths that phase N+1 was never supposed to read — if the write was unintended. The key principle: any path that participates in an artifact handoff between phases must be explicitly present in both the upstream phase's write allowlist and the downstream phase's read allowlist. Implicit "of course it can read that" assumptions are the source of the drift; make them explicit.

---

### 6.4 Unbounded Loop

**What it looks like**

A Loop primitive is declared but its exit conditions are absent, underspecified, or structurally unreachable. An absent exit condition is the most obvious form: the loop has no max-iters, no early-stop criterion, and no external signal. An underspecified exit condition exists on paper but cannot actually trigger — for example, a max-iters of "unlimited" or an early-stop condition defined as "when the score is perfect," which may never happen on real data. A structurally unreachable exit condition is one where the early-stop logic has a bug: the condition checks a variable that is never updated, or uses a threshold that is always satisfied regardless of results.

**Why it fails**

An unbounded loop runs indefinitely. In the best case, it exhausts the API budget and stops due to an external resource limit the harness didn't plan for — leaving the harness in an ambiguous intermediate state. In the worst case, it continues accumulating commits, consuming compute, and potentially taking irreversible actions (external API calls within the loop) long after any reasonable definition of "done" has been passed. Because the harness has no exit logic, there is no clean-state summary artifact produced on termination, no record of why the loop stopped, and no recovery procedure for the partially-executed state.

**How to detect it during brainstorming/debating**

Every Loop primitive must declare at least one of: (a) a maximum iteration count (a concrete positive integer), (b) an early-stop condition (a specific, machine-evaluable predicate defined over loop state), or (c) an external signal (a specific file path, API endpoint, or environment variable whose value the loop checks on each iteration). If none of these three are declared, the loop is unbounded by definition. Probing question: "If this loop runs and the score never improves — for any reason — what causes it to stop? Can you give me the exact condition, in terms of concrete values, that would cause the harness to exit the loop?"

**How to fix it**

Add a bounded exit using one or more of the three mechanisms. The minimum viable fix is a max-iters ceiling: even if it is generous (e.g., 1000 iterations), it ensures the loop cannot run forever. A better fix combines max-iters with an early-stop condition that fires when further iteration is unlikely to produce improvement (e.g., N consecutive iterations with no improvement above a threshold). The most robust fix adds an external-signal path so a human can terminate the loop cleanly at any time without aborting the harness mid-state. All three exit mechanisms should write a summary artifact on exit recording the iteration count, the triggering exit condition, and the final state — so the harness is always in a known state when the loop ends.

---

### 6.5 Decide Without Trigger

**What it looks like**

A Decide phase names the decision type (Script, AI-Judge, or Human-Check) and states what the decision is about — for example, "compare the new score to the baseline and decide to keep or discard this iteration's code changes." But the phase description stops there. It does not specify who or what actually executes the resulting git operation (the `git reset --hard` that discards, or the explicit keep-commit that confirms). The judge evaluates and issues a verdict, but the phase specification is silent on what mechanism reads that verdict and performs the action.

**Why it fails**

The gap between "a verdict is issued" and "a git operation is executed" is where the real work of a Decide phase lives, and it is where most harnesses go wrong. If the implementing agent is expected to read the judge's verdict and then run `git reset --hard` on a discard verdict, the agent is acting as both the executor of the phase's work and the mechanism of its own rollback — which means if the agent fails or misbehaves between the verdict and the reset, the discard never happens. Worse: if the harness assumes the judge itself runs the git operation, but the judge is a read-only AI-Judge subagent (which it must be, for independence), the git operation will never run at all. This ambiguity typically surfaces at runtime as either a "successful" discard verdict followed by no actual rollback, or a git operation running without a valid verdict to justify it.

**How to detect it during brainstorming/debating**

Every Decide phase must name both the judge (the entity that evaluates and issues a verdict) and the actuator (the entity that executes the resulting git operation after the verdict is issued). These are two distinct roles that must be assigned to two distinct mechanisms. Probing question: "After the judge issues a DISCARD verdict on this iteration — who runs `git reset --hard`? Is it a script triggered by the harness, the implementing agent reading the verdict artifact, or a separate automation? And how does that mechanism know the verdict was DISCARD rather than KEEP?" The answer must be a specific named mechanism, not "the harness handles it" or "the agent knows what to do."

**How to fix it**

Either split the Decide phase into two explicitly named sub-steps — a "Decide" step (judge evaluates, writes verdict artifact) and an "Execute" step (actuator reads verdict artifact, runs the git operation) — or merge them into a single owned action where one named mechanism both evaluates and acts. The split design is strongly preferred for auditability: the verdict artifact is committed first as evidence, and the actuator script reads it and performs the git operation as a deterministic, scriptable step. The merged design is acceptable only if the evaluator and actuator are the same script (which is only possible for Script-type decisions where the keep/discard logic is fully deterministic). In neither case is "the agent decides and acts in the same context" acceptable — the implementing agent must not be its own rollback mechanism.

---

### 6.6 Guardian Blind Spot

**What it looks like**

The guardian's review scope is narrower than the phase's action surface. For example: the guardian checks that all modified files fall within the write allowlist, but the phase is also permitted to call shell commands — and the guardian does not see the shell command log. Or: the guardian checks the output artifact for structural completeness, but the phase is also allowed to write temporary files that are later deleted, and the guardian never learns whether those temporary paths were within or outside the allowlist.

**Why it fails**

A guardian with a blind spot enforces only the portion of the constraint boundary it can see. Violations that fall outside its view pass silently. Over time, the implementing agent — not necessarily through intent, but through natural optimization pressure — will tend to do more of its work in the blind spot. This is not a theoretical concern: if writing to an unreviewable path is faster or easier than writing to a reviewable one, the agent will find that path. The guardian's PASS verdict on a phase with a blind spot does not mean "no violations occurred" — it means "no violations occurred in the subset of actions the guardian can see." This distinction is invisible in the guardian's output, which makes the false assurance more dangerous than no guardian at all.

**How to detect it during brainstorming/debating**

For each phase, list every action the phase is permitted to take: every file it can write, every shell command it can run, every external call it can make. For each permitted action, ask: "Does the guardian see evidence of what happened here?" The guardian's scope must be a superset of every tool pattern the phase is allowed to call. Any permitted action that is not in the guardian's view is a blind spot. Probing question: "For phase X, the allowlist permits [list all permitted actions]. For each of those: does the guardian receive a log, a diff, or an artifact that proves what happened? If any permitted action produces no evidence the guardian sees, that is a blind spot."

**How to fix it**

Either widen the guardian's scope to include evidence of all permitted actions (provide the shell command log, the temporary file manifest, the API call record), or narrow the phase's permissions to exclude actions that cannot be made visible to the guardian. The former is generally preferred because it preserves the phase's capabilities; the latter may be appropriate if a class of actions is genuinely difficult to make reviewable (e.g., certain external API calls). For actions that cannot be made reviewable, move them to hook enforcement instead: if the guardian cannot see it, the hook must gate it.

---

### 6.7 Hook-Over-Guardian

**What it looks like**

A user reaches for a Hook when a Guardian would do — they write a PreToolUse hook to block or check an operation that is, in fact, reversible. Common examples: writing a hook to prevent the agent from editing a specific file (which git can undo), writing a hook to check the length of a commit message (which can be amended), or writing a hook to require confirmation before any file write (which duplicates what the guardian already does, but pre-hoc and for every single operation rather than per-phase).

**Why it fails**

Hooks are designed for irreversible operations. Using them on reversible operations adds pre-hoc friction to every occurrence of the operation, slowing the harness and making the implementing agent's work more interrupted. A hook that fires on a reversible operation is, at best, redundant with the guardian (which will catch the same violation post-hoc). At worst, it creates a false sense of security: the user believes the hook is preventing violations, but the hook's logic is less sophisticated than a guardian prompt and may miss semantic violations that the guardian would catch. Hook-Over-Guardian also signals a design philosophy mismatch: hooks are meant to be rare and targeted at the irreversible edge; if a harness has many hooks, most of them are probably doing guardian work badly.

**How to detect it during brainstorming/debating**

Ask the core question: "Is this operation truly irreversible?" If the answer is "no" — if git can undo it, if the file can be restored, if the commit can be reset — then a hook is not the right tool. Hooks are for operations where a mistake cannot be cheaply undone after the fact. For all reversible operations, the guardian is the right enforcement mechanism. Probing question: "For this hook you're designing — if the operation it's guarding runs and produces a bad result, what is the recovery procedure? If the recovery procedure is a `git reset` or a file restore, the guardian can handle it; the hook is unnecessary."

**How to fix it**

Move the check from the hook into the guardian prompt. The guardian's Decision Rubric should include the criterion the hook was checking (e.g., "all modified file paths fall within the allowlist," "no test files were modified during the Impl phase"). If the guardian prompt is already checking this criterion, remove the hook entirely — it is pure overhead. Reserve hooks for the specific operations listed in the Hook vs Guardian Decision Guide (§5): external API calls, destructive bash outside the project, git pushes, package publishes, and other operations whose reversal is impractical or impossible.

---

### 6.8 Scope Creep Into Deployment

**What it looks like**

The plan or implementation extends past "committed code in the user's project" into territory the spec did not declare: deployment to test/staging/production, `git push` on the user's behalf, branch merges, release tagging, CI/CD pipeline configuration, "go live" instructions, or unsolicited "manual e2e in real environment" steps in the implementing skill's terminal message. A frequent shape of this pitfall: an "实际生效路径" / "next actual steps" section appended to the implementing skill's output that proposes deployment + manual verification, even though the spec only asked for code + tests.

**Why it fails**

Unleash's safety model rests on a clean scope boundary — the harness builds artifacts inside the user's project tree, and the user controls what happens to those artifacts afterward. The moment the harness suggests or attempts deployment, three things break: (1) the user no longer trusts that invoking Unleash is bounded — every invocation now risks side effects outside the project; (2) the harness skills' contracts become unclear (does implementing produce code, or code-and-deploy? does validating verify the build, or the deployment?); (3) deployment-related advice is rarely correct anyway, because the AI lacks knowledge of the user's actual deployment pipeline, secrets, environments, and rollback procedures. The pitfall typically originates from "helpful extrapolation" by the AI generating the final user-facing message — not from any explicit task in the plan — which makes it especially easy to miss in static review.

**How to detect it during brainstorming/debating**

Look for any task description, plan section, or skill termination message that uses the words "deploy", "push", "merge", "release", "go live", "test environment", "staging", "production", "rollout", or "ship". Also look for sections titled "next actual steps" / "实际生效路径" / "what to do now" / "follow-up actions" that go beyond invoking the next Unleash skill. Probe questions: "Where does this harness's responsibility end? After the code is committed, or after it's running somewhere?" — the answer must be the former. "If the implementing skill produced a perfect spec-compliant build but no deployment, would that be acceptable?" — the answer must be yes.

**How to fix it**

Remove every deployment-related task from the plan; remove every deployment-related sentence from skill termination messages. Each Unleash skill terminates by handing control back to the user with a literal message — no extrapolation. The implementing skill in particular must deliver its terminal message verbatim per its template, with no appended "you should now..." section. If the user genuinely wants deployment automation, that is a separate harness they would design by running Unleash again on a deployment-specific spec — not something this harness's planning or implementing layers should silently include.

---

### 6.9 Negation Overcorrection

**What it looks like**

A safety mechanism is introduced to prevent a specific bad behavior, but the mechanism is so broad that it also prevents valid behaviors the spec explicitly requires. Common forms: a PreToolUse hook that blocks all file writes to prevent unreviewed changes, but the spec's Phase 2 is explicitly a Restricted-Write phase; a guardian rubric that flags any shell command as a violation, but the spec's Script phase requires a named bash operation; a test gate that rejects any test that isn't fully automated, but the spec chose testing_mode B (manual checklist) and the task correctly implemented the checklist.

**Why it fails**

Negation Overcorrection makes the harness self-contradictory: the spec says "do X" and the safety layer says "never do X." The implementing agent is placed in an impossible position — it cannot satisfy both the spec and the safety mechanism simultaneously. The failure mode is typically silent: the agent finds a workaround (e.g., using a different tool pattern that the safety layer doesn't recognize), which means the safety layer is not actually enforcing the constraint it was designed for — it's just pushing the agent to use less-visible paths. Alternatively, the agent halts and reports BLOCKED, but the controller has no protocol for resolving a contradiction between the spec and its own safety layer.

**How to detect it during brainstorming/debating**

For every safety mechanism (hook, guardian rubric, test gate), trace every action it prohibits and ask: "Is any of these actions explicitly required by the spec?" If the answer is yes, the safety mechanism is overcorrected. Also check for negation framing: mechanisms defined in terms of "do not allow X" rather than "only allow Y" tend to overcorrect because X is often a legitimate tool in a different phase. Probing question: "If the spec requires a file write in phase 2, does any hook or guardian rule fire on that write? If yes, the safety layer and the spec are in conflict."

**How to fix it**

Replace blanket negations with scoped, phase-aware allowlists. A hook should not say "block all file writes"; it should say "block file writes outside the phase's declared write allowlist." A guardian rubric should not say "flag any shell command"; it should say "flag shell commands that are not in the phase's declared command allowlist." The fix is always the same: change the safety mechanism from a blacklist ("prevent X") to a whitelist ("only permit what the spec named"). If the safety mechanism was generated by an earlier version of the skill and the spec has since evolved, re-run the safety-layer generation against the current spec rather than patching the old mechanism.

---

### 6.10 Recency Amnesia

**What it looks like**

A skill operates correctly in early turns but gradually drifts from the spec's intent as the conversation lengthens. The model stops referencing the committed spec or plan, instead treating the most recent user message as the primary source of truth. Decisions made in turn 3 are silently overridden in turn 12 because the model no longer remembers they were committed. The user says "actually, let's also handle edge case X" in turn 9, and by turn 15 the model has treated X as if it were in the original spec, even though it was never debated, never specced, and never planned.

**Why it fails**

Recency Amnesia is a context-window failure mode, not an intent failure. The model does not consciously decide to ignore the spec; it simply loses the spec's details in the noise of a long conversation. The most recent messages have higher activation, and the early committed decisions fade. When the user makes a casual suggestion ("maybe also...", "what if we...", "could you just..."), the model treats it as a directive because it has no strong competing memory of the spec's boundaries. The result is a harness that grows organically during conversation rather than staying within its designed shape — scope creep that happens one message at a time, below the threshold of conscious decision.

**How to detect it during brainstorming/debating**

Recency Amnesia cannot be fully prevented by prompting alone; it requires structural guards:
- **Anchor Summary (lightweight):** After every 8th message in a skill conversation, the skill re-reads the committed spec and plan from disk and outputs a 5-bullet anchor summary: (1) original harness purpose, (2) committed decisions that cannot change without user approval, (3) what the current turn is about, (4) whether the current turn threatens any committed decision, (5) recommended stance (proceed / pause / reject). This summary is internal; it is shown to the user only if the stance is pause or reject.
- **Drift Check (debating):** In `unleash:debating`, every user answer that closes a gap is classified against the brainstorm baseline: DERIVED, OVERRIDES, NARROWS, or NEW_GROUND. OVERRIDES and NARROWS are recorded and fed into a Phase E adversarial audit before the spec is presented for approval.
- **Group Checkpoint (implementing):** In `unleash:implementing`, after completing each Task Group, the controller re-reads the plan and verifies that all artifacts exist at declared paths and that testing_mode has not been silently altered.
- Probing question: "In the last 3 turns, have any of my responses contradicted or narrowed something I said in the first 3 turns? If yes, which turn introduced the drift?"

**How to fix it**

The fix is prevention, not retroactive correction — once Recency Amnesia has altered the spec or implementation, the drift is already committed. Prevention requires the structural guards above (Anchor Summary, Drift Check, Group Checkpoint). If drift is detected retroactively: for debating, return to Phase C and re-open the drifted gap with an explicit challenge; for implementing, STOP at the Group Checkpoint and report the deviation before proceeding. Do not "smooth over" drift by silently adjusting the spec or plan to match the recent conversation.

---

## 7. Vocabulary

Canonical definitions of terms used across Unleash skills. When a skill's conversation uses one of these terms, it should match the definition here.

---

**5 Elements** — The five design lenses used as the questioning backbone of harness design: Constraint Boundary, Quantifiable Feedback, State Persistence, Reversibility, and Autonomy (§1). These are not a checklist to complete mechanically; they are interrogation tools. Each element is evaluated for applicability first, and any element without a meaningful expression in a given harness is marked N/A with an explicit rationale.

**Allowlist** — The set of file paths and tool patterns a phase is permitted to touch during its execution. Allowlists are per-phase and dynamic across phases — a property called L2 dynamism — meaning phase 1 may permit writes to `docs/` while phase 2 permits writes to `src/` and phase 3 opens `tests/`. The allowlist is the primary specification of the Constraint Boundary element. An allowlist that is not written down and version-controlled is not an allowlist; it is an informal assumption.

**Archive** — A preserved bundle produced by `unleash:archiving` at the end of a harness's life. The archive contains all harness artifacts, the spec, the plan, the guardian prompt, and any hook scripts, bundled in a form that can be consulted later or used as the starting point for a new harness iteration. Archiving is a Plan 3 concern; its exact format is defined by the archiving skill.

**Artifact** — Any file produced or consumed by a phase. Artifacts include spec documents, plans, per-phase markdown state files, output documents (analysis reports, evaluation results), hook scripts, and any source code or configuration files modified by the harness. Every artifact that participates in a phase handoff must appear in both the upstream phase's write allowlist and the downstream phase's read allowlist; a path that appears in one but not the other is an Allowlist Drift candidate.

**B-layer** — The set of soft-guidance artifacts addressed to the AI agent running the harness. B-layer artifacts include the spec document, the plan, and per-phase markdown instructions. They express intent, context, and guidance; they tell the AI what to do and why. B-layer artifacts are readable and modifiable by the AI. They are not enforcement mechanisms — they can be misread, misunderstood, or ignored by a misbehaving agent. Contrast with C-layer.

**C-layer** — The set of hard-enforcement artifacts that constrain what the AI agent can do, independent of whether the agent reads or respects the B-layer. C-layer artifacts include Claude Code PreToolUse hooks, git hooks, pre-commit scripts, and any other mechanism that operates at the system level to block or gate actions before they execute. C-layer enforcement fires whether or not the AI agent is cooperating; it is the defense against misconfiguration, prompt injection, and agent misbehavior. B-layer and C-layer together form the harness's constraint system.

**Gate** — A condition on a phase transition. An entry gate is a condition that must be true before a phase may start (e.g., the prior phase's artifact is present and committed). An exit gate is a condition that must be true before a phase may be considered complete (e.g., the test suite passes, the guardian issues a PASS verdict). Gates are not optional: a phase without a declared entry gate can start at any time regardless of harness state, and a phase without a declared exit gate can end without producing its intended output.

**Guardian** — An independent AI subagent that reviews harness activity post-hoc and triggers rollback on violation. The guardian receives a set of evidence artifacts (git diff, tool-call log, output artifacts) after each phase completes, applies the Decision Rubric from its prompt, and issues a PASS or FAIL verdict. On FAIL, it triggers the appropriate rollback mechanism. The guardian is independent: it does not share context with the implementing agent, does not receive the implementing agent's reasoning, and evaluates only hard evidence. Independence is the guardian's most important property; a guardian that shares context with the implementer will rationalize violations. See §4.

**Harness** — A system of constraints, feedback, state persistence, reversibility, and autonomy conditions that makes AI agent behavior reliable for a given task. A harness is not a prompt; it is a multi-artifact system that includes a spec (B-layer), enforcement mechanisms (C-layer), a guardian, and defined phase transitions. The five elements (§1) are the design vocabulary for specifying what a harness needs. A harness that is missing any applicable element is under-specified, even if it runs successfully on a clean path — the missing element represents a failure mode that has not been designed for.

**Hook** — A pre-hoc technical block (Claude Code PreToolUse hook or git hook) that fires before a specific operation executes and can block it if conditions are not met. Hooks are reserved for irreversible operations — operations whose effects cannot be cheaply undone after completion. For all reversible operations, the guardian is the appropriate enforcement mechanism (see §5). A harness with many hooks covering reversible operations is likely exhibiting the Hook-Over-Guardian pitfall (§6.7).

**Irreversible operation** — An operation whose effect cannot be cheaply undone after completion (see §5). Examples: sending an email, calling an external API that creates a resource, pushing to a remote git repository, publishing a package. The reversibility test is not theoretical ("could this be undone with enough effort?") but practical ("can this be undone within the harness's response time, without human coordination, without side effects on other systems?"). When uncertain, default to treating an operation as irreversible.

**Manifest** — `.unleash/manifest.json`, the authoritative inventory of every file Unleash has created or modified, including the originating task and commit SHA per entry. Schema documented in §8.2. Consumed by `unleash:validating`, `unleash:walking-through`, `unleash:archiving`, and `scripts/unleash-uninstall.sh`. Appended by `unleash:implementing` as it commits each task.

**Phase** — One step in a harness's state machine. A phase has a type (its Phase Primitive), an entry gate, an exit gate, an allowlist (read and write), a list of artifacts consumed, and a list of artifacts produced. Phases are atomic with respect to commits: a phase either completes and commits its work, or it is rolled back entirely. A phase that commits partial work violates atomicity and makes rollback ambiguous. The full harness is the ordered sequence of all its phases, with the transitions between them governed by gates.

**Phase Primitive** — An abstract behavior type that categorizes what a phase does (§3). The six primitives are: Read-Only, Restricted-Write, Script, Human-Check, AI-Judge, and Loop. Primitives are vocabulary for composing phases during harness design — they are not implementations, templates, or code. Assigning a primitive to a phase establishes its expected allowlist shape, commit behavior, guardian responsibility, and common failure modes, without prescribing how the phase is implemented. A phase that doesn't fit any primitive cleanly should be named explicitly by the user as a custom type.

**Runtime Guardian** — An alias for Guardian, used to emphasize that the guardian operates at harness runtime (reviewing live phase activity) as opposed to build-time reviewers (human reviewers who read the spec before the harness runs). The distinction matters when a harness design includes both: a build-time human review of the spec does not substitute for a runtime guardian, and a runtime guardian does not substitute for a build-time spec review. Both serve different purposes.

**Starter Pattern** — A conceptual example offered during brainstorming (§2) to help a user understand what a harness for their kind of task might look like. Starter patterns are suggestions, not templates: they are never applied to a user's harness automatically or mechanically. The four starter patterns are: Coding Pipeline, Metric Loop, Hybrid, and Freeform. Each pattern is a description of a typical phase sequence and typical 5-element shape for a class of tasks; the user may accept, modify, or reject any part of it.

**Uninstall** — `scripts/unleash-uninstall.sh`, the manifest-driven mechanical removal of all changes Unleash made to the project. Not a skill — uninstall is reversal mechanics, not decision-making. Asks for per-file confirmation; refuses to remove a `modified` file if its current SHA differs from `original_sha` recorded in the manifest (safety check against post-Unleash hand edits).

**Anchor Summary** — A lightweight internal reset mechanism required after every 8th message in any Unleash skill conversation. The skill re-reads the committed spec and plan from disk, then outputs a 5-bullet summary: (1) original harness purpose, (2) committed decisions that cannot change without user approval, (3) what the current turn is about, (4) whether the current turn threatens any committed decision, (5) recommended stance (proceed / pause-for-confirmation / reject-as-out-of-scope). The summary is not shown to the user unless the stance is pause or reject. Defined in `unleash:using-unleash` Long-duration dialogue guard.

**Drift Check** — A mandatory classification performed in `unleash:debating` Phase C after every user answer that closes a gap. The answer is classified against the brainstorm baseline as DERIVED (consistent), OVERRIDES (replaces earlier decision), NARROWS (scopes down), or NEW_GROUND (no basis in brainstorm). OVERRIDES and NARROWS are recorded and fed into Phase E's adversarial audit. A gap closure without a Drift Check is a skill failure.

**Group Checkpoint** — A hard gate in `unleash:implementing` Phase C, triggered after completing the last task in a Group. The controller re-reads the plan's Group section and verifies: (a) every task in the Group has status DONE or DONE_WITH_CONCERNS, (b) all artifacts in the Group's Dependency Map exist at declared paths, (c) `testing_mode` has not been silently altered. If any check fails, the controller STOPs and reports the deviation; if all pass, a checkpoint record is appended to `.unleash/checkpoints/group-<N>.md`.

---

## 8. Project Filesystem Layout

Every Unleash-managed project uses a consistent `.unleash/` subdirectory at the project root. This convention is fixed across harnesses so that skills, the uninstall script, and human readers can find artifacts without negotiation.

### 8.1 Directory layout

```
<project-root>/
├── .unleash/                       # Unleash-managed runtime artifacts
│   ├── manifest.json               # authoritative inventory of every file Unleash has created or modified (see §8.2)
│   ├── phases/                     # phase configs produced by unleash:implementing per spec
│   │   └── <N>-<phase-name>.json
│   ├── guardians/                  # guardian prompts produced by unleash:implementing per spec
│   │   └── <phase-name>-guardian.md
│   ├── walkthroughs/               # first-run records produced by unleash:walking-through
│   │   └── <YYYY-MM-DD>-<name>.md
│   └── archives/                   # frozen bundles produced by unleash:archiving
│       └── <YYYY-MM-DD>-<name>/
└── docs/unleash/                   # human-readable Unleash workflow docs (committed alongside source)
    ├── brainstorm/                 # brainstorm notes from unleash:brainstorming
    │   └── <YYYY-MM-DD>-<name>.md
    ├── specs/                      # specs from unleash:debating
    │   └── <YYYY-MM-DD>-<name>-spec.md
    ├── plans/                      # plans from unleash:planning
    │   └── <YYYY-MM-DD>-<name>-plan.md
    ├── validation/                 # validation reports from unleash:validating
    │   └── <YYYY-MM-DD>-<name>-validation.md
    └── walkthroughs/               # mirrors of .unleash/walkthroughs (human-friendly copies; optional)
```

The split between `.unleash/` (runtime) and `docs/unleash/` (process artifacts) is intentional: `.unleash/` contains the machinery the harness needs to run, while `docs/unleash/` contains the conversation that produced the harness. Users can grep their project for either independently. Both are git-tracked.

### 8.2 Manifest schema

`.unleash/manifest.json` is the authoritative inventory of every file Unleash has created or modified. Schema (JSON):

```json
{
  "schema_version": "1",
  "harness_name": "<slug from spec>",
  "spec_sha": "<git sha of spec.md at plan time>",
  "plan_sha": "<git sha of plan.md at implementation time>",
  "unleash_version": "0.3.0",
  "installed_at": "2026-04-25T12:34:56Z",
  "created": [
    {
      "path": ".unleash/phases/1-spec.json",
      "task": "PM1",
      "commit_sha": "abcd1234"
    }
  ],
  "modified": [
    {
      "path": ".claude/settings.local.json",
      "block_marker": "# unleash-managed:start ... # unleash-managed:end",
      "original_sha": "ef567890",
      "task": "S1",
      "commit_sha": "1234abcd"
    }
  ]
}
```

**Field semantics:**
- `created` — files Unleash created from scratch. Uninstall removes these by `rm`.
- `modified` — files Unleash modified in place. The `block_marker` field names the comment delimiters (Unleash's modification is sandwiched between them); uninstall removes only the block, leaving rest of file intact. The `original_sha` is the SHA of the file BEFORE Unleash modified it, captured for safety verification (refuse to uninstall if file changed unexpectedly).
- `task` — the plan task ID that produced this entry (for traceability)
- `commit_sha` — the git commit SHA that introduced the change

The manifest is appended to by `unleash:implementing` as it commits each task. Validating, walking-through, and archiving all READ from the manifest as their inventory. The uninstall script (`scripts/unleash-uninstall.sh`) reverses every entry on demand.

### 8.3 Uninstall semantics

Three uninstall use cases:
- **Clean removal** — user wants to disengage from the harness entirely. `scripts/unleash-uninstall.sh` removes every `created` file and reverts every `modified` block. Asks for confirmation per file.
- **Archive-then-remove** — user has finished using the harness, wants to keep the lifecycle record but remove the runtime machinery. Run `unleash:archiving` first (preserves bundle in `.unleash/archives/<...>/`), then `unleash-uninstall.sh` (removes phases/, guardians/, manifest.json — but `archives/` survives by design).
- **Error rollback** — if any Unleash skill fails mid-chain, the skill's error path can invoke `unleash-uninstall.sh --since <commit-sha>` to revert only the entries created after that point.

Uninstall is mechanical, not LLM-mediated. The script reads JSON, removes files, restores blocks, asks confirmations. No skills involved.
