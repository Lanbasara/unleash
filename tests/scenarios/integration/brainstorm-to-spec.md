# Scenario: Brainstorm-to-Spec Chain

## Purpose

Validate the inter-skill contract between `unleash:brainstorming` (produces `brainstorm.md`) and `unleash:debating` (consumes it, produces `spec.md`). Both files must be git-committed. Debating must be able to reference the brainstorm's commit SHA, proving that the chain does not silently drift and that output formats remain stable across the two skills' boundaries.

## Setup

Bash commands that create a fresh throwaway project at `/tmp/unleash-test-integration/`:

```bash
set -e
rm -rf /tmp/unleash-test-integration
mkdir -p /tmp/unleash-test-integration/sort
cd /tmp/unleash-test-integration

cat > README.md << 'EOF'
# Sorting Module
Small library of sorting algorithms. Refactor target.
EOF

cat > pyproject.toml << 'EOF'
[project]
name = "sort-lib"
version = "0.1.0"
requires-python = ">=3.11"
EOF

cat > sort/__init__.py << 'EOF'
EOF

cat > sort/merge.py << 'EOF'
def merge_sort(items):
    if len(items) <= 1:
        return items
    mid = len(items) // 2
    return merge_sort(items[:mid]) + merge_sort(items[mid:])  # intentionally broken: no merge step
EOF

git init -q
git config user.email "test@test.local"
git config user.name "test"
git add -A
git commit -q -m "initial sorting module"

echo "Fixture ready at /tmp/unleash-test-integration/"
```

## User Prompts (Sequential)

### Prompt 1 (to brainstorming skill):

```
I want to harness a refactor of my sorting module. I know `merge_sort` is broken — missing the merge step. Help me design a harness for fixing it.
```

### Prompt 2 (to debating skill, after brainstorm is committed):

```
Brainstorm committed. Let's debate.
```

Between Prompts 2 and 3, the test harness simulates a short debate: the test harness supplies three predetermined answers to debating's questions (e.g., "A", "use the existing test in tests/", "keep it simple"). The specific answers are not load-bearing—what matters is that debating consumes them and narrows the gap map.

### Prompt 3 (to debating skill, after 3 debate turns):

```
I think we're aligned. Please draft the spec.
```

## Expected Flow

Step-by-step breakdown of what should happen:

1. **Brainstorming Phase A**: Brainstorming skill reads README.md, pyproject.toml, git log, and sort/merge.py. It identifies the broken merge step as the core refactoring target.

2. **Brainstorming Grounded Dialogue (5–8 turns)**: For this integration test, the test harness can short-circuit with simulated user answers. The point is to produce a `brainstorm.md` with all six required sections: Project Context, Harness Intent, Case-Type Hypothesis, 5-Element Applicability Sketch, Candidate Starter Patterns, and Open Questions for Debating.

