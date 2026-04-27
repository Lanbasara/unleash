---
name: walking-through
description: "Use after unleash:validating passes — chaperones the harness's first real run on a small task, drives a phase 0 → phase 1 transition, deliberately violates allowlist to verify guardian fires and git reset rolls back, records outcome. Runs ONCE per harness build."
---

# Unleash: Walking-Through

> Take the built harness on its first real run. Drive a phase transition, intentionally trip the guardian, verify rollback works in vivo. Record outcome.

<HARD-GATE>
Do NOT skip the intentional-violation smoke test. The whole point of walking-through is in vivo verification that the guardian fires and git reset rolls back — not that the guardian prompt looks correct (validating already covered that). A walkthrough without a real attempted violation is theater.

Do NOT modify the harness's spec, plan, manifest, or any committed artifact. Walking-through observes and records; the only files it WRITES are: (a) the small first-run task it drives Claude through (in the user's project, e.g. tests/test_X.py + src/X.py), and (b) the walkthrough record at docs/unleash/walkthroughs/<date>-<name>-first-run.md.

Do NOT auto-invoke unleash:archiving. Walking-through is start-of-life; archiving is end-of-life. They are bookends, not adjacent steps.

Do NOT pick a "production-grade" first-run task. Pick something small and bounded — a single function fix, a tiny refactor — so the smoke test runs in minutes not hours and a rollback is cheap.
</HARD-GATE>

## Precondition

Before proceeding with any walkthrough activity, verify all three conditions below. If any condition fails, STOP with the exact error prompt shown.

**Condition 1: Manifest is present and parseable.**

The file `.unleash/manifest.json` must exist and parse as valid JSON with at least one phase config entry and at least one guardian entry. Run:

```bash
python3 -c "import json,sys; d=json.load(sys.stdin); assert d.get('created'), 'no created entries'" < .unleash/manifest.json
ls .unleash/phases/*.json 2>/dev/null
ls .unleash/guardians/*.md 2>/dev/null
```

If absent, malformed, or missing phase/guardian entries, STOP and tell the user:

> "`.unleash/manifest.json` is missing, not valid JSON, or contains no phase/guardian entries. Implementation may be incomplete. Re-run unleash:implementing or repair the manifest before invoking walking-through."

**Condition 2: Validation report exists with overall verdict PASS.**

A file matching `docs/unleash/validation/<YYYY-MM-DD>-<name>-validation.md` must exist and its `**Overall:**` field must read `✅ PASS`. If the file is absent, or if the overall verdict is `❌ FAIL`, STOP and tell the user:

> "Validation report not found or verdict is FAIL. Address validation findings first (re-run unleash:validating after fixes), then invoke walking-through."

Walking-through is the gate between "validated harness" and "trusted for use." Do not cross it without a PASS report.

**Condition 3: A small first-run task is identifiable.**

A bounded first-run task must be nameable before the walkthrough begins. Check:
- Did the user's prompt name a specific task (e.g., "first run on the multiply bug fix")?
- Does the project README contain a TODO, BUG, or FIXME pointing at a small bounded problem?
- Is there a failing test visible in the project?

If no task is identifiable from the prompt or the project, ASK the user to name one. Do NOT invent one. Do NOT default to the largest open task — small and bounded is the requirement.

## Contract

**Consumes:** built harness in `.unleash/`, validation report (must show overall PASS), and a small bounded first-run task (named by user or inferred from project).

**Produces:** `docs/unleash/walkthroughs/<YYYY-MM-DD>-<name>-first-run.md` — record of the chaperoned first run including phase transitions observed, intentional violation attempted, guardian response captured verbatim, rollback outcome, and overall verdict (READY-FOR-USE or BLOCKED-FOR-USER-FIX).

**Precondition:** Validation passed; manifest present; first-run task identified.

**Postcondition:** walkthrough.md committed; harness's `.unleash/` artifacts unchanged; if guardian smoke test failed (guardian did NOT fire on violation, OR git reset did not restore state), verdict is BLOCKED and user is told what to fix in spec/plan before re-running.

## Anti-patterns: "the smoke test is theater"

