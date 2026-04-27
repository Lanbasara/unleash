# Scenario: Implementing Pastes Full Task Text

## Purpose

The unleash:implementing skill must NEVER tell a subagent to "read the plan file" or reference tasks by line numbers. Instead, when dispatching a subagent to execute a task, the controller must paste the task's complete text AND all relevant scene-setting context (Harness Goal, Harness Case, Guardian Role, upstream/downstream artifacts) directly into the subagent prompt. Batching multiple tasks into a single dispatch is forbidden. Additionally, the controller must avoid deep review after a task completes (code quality reviews, spec-compliance validation, and test result analysis are deferred to unleash-validating in Plan 3).

## Setup

```bash
set -e
rm -rf /tmp/unleash-test-implementing
mkdir -p /tmp/unleash-test-implementing/docs/unleash/plans
cd /tmp/unleash-test-implementing

# Project stub (minimal)
cat > README.md << 'EOF'
# Tiny Logger
One-function logging utility.
EOF

cat > pyproject.toml << 'EOF'
[project]
name = "tiny-logger"
version = "0.1.0"
requires-python = ">=3.11"
EOF

mkdir -p logger tests
touch logger/__init__.py tests/__init__.py

# Committed plan.md (produced notionally by unleash-planning)
cat > docs/unleash/plans/2026-04-25-logger-refactor-plan.md << 'PLAN_EOF'
# Logger Refactor Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use unleash:implementing to execute this plan task-by-task.

**Goal:** Replace logger.log() stub with a tested implementation that writes timestamped lines to stderr.
**Architecture:** Add logger/core.py with log() function; add tests/test_core.py with 3 tests for basic, edge (empty string), and unicode cases.
**Harness Case:** coding
**Guardian Role:** Check that each phase's write diff stays inside the declared allowlist; trigger git reset on violation.
**Phase Summary:** Test → Impl → Verify

**Reference spec:** /tmp/unleash-test-implementing/docs/unleash/specs/logger-refactor-spec.md @ sha abc123 (notional)

---

## Artifact Dependency Map

| Artifact | Producer (Task) | Consumer | Type |
|---|---|---|---|
| tests/test_core.py | T1 | runtime pytest | test |
| logger/core.py | T2 | runtime, tests | source |
| docs/unleash/verification.md | T3 | user | doc |

---

## Group A: Phase Machine

### Task 1: Write failing tests for log()

**Files:**
- Create: `tests/test_core.py`
- Artifact Type: `test`
- Produces: `tests/test_core.py`
- Consumes: spec (notional)

- [ ] **Step 1: Write the test file**

\`\`\`python
import io
import sys
from logger.core import log

def test_log_basic(capsys):
    log("hello")
    captured = capsys.readouterr()
    assert "hello" in captured.err
    assert captured.out == ""

def test_log_empty(capsys):
    log("")
    captured = capsys.readouterr()
    assert captured.err.endswith("\n")

def test_log_unicode(capsys):
    log("héllo 世界")
    captured = capsys.readouterr()
    assert "héllo 世界" in captured.err
\`\`\`

- [ ] **Step 2: Run tests to confirm they fail**

Run: \`pytest tests/test_core.py -v\`
Expected: all 3 fail with ImportError

- [ ] **Step 3: Commit**

\`\`\`bash
git add tests/test_core.py && git commit -m "test: add tests for logger.log (failing)"
\`\`\`

### Task 2: Implement log()

**Files:**
- Create: `logger/core.py`
- Artifact Type: `source`
- Produces: `logger/core.py`
- Consumes: `tests/test_core.py` (from T1)

- [ ] **Step 1: Write minimal implementation**

\`\`\`python
import sys
from datetime import datetime

def log(message: str) -> None:
    ts = datetime.utcnow().isoformat(timespec="seconds")
    sys.stderr.write(f"{ts} {message}\n")
\`\`\`

- [ ] **Step 2: Run tests to confirm they pass**

Run: \`pytest tests/test_core.py -v\`
Expected: 3 passed

- [ ] **Step 3: Commit**

\`\`\`bash
git add logger/core.py && git commit -m "feat: logger.log writes timestamped lines to stderr"
\`\`\`
PLAN_EOF

git init -q
git config user.email "test@test.local"
git config user.name "test"
git add -A
git commit -q -m "initial project + plan"

echo "Fixture ready at /tmp/unleash-test-implementing/"
```

## Baseline behavior (WITHOUT the skill)

A generic controller given a plan file would tell the subagent something like: "read the plan at docs/unleash/plans/2026-04-25-logger-refactor-plan.md and implement Task 1". This approach fails because the subagent will load the entire plan document into its context, exposing all future tasks, artifact lists, and implementation details unrelated to Task 1. This introduces noise, cognitive overhead, and cross-task contamination — the subagent may accidentally reference Task 2's implementation while writing Task 1's tests, or make decisions based on the full architecture rather than the isolated task scope.

## Expected behavior (WITH the skill)

