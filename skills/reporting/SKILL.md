---
name: reporting
description: "Use after a single Unleash-driven coding task is complete and you don't have a runtime harness installed (no .unleash/manifest.json) — writes a brief independent-reviewer report covering intent, what changed, and observations. Lightweight B-layer-only counterpart to unleash:archiving."
---

# Unleash: Reporting

> Wrap up a single dialogically-driven coding task with a brief cold-review report from a fresh reviewer who sees only the spec and the aggregate diff.

<HARD-GATE>
Do NOT pass brainstorm.md, plan.md, commit messages, or any "what happened during the build" narrative to the fresh reviewer. The reviewer sees ONLY: the committed spec.md + the aggregate filtered git diff (spec → HEAD, excluding docs/unleash/) + (if the user volunteered them) the user's one-line verification notes. Anything else defeats the cold-review contract.

Do NOT run if `.unleash/manifest.json` exists. The presence of a manifest indicates a runtime harness was installed; that case belongs to unleash:archiving.

Do NOT use grep on commit messages or on diff text to filter Unleash meta-artifacts. The ONLY correct filter mechanism is git pathspec syntax (`-- ':!docs/unleash/'`), which filters by file path that a commit actually touched. Commit messages containing the string "docs/unleash" do NOT mean the commit touched that path; line-based grep on diff output can falsely match code comments or documentation strings.

Do NOT extrapolate beyond the literal terminal message — no "now you should deploy", "go push to production", "consider running this in CI". Reporting wraps up; the user owns whatever comes next.
</HARD-GATE>

## Precondition

Verify in order:

**Condition 1: spec.md exists and is committed.**

Path: `docs/unleash/specs/<YYYY-MM-DD>-<slug>-spec.md`

If absent or uncommitted, STOP with:

> "spec.md not found at expected path or not committed. Reporting requires a committed spec to anchor the diff range. If you have a spec, commit it first; if you don't, this isn't an Unleash-driven workflow and reporting doesn't apply."

**Condition 2: HEAD ≠ spec.md's first commit.**

```bash
git rev-parse HEAD
git log --diff-filter=A --format=%H -- docs/unleash/specs/<file> | tail -1
```

These must differ. If equal, STOP with:

> "HEAD is the spec commit itself — there is no implementation to report on. Run unleash:implementing first, then return."

**Condition 3: NO manifest at `.unleash/manifest.json`.**

If manifest exists, STOP with:

> "A `.unleash/manifest.json` is present, which means you have a runtime harness installed. Reporting is for B-layer-only workflows; for runtime harnesses, invoke unleash:archiving instead — it preserves the lifecycle bundle and runs a deeper review covering guardian and hook dimensions that don't apply to single-task workflows."

## Contract

**Consumes:** the committed spec.md at `docs/unleash/specs/<...>-spec.md`, the aggregate filtered git diff from the spec commit to HEAD (path-filtered, not message-filtered), and (optionally) the user's one-line verification notes from the user prompt.

**Produces:** `docs/unleash/reports/<YYYY-MM-DD>-<name>-report.md` — a brief markdown report from a fresh independent reviewer covering 4 dimensions (faithfulness, quality, observability, lessons-learned) plus an Open Questions section.

**Precondition:** spec.md committed; HEAD has diverged from spec commit; no `.unleash/manifest.json` present.

**Postcondition:** report committed; no other files touched; the reviewer subagent had no access to brainstorm/plan/commit-messages/manifest.

## Anti-patterns: "more context for the reviewer is always better"

The following rationalizations feel true in the moment. Each one produces a weaker outcome when acted on. Recognize them and reject them.

> **Thought:** "I'll feed the reviewer the brainstorm too — more context will help them write a better review."
> **Rebuttal:** Brainstorm captures pre-decision exploration. Showing it to the reviewer leaks information about what the user CONSIDERED but didn't commit to. The reviewer's job is to audit what was COMMITTED (the spec) against what was BUILT (the diff). Anything in between is the implementer's narrative; including it makes the cold review warm.

> **Thought:** "I should run the user's tests myself to verify pytest passes — that's part of reporting."
> **Rebuttal:** That's validation, not reporting. Reporting writes an audit based on what the user reports + what's in git. If the user says 'pytest passing' and they're wrong, that's information the reviewer notes ("user reports tests pass; I cannot independently verify from the diff alone"). Re-running tests crosses into validating's territory and is out of scope here.

