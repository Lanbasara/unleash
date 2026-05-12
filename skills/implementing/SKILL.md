---
name: implementing
description: "Use after unleash:planning produces a committed plan.md — dispatches fresh subagents per task, each receiving full task text verbatim (never file references), with harness-specific scene-setting; does not review (that is unleash:validating's job)."
---

# Unleash: Implementing

> Drive a committed plan.md to real harness code by dispatching one fresh subagent per task, each with the full task text pasted into its prompt.

<HARD-GATE>
Do NOT tell a subagent to read the plan file. Do NOT pass a file path where the task is described. Every subagent dispatch MUST include the complete text of that task pasted verbatim into the subagent prompt.

Do NOT include multiple tasks in a single dispatch. One subagent handles exactly one task from the plan. If the plan has 8 tasks, there are 8 dispatches.

Do NOT do any review after the subagent reports DONE. Spec-compliance review and code-quality review are BOTH deferred to unleash:validating (Plan 3 of the Unleash roadmap). Running such review here is a skill failure — it duplicates work, loses the independence guarantee validating provides, and makes this skill expensive and slow.

This applies even when the plan looks simple, even when the user is in a hurry, and even when batching two tasks "would save time."
</HARD-GATE>

## Precondition

Before proceeding with any dispatch activity, verify all conditions below. If any condition fails, STOP and report the specific missing item to the user.

**Condition 1: Plan file exists.**

The file must be present at:

```
docs/unleash/plans/<YYYY-MM-DD>-<slug>-plan.md
```

If the file is absent, STOP and tell the user:

> "Plan file not found at expected path. Run unleash:planning to produce a committed plan before invoking implementing."

**Condition 2: Plan is committed.**

Run `git log --oneline -5 -- docs/unleash/plans/<filename>` to confirm the plan file appears in the commit log. If the plan is dirty or untracked, STOP and tell the user:

> "The plan at `docs/unleash/plans/<filename>` is not committed. Commit it (and have the user approve it) before invoking unleash:implementing. Implementing works against a specific committed version — uncommitted plans cannot be cited reliably."

**Condition 3: Plan passes structural check.**

Read the plan and confirm all of the following are present:

- Header metadata: `**Harness Case:**`, `**Guardian Role:**`, and `**Phase Summary:**`
- Artifact Dependency Map section with at least one table row
- At least one Task Group (Group A, Group B, or similar)
- Zero matches for placeholder text: TBD, TODO, fill in later, fill in details, placeholder, FIXME

If any element is missing or a placeholder scan returns matches, STOP and tell the user:

> "Plan fails structural check. Missing: [list the missing elements]. Re-run unleash:planning to complete the plan before invoking implementing. Implementing cannot execute an incomplete plan."

## Contract

**Consumes:** `docs/unleash/plans/<YYYY-MM-DD>-<name>-plan.md` (committed, passes structural check).

**Produces:** Real harness code in the user's project — phase config files, guardian prompt files, optional hook scripts, settings patches, walkthrough scripts. Every artifact at the path declared in its task's Files section. One git commit per task.

**Precondition:** Plan is committed and passes structural check.

**Postcondition:** Every task in the plan has been implemented by its dispatched subagent; every subagent reported DONE or DONE_WITH_CONCERNS (no unhandled BLOCKED); all commits present in git log.

## Anti-patterns: "let the subagent figure it out"

The following rationalizations are traps. Each one feels true in the moment and produces a weaker implementation when acted on. Recognize them and reject them.

> **Thought:** "Pasting the full task text is wasteful — the subagent can just read the plan file."
> **Rebuttal:** Pasting the task text is the only way to ensure the subagent has EXACTLY the scope the plan gives it. Reading the plan file means the subagent sees other tasks, other artifacts, other scene-setting — its context becomes polluted. The plan file is a control-plane document; tasks are execution units. Don't let them mix.

> **Thought:** "I'll batch two related tasks into one dispatch to save tokens."
> **Rebuttal:** Batching is the fastest way to lose the "fresh subagent per task" guarantee. If task A and task B are in the same context, a mistake in task A can silently influence task B's approach. The whole point of one-subagent-per-task is to make failures localized and reproducible.

> **Thought:** "After the subagent reports DONE, I should do a quick review before moving on."
> **Rebuttal:** Review is not this skill's job. Review is unleash:validating's job (Plan 3). Doing review here makes this skill expensive, slow, and redundant — you'll end up re-reviewing the same code in Plan 3 anyway. And if the controller reviews, it loses the "independent fresh context" guarantee that makes validating worth invoking at all. A light self-check inside the subagent's own context (the subagent running its own tests) is enough for now.

> **Thought:** "If the subagent fails, I should try to fix it myself."
> **Rebuttal:** If a subagent reports BLOCKED or NEEDS_CONTEXT, the controller provides the missing context and re-dispatches the same task. It does NOT patch the subagent's work itself. Letting the controller write code makes it a second implementer — two implementers for one task is how silent bugs get introduced.