The following rationalizations are traps. Each one feels true in the moment and produces a walkthrough that fails silently. Recognize them and reject them.

> **Thought:** "The guardian prompt looked good in validating — I don't need to actually fire it."
> **Rebuttal:** Validating reviewed the prompt's STRUCTURE (5 sections present, scope alignment with phase). Walking-through verifies its BEHAVIOR (does it actually catch a real diff that violates allowlist? does it produce parseable FAIL output? does the actuator script run git reset correctly?). These are different guarantees. A prompt that's structurally perfect can still fail at runtime if the rubric language is wrong or if the actuator script has a bug.

> **Thought:** "I'll skip the violation step and just walk through phase 0 → phase 1; the rollback path is well-tested in unit tests."
> **Rebuttal:** Most harnesses have ZERO unit tests for the rollback path itself — the rollback IS the harness's safety net, and the only way to test a safety net is to drop on it. Walking-through is the only place the safety net is dropped on, ever. If the violation step is skipped, the user is trusting code that's never been exercised in failure mode.

> **Thought:** "I'll pick the user's biggest open task as the first-run target — it'll save time."
> **Rebuttal:** The first-run target should be the SMALLEST useful bounded task in the project. Big tasks are slow to drive and slow to roll back; if the smoke test fails, you've burned 30 minutes on a task you have to discard. Pick something tiny — a one-function fix, a one-test addition — so the smoke test cycle is minutes, and rollback is cheap.

> **Thought:** "If guardian fires, the harness is broken — I should patch the guardian and re-run."
> **Rebuttal:** Guardian firing on the INTENTIONAL violation is the SUCCESS case for walking-through. The smoke test is designed to trip the guardian on purpose. If guardian fires + git reset works, walkthrough is PASS. If guardian does NOT fire (silent miss) or git reset does NOT restore state, that's the failure — and the fix is in the spec/plan/guardian-prompt, not in walking-through.

## Operating Protocol

### Phase A — Manifest absorption

Read before acting. Everything in Phases B–F must be grounded in what was read here.

- Read `.unleash/manifest.json` to understand what's installed — note `harness_name`, `unleash_version`, and the full `created` array
- Read each `.unleash/phases/*.json` file — note each phase's name, primitive type, `write_allowlist`, entry gate, and exit gate
- Read each `.unleash/guardians/*.md` file — note each guardian's declared review scope, Decision Rubric, and Output Format section
- Read the validation report at `docs/unleash/validation/<YYYY-MM-DD>-<name>-validation.md` — confirm `**Overall:**` is `✅ PASS`; if it is not `✅ PASS`, STOP immediately with:

> "Validation report shows FAIL. Address validation findings first before invoking walking-through."

- Note the manifest's `harness_name` and `unleash_version` for the walkthrough record header

The output of this phase is an internal model of what the harness provides. Nothing is shown to the user during this phase.

### Phase B — First-run task identification

- If the user's prompt named a task ("first run on the foo refactor"), use that task exactly
- Otherwise, scan the project for a small bounded task: read README for TODO, BUG, FIXME; check for failing tests (`pytest --co -q` or equivalent); look for the smallest plausible single-function refactor in the codebase
- If no small bounded task is identifiable, ASK the user to name one — do not invent one, do not default to the largest open issue
- Confirm the chosen task touches ONLY files inside the harness's allowlist — it must complete cleanly through phase transitions before the intentional violation step. If the task would inherently touch out-of-scope files, ask the user to name a different task

Document the chosen task as a one-sentence description for the walkthrough record.

### Phase C — Drive phase 0 → phase 1

This phase drives one or two real phase transitions using sub-subagent dispatch. Dispatch a phase-implementer subagent to perform each phase's work; dispatch a guardian subagent to invoke the corresponding guardian prompt on the resulting diff.

**Phase 1 (Test):**

- Dispatch a sub-subagent (the phase implementer) to write a failing test for the chosen task, constrained to the phase's `write_allowlist`. Instruct the subagent to commit the result.
- Verify the test runs red (`pytest -v` or project-equivalent). Note the commit SHA.
- Dispatch a guardian sub-subagent, passing it: (a) the diff for this commit, (b) the full text of the phase 1 guardian prompt, and (c) the instruction to produce a verdict per the guardian's Output Format.
- Expect PASS verdict. If the guardian returns FAIL on a clean in-scope commit: the harness is broken in a way validating missed — record the finding as BLOCKED with the guardian's verbatim output and halt.

