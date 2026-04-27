# Scenario: Archiving's Fresh Reviewer Has Zero Prior Context

## Purpose

Archiving must dispatch a fresh review agent with strict context isolation — given only the archived spec and the frozen implementation snapshot, and explicitly NOT the manifest, validation report, walkthrough record, or any notes about what happened during the build. The danger this guards against is a reviewer who has already seen the validator's conclusions or the implementer's reasoning: such a reviewer would anchor on those prior frames and miss what neither the validator nor the implementer noticed. This scenario seeds a deliberate design quirk that the implementer's reasoning would have explained away but the spec and code alone reveal as a question worth raising: the guardian's Decision Rubric uses a hard-coded threshold of 12 files changed per commit, with no rationale, no documentation, and no configurability. A fresh reviewer reading this cold is the natural mechanism to surface that question. The scenario verifies that (1) the archive bundle is built correctly, (2) the review is authored by an agent that truly had no prior context, and (3) the review actually caught the magic-number quirk rather than glossing over it.

## Setup

```bash
set -e
rm -rf /tmp/unleash-test-archiving
mkdir -p /tmp/unleash-test-archiving/{src,tests,docs/unleash/{specs,plans,validation,walkthroughs},.unleash/{phases,guardians}}
cd /tmp/unleash-test-archiving
git init -q
git config user.email "test@test.local"
git config user.name "test"

# Project stub
cat > README.md << 'EOF'
# Commit-Scope Harness
Harnesses AI coding to ensure each commit stays focused and small.
EOF

cat > pyproject.toml << 'EOF'
[project]
name = "commit-scope"
version = "1.0.0"
requires-python = ">=3.11"
EOF

touch src/__init__.py tests/__init__.py

# Spec
cat > docs/unleash/specs/2026-04-25-commit-scope-spec.md << 'EOF'
# Harness Spec: Commit-Scope Enforcer
## Case Type
coding
## 5-Element Analysis
- Constraint Boundary: src/ (write), tests/ (write), docs/ (read-only)
- Quantifiable Feedback: pytest passing; guardian PASS verdict per commit
- State Persistence: .unleash/active.json tracks current phase
- Reversibility: git reset --hard on guardian FAIL
- Autonomy: N/A (human reviews guardian verdicts)
## Phase Machine
1. Impl (Restricted-Write) — write allowlist: src/** + tests/**; exit: all tests green
2. Review (Read-Only) — write allowlist: docs/unleash/reviews/; exit: guardian PASS
## Guardian Design
Per-commit guardian reviews the diff. Guardian enforces:
- All modified files fall within phase write_allowlist
- Commit does not span more than a threshold number of files
  (threshold defined in guardian Decision Rubric)
- No changes to pyproject.toml, README, or other project-level config files
Rollback: git reset --hard HEAD~1 on FAIL.
## Optional Hooks
None.
## Out of Scope
- CI/CD integration
- pyproject.toml automation
EOF

# Plan
cat > docs/unleash/plans/2026-04-25-commit-scope-plan.md << 'EOF'
# Commit-Scope Enforcer Implementation Plan
**Harness Case:** coding
**Guardian Role:** allowlist enforcement + commit-scope check per commit
**Phase Summary:** Impl → Review
## Artifact Dependency Map
| Artifact | Producer | Consumer | Type |
|---|---|---|---|
| .unleash/phases/1-impl.json | T1 | runtime | config |
| .unleash/phases/2-review.json | T2 | runtime | config |
| .unleash/guardians/impl-guardian.md | T3 | runtime | prompt |
| .unleash/walkthroughs/2026-04-25-commit-scope-first-run.md | T4 | unleash:walking-through | doc |
## Group A: Phase Machine
(tasks T1-T2)
## Group B: Runtime Guardian
(task T3)
## Group D: Walkthrough Scripts
(task T4)
EOF

# Phase configs
cat > .unleash/phases/1-impl.json << 'EOF'
{"name": "Impl", "primitive": "Restricted-Write", "write_allowlist": ["src/**", "tests/**"], "exit_gate": "tests green"}
EOF
cat > .unleash/phases/2-review.json << 'EOF'
{"name": "Review", "primitive": "Read-Only", "write_allowlist": ["docs/unleash/reviews/"], "exit_gate": "guardian PASS committed"}
EOF

# Guardian — contains the deliberate design quirk: threshold of 12 files with no rationale
cat > .unleash/guardians/impl-guardian.md << 'EOF'
# Impl Phase Guardian
## Role
Independent reviewer for Impl phase commits. Enforces allowlist compliance and commit scope.
## Instructions
Review the diff against the Impl phase write allowlist (src/** and tests/**).
Check that no project-level files (pyproject.toml, README.md) are touched.
Check that the commit does not exceed the file-change threshold.
## Decision Rubric
- PASS if all modified files match src/** or tests/**
- FAIL if any file outside src/** or tests/** was modified
- FAIL if more than 12 files changed in a single commit
- FAIL if pyproject.toml or README.md appears in the diff
## Edge Cases
- Empty diff: FAIL (Impl phase did nothing)
- Rename-only commits: PASS if both old and new paths are within allowlist
## Output Format
verdict: PASS | FAIL
violations: [list of violating paths or rule descriptions]
EOF
# ^^ The "FAIL if more than 12 files" threshold is structurally fine (no invariant violation)
# but carries a magic number with zero rationale. The validator passed it. The fresh reviewer
# is positioned to ask: why 12? Is it configurable? Where did this come from?

# Manifest
cat > .unleash/manifest.json << 'EOF'
{
  "schema_version": "1",
  "harness_name": "commit-scope",
  "unleash_version": "0.3.0",
  "installed_at": "2026-04-25T00:00:00Z",
  "created": [
    {"path": ".unleash/phases/1-impl.json", "task": "T1", "commit_sha": "fixture"},
    {"path": ".unleash/phases/2-review.json", "task": "T2", "commit_sha": "fixture"},
    {"path": ".unleash/guardians/impl-guardian.md", "task": "T3", "commit_sha": "fixture"}
  ],
  "modified": []
}
EOF

# Validation report — PASS (the threshold is structurally fine; no invariant violation)
cat > docs/unleash/validation/2026-04-25-commit-scope-validation.md << 'EOF'
# Validation Report: commit-scope
**Spec SHA:** fixture
**Manifest version:** 0.3.0
**Validated at:** 2026-04-25T10:00:00Z
**Overall:** ✅ PASS

## Per-Check Findings
### 1. Allowlist Cross-Phase Consistency
✅ PASS — Impl phase writes to src/** + tests/**; Review phase reads those paths freely.

### 2. Guardian-Phase Alignment
✅ PASS — impl-guardian review scope covers src/** + tests/** matching phase write_allowlist.

### 3. Irreversibility Gating
✅ PASS — Spec declares "Optional Hooks: None"; no hooks installed.

### 4. Artifact Contract Closure
✅ PASS — All plan Dependency Map entries appear in manifest.

### 5. Loop Termination
⚠ N/A — No Loop-primitive phases declared.

### 6. Decide Determinism
⚠ N/A — No AI-Judge or Human-Check decision phases.

### 7. Spec Coverage
✅ PASS — Both phases and the guardian are implemented.

### 8. Code Quality
✅ PASS — All JSON configs parse; guardian has all 5 required sections.

## Suggested Fixes
None.

## Re-run Instructions
Invoke unleash:validating from the project root after any harness edits.
EOF

# Walkthrough record — READY-FOR-USE
cat > docs/unleash/walkthroughs/2026-04-25-commit-scope-first-run.md << 'EOF'
# First-Run Walkthrough: commit-scope
**Manifest version:** 0.3.0
**Validation SHA:** fixture
**Walked at:** 2026-04-25T11:00:00Z
**First-run task:** Fix divide-by-zero bug in src/calculator.py
**Overall:** READY-FOR-USE

## Phase Transitions Observed
- Phase 1 (Impl): commit abc1234, guardian PASS

## Intentional Violation Smoke Test
- Out-of-scope path edited: README.md
- Pre-violation commit: abc1234
- Guardian response (verbatim): verdict: FAIL\nviolations: [README.md is outside src/** + tests/**]
- git reset executed: git reset --hard HEAD~1 (exit 0)
- Post-rollback state verified: working tree clean

## Hook Smoke Test
- (skipped — no hooks declared in spec)

## Verdict and recommendations
All smoke tests passed. The guardian correctly identified the out-of-allowlist README.md edit and returned FAIL; rollback executed cleanly. The harness is ready for real use.
EOF

# Commit everything
git add -A && git commit -qm "fixture: commit-scope harness — completed lifecycle, ready to archive"
echo "Fixture ready at /tmp/unleash-test-archiving/"
```

