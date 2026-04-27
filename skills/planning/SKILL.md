---
name: planning
description: "Use after unleash:debating produces a committed spec.md — internalizes writing-plans discipline with harness-specific task grouping and Artifact Dependency Map to produce a plan.md that drives unleash:implementing."
---

# Unleash: Planning

> Take a committed spec.md to a committed plan.md, with task groups organized by harness construct and an explicit Artifact Dependency Map.

<HARD-GATE>
Do NOT produce a flat task list. Every plan MUST have an Artifact Dependency Map section AND task groups organized by harness construct (Phase Machine, Runtime Guardian, Optional Hooks, Walkthrough Scripts).

Do NOT leave any placeholder in the plan. Every task step must have complete code or complete content — "TBD", "TODO", "fill in later", "similar to Task N" are all plan failures.

This applies even when the spec looks simple, even when the user is in a hurry, and even when the tasks would normally be a straightforward flat list in generic writing-plans. Harness construct organization is non-negotiable.
</HARD-GATE>

## Precondition

Before proceeding with any planning activity, verify all three conditions below. If any condition fails, STOP and report the specific missing item to the user.

**Condition 1: Spec file exists.**

The file must be present at:

```
docs/unleash/specs/<YYYY-MM-DD>-<slug>-spec.md
```

If the file is absent, STOP and tell the user:

> "Spec file not found at expected path. Run unleash:debating to produce a committed spec before invoking planning."

**Condition 2: Spec is committed.**

Run `git log --oneline -5 -- docs/unleash/specs/<filename>` to confirm the spec file appears in the commit log. If the spec is dirty or untracked, STOP and tell the user:

> "The spec at `docs/unleash/specs/<filename>` is not committed. Commit it (and have the user approve it) before invoking unleash:planning. Planning works against a specific committed version — uncommitted specs cannot be cited reliably."

**Condition 3: Spec has all 6 required sections.**

Read the spec and confirm these sections are present: `case_type` (or `## Case Type`), `five_element_analysis` (or `## 5-Element Analysis`), `phase_machine` (or `## Phase Machine`), `guardian_design` (or `## Guardian Design`), `optional_hooks` (or `## Optional Hooks`), `out_of_scope` (or `## Out of Scope`).

If any section is missing, STOP and tell the user:

> "Spec is missing required section(s): [list the missing ones]. Re-run unleash:debating to complete the spec before invoking planning. A plan cannot be produced from an incomplete spec."

## Contract

**Consumes:** `docs/unleash/specs/<YYYY-MM-DD>-<name>-spec.md` (committed, validated).

**Produces:** `docs/unleash/plans/<YYYY-MM-DD>-<name>-plan.md` — implementation plan with: Plan header (case type, guardian role, phase summary), Artifact Dependency Map, Task Groups (Phase Machine, Runtime Guardian, optional Hooks, Walkthrough Scripts), per-task fields (Files, Artifact Type, Produces, Consumes, step-by-step 2–5-minute steps).

**Precondition:** Spec is committed, passes structural validation, user-approved.

**Postcondition:** Plan is committed, self-review passed (Spec Coverage / Placeholder Scan / Type Consistency / Artifact Dependency Closure / Guardian Prompt Quality).

## Anti-patterns: "just make a task list"

The following rationalizations are traps. Each one feels true in the moment and produces a weaker plan when acted on. Recognize them and reject them.

> **Thought:** "The spec is simple — a flat task list will do."
> **Rebuttal:** A flat list hides the artifact dependencies. When unleash:implementing dispatches subagents per task, each subagent needs to know what artifacts it produces vs. consumes. Without the Dependency Map, later tasks reference upstream artifacts that haven't been flagged as producers, and the plan silently becomes unexecutable.

> **Thought:** "Groups are ceremony — just number the tasks."
> **Rebuttal:** Groups tell the implementing controller whether tasks are independently dispatchable or sequentially dependent. The Phase Machine group can often be parallelized across phases; the Guardian group cannot start until the Phase Machine spec is done. Losing this information means the controller serializes everything and the build is 3× slower.

> **Thought:** "The guardian prompt is just a string — I can put a placeholder."
> **Rebuttal:** The guardian prompt is the runtime behavior of the harness. If the plan says "TODO: write guardian prompt", the implementing subagent receives a placeholder and will either make up its own prompt (unpredictable behavior) or block on the gap. The prompt needs to be fully specified in the plan, with Role / Instructions / Decision Rubric / Edge Cases / Output Format — see `references/unleash-knowledge.md` §4.2 for the schema.

> **Thought:** "I already know what this task needs; the implementer can figure out the details."
> **Rebuttal:** Implementer subagents have zero context beyond what the plan gives them. "Figure out the details" means the subagent invents a design that may not match your intent. Every design decision belongs in the plan; the subagent's job is execution, not design.

