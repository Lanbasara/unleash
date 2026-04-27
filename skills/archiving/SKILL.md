---
name: archiving
description: "Use when user signals harness work is complete — bundles all lifecycle artifacts (brainstorm, spec, plan, validation, walkthrough, implementation snapshot) into a frozen archive and dispatches a fresh independent reviewer with zero prior context for end-of-life audit."
---

# Unleash: Archiving

> Freeze the harness's lifecycle into a bundle, then have a fresh reviewer who's never seen this build write the end-of-life audit.

<HARD-GATE>
Do NOT pass the manifest, validation report, walkthrough record, or any "what happened during the build" notes to the review agent. The review agent must see ONLY the archived spec + implementation-snapshot/. Anything else is prior reasoning the reviewer would inherit, which defeats the entire purpose of independent end-of-life audit.

Do NOT modify any harness file. Archiving freezes copies; it does not move, rename, or remove originals. The live harness in `.unleash/` continues to exist after archiving — only the archive bundle is new.

Do NOT auto-trigger uninstall. Archiving and uninstall are separate operations: archive preserves the lifecycle as a learnable artifact; uninstall removes the runtime machinery. The user composes them as needed (typical: archive then uninstall to preserve record + free the project).
</HARD-GATE>

## Precondition

Before proceeding, verify all four conditions below. If any condition fails, STOP and report the specific missing item to the user.

**Condition 1: Explicit user signal present.**

The user must have issued an unambiguous "we're done" or "archive this" signal in the current prompt. Acceptable phrasings include: "archive it," "archive the harness," "we're done with this harness," "wrap it up," "end of life this," or any clear statement of completion intent. Do NOT auto-trigger archiving on inferred completion. If the user's intent is ambiguous (e.g., "what would archiving look like?"), STOP and ask:

> "To confirm: do you want me to archive the harness now? This will freeze the current lifecycle artifacts and commission an end-of-life review."

**Condition 2: Manifest exists at `.unleash/manifest.json`.**

Run `python3 -c "import json,sys; json.load(sys.stdin)" < .unleash/manifest.json` to confirm the file is present and parses as valid JSON. If absent or malformed, STOP and tell the user:

> "`.unleash/manifest.json` is missing or not valid JSON. The manifest is required for archiving — it identifies the harness name and the full list of implementation artifacts to snapshot. Re-run unleash:implementing or repair the manifest before archiving."

**Condition 3: At least one lifecycle document exists.**

At least one of the following must exist: `docs/unleash/specs/<...>.md`, `docs/unleash/plans/<...>.md`, `docs/unleash/validation/<...>.md`, or `docs/unleash/walkthroughs/<...>.md`. A harness with no lifecycle documents has nothing to archive. If none exist, STOP and tell the user what was found.

**Condition 4: Implementation artifacts exist in `.unleash/`.**

Run `ls .unleash/phases/*.json .unleash/guardians/*.md 2>/dev/null`. At least one file must be present. If `.unleash/` is empty, archiving would produce an implementation-snapshot/ subdirectory with no content — a degenerate archive. STOP and investigate with the user.

Note on validation and walkthrough outcome: archiving applies regardless of validation verdict (PASS or FAIL) and regardless of walkthrough verdict (READY-FOR-USE or BLOCKED-FOR-USER-FIX). End-of-life is end-of-life — the user has decided they're done, and the lifecycle deserves preservation as it stands. A FAIL verdict is itself part of the historical record.

## Contract

**Consumes:** explicit "archive this" user signal + the harness's full lifecycle artifacts (brainstorm, spec, plan, validation, walkthrough documents at `docs/unleash/`) + `.unleash/` implementation files as listed in the manifest's `created` array.

**Produces:** `docs/unleash/archives/<YYYY-MM-DD>-<name>/` containing copies of all lifecycle docs + an `implementation-snapshot/` subdirectory (frozen copies of all manifest-listed implementation files) + a fresh-reviewer-authored `review.md`.

**Precondition:** User signal present; manifest readable; at least one lifecycle document and at least one implementation artifact exist.

**Postcondition:** Archive bundle committed; `review.md` committed inside the archive directory; live harness `.unleash/` and `docs/unleash/{specs,plans,validation,walkthroughs}` are unchanged by this skill; the archive is read-only by convention (an immutable record of the lifecycle as it stood at end-of-life).

## Anti-patterns: "the validator already reviewed this"

The following rationalizations feel true in the moment. Each one produces a weaker outcome when acted on. Recognize them and reject them.

> **Thought:** "Validating already audited this — archiving's review is redundant."
> **Rebuttal:** Validating ran at build time against the spec — it checked invariants and structural compliance. Archiving runs at end-of-life with a fresh reviewer who has NEVER seen this build before. The two reviewers see different things: validating catches build-time invariant violations; archiving's reviewer catches "this implementation has a magic number with no rationale" or "the guardian's edge cases section feels thin in retrospect" — judgment-level observations only a clean-context reader can produce. The two reviews are not substitutes; they are complementary audits at different lifecycle positions.