**Phase 2 (Impl):**

- Dispatch a sub-subagent (the phase implementer) to write the actual fix — the task's real implementation — constrained to the phase's `write_allowlist`. Instruct the subagent to commit the result.
- Verify the test runs green. Note the commit SHA.
- Dispatch a guardian sub-subagent on this commit's diff. Expect PASS verdict.
- If the guardian returns FAIL on a clean in-scope commit: record as BLOCKED with details.

If either transition produces an unexpected guardian FAIL, halt and deliver:

> "Walking-through encountered unexpected guardian FAIL on a clean in-scope commit. This indicates a harness defect not caught by validating. Verdict: BLOCKED-FOR-USER-FIX. See Phase C finding in walkthrough record."

### Phase D — Intentional violation smoke test

This is the load-bearing phase. The walkthrough's overall verdict is determined here.

**Step 1 — Identify the out-of-scope path.**

Using the spec's `Out of Scope` section and the phase's `write_allowlist`, identify a path that falls outside every phase's write allowlist. Good candidates: `README.md`, `pyproject.toml`, `Cargo.toml`, `package.json` — any project-level file the spec explicitly excludes. Confirm via the phase configs that the chosen path is not covered by any allowlist glob.

**Step 2 — Make the intentional violation.**

During phase 2 (or whichever is the "main" implementation phase), make a small edit to the out-of-scope path. The edit can be minimal — adding a comment line, a whitespace change — enough to produce a real diff. Commit this edit (as a single commit, ideally on top of the clean Phase C commits).

This commit MUST be a real edit, not a hypothetical. If the walkthrough record says "the guardian would catch a violation if one occurred" without having created one, the smoke test has failed — it is theater, not a test.

**Step 3 — Invoke the guardian on the violation.**

Dispatch a guardian sub-subagent with: (a) the diff of the violation commit, (b) the full text of the phase's guardian prompt, (c) the instruction to produce a verdict per the guardian's Output Format. Expect FAIL verdict with the violating path named.

- **If the guardian returned FAIL with the violating path named:** smoke test passed. Proceed to Step 4.
- **If the guardian returned PASS on the violation (silent miss):** this is the critical failure case. Record the guardian's verbatim output. Overall verdict is BLOCKED-FOR-USER-FIX. Note exactly which path was edited and which allowlist rule should have caught it — the user needs this to fix the guardian prompt.

**Step 4 — Execute rollback.**

Run:

```bash
git reset --hard HEAD~1
```

Verify the violation is gone:

```bash
git diff HEAD
git status
```

- **If the working tree is clean and the out-of-scope path is restored:** rollback succeeded. Record the result.
- **If git reset did not restore the file or working tree is not clean:** record as BLOCKED-FOR-USER-FIX with the exact git status output.

The violation commit is now reverted. The project is back to its post-Phase-C state.

### Phase E — Hook smoke test (only if hooks installed)

If the spec declared optional hooks (check `optional_hooks` section in the spec; check for files in `.git/hooks/` other than `*.sample`):

