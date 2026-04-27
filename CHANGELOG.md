# Changelog

All notable changes to this plugin will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/).

## [0.4.0] - 2026-04-25

### Added
- Skill `unleash:using-unleash` — meta entry-point that establishes chain discipline before any other `unleash:*` skill is invoked. Modeled on the design subtleties of `superpowers:using-superpowers` (XML conventions, priority hierarchy, anti-rationalization mirror, Rigid-vs-Flexible signal) but adapted to Unleash's chain shape rather than a flat skill library.

### Why
External feedback (assistant review): Unleash had no "should I use Unleash at all?" gating skill and no "which workflow shape applies?" routing skill. The chain assumed correct invocation but had no entry-point that:
1. Recognized when a request was Unleash-shaped vs. when it should be handled directly,
2. Picked the right entry skill based on which artifact already existed (brainstorm.md / spec.md / plan.md / manifest.json),
3. Installed the cross-skill discipline (no auto-advance, scope ends at committed code, archiving-vs-reporting mutual exclusion, fresh-context for reviews) as invariants of the chain, not as advice.

The gap was real: without an entry-point, every individual skill repeated the same scope-boundary HARD-GATEs and termination handoffs, but nothing told the AI when not to start the chain or how to resume mid-chain. v0.4.0 closes that gap.

### Design decisions
- **Not auto-loaded by every session.** Unlike `superpowers:using-superpowers`, this skill is invoked when the user mentions Unleash / harness design / multi-step coding work, not as a hook on every conversation. Rationale: Unleash is a structured-workflow plugin, not a general-purpose discipline plugin; loading it into unrelated sessions would be noise.
- **Decision flow is artifact-driven, not user-state-driven.** The entry skill picks the next `unleash:*` skill based on which artifact (brainstorm.md, spec.md, plan.md, manifest.json) already exists and is committed — not based on chat narration. This honors the chain's "artifact is the contract" principle.
- **Anti-rationalizations target Unleash failure modes, not generic skill-bypass.** The Thought/Rebuttal pairs cover stage-skipping ("user explained, skip brainstorming"), auto-advance ("plan is committed, just start implementing"), shape confusion ("archive even with no manifest"), scope creep ("also push to remote"), memory substitution ("I remember what validating does"), and overzealous invocation ("borderline case, start brainstorming and see").
- **`SUBAGENT-STOP` retained verbatim.** The convention from `superpowers:using-superpowers` transfers cleanly: a subagent dispatched by `unleash:implementing` or any reviewer dispatched by archiving/reporting must skip the entry-point, since its dispatcher already curated the context.
- **Cross-model review concerns deferred.** The cross-model bias question (saved at `docs/design-notes/cross-model-review.md`) is independent of this entry-point change and remains an open research item.

### Verification
Static review only. Live verification deferred — the skill's effect surfaces in subsequent multi-step user sessions, similar to how `superpowers:using-superpowers` is verified.

## [0.3.2] - 2026-04-25

### Added (closes the v0.2.1 follow-up: testing_mode planning differentiation)
- `unleash:planning` now branches Test phase shape based on the spec's `testing_mode` field (which `unleash:debating` v0.2.1 captures via the 4-option probe):
  - **Mode A (TDD):** Test phase = Restricted-Write task producing `tests/` files (existing behavior, default)
  - **Mode B (manual checklist):** Test phase = Human-Check primitive producing a sharp markdown checklist at `docs/unleash/manual-checks/<date>-<name>-checklist.md` + an explicit halt step that pauses implementing until the user reports verification verdict
  - **Mode C (skip):** No Test phase at all; plan header notes `Test phase: skipped per spec testing_mode: C`
  - **Mode D (other):** Plan composed per spec's specification; STOPs if spec is ambiguous

### Changed
- `unleash:planning` Phase A — extracts `testing_mode` from spec's Quantifiable Feedback section; defaults to A with a header note if spec doesn't specify
- `unleash:planning` Plan Document Required Header — new `**Testing Mode:**` field
- `unleash:planning` Anti-patterns — new 5th rebuttal pair against silently overriding declared testing_mode
- `unleash:planning` Phase D self-review — new 6th item: "Testing-Mode Honored Check"
- `unleash:planning` Checklist — extended to 8 items reflecting testing_mode handling

### Why
v0.2.1 added the testing_mode probe to debating but planning still treated all Test phases as TDD. For users in mode B (UI flows, integration tests, judgment-call verification), this meant the spec captured intent but the plan didn't honor it — implementing dispatched subagents that wrote pytest files against architectures that didn't support them. v0.3.2 closes the loop: spec → plan → implement now respects testing_mode end-to-end.

