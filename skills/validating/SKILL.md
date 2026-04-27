---
name: validating
description: "Use after unleash:implementing produces real harness code — performs harness-aware audit (allowlist consistency, guardian alignment, irreversibility gating, artifact closure, loop termination, decide determinism) plus generic spec coverage and code quality checks. Re-runnable. Reports findings; does not modify any file."
---

# Unleash: Validating

> Audit a built harness against its spec for harness-aware invariants, with fresh context. Report findings only; fixes are the user's responsibility.

<HARD-GATE>
Do NOT modify any harness file during validation. This skill produces a validation report and nothing else. Suggested fixes go IN the report; they are not applied. The user (or a re-invocation of unleash:planning + unleash:implementing) applies fixes.

Do NOT skip any of the 6 harness-specific checks. If a check is genuinely inapplicable to this harness (e.g., Loop Termination on a non-Loop spec), the report must explicitly say so with reason — silent omission is a skill failure.

Do NOT inherit reasoning from implementing or any prior skill. Each validation runs with fresh context. Read the spec, plan, manifest, and implementation artifacts as if you have never seen them before.

Do NOT auto-invoke unleash:walking-through. Validation is the gate between "code exists" and "harness is trusted for use" — the user must consciously cross that gate by invoking walking-through themselves.
</HARD-GATE>

## Precondition

Before proceeding with any validation activity, verify all four conditions below. If any condition fails, STOP and report the specific missing item to the user.

**Condition 1: Plan file exists and is committed.**

The file must be present at:

```
docs/unleash/plans/<YYYY-MM-DD>-<slug>-plan.md
```

Run `git log --oneline -5 -- docs/unleash/plans/<filename>` to confirm the file appears in the commit log. If absent or untracked, STOP and tell the user:

> "Plan file not found or not committed at expected path. Run unleash:planning and ensure the plan is committed before invoking validating."

**Condition 2: Manifest exists and is parseable JSON.**

The file `.unleash/manifest.json` must exist and parse as valid JSON (run `python3 -c "import json,sys; json.load(sys.stdin)" < .unleash/manifest.json` or equivalent). If absent or malformed, STOP and tell the user:

> "`.unleash/manifest.json` is missing or not valid JSON. The manifest is the authoritative inventory validating reads — implementation may be incomplete. Re-run unleash:implementing or repair the manifest before invoking validating."

**Condition 3: At least one Phase Machine artifact exists at `.unleash/phases/`.**

Run `ls .unleash/phases/*.json 2>/dev/null`. If the directory is absent or contains no `.json` files, STOP and tell the user:

> "No phase config files found at `.unleash/phases/`. Implementation may not have run or may have failed. Re-run unleash:implementing before invoking validating."

**Condition 4: At least one Guardian artifact exists at `.unleash/guardians/`.**

Run `ls .unleash/guardians/*.md 2>/dev/null`. If the directory is absent or contains no `.md` files, STOP and tell the user:

> "No guardian prompt files found at `.unleash/guardians/`. Implementation may not have run or may have failed. Re-run unleash:implementing before invoking validating."

## Contract

**Consumes:** the implemented harness in the project's `.unleash/`, the original spec at `docs/unleash/specs/<...>.md`, and `.unleash/manifest.json`.

**Produces:** `docs/unleash/validation/<YYYY-MM-DD>-<name>-validation.md` — validation report with a pass/fail on each check, specific issue locations, suggested fixes.

**Precondition:** Implementation postcondition met (manifest exists, plan committed, harness artifacts present in `.unleash/`).

**Postcondition:** All harness-specific invariants pass, OR issues are documented in the report with concrete remediation paths. The harness's files are unchanged by this skill regardless of outcome.

## Anti-patterns: "the build was clean so the harness must be too"

The following rationalizations are traps. Each one feels true in the moment and produces a weaker outcome when acted on. Recognize them and reject them.

> **Thought:** "Implementing reported all DONE, so validation is just a formality."
> **Rebuttal:** Implementing's DONE means each subagent's tests passed for its OWN task. It does not mean cross-task invariants hold. Guardian Blind Spot, Orphan Artifact, and Allowlist Drift are silent failures that pass per-task tests and only surface under harness-aware audit. Validation is the only place these are caught.

> **Thought:** "I'll just fix the issues I find as I go — saves a round trip."
> **Rebuttal:** Validating audits; it does not modify. Fixing during validation conflates two responsibilities: detection (this skill) and correction (re-running planning + implementing on a revised spec). Mixing them means the user can't trust that the report describes the harness as it stands — a fix applied silently leaves the report describing a state that no longer exists.