> **Thought:** "Commit messages would help the reviewer understand the workflow's structure."
> **Rebuttal:** Commit messages are implementer narrative. A commit message saying "feat: fix login flow" pre-frames the diff as a fix; the reviewer's job is to judge whether the diff actually IS a fix that matches the spec. Showing the framing biases the cold review. The reviewer reads the diff and judges from first principles.

> **Thought:** "I'll grep the commit log for `docs/unleash` to find and exclude those commits."
> **Rebuttal:** Don't use grep on commit messages or diff output text. Use git pathspec syntax (`-- ':!docs/unleash/'`), which filters by the FILE PATH a commit touched. A commit message containing the string "docs/unleash" doesn't mean the commit touched that path — it might just mention it in prose. Line-based grep on diff output can also falsely match code comments. Pathspec is the only correct mechanism; everything else is a footgun.

> **Thought:** "I should suggest fixes for issues the reviewer flags."
> **Rebuttal:** Reporting writes the report; the report contains the reviewer's findings; the user (not this skill) decides what to do with them. Suggesting fixes here would 1) duplicate the reviewer's open-questions section, 2) blur the boundary between this skill and validating/implementing, and 3) leak controller reasoning into a contract we promised would be cold.

## Operating Protocol

### Phase A — Absorption

- Verify Conditions 1–3 from Precondition; STOP if any fail
- Locate spec.md path; identify its first-commit SHA via `git log --diff-filter=A --format=%H -- <path> | tail -1`
- Read spec.md content (full, verbatim — for passing to reviewer in Phase C)
- Note HEAD SHA
- Note user's one-line verification notes if present in the user prompt

### Phase B — Diff aggregation (with transparent filter report)

Compute the filtered aggregate diff using **git pathspec only**:

```bash
# 1. Get list of files included (path-filter excludes docs/unleash/)
INCLUDED_FILES=$(git diff --name-only <spec-sha>..HEAD -- ':!docs/unleash/')

# 2. Get list of files excluded (the complement: only docs/unleash/ files)
EXCLUDED_FILES=$(git diff --name-only <spec-sha>..HEAD -- 'docs/unleash/')

# 3. Get the actual diff content
DIFF=$(git diff <spec-sha>..HEAD -- ':!docs/unleash/')
```

**Print a transparent filter report** before proceeding (so the user can see exactly which files were included/excluded — catches surprise cases where their project has unusual paths under docs/unleash/):

```
Filter report (Phase B)
=======================
Diff range: <spec-sha>..HEAD
Filter: pathspec ':!docs/unleash/' (file-path based; NOT message-based)

Files included in report (N):
  - <file 1>
  - <file 2>
  ...

Files excluded as Unleash meta-artifacts (M):
  - <file 1>
  - <file 2>
  ...

Total diff lines: <count>
```

If `INCLUDED_FILES` is empty, STOP with:

> "No production code changes between spec commit and HEAD (all changes were under docs/unleash/). Reporting cannot audit nothing — verify the implementation actually committed code outside docs/unleash/, or invoke reporting after the fix lands."