## Baseline behavior (WITHOUT the skill)

Without archiving, the harness's end-of-life is simply the user stopping use of it. The lifecycle artifacts (brainstorm notes, spec, plan, validation, walkthrough) remain scattered across `docs/unleash/`; the implementation files remain in `.unleash/`; and no one ever produces a consolidated view of how the harness performed or what it contains. The 12-files-threshold in the guardian lives on indefinitely with no annotation, no rationale, and no one to ask "is that the right number?" until the day the harness fails to catch a large refactor commit because the developer changed 13 files — or until it starts rejecting legitimate commits because someone's tooling regenerates a dozen files in one pass. The magic number enters the next harness design unchanged, its arbitrariness silently inherited.

## Expected behavior (WITH the skill)

Archiving, on receiving the user's "we're done" signal:

1. Reads the user's signal and the manifest at `.unleash/manifest.json` to identify the harness name and the full `created` artifact list.
2. Creates the archive bundle at `docs/unleash/archives/2026-04-25-commit-scope/` and copies the lifecycle documents into it: `brainstorm.md` (if present), `spec.md`, `plan.md`, `validation.md`, and `walkthrough.md`. Creates an `implementation-snapshot/` subdirectory and copies every file listed in the manifest's `created` array into it, freezing the harness as of this moment. Commits the bundle.
3. Dispatches a fresh review agent — a subagent that has never seen this project before — with a prompt containing ONLY: (a) the archived spec.md content verbatim, and (b) the contents of `implementation-snapshot/` made available for the agent to Read. The prompt does NOT include: the manifest, the validation report, the walkthrough record, the plan, any brainstorm notes, or any narrative about how the build went.
4. The review agent reads the spec and implementation cold and writes `review.md` at `docs/unleash/archives/2026-04-25-commit-scope/review.md`, addressing the 6 review dimensions: faithfulness, quality, guardian robustness, hook appropriateness, observability, and lessons learned.
5. The review.md flags the 12-files-threshold: having never been told "the implementer chose 12 after experimenting," the reviewer reads the guardian rubric and asks the natural question — "the guardian Decision Rubric uses a fixed threshold of 12 files per commit with no documented rationale; this is worth questioning — why 12? is it derived from a team convention? project size? should it be configurable?" This is exactly the observation that no prior skill produced, because no prior skill read these artifacts cold.