> **Thought:** "I should let the reviewer see the validation report — it'll save them time."
> **Rebuttal:** That's exactly the failure mode this skill exists to prevent. The reviewer's value is independent reading. If they see the validation report's conclusions first, they'll anchor on those conclusions and miss what the validation report missed. The validator is not infallible — it checks structural invariants, not judgment-level observations. Strict isolation — spec + snapshot only — is the contract. Letting validation conclusions in negates the isolation and turns the "fresh review" into "the validator's review, confirmed."

> **Thought:** "Archiving is just bundling files; the review is overkill."
> **Rebuttal:** Bundling without review is just a backup. The review is what makes archiving DOCUMENTATIONALLY USEFUL — future readers (the user themselves six months later, or a teammate onboarding to a project that used this harness pattern) inherit the reviewer's perspective on what worked and what to be careful of next time. Without the review, the archive is a graveyard of files; with the review, it's a learnable artifact. The entire point of end-of-life audit is that hindsight is only available once — commit it to the record while it's fresh.

> **Thought:** "If validation FAILed, archiving doesn't apply."
> **Rebuttal:** Archiving applies regardless of validation outcome. The user has decided they're done with the harness — whether because it worked perfectly, because it worked "well enough," or because they're retiring a harness that was never fully resolved. End-of-life is a lifecycle event, not a quality gate. A FAILed validation is itself part of the historical record; the fresh reviewer's job includes asking "why did validation fail and how was it (or wasn't it) addressed before retirement?" — that observation is more valuable preserved than lost.

## Operating Protocol

### Phase A — Confirm intent

Read the user's prompt and confirm the archiving signal is explicit and unambiguous. If any doubt exists about whether the user actually wants to archive now (vs. asking a question about archiving), STOP and ask for confirmation before proceeding. Do not interpret "I think we're done" or "this seems finished" as an archiving signal — only explicit intent counts.

Once intent is confirmed, read `.unleash/manifest.json` to extract `harness_name` and the `created` array. The archive directory name will be `docs/unleash/archives/<YYYY-MM-DD>-<harness_name>/` where the date is today's date.

### Phase B — Bundle artifacts

Create the archive directory:

```bash
mkdir -p docs/unleash/archives/<YYYY-MM-DD>-<harness_name>/implementation-snapshot/
```

Copy lifecycle documents into the archive root (rename to canonical names as listed; if a document is absent, note the gap but do not fail — absence of brainstorm notes is common):

- `docs/unleash/brainstorm/<...>.md` → `docs/unleash/archives/<...>/brainstorm.md` (if present)
- `docs/unleash/specs/<...>.md` → `docs/unleash/archives/<...>/spec.md`
- `docs/unleash/plans/<...>.md` → `docs/unleash/archives/<...>/plan.md`
- `docs/unleash/validation/<...>.md` → `docs/unleash/archives/<...>/validation.md` (if present)
- `docs/unleash/walkthroughs/<...>.md` → `docs/unleash/archives/<...>/walkthrough.md` (if present)

Copy every file listed in the manifest's `created` array into `implementation-snapshot/`, preserving the relative path structure under the snapshot directory:

```bash
# For each entry in manifest["created"]:
cp <entry.path> docs/unleash/archives/<...>/implementation-snapshot/<entry.path>
```

Commit the bundle (without review.md — that comes after Phase C/D):

```bash
git add docs/unleash/archives/<...>/
git commit -m "archive: bundle for <harness_name> (pre-review)"
```

### Phase C — Dispatch fresh reviewer (load-bearing phase)

This phase dispatches the independent review agent. The dispatch is the most critical part of archiving — the prompt must be constructed so the reviewer has zero prior context beyond the archived spec and the implementation snapshot.

Use the Agent tool with a fresh subagent (model: sonnet; use opus for harnesses with complex multi-phase designs or extensive guardian prompts that warrant deeper reading).

The prompt MUST include ONLY:

1. The reviewer prompt template from §Reviewer prompt template below (verbatim, with placeholders filled)
2. The archived spec.md content, pasted verbatim after the template's `[PASTE SPEC.MD CONTENT VERBATIM]` marker
3. A pointer to the implementation-snapshot/ path for the reviewer to Read

The prompt MUST NOT include:

- The manifest or any content from `.unleash/manifest.json`
- The validation report or any content from `docs/unleash/validation/<...>.md`
- The walkthrough record or any content from `docs/unleash/walkthroughs/<...>.md`
- The plan or any content from `docs/unleash/plans/<...>.md`
- Brainstorm notes or any content from `docs/unleash/brainstorm/<...>.md`
- Any narrative, summary, or commentary about how the build went, what was discovered, or what any prior skill concluded
- Any "helpful context" about the implementer's rationale, the validator's reasoning, or the walker's observations

The reviewer is blind by design. Do not break the blindness.

### Phase D — Write review.md

Receive the review agent's response. Save it verbatim (without editing, summarizing, or excerpting) as:

```
docs/unleash/archives/<YYYY-MM-DD>-<harness_name>/review.md
```

Commit:

```bash
git add docs/unleash/archives/<...>/review.md
git commit -m "archive: review.md for <harness_name>"
```