> **Thought:** "I'll spot-check a few artifacts and call it good."
> **Rebuttal:** All 6 harness-specific checks must run, even if some return PASS or N/A trivially. Spot-checking lets pitfalls in the unchecked categories survive into walking-through and possibly into production use. Coverage is the only contract validation upholds.

> **Thought:** "If the user already approved the plan, the implementation must match it."
> **Rebuttal:** Subagents implementing tasks can drift from the plan in non-obvious ways: an invented file path, an unfilled placeholder caught only later, a guardian prompt that's complete in form but weak in substance. Approval-of-plan is upstream; what's on disk now is downstream. The audit is what bridges them.

## Operating Protocol

### Phase A — Absorption

Read before auditing. Every finding in Phase B and Phase C must be grounded in something read during this phase.

- Read the committed spec.md in full — locate it at `docs/unleash/specs/<YYYY-MM-DD>-<name>-spec.md`; read every section, including `phase_machine`, `guardian_design`, `optional_hooks`, and `five_element_analysis`
- Read the committed plan.md in full — for understanding what the implementation was supposed to produce; subsequent checks compare the implementation against the spec, not the plan (the plan informs what artifacts were declared and in what dependency relationships)
- Read `.unleash/manifest.json` and parse it as the authoritative inventory: note every entry in `created` and `modified`, the `harness_name`, and the `unleash_version`
- Read each `.unleash/phases/*.json` file — note each phase's name, primitive type, write_allowlist, and exit_gate
- Read each `.unleash/guardians/*.md` file — note each guardian's declared review scope, Instructions, Decision Rubric, and Edge Cases sections
- If any hooks are installed, read `.git/hooks/*` (excluding files named `*.sample`) — note trigger conditions and operations each hook gates
- Read `references/unleash-knowledge.md` §6 (Common Pitfalls) — pitfalls inform check semantics; have this section present during Phase B to identify which pitfall name applies to each finding
- Note the spec's commit SHA (`git log --oneline -5 -- docs/unleash/specs/<filename>`) and the manifest's `unleash_version` — both go into the report header

The output of Phase A is an internal model of the harness as-built. Nothing is shown to the user during this phase.

### Phase B — Six harness-specific checks

For each check below, perform the inspection and record findings. Each check produces one of:
- ✅ PASS — the invariant holds across all relevant artifacts
- ❌ FAIL with cited file:line locations and the specific pitfall name from §6
- ⚠ N/A with reason — only valid for genuinely inapplicable checks; the reason must cite a specific harness property that makes the check inapplicable

**Check 1 — Allowlist Cross-Phase Consistency** (Pitfall: §6.3 Allowlist Drift)

For every pair of adjacent phases (N, N+1):
1. List every path pattern in phase N's `write_allowlist`
2. Confirm that each such pattern falls within phase N+1's `read_allowlist` (or within a superset glob that covers it)
3. If any path written by phase N cannot be read by phase N+1, that is Allowlist Drift — FAIL with the specific path and both phase config filenames

Note: "read_allowlist" may be expressed as the absence of a strict write_allowlist (i.e., read-only phases may read anything). Check only paths that participate in artifact handoffs between phases.

N/A valid only if: the harness has exactly one phase (no cross-phase handoff possible). State this explicitly.

**Check 2 — Guardian-Phase Alignment** (Pitfall: §6.6 Guardian Blind Spot)

For every phase that has an associated guardian:
1. List every action the phase is permitted to take: every pattern in its `write_allowlist`, every shell command category it allows, every external call it permits
2. Read the corresponding guardian prompt's Instructions and Decision Rubric sections
3. Confirm that the guardian's declared review scope equals or exceeds the phase's full action surface — every permitted action must produce evidence the guardian sees (a diff, a log, an artifact)
4. Any permitted action that is not visible to the guardian is a Blind Spot — FAIL with the specific missing coverage, citing the phase JSON path and the guardian MD path

N/A valid only if: no phase in the harness has a guardian. If any phase has a guardian, this check runs for that phase. State any N/A per-phase with reason.

**Check 3 — Irreversibility Gating** (Pitfalls: §6.7 Hook-Over-Guardian and missing-hook-on-irreversible)

Cross-reference the spec's `optional_hooks` section, the spec's `five_element_analysis` Reversibility entry, and any installed `.git/hooks/*` files:
1. Every operation the spec marks irreversible must be hook-gated — if a hook is absent for an irreversible operation, FAIL citing the operation and the spec path
2. Every hook that is installed must correspond to an irreversible operation declared in the spec — if a hook is present for a reversible operation, FAIL citing the hook file and the spec's reversibility declaration
3. A spec that says "Optional Hooks: None" and has no installed hooks → this check is ✅ PASS
4. A spec that says "Optional Hooks: None" but has installed hooks → FAIL (Hook-Over-Guardian)