- Identify the hook's trigger condition from the spec
- Attempt to trigger it in a controlled way (e.g., if there's a hook on `git push`, attempt a push to a fake/dry-run remote: `git push --dry-run <remote>` or `git push <fake-remote>`)
- Verify the hook blocks the operation and emits the expected message
- Record outcome: hook path, trigger attempted, blocked (yes/no), hook output verbatim

If no hooks are installed, skip Phase E entirely and note: "no hooks declared in spec; Phase E skipped."

### Phase F — Record and report

Produce `docs/unleash/walkthroughs/<YYYY-MM-DD>-<name>-first-run.md` with this exact structure:

```markdown
# First-Run Walkthrough: <harness-name>
**Manifest version:** <unleash_version from manifest.json>
**Validation SHA:** <git commit sha of the validation.md file>
**Walked at:** <ISO timestamp>
**First-run task:** <one-sentence description of the chosen task>
**Overall:** READY-FOR-USE | BLOCKED-FOR-USER-FIX

## Phase Transitions Observed
- Phase 1 (Test): commit <sha>, guardian PASS
- Phase 2 (Impl): commit <sha>, guardian PASS

## Intentional Violation Smoke Test
- Out-of-scope path edited: <path>
- Pre-violation commit: <sha of the clean Phase C head>
- Guardian response (verbatim): <copy from guardian sub-subagent's output, unedited>
- git reset executed: <the literal command and its output>
- Post-rollback state verified: <output of git diff HEAD and git status — should be clean>

## Hook Smoke Test
- (skipped — no hooks declared in spec) | (attempted at <hook path>; trigger: <description>; blocked: yes/no; output: <verbatim>)

## Verdict and recommendations
[Narrative paragraph. If READY-FOR-USE: confirm all smoke tests passed and the harness is ready for real use. If BLOCKED-FOR-USER-FIX: name every specific finding (guardian silent miss at which path, rollback failure at which step, hook failure at which trigger) and tell the user which artifact to fix (spec section, guardian prompt file path, actuator script path). Be specific — "fix the guardian" is not useful; "expand impl-guardian.md Decision Rubric line 3 to include README.md as a FAIL case" is useful.]
```

After writing the file, commit it:

```bash
git add docs/unleash/walkthroughs/
git commit -m "walkthrough: <READY-FOR-USE|BLOCKED-FOR-USER-FIX> for <harness-name>"
```

where `<harness-name>` matches the `harness_name` field in `.unleash/manifest.json`.

## Output artifact

The single output artifact of this skill is:

```
docs/unleash/walkthroughs/<YYYY-MM-DD>-<name>-first-run.md
```

The harness's `.unleash/` directory is UNCHANGED by this skill. Walking-through is an observer and recorder, not a modifier. The only files this skill writes are:
- The small first-run task files (e.g., `tests/test_X.py`, `src/X.py`) — created during Phases C and D, with the Phase D violation commit reverted by git reset
- The walkthrough record at `docs/unleash/walkthroughs/` — committed at the end of Phase F

## Termination

<HARD-GATE>
Do NOT invoke unleash:archiving. Archiving is end-of-life — use only after the harness has done its real work in production. Walking-through has just shown the harness CAN start; the user now uses it for actual work, then archives whenever they're done.

Do NOT extrapolate beyond the literal terminal message — no "now you should deploy", no "go run this on the auth refactor", no "consider these production checks".

Deliver this message LITERALLY:

> Walkthrough complete. Verdict: \<READY-FOR-USE | BLOCKED-FOR-USER-FIX\>. Record at docs/unleash/walkthroughs/\<filename\>. Phase transitions: \<count\>. Guardian smoke test: \<result\>. Hook smoke test: \<skipped | result\>. The harness is now in your hands — use it for real work; invoke unleash:archiving when you're ready to retire it.

Nothing after this. The user's domain begins here.
</HARD-GATE>

## Checklist

Complete these items in order. Use TodoWrite to track progress.

1. Phase A: read manifest, all phase configs, all guardian prompts; read validation report and confirm overall verdict is PASS; note harness_name and unleash_version for record header
2. Phase B: identify the first-run task from user prompt or project scan; confirm it touches only in-allowlist files; if no task identifiable, ask user before proceeding
3. Phase C: drive phase 1 (Test) via sub-subagent — implementer commits failing test, guardian sub-subagent returns PASS on clean diff; note commit SHA
4. Phase C: drive phase 2 (Impl) via sub-subagent — implementer commits fix, test runs green, guardian sub-subagent returns PASS on clean diff; note commit SHA
5. Phase D: make intentional violation (real edit to out-of-scope path, real commit); invoke guardian sub-subagent; expect FAIL; run git reset --hard HEAD~1; verify clean state
6. Phase E: if hooks installed, attempt to trigger each; record blocked/not-blocked outcome; if no hooks, note skipped
7. Phase F: write walkthrough record with all required sections (phase transitions, intentional violation verbatim guardian output, rollback outcome, hook outcome, verdict); commit; deliver literal terminal message