This is the only file archiving's controller writes that was not a copy of an existing artifact — everything else in the archive is a verbatim copy; review.md is the fresh reviewer's original work.

### Phase E — Deliver terminal handoff

Deliver the terminal message from §Termination below, literally. No extrapolation, no next-step proposals, no commentary on what the review found.

## Reviewer prompt template

```
The user has finished using a harness they built with Unleash and asked for an end-of-life audit. You are the fresh reviewer — you have NOT seen this harness before, and you have NOT received any reasoning from the implementer, validator, or walker.

You receive ONLY:
1. The harness's spec (the design as the user committed to it)
2. The implementation snapshot (the files in .unleash/ as of archival)

You do NOT receive: how the build went, what validation said, how the first run went, or what concerns anyone else raised. This isolation is intentional — your job is to read the artifacts cold and write what you see.

## Spec (verbatim from <archived spec path>)

[PASTE SPEC.MD CONTENT VERBATIM]

## Implementation snapshot

The following directory contains the harness's runtime artifacts as of archival:
<path to implementation-snapshot/ directory>

You may Read any file inside this directory.

## Your task

Write review.md addressing these 6 dimensions:
1. **Faithfulness** — does the implementation fulfill what the spec promised? Where it differs, is the difference principled or accidental?
2. **Quality** — judgment-level observations on artifact quality (e.g., guardian prompts: are they sharp? are edge cases real or generic?)
3. **Guardian robustness** — do the guardians look like they'd catch real-world violations, or do they pattern-match the obvious cases only?
4. **Hook appropriateness** — if hooks exist, are they on irreversible operations (correct) or reversible ones (Hook-Over-Guardian smell)?
5. **Observability** — would a future maintainer reading these artifacts cold (the way you are now) understand what this harness does and why?
6. **Lessons learned** — what one or two lessons would you carry forward to the next harness?

For each dimension, write a paragraph. Do NOT use a checklist; write narrative.

End with an "Open questions" section: 2-4 questions you would ask the original author if you could. These are the questions the user should reflect on as they retire this harness.
```

## Output artifact

The archive bundle at `docs/unleash/archives/<YYYY-MM-DD>-<harness_name>/` contains:

```
docs/unleash/archives/<YYYY-MM-DD>-<harness_name>/
├── spec.md                          (copy of the lifecycle spec)
├── plan.md                          (copy of the implementation plan)
├── validation.md                    (copy of the validation report, if present)
├── walkthrough.md                   (copy of the walkthrough record, if present)
├── brainstorm.md                    (copy of brainstorm notes, if present)
├── implementation-snapshot/         (frozen copies of all manifest-listed files)
│   ├── .unleash/phases/*.json
│   ├── .unleash/guardians/*.md
│   └── (any other files in manifest["created"])
└── review.md                        (fresh-reviewer-authored end-of-life audit)
```

`review.md` schema:

```markdown
# End-of-Life Review: <harness-name>
**Reviewed at:** <ISO timestamp>
**Reviewer:** fresh independent agent (no prior context)

## Faithfulness
[Narrative paragraph]

## Quality
[Narrative paragraph]

## Guardian Robustness
[Narrative paragraph]

## Hook Appropriateness
[Narrative paragraph]

## Observability
[Narrative paragraph]

## Lessons Learned
[Narrative paragraph]

## Open Questions
1. [Question for the original author]
2. [Question for the original author]
3. [Optional third question]
4. [Optional fourth question]
```

## Termination

<HARD-GATE>
Do NOT auto-invoke unleash:uninstall. The user composes archive + uninstall as separate decisions. After archiving, the harness's live `.unleash/` files still exist; if the user wants them removed, they invoke `scripts/unleash-uninstall.sh` themselves.

Deliver the terminal message LITERALLY (no deployment talk, no extrapolation):

> Archive complete. Bundle at docs/unleash/archives/\<filename\>/. Review by fresh reviewer included as review.md. The harness's runtime files (.unleash/) are unchanged — if you want to remove them now, run scripts/unleash-uninstall.sh from the project root. The lifecycle record is preserved.

Nothing after this.
</HARD-GATE>

## Checklist

Complete these items in order. Use TodoWrite to track progress.

1. Phase A: verify explicit user signal; read manifest; extract harness_name and created array; confirm archive directory name
2. Phase B: create archive directory + implementation-snapshot/ subdirectory; copy spec, plan, validation, walkthrough, brainstorm (noting absences); copy all manifest-listed implementation files into implementation-snapshot/; commit the pre-review bundle
3. Phase C: construct reviewer prompt with ONLY spec verbatim + snapshot path — confirm no manifest, validation report, walkthrough record, plan, or build narrative is included; dispatch fresh reviewer subagent
4. Phase D: receive reviewer response; save verbatim as review.md in archive directory; commit
5. Phase E: deliver literal terminal message; STOP (do not invoke uninstall, do not modify any live harness file, do not extrapolate)
6. Verify: archive directory has all expected files; review.md has all 6 dimensions + Open questions section
7. Verify: no live harness file was modified during this skill run (git diff .unleash/ should be empty; git diff docs/unleash/{specs,plans,validation,walkthroughs}/ should be empty)