> **Thought:** "The user will obviously also need to deploy / push / set up CI — let me plan those steps too."
> **Rebuttal:** Deployment, `git push`, CI/CD pipelines, branch merges, release tagging, and "going live" are explicitly OUT of Unleash's scope. The spec governs the plan's reach; if the spec did not declare a step, do not plan it. The user's domain begins where the harness's committed code ends — Unleash builds the code and stops. Inventing deployment tasks erodes the boundary that makes Unleash safe to invoke.

> **Thought:** "The user picked testing_mode B but TDD is just so much cleaner — I'll plan unit tests anyway and they can ignore the checklist if they don't like it."
> **Rebuttal:** The testing_mode is the user's commitment in the spec, not a suggestion. Mode B exists because the user knows their domain and decided unit tests aren't feasible (UI flows, external integrations, judgment calls about UX). Overriding their declared mode by silently inserting unit tests means the plan doesn't match what they signed up for; implementing dispatches subagents that write tests against an architecture that doesn't support them; the whole chain stalls. Honor the declared mode. If you think TDD is genuinely better for the case, raise it as a concern in Phase D self-review and let the user decide whether to revise the spec — don't override silently.

## Operating Protocol

### Phase A — Absorption

Read before planning. Every decision in Phase C must be grounded in something read during this phase.

- Read the committed spec.md in full, treating every section as a hard constraint on what the plan must build
- Note the spec's commit SHA (run `git log --oneline -5 -- <spec-path>`) to record in the plan's header as the reference spec
- Read `references/unleash-knowledge.md` §3 (Phase Primitive Vocabulary) and §4 (Runtime Guardian Design Patterns) — the guardian prompt schema in §4.2 is required reading before writing any guardian task
- **Extract `testing_mode` from spec's Quantifiable Feedback section.** Look for a line like `testing_mode: A` (or B, C, other). If the spec doesn't explicitly declare a testing_mode, default to A and note this in the plan header as `**Testing Mode:** A (default — spec did not specify)`. If testing_mode is `D` / `other`, the spec MUST also specify what kind of testing the user wants; if that specification is missing, STOP and tell the user to revise the spec to clarify.
- If the spec mentions starter patterns or references prior brainstorm artifacts, read those too

The output of Phase A is an internal understanding of the spec and harness vocabulary. Nothing is shown to the user during this phase.

### Phase B — Artifact Dependency Mapping (INTERNAL)

Before composing any tasks, build an internal map: for each artifact the harness will require, identify its producer task and its consumer(s). This map drives the Artifact Dependency Map section written in Phase D.

Typical artifacts for a coding-case harness (adapt to what the spec actually declares):

- `.unleash/phases/<N>-<name>.json` per phase — producer: Phase Machine task for that phase; consumer: implementing subagent and guardian
- `.unleash/guardians/<phase>-guardian.md` per phase that has a write allowlist — producer: Guardian task for that phase; consumer: guardian review invocation
- `.unleash/settings-patch.json` if the spec triggers settings changes — producer: settings task; consumer: harness install step
- `.unleash/walkthrough.md` — producer: Walkthrough task; consumer: unleash:walking-through

Do NOT invent artifacts the spec does not call for. If the spec's `optional_hooks` section says "None", there are no hook artifacts — do not add them. The map reflects only what the spec declares.

This map is NOT presented to the user yet — Phase D writes it into the plan as the Artifact Dependency Map table.

### Phase C — Task Composition (INTERNAL)

Compose tasks, grouped by harness construct. The construct groups are defined by what the spec declares — not all four groups are present in every plan.

#### Testing-mode shapes the Test phase

The spec's `testing_mode` (extracted in Phase A) determines what Test-phase tasks look like in Group A. Branch the plan as follows:

**Mode A (TDD) — current default behavior:**
Test phase is a `Restricted-Write` primitive. Group A includes a task that writes failing test files in `tests/` (or the spec's declared test-file location), exit gate is "tests run red". The next phase (Impl) makes them green.

**Mode B (manual checklist):**
Test phase is a `Human-Check` primitive (per knowledge §3.4). Group A's Test task does NOT write code; it writes a sharp markdown checklist file at `docs/unleash/manual-checks/<date>-<name>-checklist.md` containing concrete steps the user will perform manually (e.g. "1. Open the app at localhost:3000 and click Login. 2. Enter user@test.com / wrong-password. 3. Confirm error message says 'Invalid credentials' (not 'User not found')."). The Impl phase happens, then the plan halts with a Human-Check task that says "Run the checklist; report which items pass/fail." Implementing pauses here, waits for the user's report, then resumes (or the user invokes implementing again with the checklist results in the prompt).

The checklist must be SHARP — concrete steps the user can execute without further interpretation. Vague checklists ("verify the feature works") are a plan failure.

**Mode C (skip testing):**
No Test phase. Group A includes only Impl + Verify (no Test). The plan header explicitly notes `Test phase: skipped per spec testing_mode: C`. The user signed up for "I'll judge by reading code"; the plan respects that. Do NOT silently slip in a Test phase.

**Mode D (other):**
The spec must specify what the user wants. Read it. Compose the Test phase per the spec. If the spec is ambiguous, STOP and ask the user to clarify (do not invent).

**Group A: Phase Machine** — always present. One or more tasks to create the phase configuration files (entry gates, exit gates, allowlists, artifact declarations) for every phase listed in the spec's `phase_machine` section. Configuration must be complete: if a phase declares an allowlist, the task must write the full allowlist, not a placeholder.

**Group B: Runtime Guardian** — always present. One task to write the guardian prompt file, one or more tasks for invocation glue and rollback mechanism. The guardian prompt task must produce the full prompt containing all five sections from `references/unleash-knowledge.md` §4.2: Role, Instructions, Decision Rubric, Edge Cases, Output Format. "Write a guardian prompt" without the full content is a plan failure.

**Group C: Optional Hooks** — present only if the spec's `optional_hooks` section declares at least one hook. If `optional_hooks` says "None" or "No hooks required", Group C is absent from the plan. Do NOT invent hooks that the spec did not declare. When Group C (Optional Hooks) IS present, every hook task MUST include a four-item Hook Safety Checklist: (1) trigger condition, (2) reversibility assessment, (3) rollback plan if hook fires wrongly, (4) fallback behavior if hook itself fails. Missing any of these four items is a plan failure.

**Group D: Walkthrough Scripts** — always present. Tasks to create the walkthrough artifacts that unleash:walking-through will execute for the supervised first run.

**Phase transition verification:** For each phase N > 1 in the spec's phase machine, the plan MUST include a task (in Group A) that verifies the prior phase (N-1)'s output artifact exists and is valid before phase N can begin. The verification takes the form of a small script or check that the implementing subagent runs. Do not leave phase transitions implicit.

**Per-task rules:**

- **Files** field: list each file the task Creates, Modifies, or Tests, with exact paths
- **Artifact Type** field: one of config / prompt / script / test / doc
- **Produces** field: name the artifact(s) this task outputs (must appear in the Dependency Map)
- **Consumes** field: name the artifact(s) this task takes as input (must appear in the Dependency Map as produced by a prior task or declared as an external harness input)

**External harness input** means an artifact that exists in the project before this plan executes — e.g., the spec.md itself, an existing `CLAUDE.md`, or a project file the harness reads but does not produce. External inputs appear in the Dependency Map as rows with Producer = "external" and are valid Consumes references for any task.
- **Steps** field: 2–5-minute steps with complete code — no descriptions of what to do without showing the code or content

**On task granularity:**

Tasks (the units in this plan) aim for 2–5 minutes each — one focused action: write one file, run one verification, commit one artifact. This is the writing-plans discipline inherited for plan construction.

Phases (the runtime units in the user's harness) take whatever duration the spec declares. The plan builds tasks around the spec's phase machine as-is — do not second-guess the phase machine's structure or the resource each phase represents.

Do NOT comment on whether the spec's phases are appropriately sized. Do NOT suggest splitting, merging, or resizing phases. The spec's phase machine is accepted as-is. Your only job in Phase C is to write tasks that implement what the spec declared.

### Phase D — Self-Review and Commit

Run the 5-item self-review checklist before presenting the plan to the user. Fix any failures in-line — do not present a plan with known deficiencies.

1. **Spec Coverage** — skim each section of the spec; confirm every requirement maps to at least one task. List any gap found and add the missing task before proceeding.
2. **Placeholder Scan** — search the plan for: TBD, TODO, fill in later, fill in details, similar to Task, implement later, FIXME. Each match is a plan failure; fix it by writing the actual content.
3. **Type Consistency** — verify that types, names, paths, and artifact names match exactly across all tasks. A file called `guardian-phase-1.md` in Task G1 must not appear as `guardian-p1.md` in Task G2.
4. **Artifact Dependency Closure** — every artifact in the Dependency Map has a named producer task AND a named consumer task. Orphan artifacts (produced but never consumed, or consumed but never produced) are plan failures.
5. **Guardian Prompt Quality** — the guardian prompt task must contain the full five-section prompt (Role / Instructions / Decision Rubric / Edge Cases / Output Format). A task that says "write a guardian prompt covering allowlist compliance" without the full text fails this check.
6. **Testing-Mode Honored Check** — verify the plan's Test phase shape matches the spec's `testing_mode`: mode A → Restricted-Write tests/ task; mode B → Human-Check checklist task + halt step; mode C → no Test phase; mode D → matches spec's specification. If the plan deviated from declared mode, fix in-line.

Present the self-review summary alongside the plan. Commit on user approval.

## Plan Document Required Header

Every plan produced by this skill MUST begin with exactly this header structure:

```markdown
# <Name> Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use unleash:implementing to execute this plan task-by-task.

**Goal:** <one sentence from the spec describing what this harness builds>

**Architecture:** <2-3 sentences describing the harness's runtime structure — case type, phase sequence, guardian role>

**Harness Case:** coding | metric | hybrid | freeform

**Guardian Role:** <one sentence: what the guardian reviews and what it does on violation>

**Phase Summary:**
- Phase 1 — <name>: <one line>
- Phase 2 — <name>: <one line>
- … (one line per phase declared in the spec)

**Testing Mode:** A | B | C | other (verbatim from spec; cite source line if needed)

**Reference spec:** <absolute path to spec.md> @ <commit SHA>

---

## Artifact Dependency Map

| Artifact | Producer | Consumer | Type |
|---|---|---|---|
| <artifact name or path> | <Task ID that creates it> | <Task ID(s) that read it> | config / prompt / script / test / doc |
| … | … | … | … |
```

The Artifact Dependency Map table must include every artifact that crosses a task boundary (produced by one task and consumed by another). Artifacts that are only internal to a single task need not appear. The table must have exactly four columns in this order: Artifact, Producer, Consumer, Type.

After the header, the plan body follows with the task groups (Group A, B, C if applicable, D).

## Output Artifact

**Filename:** `docs/unleash/plans/<YYYY-MM-DD>-<slug>-plan.md`

The slug matches the spec's slug. The date is today's date.

The file must contain all of the following sections, in order:

1. **Plan header** — as specified in §8 above, including the `**Reference spec:**` field with absolute path + commit SHA of the spec this plan was derived from, and the Artifact Dependency Map table
2. **Group A: Phase Machine** — tasks for every phase in the spec's phase machine
3. **Group B: Runtime Guardian** — guardian prompt task + invocation/rollback tasks
4. **Group C: Optional Hooks** — present only if spec declares hooks; otherwise include a note: `**Group C: Optional Hooks** — None (not declared in this harness's spec)`
5. **Group D: Walkthrough Scripts** — tasks for the first-run walkthrough
6. **Settings Impact Summary** — if any task modifies `.claude/settings.local.json` or similar user-facing config, the plan MUST include a dedicated section naming each modification, its runtime effect, and whether it persists after harness completion. If no settings are modified, state "None — this harness does not touch Claude Code user settings."
7. Self-review summary — one line per the 5-item checklist confirming each passed (or noting what was fixed)

A plan missing any of these sections is incomplete and must not be committed.

## Termination

<HARD-GATE>
Do NOT invoke unleash:implementing automatically. Present the plan to the user, commit it to git, and then tell the user to invoke unleash:implementing when they are ready. The user should read the plan and confirm it captures their intent before code starts to get generated.
</HARD-GATE>

The plan represents a complete design for the harness implementation. Auto-advancing to unleash:implementing before the user has read the plan erodes the purpose of the self-review step: if the user discovers in the middle of a subagent dispatch that the plan made a wrong design choice, the dispatch must be abandoned and the plan revised anyway. The cost of the auto-advance is not saved time — it is an invalidated implementation run. Present the plan, commit on approval, and stop. The user invokes unleash:implementing when they are ready.

## Checklist

Complete these items in order. Use TodoWrite to track progress.

1. Phase A: read spec.md + knowledge doc §3 and §4; **extract `testing_mode` from spec's Quantifiable Feedback**; note commit SHA
2. Phase B: build internal Artifact Dependency Map — for each artifact, name its producer task and consumer task(s); do not add artifacts the spec did not declare
3. Phase C: compose task groups — Group A (Phase Machine) always, Group B (Runtime Guardian) always, Group C (Optional Hooks) only if spec declares hooks, Group D (Walkthrough Scripts) always
4. Phase C: branch Test phase shape on testing_mode (A → Restricted-Write tests; B → Human-Check checklist + halt; C → no Test phase; D → per spec)
5. Phase C: write complete per-task content (no placeholders) — full code, full file paths, full guardian prompt with all five sections, verification commands
6. Phase D: run 6-item self-review (Spec Coverage / Placeholder Scan / Type Consistency / Artifact Dependency Closure / Guardian Prompt Quality / Testing-Mode Honored Check); fix every finding in-line
7. Present the plan and self-review summary to the user for approval
8. On approval, commit plan to git; STOP (do not invoke unleash:implementing)