## Operating Protocol

### Phase A — Absorption

- Read the committed plan.md in full (you, the controller, do this; the subagents do not read the plan)
- Read `references/unleash-knowledge.md` §3 (Phase Primitives) and §4 (Guardian Patterns) — context for the scene-setting you will provide
- Note the plan's commit SHA for reference
- Extract all tasks into an internal list (task number, title, files, artifact type, produces, consumes, steps as a complete text blob)

### Phase B — Dispatch plan (INTERNAL)

For each task in the plan (in plan order), prepare:
- **Task text blob** — the task's full markdown content from title through final commit step, preserving all code blocks verbatim
- **Scene-setting** — Goal + Harness Case + Guardian Role + "Artifacts consumed from upstream tasks: <list>" + "Artifacts produced by this task: <list>" drawn from the Artifact Dependency Map

Do NOT start dispatching yet. Phase C is where dispatches happen.

### Phase C — Sequential dispatch (one subagent per task, in plan order)

For task i in 1..N:
1. Dispatch a fresh subagent with:
   - subagent_type: general-purpose
   - model: sonnet by default, haiku if the task is mechanical (pure file write with exact content), opus if the task involves design judgment
   - prompt: use the template in §8 below, substituting task text + scene-setting
2. Wait for subagent report (DONE | DONE_WITH_CONCERNS | BLOCKED | NEEDS_CONTEXT)
3. Handle status:
   - **DONE** → 
      - note commit SHA
      - **append manifest entries**: for each file the just-committed task created or modified (use `git show --name-status <commit-sha>` to enumerate), append a row to `.unleash/manifest.json` with the task ID, commit SHA, and (for modifications) the file's `original_sha` captured before the task ran. If `.unleash/manifest.json` does not exist, create it with the schema header (see `references/unleash-knowledge.md` §8.2 for the exact JSON schema and field semantics).
      - proceed to task i+1
   - **DONE_WITH_CONCERNS** → log the concerns in a running notes list; proceed to task i+1 (concerns are for unleash:validating in Plan 3 to address, NOT for this controller to evaluate)
   - **BLOCKED** → the controller provides additional context (from the plan, the spec, or the project state) and re-dispatches task i with the same model
   - **NEEDS_CONTEXT** → same as BLOCKED — add context, re-dispatch
4. If re-dispatch fails twice on the same task, escalate: report the specific blocker to the user and STOP (do not try yet another re-dispatch)
5. **Group Checkpoint** — after completing the last task in a Group (as declared in the plan's Group structure), verify before proceeding to the next Group:
   - Re-read the plan's Group section for this Group (the Dependency Map and task list for the Group)
   - Verify (a) every task in the Group has status DONE or DONE_WITH_CONCERNS, (b) all artifacts declared in the Group's Dependency Map entries exist at their declared paths, (c) `testing_mode` (if declared in the spec) has not been silently altered by any task in the Group
   - If any verification fails: STOP, report the specific deviation to the user, and do not proceed to the next Group until the user resolves it
   - If all verifications pass: append a checkpoint record to `.unleash/checkpoints/group-<N>.md` (create the directory if needed) noting the Group, task IDs, commit SHAs, and pass/fail status; then proceed

**What this Phase C does NOT do:**
- It does NOT review the subagent's output for spec compliance
- It does NOT review the subagent's output for code quality
- It does NOT compare the subagent's output against the Artifact Dependency Map
- It does NOT inspect the git diff
- It does NOT re-run or re-analyze the subagent's test output (the subagent's own self-check is sufficient; test-result analysis is a form of review and belongs in unleash:validating)
- It does NOT patch the subagent's work
- All of these happen later in unleash:validating with a fresh independent context

### Phase D — Final summary

After all N tasks have status DONE or DONE_WITH_CONCERNS:
- Run `git log --oneline` to show commits produced during this run
- Summarize to the user: which tasks completed DONE, which DONE_WITH_CONCERNS (list concerns verbatim — do not paraphrase or judge), which commit SHAs were produced
- Tell the user the terminal message (see §10 Termination)

## Subagent prompt template

Use this template for each task dispatch. Substitute `<PLACEHOLDER>` regions with actual content; no placeholder may remain in the final prompt you send.

---
You are implementing task <TASK NUMBER>: <TASK TITLE> for the <HARNESS NAME> harness.

## Task

<PASTE COMPLETE TASK TEXT FROM PLAN, START TO END — INCLUDING FILES SECTION AND ALL STEPS WITH ALL CODE BLOCKS VERBATIM>

## Scene-setting

**Harness Goal:** <COPY FROM PLAN HEADER>
**Harness Case:** <coding | metric | hybrid | freeform>
**Guardian Role:** <ONE SENTENCE FROM PLAN HEADER>