3. **Brainstorming Commit**: Brainstorming commits the file at `docs/unleash/brainstorm/<YYYY-MM-DD>-sorting-refactor.md`. The filename pattern includes a date prefix (ISO 8601 format; may be today's date).

4. **Debating Initialization**: User invokes debating skill. Debating reads the brainstorm file. Its first response acknowledges the brainstorm's commit SHA explicitly, proving it can locate and reference the prior work.

5. **Debating Phase A + Phase B**: Debating re-reads project context and knowledge doc. It runs Phase B internally to construct a gap map.

6. **Debating Phase C (Externalize Gap Map)**: Debating's first user-facing message externalizes the gap map, structuring the debate around identified gaps.

7. **Debating Dialogue (3 Challenges)**: Debating issues three challenges (one at a time). For each, the simulated user provides a predetermined answer, advancing the gap-closure process.

8. **Debating Phase D (Convergence)**: User says "draft the spec". Debating enters convergence, confirms gap map closure, and drafts `docs/unleash/specs/<YYYY-MM-DD>-sorting-refactor-spec.md` with all six required sections: case_type, five_element_analysis, phase_machine, guardian_design, optional_hooks, and out_of_scope.

9. **Spec Commit**: Spec is committed to git.

## Judge Rubric

Four binary PASS/FAIL checks:

1. **Brainstorm Artifact (PASS REQUIRED)**: Does `docs/unleash/brainstorm/<date>-sorting-refactor.md` exist after brainstorming completes? Does it contain all six required sections (Project Context, Harness Intent, Case-Type Hypothesis, 5-Element Applicability Sketch, Candidate Starter Patterns, Open Questions for Debating)?

2. **Spec Artifact (PASS REQUIRED)**: Does `docs/unleash/specs/<date>-sorting-refactor-spec.md` exist after debating completes? Does it contain all six required sections (case_type, five_element_analysis, phase_machine, guardian_design, optional_hooks, out_of_scope)?

3. **Commit SHA Reference (PASS REQUIRED)**: Did debating's first user-facing message reference the brainstorm's git commit SHA explicitly (e.g., "I reviewed your brainstorm at commit abc1234…")?

4. **Git Commits Exist (PASS REQUIRED)**: Are BOTH files git-committed (not just on disk)? Run `git log --all` in the test directory and confirm commits exist for each file. Check that the working tree is clean or only contains expected untracked artifacts.

## Ambiguity Resolution

Brief rules for edge cases:

- **Brainstorm Path Mismatch**: If brainstorming produces a file at a slightly different path (e.g., `docs/unleash/brainstorm/sorting-refactor.md` without date prefix), Check 1 FAILS. The date-prefixed convention is part of the inter-skill contract.

- **Spec Section Names Mismatch**: If debating's spec uses different section names (e.g., `## Five Elements` instead of `## Five Element Analysis`), Check 2 FAILS. Section names are part of the downstream planning contract.

- **Flexible Debate Turn Count**: "Three debate turns" in the flow is illustrative. If debating finishes in 2 turns or requires 5, that is acceptable as long as the final spec has all six sections.

- **Commit Message Content**: Commit messages need not follow a specific format. The check is only that `git log --all` shows commits adding each file.

## How to Run

**Test Environment**:
- Working directory: `/tmp/unleash-test-integration/`
- Both skills loaded from `/Users/HaokunGuo/unleash/skills/brainstorming/SKILL.md` and `/Users/HaokunGuo/unleash/skills/debating/SKILL.md`
- Knowledge doc available at `/Users/HaokunGuo/unleash/references/unleash-knowledge.md`
- Read, Write, Bash, and Git tools available (Write is needed for the skills to produce artifacts)

**Test Steps**:

1. Execute the `## Setup` bash commands to create the fixture at `/tmp/unleash-test-integration/`.
2. Dispatch a fresh subagent with brainstorming skill loaded and issue Prompt 1. Simulate user replies until brainstorming drafts and commits the brainstorm.md.
3. Dispatch another fresh subagent (or continue the same if plausible) with debating skill loaded and issue Prompt 2. Simulate three predetermined user replies to advance the debate until three rounds of challenges complete.
4. Issue Prompt 3; collect the final spec drafted and committed by debating.
5. Apply the four judge rubric checks against the filesystem state of `/tmp/unleash-test-integration/`.
6. Record PASS/FAIL with relevant transcript excerpts.

## Verification Commands

Run these after the scenario completes to verify the output:

```bash
# Count markdown section headers (expect 8+)
grep -c "^## " /Users/HaokunGuo/unleash/tests/scenarios/integration/brainstorm-to-spec.md

# Verify domain-specific references appear throughout
grep -n "sorting-refactor\|merge_sort" /Users/HaokunGuo/unleash/tests/scenarios/integration/brainstorm-to-spec.md

# Verify commit SHA requirement is documented
grep -n "commit SHA" /Users/HaokunGuo/unleash/tests/scenarios/integration/brainstorm-to-spec.md

# Check line count (expect ~140+ lines)
wc -l /Users/HaokunGuo/unleash/tests/scenarios/integration/brainstorm-to-spec.md

# Verify file is not yet committed
cd /Users/HaokunGuo/unleash && git status | grep integration
```

**Expected Results**:
- 8+ `##` sections
- "sorting-refactor" and "merge_sort" appear multiple times throughout the document
- "commit SHA" appears explicitly in the judge rubric section
- Line count approximately 140+ lines
- File appears as untracked in `git status`