If the user looks at the filter report and sees something unexpected (e.g., a project file that shouldn't be excluded), they can interrupt and correct course before the reviewer is dispatched.

### Phase C — Dispatch fresh reviewer

Use the Agent tool with:
- subagent_type: general-purpose
- model: sonnet (or opus for complex/long diffs)
- prompt: use the template in §8 below, substituting:
  - `<SPEC.MD CONTENT VERBATIM>` — the full spec.md
  - `<AGGREGATE DIFF>` — the output from Phase B
  - `<USER VERIFICATION NOTES>` — the one-liner from user prompt, or "(none provided)"

The prompt does NOT include: plan.md, brainstorm.md, commit messages, manifest, or the filter report from Phase B (the filter report is for the user, not the reviewer).

Wait for reviewer response. The reviewer's output IS the report content.

### Phase D — Save report and terminal handoff

Save reviewer's response to `docs/unleash/reports/<YYYY-MM-DD>-<harness-name>-report.md`. Use the spec's slug for `<harness-name>`. Wrap it with a header:

```markdown
# Cold Review Report: <harness-name>
**Spec SHA:** <spec-sha>
**HEAD SHA:** <head-sha>
**Reviewed at:** <ISO timestamp>
**Files audited:** <N> production-code files (Unleash meta-artifacts excluded via pathspec)
**User verification notes:** <one-liner or "(none provided)">

---

<reviewer's full response, verbatim>
```

Commit:

```bash
git add docs/unleash/reports/ && git commit -m "report: cold review for <harness-name>"
```

Then deliver the literal terminal message (see §10 Termination).

## Reviewer prompt template

```
A user has finished a single coding task driven by Unleash. They are wrapping up and asked for an independent cold review. You are the fresh reviewer — you have NOT seen this work before, you have NOT received any reasoning from the implementer, and you have NOT been told what intermediate steps occurred.

You receive ONLY:
1. The committed spec.md (the design the user committed to)
2. The aggregate git diff (what got built, filtered to production code only)
3. The user's reported verification (a one-liner — sometimes empty)

You do NOT receive: the brainstorm, the plan, commit messages, or any narrative about how the build went. This isolation is intentional — your job is to read spec + diff cold and write what you see.

## Spec (verbatim)

<SPEC.MD CONTENT VERBATIM>

## Aggregate diff (spec → HEAD, code paths only)

<AGGREGATE DIFF>

## User's reported verification

<USER VERIFICATION NOTES>

## Your task

Write a brief report in markdown addressing these 4 dimensions, ONE PARAGRAPH each:

1. **Faithfulness** — does the diff fulfill what the spec promised? Where it differs, is the difference principled or accidental? If the user reported verification, briefly note whether the diff makes that claim plausible (you cannot run tests; you can only assess whether the diff looks like it would pass them).

2. **Quality** — judgment-level observations on the diff's craft. Naming, structure, edge cases, any code-smell signals (e.g., a magic number with no rationale, a regex that looks fragile, a missing null-check on user input). Be specific — quote the exact line if you flag something.

3. **Observability** — would a future maintainer reading the spec + diff cold (the way you are now) understand what changed and why? Is the diff self-explanatory or does it depend on context only the original author has?

4. **Lessons learned** — one or two takeaways the user should carry forward. These can be about the fix itself, about how the spec was structured, or about the gap between "what was committed" and "what got built". Avoid platitudes; be specific to this case.

End with an "Open Questions" section: 2–4 questions you would ask the original author if you could. These are for the user to reflect on as they finish this task.

Keep the whole report to 300–600 words. Reporting is meant to be readable in two minutes — not exhaustive.
```

## Output artifact

The single file at `docs/unleash/reports/<YYYY-MM-DD>-<harness-name>-report.md` produced in Phase D, including the header wrapper.

## Termination

<HARD-GATE>
Do NOT extrapolate beyond the literal terminal message. No "next actual steps", no deployment talk, no "you should now run X in production", no manual e2e suggestions. Reporting is the wrap-up; what comes next is the user's call.

Deliver this terminal message LITERALLY (only the bracketed substitutions filled in):

> Report complete. Saved to docs/unleash/reports/\<filename\>. Reviewer addressed faithfulness, quality, observability, lessons learned, and open questions. Read it as a 2-minute audit of your fix; act on the findings as you see fit. Unleash's work on this task ends here.

Nothing after this paragraph. The user's domain begins where Unleash ends.
</HARD-GATE>

## Checklist

Complete these items in order. Use TodoWrite to track progress.

1. Phase A: verify all 3 preconditions (spec exists/committed, HEAD ≠ spec SHA, no manifest)
2. Phase A: read spec.md content verbatim; capture spec SHA + HEAD SHA + user verification notes
3. Phase B: compute pathspec-filtered diff; print transparent filter report (files included / excluded / total lines)
4. Phase B: STOP if filter report shows zero files included
5. Phase C: dispatch fresh reviewer with spec + diff + verification notes ONLY (NOT the filter report; NOT plan/brainstorm)
6. Phase D: wrap reviewer's response with header; save to docs/unleash/reports/; commit
7. Deliver literal terminal message; STOP (no extrapolation)