### Verification
Live test PASSED 5/5 on a `testing_mode: B` fixture (a Flask login UI bug):
- plan.md committed at expected path
- header includes `**Testing Mode:** B (manual checklist)` with source citation
- Test phase task = Human-Check primitive producing a 5-step concrete numbered checklist (NOT pytest)
- Explicit halt step before Impl pause for user's report
- Zero pytest TDD slipped into the plan

## [0.3.1] - 2026-04-25

### Added (driven by real-world test feedback)
- Skill `unleash:reporting` — B-layer-only end-of-life skill. Writes a brief cold-review report (300-600 words, 4 dimensions + Open Questions) for single coding tasks where Unleash drove the dialogue but no runtime harness got installed. Parallel-2-of-1 to `unleash:archiving`: skills enforce mutual exclusion based on whether `.unleash/manifest.json` exists.
- Stress scenario `tests/scenarios/reporting/cold-review-on-bugfix.md` covering the pathspec-vs-grep edge case (commit message mentions `docs/unleash/specs/...` but commit only touches `src/...`)

### Why (gap discovered during real-world test)
User test of v0.3.0: completed a bug fix using `unleash:brainstorming → debating → planning → implementing` and tried to invoke `unleash:archiving`. Archiving correctly STOP'd because no `.unleash/manifest.json` existed (the harness was entirely B-layer — no runtime artifacts installed). This was correct behavior, but revealed an unmet need: the user still wanted a wrap-up report. v0.3.1 fills that gap.

### Design decisions (captured in SKILL.md anti-patterns)
- **Parallel-2-of-1 with archiving:** mutually exclusive based on manifest presence; each skill redirects to the other when wrong fit.
- **Cold-review isolation:** reviewer sees ONLY spec.md + filtered git diff + (optional) user verification one-liner. Never plan.md, brainstorm.md, commit messages, or manifest.
- **Pathspec-only filtering:** the diff is filtered using git pathspec syntax (`-- ':!docs/unleash/'`), NOT grep on commit messages or diff text. SKILL.md explicitly forbids message-based or line-based filtering as anti-patterns (catches the footgun where a commit message mentions `docs/unleash/specs` in prose but the commit only touched code).
- **Transparent filter report:** Phase B prints which files were included/excluded for the user to inspect before the reviewer is dispatched, catching unusual project layouts.

### Verification
- Live test PASSED 5/5 rubric checks including the pathspec-vs-grep edge case (a commit whose message mentioned `docs/unleash/specs/...` but only touched `src/logger.py` was correctly INCLUDED in the diff via pathspec; a commit that only touched `docs/unleash/specs/...` files was correctly EXCLUDED).
- Cold-review isolation verified: reviewer dispatch prompt contained zero plan/brainstorm/commit-message content.

## [0.3.0] - 2026-04-25

### Added (Plan 3 complete: verify + lifecycle)
- Skill `unleash:validating` — harness-aware audit performing 6 invariant checks (allowlist consistency, guardian alignment, irreversibility gating, artifact closure, loop termination, decide determinism) plus 2 generic checks (spec coverage, code quality); re-runnable; reports findings without applying fixes
- Skill `unleash:walking-through` — chaperones first real run; drives phase transition; **intentionally violates allowlist** to verify guardian fires and `git reset --hard` rolls back; records first-run outcome
- Skill `unleash:archiving` — bundles all lifecycle artifacts (brainstorm, spec, plan, validation, walkthrough, implementation snapshot) into `.unleash/archives/<...>/`; dispatches a **fresh independent reviewer** with strict context isolation (only spec + snapshot, NO manifest/validation/walkthrough) for end-of-life audit
- Manifest infrastructure: `.unleash/manifest.json` schema (`schema_version`, `harness_name`, `created`, `modified`, etc.) documented in knowledge §8.2
- `scripts/unleash-uninstall.sh` — manifest-driven mechanical uninstall with `--since` filter, `--yes` mode, and `original_sha` safety check (refuses to revert hand-edited files unless explicitly confirmed)
- Knowledge base §8 Project Filesystem Layout — canonical `.unleash/` and `docs/unleash/` directory conventions
- 3 stress-test scenarios (validating: 3 deliberate invariant violations; walking-through: guardian-fires-on-violation; archiving: fresh-reviewer-blind)
- Full 7-skill chain integration scenario at `tests/scenarios/integration/full-chain.md` for user manual end-to-end testing

### Changed
- `unleash:implementing` modified to append entries to `.unleash/manifest.json` per task commit (additive — no breaking change to v0.2.x behavior; the skill simply now produces an additional artifact)