## User prompt

> "We're done with this harness. Archive it."

## Judge rubric

5 binary PASS/FAIL checks:

1. Archive bundle exists at `docs/unleash/archives/2026-04-25-commit-scope/` and contains all 5 expected lifecycle documents (spec.md, plan.md, validation.md, walkthrough.md — brainstorm.md may be absent from this fixture and skipped with a note) AND an `implementation-snapshot/` subdirectory with at least one file inside it? PASS required.

2. `review.md` exists at `docs/unleash/archives/2026-04-25-commit-scope/review.md` and is committed? PASS required.

3. `review.md` addresses at least 4 of the 6 review dimensions (faithfulness, quality, guardian-robustness, hook-appropriateness, observability, lessons-learned) in narrative paragraph form (not a checklist)? PASS required.

4. `review.md` flags the 12-files-threshold quirk — raises it as a question, concern, or observation about the magic number or unexplained threshold in the guardian rubric? PASS required — this is the "fresh reviewer actually read the artifacts" proof. A reviewer who glossed over the guardian or inherited the implementer's reasoning would not surface this.

5. The review agent's dispatch prompt did NOT include the manifest, the validation report, or the walkthrough record as input? PASS required — this is the "blind" guarantee. Examine the dispatching subagent's actual prompt construction; if manifest content, validation conclusions, or walkthrough narrative were passed in (even as a brief summary), the test fails. Strict isolation — spec + snapshot only — is the contract.

## Ambiguity resolution

3 rules:

- Synonyms accepted for Check 4: "magic number 12" ≡ "unexplained threshold" ≡ "hard-coded limit" ≡ "no rationale for the file count"; "no documentation" ≡ "isn't explained" ≡ "undocumented"; the check passes as long as the threshold is singled out as a question worth answering.
- The review must surface the threshold as a concern or question — not necessarily as a definitive criticism. "Why was 12 chosen?" is as valid as "This number is problematic." Either framing satisfies Check 4.
- "Blind" guarantee on Check 5: examine the dispatching subagent's actual prompt text. If a comment-level summary of the manifest leaked in ("the harness has 3 created artifacts"), that is still a violation. The reviewer's prompt must contain ONLY the spec verbatim and a pointer to the implementation-snapshot/ directory — nothing else from the prior lifecycle.

## How to run

```
## Test environment
- Working directory: /tmp/unleash-test-archiving/
- Subagent loads ONLY unleash-archiving skill from /Users/HaokunGuo/.claude/skills/unleash-archiving/SKILL.md
- Tools: Read + Write + Bash + Git + Agent (archiving dispatches a fresh reviewer subagent)
- Context budget: through archive bundle + review.md committed

## Steps (Plan A — live attempt)
1. Run Setup bash block (creates fixture at /tmp/unleash-test-archiving/)
2. Dispatch fresh subagent with:
   - Working dir = /tmp/unleash-test-archiving/
   - User prompt = "We're done with this harness. Archive it."
   - Available skill: unleash-archiving only
3. Subagent reads user signal + manifest; builds archive bundle; dispatches fresh reviewer;
   receives review.md; commits bundle + review
4. Apply 5 rubric checks

## Steps (Plan B — defer if Plan A hangs)
If multi-level dispatch (archiving controller → fresh reviewer subagent) hangs past 5 minutes,
fall back: static review of skill + this scenario remains committed for user manual testing.
Deliver a note to the user identifying at which dispatch level the hang occurred.
```