- **Read once:** The controller reads the plan.md file once at startup and extracts all tasks, dependencies, and scene-setting into memory (not repeatedly re-reading).
- **Dispatch with full text:** For each task, the controller dispatches a fresh subagent with the **complete task text pasted verbatim into the prompt**. The subagent sees the task's name, files, steps, code blocks, and artifacts — exactly as written in the plan — not a reference like "see line 42 in the plan file" or "read Task 1 from the plan".
- **Scene-setting only:** The subagent prompt includes context needed for that task alone: the Harness Goal, Harness Case, Guardian Role, and the upstream/downstream artifacts relevant to that specific task. It does NOT include the text of other tasks, alternate implementation paths, or unrelated artifact definitions.

## User prompt

> Plan committed at docs/unleash/plans/2026-04-25-logger-refactor-plan.md. Start implementing.

## Judge rubric

Five binary PASS/FAIL checks (all PASS required):

1. **Read plan.md first:** Controller's first action is to Read the plan.md file (not immediately dispatch to a subagent without reading). PASS required.

2. **Full task text pasted:** When dispatching the subagent for Task 1, the subagent prompt contains the complete code blocks from Task 1 verbatim, specifically including the three test function definitions: `def test_log_basic(capsys):`, `def test_log_empty(capsys):`, and `def test_log_unicode(capsys):`. The prompt does NOT use references like "see Task 1 in the plan" or "read the task definition at line N". PASS required.

3. **Scene-setting included:** Subagent prompt includes scene-setting context for Task 1: at minimum the Harness Case ("coding") and Guardian Role ("Check that each phase's write diff stays inside the declared allowlist; trigger git reset on violation"). PASS required.

4. **No cross-task leakage:** Subagent prompt does NOT contain Task 2's `logger/core.py` implementation code or other tasks' code blocks. Even a summary like "Task 2 will implement the core module" counts as leakage and fails this check. PASS required.

5. **No deep review after DONE:** After Task 1 completes (subagent returns), the controller does NOT perform a deep review: no spec-compliance review, no code-quality review, no test result analysis, no "let me verify the implementation matches the spec" logic. The controller may ask the subagent for a 1-sentence status update as it finishes, but does not re-review the work. PASS required.

## Ambiguity resolution

Three edge-case rules to clarify the judge rubric:

- **Summaries count as leakage:** If the controller pastes Task 1 AND an "executive summary" of all other tasks, or "Task 2 will implement X and Task 3 will do Y", Check 4 FAILS. The discipline is zero cross-task information leakage; even summaries violate this.

- **Self-check is allowed:** If the controller asks the subagent to verify its own tests pass as a light sanity check (e.g., "run pytest before committing"), that's within the subagent's own task scope and does not count as deep review. Check 5 still passes.

- **Status update is not review:** If the controller asks the subagent for a 1-sentence status update (e.g., "did Task 1 complete?") and the subagent replies "tests written and committed", the controller then moves to Task 2 without analyzing the tests or re-running them — that's not a deep review. Check 5 passes.

## How to run

### Test environment

- **Working directory:** /tmp/unleash-test-implementing/
- **Subagent skill:** Loads ONLY unleash-implementing from /Users/HaokunGuo/.claude/skills/unleash-implementing/SKILL.md
- **Subagent tools:** Read, Write, Bash, Git, Agent (Agent tool is required because implementing dispatches sub-subagents for tasks)
- **Context budget:** Collect through Task 1 dispatch completion (Task 2 need not run for this scenario to pass)

### Steps

1. Run the **Setup** bash block above to create the fixture.
2. Dispatch a fresh subagent with:
   - Working directory: `/tmp/unleash-test-implementing/`
   - Skill: unleash-implementing
   - User prompt (verbatim): "Plan committed at docs/unleash/plans/2026-04-25-logger-refactor-plan.md. Start implementing."
3. Capture the subagent's action log:
   - Does it Read the plan.md file first?
   - What is the exact prompt it passes to its Task 1 sub-subagent (via Agent tool)?
4. Apply the 5 judge rubric checks to the captured logs:
   - Check 1: Was plan.md Read before any dispatch?
   - Check 2: Does Task 1 subagent prompt contain test function defs verbatim?
   - Check 3: Does it include Harness Case + Guardian Role?
   - Check 4: Does it exclude Task 2 code?
   - Check 5: Does controller move to Task 2 without deep review?
5. Record PASS/FAIL for each check.

## Verification

```bash
# Confirm file exists and has all sections
grep -c "^## " /Users/HaokunGuo/unleash/tests/scenarios/implementing/subagent-dispatch.md

# Confirm key phrase appears
grep -n "full task text" /Users/HaokunGuo/unleash/tests/scenarios/implementing/subagent-dispatch.md

# Confirm user prompt is present
grep -n "Plan committed at" /Users/HaokunGuo/unleash/tests/scenarios/implementing/subagent-dispatch.md

# Check line count
wc -l /Users/HaokunGuo/unleash/tests/scenarios/implementing/subagent-dispatch.md

# Confirm file is untracked
cd /Users/HaokunGuo/unleash && git status | grep implementing
```

Expected: at least 9 `##` sections; "full task text" appears multiple times; "Plan committed at" present in user prompt section; approximately 250+ lines; file shown as untracked.

## Bash syntax validation

Run before committing:

```bash
bash -n /Users/HaokunGuo/unleash/tests/scenarios/implementing/subagent-dispatch.md
```

(This validates only the markdown file itself, not the embedded bash blocks.)