**MANDATORY — Read these files before doing anything:**
You MUST read the following files from disk using your ReadFile tool. The design contract is in these files, not in this prompt summary.

1. `docs/unleash/specs/<spec-filename>.md` — the committed spec (your hard constraint)
2. `docs/unleash/plans/<plan-filename>.md` — the plan containing your task (find your task by title)
3. `.unleash/phases/<current-phase>.json` — your phase allowlist and exit gate

**This task's upstream artifacts** (produced by earlier tasks): <LIST FROM DEPENDENCY MAP, or "none" if this is the first task>
**This task's downstream artifacts** (consumed by later tasks or runtime): <LIST FROM DEPENDENCY MAP>

**Orientation summary** (for context only — do NOT treat this as the contract):
<ONE SENTENCE: what this task is about>

## Before you begin

If you have questions about the requirements or approach, ask them now. Do not guess.

## Your job

Implement the task above. Follow the steps in order. Write complete code (not descriptions). Run the verification commands. Commit the result as the task's Commit step specifies.

## Self-check (light, inside your own context)

Before reporting DONE:
- Did I run every verification step in the task?
- Did all declared verifications pass?
- Did I commit with the exact commit message the task specifies?

If any self-check fails, fix and re-verify before reporting. This self-check is NOT a review; it's just confirming your own work ran the commands the task named.

## Report format

Report one of:
- **DONE** — all steps executed, all verifications pass, commit made; list the commit SHA
- **DONE_WITH_CONCERNS** — steps executed but you observed something a reviewer should know (e.g., "test passes but feels brittle")
- **BLOCKED** — you cannot complete; describe the specific blocker and what you tried
- **NEEDS_CONTEXT** — you need information not in this prompt; specify exactly what you need

Do NOT report anything else. Your response is consumed programmatically by the controller.

---

## Output artifact

This skill does not produce a single artifact; it produces the code + commits specified in the plan's tasks. Specifically:

- One commit per task (matching the plan's Commit step)
- Files at the paths declared in each task's Files section
- Every Artifact in the plan's Dependency Map exists at its declared path

The "artifact" this skill produces is the harness implementation itself, scattered across the project per the plan's structure. This skill does not verify that the artifacts match the Dependency Map; that verification is unleash:validating's job.

**Manifest:** `.unleash/manifest.json` is incrementally written as each task commits; by Phase D it is the complete inventory of every file this implementation created or modified. Validating, walking-through, archiving, and the uninstall script (`scripts/unleash-uninstall.sh`) all consume it. The manifest schema is in `references/unleash-knowledge.md` §8.2.

## Termination

<HARD-GATE>
Do NOT invoke unleash:validating automatically. Validating (Plan 3 of the Unleash roadmap) has a specific precondition that the user must reach consciously — it's the gate between "code exists" and "harness is trusted for use". Auto-advancing hides that decision.

When you finish Phase D, deliver the terminal message **literally**, with only the bracketed substitutions filled in. Do NOT add any "next actual steps" / "实际生效路径" / "you should now deploy" / "manually run e2e" / "judge against guardian" extrapolation. Unleash's scope ends at "committed code in the user's project". Deployment, `git push`, CI/CD, production rollout, and any verification step the spec did not declare are explicitly OUT of scope and must not appear in your final message.

Terminal message template (verbatim, only `<...>` placeholders substituted):

> Implementation complete. Tasks completed: \<N\>. Commits: \<list of SHAs\>. Concerns to review: \<list of DONE_WITH_CONCERNS items or "none"\>. Invoke unleash:validating when ready to verify the harness against its spec (validating ships in Plan 3; until then you can manually inspect artifacts against the plan's Dependency Map).

Nothing after this paragraph. No follow-up section. No "actual effective path". No "next steps for you". The user's domain begins where Unleash ends — respect that boundary.
</HARD-GATE>

## Checklist

Complete these items in order. Use TodoWrite to track progress.

1. Phase A: read plan.md + knowledge doc §3 and §4; note plan commit SHA
2. Phase A: extract all tasks into an internal list with full text blobs preserved; note Group boundaries from the plan
3. Phase B: prepare dispatch-plan per task (task text + amputated scene-setting with artifact paths and mandatory file-read instructions)
4. Phase C: dispatch task 1 with FULL task text pasted; wait for report
5. Phase C: handle status per rules (DONE → note + **append to manifest** + next; DONE_WITH_CONCERNS → note + next; BLOCKED/NEEDS_CONTEXT → add context + re-dispatch; do NOT review output)
6. Phase C: after completing the last task in each Group, run Group Checkpoint (verify artifact existence, verify testing_mode conservation); STOP on deviation
7. Phase C: repeat sequentially for all N tasks and all Groups (never parallel, never batch)
8. Phase D: summarize commits, concerns, and checkpoint results; STOP (do not invoke validating, do not review)