N/A valid only if: the spec declares no irreversible operations AND no hooks are installed.

**Check 4 — Artifact Contract Closure** (Pitfall: §6.2 Orphan Artifact)

Cross-reference the plan's Artifact Dependency Map table and the manifest's `created` array:
1. For every artifact in the Dependency Map, confirm it has both a declared producer task AND a declared consumer (task or runtime)
2. For every artifact in the Dependency Map, confirm it has an entry in the manifest's `created` or `modified` array (or is explicitly declared as an external harness input in the plan)
3. For every entry in the manifest's `created` array, confirm it has a corresponding row in the Dependency Map (or is explicitly noted as a build side-effect)
4. An artifact with no consumer is a produced-but-never-consumed orphan — FAIL with the artifact path and the Dependency Map row
5. An artifact declared in the Dependency Map but absent from the manifest and absent from disk is a missing-producer orphan — FAIL with the artifact path, the Dependency Map row, and the fact that the manifest lacks an entry

N/A: this check is always applicable if a plan and manifest exist. Never mark N/A.

**Check 5 — Loop Termination** (Pitfall: §6.4 Unbounded Loop)

For every phase whose primitive type is "Loop" (as declared in its `.unleash/phases/*.json` `primitive` field):
1. Confirm the phase declares at least one of: `max_iters` (a concrete positive integer), `early_stop` (a specific machine-evaluable predicate), or `external_signal` (a named file path, endpoint, or environment variable the loop checks on each iteration)
2. If none of these three are present, FAIL with the phase config filename and the missing termination mechanisms

N/A valid only if: no phase in the harness has `"primitive": "Loop"` in its config. State this explicitly with the list of phase primitives found, so the absence of Loop is verifiable.

**Check 6 — Decide Determinism** (Pitfall: §6.5 Decide Without Trigger)

For every phase whose primitive type is "AI-Judge", "Human-Check", or whose function in the spec is a Decide phase:
1. Confirm the phase specifies the judge type — one of: Script, AI-Judge, or Human-Check
2. Confirm the phase specifies the actuator — the specific named mechanism that reads the judge's verdict and executes the resulting git operation (e.g., a specific script path, a named harness step, a named human action)
3. If the judge type is missing, FAIL citing the phase config and the absence of a judge type declaration
4. If the actuator is missing — if the phase says what decides but not what executes after the decision — FAIL citing the specific Decide Without Trigger pattern

N/A valid only if: no phase in the harness has a decision-making role (no AI-Judge, Human-Check, or explicit Decide primitive). State this explicitly.

### Phase C — Two generic checks

**Check 7 — Spec Coverage**

For every requirement declared in spec.md (each phase in `phase_machine`, each constraint in `guardian_design`, each hook in `optional_hooks`):
1. Confirm it maps to at least one artifact in either the Dependency Map or the manifest
2. A spec requirement with no corresponding implementation artifact is a coverage gap — FAIL citing the spec section and the missing artifact
3. Read the spec top to bottom; treat each declared phase, each declared guardian behavior, and each declared hook as a separate requirement to check

N/A: this check is always applicable. Never mark N/A.

**Check 8 — Code Quality**

For each guardian prompt (`.unleash/guardians/*.md`):
1. Confirm it has all 5 required sections as defined in `references/unleash-knowledge.md` §4.2: Role, Instructions, Decision Rubric, Edge Cases, Output Format
2. A guardian missing any of these 5 sections is a quality failure — FAIL citing the guardian file and the missing section(s)

For each phase config (`.unleash/phases/*.json`):
1. Confirm it is syntactically valid JSON (re-run `python3 -c "import json,sys; json.load(sys.stdin)" < <file>` for each)
2. A file that fails JSON parsing is a quality failure — FAIL citing the file

For each script artifact (hook scripts in `.git/hooks/`, walkthrough scripts in `.unleash/walkthroughs/`):
1. Run `bash -n <script>` for shell scripts to confirm syntactic validity
2. A script that fails `bash -n` is a quality failure — FAIL citing the script file and the error output

N/A: this check is always applicable if any of these artifact types are present. Never mark N/A unless none of these artifact types exist (which would have failed Precondition checks).

### Phase D — Synthesize report

Produce `docs/unleash/validation/<YYYY-MM-DD>-<name>-validation.md` with the structure defined in §Validation report schema below. Write the full report — all 8 check results — regardless of overall verdict. Do NOT write a partial report.

