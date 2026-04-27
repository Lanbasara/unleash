# Scenario: Spec-to-Harness End-to-End

## Purpose

Validate that unleash:planning's output is correctly consumed by unleash:implementing AND that the produced harness artifacts actually match the plan's Artifact Dependency Map. This is the first end-to-end test that the build half of the chain is coherent.

## Setup

Bash fixture creating a project with committed brainstorm + committed spec (simulating post-debating state):

```bash
set -e
rm -rf /tmp/unleash-test-e2e
mkdir -p /tmp/unleash-test-e2e/{docs/unleash/brainstorm,docs/unleash/specs,sort,tests}
cd /tmp/unleash-test-e2e

cat > README.md << 'EOF'
# Sorter
One-function merge sort library.
EOF

cat > pyproject.toml << 'EOF'
[project]
name = "sorter"
version = "0.1.0"
requires-python = ">=3.11"
EOF

cat > sort/__init__.py << 'EOF'
EOF

cat > sort/merge.py << 'EOF'
def merge_sort(items):
    if len(items) <= 1:
        return items
    # BUG: missing merge step
    mid = len(items) // 2
    return merge_sort(items[:mid]) + merge_sort(items[mid:])
EOF

cat > docs/unleash/brainstorm/2026-04-25-sorter-refactor.md << 'EOF'
# Brainstorm Notes: Sorter Refactor
## Project Context
FastAPI-free Python project with broken merge_sort (missing merge step).
## Harness Intent
Fix merge_sort with discipline (tests first, then implement).
## Case-Type Hypothesis
Coding.
## 5-Element Applicability Sketch
- Constraint: sort/merge.py + tests/
- Feedback: pytest passing
- State: docs/unleash/
- Reversibility: git reset
- Autonomy: N/A
## Candidate Starter Patterns
Coding Pipeline.
## Open Questions
(none)
EOF

cat > docs/unleash/specs/2026-04-25-sorter-refactor-spec.md << 'EOF'
# Harness Spec: Sorter Refactor
## Case Type
coding
## 5-Element Analysis
- Constraint Boundary: `sort/merge.py` + `tests/test_merge.py`
- Quantifiable Feedback: pytest passes on 4 cases (empty, single, sorted, reverse)
- State Persistence: docs/unleash/
- Reversibility: git reset --hard HEAD~1 per phase
- Autonomy: N/A — human in loop
## Phase Machine
1. Test (Restricted-Write) — write allowlist: tests/test_merge.py; exit: tests red
2. Impl (Restricted-Write) — write allowlist: sort/merge.py + tests/; exit: tests green
3. Verify (Read-Only) — write allowlist: docs/unleash/verification.md only; exit: verification.md committed
## Guardian Design
Per-phase guardian reviews git diff; triggers git reset on allowlist violation.
## Optional Hooks
None.
## Out of Scope
- pyproject.toml changes
- Files outside sort/ or tests/
EOF

git init -q
git config user.email "test@test.local"
git config user.name "test"
git add -A
git commit -q -m "initial project + brainstorm + spec"

echo "Fixture ready at /tmp/unleash-test-e2e/"
```

## User prompts (sequential)

- Prompt 1 (to unleash:planning): `"Spec committed. Write the plan."`
- Simulated user approves the plan when prompted
- Prompt 2 (to unleash:implementing): `"Plan committed. Start implementing."`

## Expected flow

- Planning reads spec, produces plan.md at `docs/unleash/plans/2026-04-25-sorter-refactor-plan.md` with Artifact Dependency Map + task groups
- User approves; plan is committed
- Implementing reads plan, dispatches subagents for each task in order
- Subagents create `tests/test_merge.py`, modify `sort/merge.py`, create `docs/unleash/verification.md` — each with its own commit
- Implementing reports DONE with commit SHAs

## Judge rubric

6 binary PASS/FAIL checks:

1. plan.md exists and is committed with the required structure (header, Dependency Map, Task Groups, zero placeholders)
2. plan.md's Artifact Dependency Map lists `tests/test_merge.py` and `sort/merge.py` as producers (among others)
3. After implementing, `tests/test_merge.py` exists with at least 4 test functions (empty, single, sorted, reverse)
4. After implementing, `sort/merge.py` has a correct merge step (`pytest tests/ -v` passes on all 4 tests)
5. Each phase's commits stay inside the phase's allowlist (Test phase touches only tests/; Impl phase touches sort/ + tests/; Verify phase touches only docs/unleash/verification.md)
6. `docs/unleash/verification.md` exists and is committed

## Ambiguity resolution

3 edge-case rules:

- If implementing produces test files that aren't in the plan's Artifact Map, Check 5 FAILS (scope creep).
- If pytest passes but one test is a no-op (e.g., `assert True`), Check 4 FAILS — tests must be meaningful.
- If commits show wrong file paths for a phase, Check 5 FAILS.

## How to run

### Test environment
- Working directory: /tmp/unleash-test-e2e/
- Both unleash-planning and unleash-implementing skills loaded (from user-level install after sync)
- Read + Write + Bash + Git + Agent tools available (implementing needs Agent to dispatch sub-subagents)
- Context budget: through end-to-end completion (Verify phase commit)

### Steps
1. Run Setup
2. Dispatch subagent 1 (unleash-planning) with Prompt 1, collect plan.md + commit
3. Dispatch subagent 2 (unleash-implementing) with Prompt 2, collect all phase commits
4. Apply 6 judge rubric checks against filesystem + git log + pytest
5. If all PASS, cleanup; if any FAIL, leave fixture and report
