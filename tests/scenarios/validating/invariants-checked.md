# Scenario: Validating Catches Spec Invariant Violations

## Purpose

The `unleash:validating` skill must perform 8 harness-specific checks:
1. **Allowlist consistency** — phase write_allowlist matches guardian review scope
2. **Guardian alignment** — guardians can see all files their phase can modify
3. **Irreversibility gating** — irreversible operations protected by guardians or hooks
4. **Artifact closure** — all artifacts in plan dependency map have producer tasks + manifest entries
5. **Loop termination** — phase exit gates are testable and prevent infinite loops
6. **Decide determinism** — guardian decisions are consistent (no randomness)
7. **Spec coverage** — all phase machine steps appear in both spec and plan
8. **Code quality** — no syntax errors in phase configs, guardian prompts, or implementation

Generic code reviewers (without harness awareness) would not catch the 3 deliberate violations in this fixture: they lack the cross-file invariant inspection, plan/manifest cross-reference capability, and hook-vs-guardian decision audit logic. This scenario tests that validating produces a report naming each violation by name with file:line references, enabling harness operators to catch pitfalls from the knowledge base § Guardian Blind Spot, Orphan Artifact, Hook-Over-Guardian.

## Setup

Bash creating fixture at `/tmp/unleash-test-validating/`. Project + committed spec + committed plan + committed implementation containing the 3 deliberate violations:

```bash
set -e
rm -rf /tmp/unleash-test-validating
mkdir -p /tmp/unleash-test-validating/{src,tests,docs/unleash/{specs,plans},.unleash/{phases,guardians}}
cd /tmp/unleash-test-validating
git init -q
git config user.email "test@test.local"
git config user.name "test"

# Project stub
cat > README.md << 'EOF'
# Toy Project
EOF
cat > pyproject.toml << 'EOF'
[project]
name = "toy"
version = "0.1.0"
requires-python = ">=3.11"
EOF
cat > src/utils.py << 'EOF'
def add(a, b): return a + b
EOF
touch src/__init__.py tests/__init__.py

# Spec — declares 3 phases, guardian on Test+Impl, no hooks
cat > docs/unleash/specs/2026-04-25-toy-spec.md << 'EOF'
# Harness Spec: Toy Refactor
## Case Type
coding
## 5-Element Analysis
- Constraint Boundary: src/ and tests/
- Quantifiable Feedback: pytest passing; testing_mode: A (TDD)
- State Persistence: docs/unleash/
- Reversibility: git reset
- Autonomy: N/A
## Phase Machine
1. Test (Restricted-Write) — write allowlist: tests/
2. Impl (Restricted-Write) — write allowlist: src/ + tests/
3. Verify (Read-Only) — write allowlist: docs/unleash/verification.md
## Guardian Design
Per-phase guardian reviews diff against allowlist; rolls back on violation.
## Optional Hooks
None.
## Out of Scope
- pyproject.toml changes
EOF

# Plan — declares 3 phase configs + 2 guardians (Test, Impl) + walkthrough.md as artifact
cat > docs/unleash/plans/2026-04-25-toy-plan.md << 'EOF'
# Toy Implementation Plan
**Harness Case:** coding
**Guardian Role:** allowlist enforcement per phase
**Phase Summary:** Test → Impl → Verify
## Artifact Dependency Map
| Artifact | Producer | Consumer | Type |
|---|---|---|---|
| .unleash/phases/1-test.json | T1 | runtime | config |
| .unleash/phases/2-impl.json | T2 | runtime | config |
| .unleash/phases/3-verify.json | T3 | runtime | config |
| .unleash/guardians/test-guardian.md | T4 | runtime | prompt |
| .unleash/guardians/impl-guardian.md | T5 | runtime | prompt |
| .unleash/walkthroughs/2026-04-25-toy-first-run.md | T6 | unleash:walking-through | doc |
## Group A: Phase Machine
(tasks T1-T3 — phase configs)
## Group B: Runtime Guardian
(tasks T4-T5 — guardian prompts)
EOF

# === Phase configs (correct) ===
cat > .unleash/phases/1-test.json << 'EOF'
{"name": "Test", "primitive": "Restricted-Write", "write_allowlist": ["tests/**"], "exit_gate": "tests run red"}
EOF
cat > .unleash/phases/2-impl.json << 'EOF'
{"name": "Impl", "primitive": "Restricted-Write", "write_allowlist": ["src/**", "tests/**"], "exit_gate": "tests green"}
EOF
cat > .unleash/phases/3-verify.json << 'EOF'
{"name": "Verify", "primitive": "Read-Only", "write_allowlist": ["docs/unleash/verification.md"], "exit_gate": "verification.md committed"}
EOF

# === VIOLATION 1: Guardian Blind Spot ===
# Impl guardian's review_scope only checks tests/ but Impl phase allows src/ + tests/.
# A guardian that only sees tests/ has a blind spot for src/ writes.
cat > .unleash/guardians/test-guardian.md << 'EOF'
# Test Phase Guardian
## Role
Independent reviewer for Test phase commits.
## Instructions
Review the diff against the Test phase allowlist (tests/**).
## Decision Rubric
- PASS if all modified files match tests/**
- FAIL otherwise
## Output Format
verdict: PASS | FAIL
EOF

cat > .unleash/guardians/impl-guardian.md << 'EOF'
# Impl Phase Guardian
## Role
Independent reviewer for Impl phase commits.
## Instructions
Review the diff against the allowlist. Check only that files under tests/** were the only ones modified.
## Decision Rubric
- PASS if all modified files match tests/**
- FAIL otherwise
## Output Format
verdict: PASS | FAIL
EOF
# ^^ The Impl guardian only checks tests/** — Guardian Blind Spot for src/ writes.

# === VIOLATION 2: Orphan Artifact / Missing producer ===
# walkthrough.md is in the Dependency Map (line 6 of plan) as produced by T6,
# but no T6 task content exists in the plan AND the file itself is absent.

# === VIOLATION 3: Hook-Over-Guardian ===
# Spec said "Optional Hooks: None" (all reversible). Yet a pre-commit hook is present
# blocking edits to src/utils.py — a reversible operation that doesn't need hook protection.
mkdir -p .git/hooks
cat > .git/hooks/pre-commit << 'EOF'
#!/usr/bin/env bash
# Block edits to src/utils.py — Hook-Over-Guardian violation
if git diff --cached --name-only | grep -q "^src/utils.py$"; then
  echo "BLOCKED: src/utils.py is protected by hook"
  exit 1
fi
EOF
chmod +x .git/hooks/pre-commit

# === Manifest ===
cat > .unleash/manifest.json << 'EOF'
{
  "schema_version": "1",
  "harness_name": "toy",
  "unleash_version": "0.3.0",
  "installed_at": "2026-04-25T00:00:00Z",
  "created": [
    {"path": ".unleash/phases/1-test.json", "task": "T1", "commit_sha": "fixture"},
    {"path": ".unleash/phases/2-impl.json", "task": "T2", "commit_sha": "fixture"},
    {"path": ".unleash/phases/3-verify.json", "task": "T3", "commit_sha": "fixture"},
    {"path": ".unleash/guardians/test-guardian.md", "task": "T4", "commit_sha": "fixture"},
    {"path": ".unleash/guardians/impl-guardian.md", "task": "T5", "commit_sha": "fixture"}
  ],
  "modified": []
}
EOF
# Note: manifest does NOT list walkthrough.md, but plan's Dependency Map does — orphan artifact.

git add -A && git commit --no-verify -qm "fixture: toy harness with 3 deliberate violations"
# Note: --no-verify is intentional — the pre-commit hook IS one of the deliberate violations
# (Hook-Over-Guardian on a reversible operation) and would block this fixture commit otherwise.
echo "Fixture ready at /tmp/unleash-test-validating/"
```