After writing the report, commit it:

```bash
git add docs/unleash/validation/
git commit -m "validation: <PASS|FAIL> for <harness-name>"
```

where `<harness-name>` matches the `harness_name` field in `.unleash/manifest.json`.

## Validation report schema

A concise reference of the report's required structure:

```markdown
# Validation Report: <harness-name>
**Spec SHA:** <git sha of spec.md>
**Manifest version:** <unleash_version from manifest>
**Validated at:** <ISO timestamp>
**Overall:** ✅ PASS | ❌ FAIL

## Per-Check Findings

### 1. Allowlist Cross-Phase Consistency
[✅ PASS | ❌ FAIL | ⚠ N/A] [details; if FAIL: file:line locations + pitfall name from §6]

### 2. Guardian-Phase Alignment
[✅ PASS | ❌ FAIL | ⚠ N/A] [details; if FAIL: file:line locations + pitfall name from §6]

### 3. Irreversibility Gating
[✅ PASS | ❌ FAIL | ⚠ N/A] [details; if FAIL: file:line locations + pitfall name from §6]

### 4. Artifact Contract Closure
[✅ PASS | ❌ FAIL | ⚠ N/A] [details; if FAIL: file:line locations + pitfall name from §6]

### 5. Loop Termination
[✅ PASS | ❌ FAIL | ⚠ N/A] [details; if FAIL: file:line locations + pitfall name from §6]

### 6. Decide Determinism
[✅ PASS | ❌ FAIL | ⚠ N/A] [details; if FAIL: file:line locations + pitfall name from §6]

### 7. Spec Coverage
[✅ PASS | ❌ FAIL] [details; if FAIL: spec section + missing artifact]

### 8. Code Quality
[✅ PASS | ❌ FAIL] [details; if FAIL: artifact file + specific deficiency]

## Suggested Fixes
[For each ❌ FAIL: a concrete remediation path. Not "consider revisiting" — a specific action.
 Example: "Widen impl-guardian.md review_scope to include src/** to match phase 2-impl.json write_allowlist."
 Suggestions are advisory; the user applies them by re-running unleash:planning + unleash:implementing.]

## Re-run Instructions
[One paragraph: how to re-invoke validating after fixes have been applied. Typical: invoke unleash:validating from the project root after the spec or harness implementation has been updated. Validating is re-runnable at any time — including after manual edits to any harness artifact.]
```

**Overall verdict rule:** ✅ PASS requires all 8 checks to be either PASS or N/A (with reason). A single ❌ FAIL in any check makes the overall verdict ❌ FAIL.

## Termination

<HARD-GATE>
Do NOT invoke unleash:walking-through automatically. The user must consciously decide whether to proceed — FAIL findings should be addressed before walking-through; PASS findings still warrant the user's review of the report.

When you finish Phase D, deliver the terminal message LITERALLY (no extrapolation, no unsolicited step proposals, no out-of-scope instructions, no "you should now..."):

> Validation complete. Verdict: \<PASS | FAIL\>. Report at docs/unleash/validation/\<filename\>. Findings: \<count\> PASS, \<count\> FAIL, \<count\> N/A. Re-run validating any time after edits. Invoke unleash:walking-through when ready to chaperone the harness's first real-world run (walking-through ships in Plan 3 of the Unleash roadmap alongside this skill).

Nothing after this paragraph. No follow-up. The user's domain begins where Unleash ends — respect that boundary.
</HARD-GATE>

## Checklist

Complete these items in order. Use TodoWrite to track progress.

1. Phase A: read spec, plan, manifest, all phase configs, all guardian prompts, hooks if any, knowledge §6; note spec SHA and manifest unleash_version for report header
2. Phase B: run check 1 (Allowlist Cross-Phase Consistency); record ✅ PASS, ❌ FAIL with file:line + pitfall name, or ⚠ N/A with reason
3. Phase B: run checks 2–6 (Guardian-Phase Alignment, Irreversibility Gating, Artifact Contract Closure, Loop Termination, Decide Determinism); record each as PASS / FAIL / N/A
4. Phase C: run check 7 (Spec Coverage); record PASS or FAIL with missing artifact citations
5. Phase C: run check 8 (Code Quality across guardians/configs/scripts); record PASS or FAIL with specific deficiency citations
6. Phase D: synthesize report with all 8 check results + overall verdict + suggested fixes for every FAIL; commit to `docs/unleash/validation/`
7. Deliver literal terminal message; STOP (do not invoke walking-through, do not modify any harness file)