### Design decisions (resolves spec §10 open questions)
- **§10.2 Manifest format and uninstall command:** manifest is `.unleash/manifest.json` with documented JSON schema; uninstall is a **bash script** (`scripts/unleash-uninstall.sh`), not a skill — uninstall is mechanical reversal, not LLM decision-making
- **§10.3 Project location convention:** `.unleash/` at project root with subdirectories `phases/`, `guardians/`, `walkthroughs/`, `archives/`; `docs/unleash/` for human-readable workflow artifacts (brainstorm/specs/plans/validation/walkthroughs)

### Verification status
- `unleash:validating` passed live test 5/5 + bonus catch (skill found a 4th violation beyond the 3 deliberately seeded)
- `unleash:walking-through` static review only; live multi-level dispatch (skill → phase implementer → guardian) deferred to user manual testing per Plan 2 T7's hang lesson
- `unleash:archiving` static review only; live multi-level dispatch (skill → fresh reviewer) similarly deferred
- Full-chain integration scenario delivered as runnable artifact for user manual demonstration

## [0.2.1] - 2026-04-25

### Changed (scope-boundary patch from real-world test feedback)
- **`unleash:implementing` Termination tightened** — terminal message is now strictly literal; explicit HARD-GATE forbids "next actual steps" / "实际生效路径" / "deploy" / "manual e2e" / any extrapolation beyond invoking unleash:validating
- **`unleash:planning` Anti-patterns +1** — added 5th rebuttal pair against deployment scope creep: "Deployment, push, CI/CD, release tagging, going live are explicitly out of scope. The spec governs the plan's reach."
- **`unleash:debating` Feedback-sharpness probe extended** — when concretizing Quantifiable Feedback for coding-case harnesses, the skill must now surface a 4-option testing-mode question: (A) Standard red-green TDD; (B) Logical/manual checklist for human; (C) Skip testing entirely; (D) Other. The chosen mode must be recorded in the spec as `testing_mode`. No defaulting to TDD without asking.
- **`references/unleash-knowledge.md` §6 Common Pitfalls +1** — added 6.8 Scope Creep Into Deployment with detection probes and fix guidance.

### Why
Real-world test of v0.2.0 surfaced that AI's "helpful extrapolation" added deployment + manual e2e + guardian-based judgment to implementing's terminal message, even though the spec didn't declare any of that. v0.2.1 hardens scope to "committed code in the user's project; nothing past that boundary."

## [0.2.0] - 2026-04-25

### Added
- Skill `unleash:planning` — takes spec.md → plan.md with Artifact Dependency Map and task groups organized by harness construct (Phase Machine / Runtime Guardian / Optional Hooks / Walkthrough)
- Skill `unleash:implementing` — dispatches fresh subagents per plan task with full task text pasted verbatim; no deep review (deferred to Plan 3's unleash:validating)
- Stress-test scenarios for both skills (`tests/scenarios/planning/artifact-map-present.md`, `tests/scenarios/implementing/subagent-dispatch.md`)
- Full-chain integration scenario `tests/scenarios/integration/spec-to-harness.md` covering the planning → implementing chain on a Sorter Refactor fixture

### Design decisions (resolves spec §10 open questions)
- **§10.1 Guardian runtime invocation:** per-phase-batch review with git-reset rollback (not per-tool-call, not continuous). Phase size is task-specific and not prescribed.
- **§10.5 Guardian prompt evolution:** guardian prompts are single files at stable paths (`.unleash/guardians/<phase>-guardian.md`), directly editable by the user; structural changes require re-planning.

### Notes on verification
- `unleash:planning` passed live sanity test (5/5 rubric checks + 2 bonus checks for spec §5.3 supplements).
- `unleash:implementing` was statically reviewed (spec compliance + code quality both clean for review-creep and phase-size red flags). Live nested-dispatch verification deferred to user manual testing — this mirrors the Plan 1 deployment pattern and the chain integration test (T10) is similarly deferred.

## [0.1.0] - 2026-04-24

### Added
- Plugin scaffolding (`.claude-plugin/plugin.json`, `package.json`, `.gitignore`)
- Documentation skeleton (`README.md`, `LICENSE`, `CHANGELOG.md`)
- Knowledge base `references/unleash-knowledge.md` (5-Element framework, starter patterns, phase primitives, guardian patterns, hook decision guide, common pitfalls, vocabulary)
- Skill `unleash:brainstorming` — context-first intake dialogue
- Skill `unleash:debating` — gap-driven challenge producing committed spec
- Stress-test scenarios for both skills and integration