## Baseline behavior (WITHOUT the skill)

A generic code reviewer performing static analysis would:
- ✗ Not cross-reference guardian review scope against phase write_allowlist
- ✗ Not detect that impl-guardian checks only tests/** while phase allows src/** writes
- ✗ Not correlate plan Dependency Map entries to manifest created array
- ✗ Not detect missing producer task (T6) for walkthrough.md
- ✗ Not audit hooks against spec reversibility declarations
- ✗ Not detect that .git/hooks/pre-commit blocks reversible edits

Result: **All 3 violations silently pass generic code review.**

## Expected behavior (WITH the skill)

Validating produces `docs/unleash/validation/2026-04-25-toy-validation.md` containing:

```
# Validation Report: Toy Harness

## Overall Verdict
❌ FAIL (3 violations found)

## Violations

### 1. Guardian Blind Spot — Impl Phase
**Severity:** CRITICAL
**Location:** .unleash/guardians/impl-guardian.md
**Problem:** Impl phase write_allowlist is ["src/**", "tests/**"] but impl-guardian review_scope only checks tests/**
**Evidence:**
  - Phase definition (.unleash/phases/2-impl.json): write_allowlist: ["src/**", "tests/**"]
  - Guardian definition (.unleash/guardians/impl-guardian.md): review_scope tests/**
**Implication:** Guardian cannot see src/ writes; implementation code changes bypass review.
**Remediation:** Expand impl-guardian review_scope to ["src/**", "tests/**"] or narrow phase allowlist.

### 2. Orphan Artifact — walkthrough.md Missing Producer
**Severity:** CRITICAL
**Location:** docs/unleash/plans/2026-04-25-toy-plan.md (Dependency Map row 6)
**Problem:** Artifact declared in plan Dependency Map (producer: T6) not in manifest created array; file absent.
**Evidence:**
  - Plan Dependency Map lists: .unleash/walkthroughs/2026-04-25-toy-first-run.md, producer T6
  - Manifest created array: no entry for walkthrough.md
  - File system: .unleash/walkthroughs/ does not exist or is empty
**Implication:** Artifact dependency untracked; walking-through skill will fail to find walkthrough.
**Remediation:** Remove row 6 from Dependency Map OR add T6 task definition to plan AND commit walkthrough.md.

### 3. Hook-Over-Guardian — Reversible Operation Protected by Hook
**Severity:** CRITICAL
**Location:** .git/hooks/pre-commit
**Problem:** Spec declares "Optional Hooks: None" (all operations reversible); hook blocks src/utils.py edits.
**Evidence:**
  - Spec (docs/unleash/specs/2026-04-25-toy-spec.md): "Optional Hooks: None"
  - Reversibility assessment: src/ edits reversible via "git reset" (per 5-Element Analysis)
  - Hook (.git/hooks/pre-commit): blocks src/utils.py commits
**Implication:** Guardian approval + git reset sufficient; hook adds redundant gating and violates spec reversibility contract.
**Remediation:** Remove .git/hooks/pre-commit OR update spec to declare hook as optional control.

## Checks Performed
- [x] Phase write_allowlist vs guardian review_scope alignment
- [x] Plan Dependency Map artifacts in manifest
- [x] Spec reversibility vs hook presence
- [x] Guardian decision rubric syntax
- [x] Phase config JSON validity
- [x] Exit gate testability
```

All 3 violations named explicitly with file:line references. Validation report has overall verdict: **FAIL**.

## User prompt

> "Implementation complete; please validate before walking-through."

## Judge rubric

5 binary PASS/FAIL checks:

1. **Validation artifact exists and is committed**
   - File: `docs/unleash/validation/2026-04-25-toy-validation.md`
   - Status: must be committed to git (not untracked)
   - PASS required

2. **Guardian Blind Spot violation detected**
   - Must name "Guardian Blind Spot" OR synonym: "guardian scope narrower than phase action surface", "review_scope mismatch", "guardian cannot see phase writes"
   - Must reference `.unleash/guardians/impl-guardian.md` with specific issue
   - PASS required

3. **Orphan Artifact violation detected**
   - Must name "Orphan Artifact" OR synonym: "missing producer", "dependency map orphan", "declared but not created", "plan/manifest mismatch"
   - Must reference walkthrough.md OR `.unleash/walkthroughs/2026-04-25-toy-first-run.md`
   - PASS required

4. **Hook-Over-Guardian violation detected**
   - Must name "Hook-Over-Guardian" OR synonym: "hook on reversible operation", "redundant hook protection", "hook violates spec reversibility contract"
   - Must reference `.git/hooks/pre-commit` with specific issue
   - PASS required

5. **Overall verdict is FAIL**
   - Must state verdict clearly: "FAIL" OR "❌ FAIL" OR "Status: FAIL"
   - Vague statements like "there were issues to address" without clear verdict status = FAIL
   - PASS required

## Ambiguity resolution

3 rules for acceptance:
- **Synonyms accepted:** "guardian doesn't see src/" ≡ "Guardian Blind Spot"; "missing producer" ≡ "Orphan Artifact"; "hook on reversible op" ≡ "Hook-Over-Guardian"
- **Vague flags fail:** Statements like "looks suspicious" or "consider reviewing impl-guardian.md" without naming the specific violation type → Checks 2/3/4 FAIL
- **Verdict must be explicit:** "FAIL" or "❌ FAIL" required; narrative like "there were issues" without a clear verdict word → Check 5 FAIL

## How to run

```
## Test environment
- Working directory: /tmp/unleash-test-validating/
- Subagent loads ONLY unleash-validating skill from /Users/HaokunGuo/.claude/skills/unleash-validating/SKILL.md
- Tools: Read + Write + Bash + Git (single-level dispatch — no nested subagents)
- Context budget: through validation.md being committed

## Steps
1. Run Setup bash block (creates fixture at /tmp/unleash-test-validating/)
2. Dispatch fresh subagent with:
   - Working dir = /tmp/unleash-test-validating/
   - User prompt = "Implementation complete; please validate before walking-through."
   - Available skill: unleash-validating only
3. Subagent reads spec/plan/manifest/implementation files; produces validation.md; commits
4. Apply 5 rubric checks
```

## Verification

After running the scenario, execute:

```bash
# Check section count
grep -c "^## " /Users/HaokunGuo/unleash/tests/scenarios/validating/invariants-checked.md

# Check all 3 violation names appear
grep -n "Guardian Blind Spot\|Orphan Artifact\|Hook-Over-Guardian" /Users/HaokunGuo/unleash/tests/scenarios/validating/invariants-checked.md

# Check line count
wc -l /Users/HaokunGuo/unleash/tests/scenarios/validating/invariants-checked.md

# Check file is untracked (not committed)
cd /Users/HaokunGuo/unleash && git status | grep invariants-checked.md
```

Expected results:
- Section count: **9+** (all required sections present)
- Violation names: **3 matches** (Guardian Blind Spot, Orphan Artifact, Hook-Over-Guardian each appear at least once)
- Line count: **≥160** lines
- Git status: **??** (file is untracked, not committed)
