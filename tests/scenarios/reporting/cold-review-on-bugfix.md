# Scenario: Cold Review On B-Layer-Only Bug Fix

## Purpose

Reporting is the B-layer-only end-of-life skill. It must (a) refuse to run if manifest exists (yields to archiving), (b) filter the diff by git pathspec only (NOT by commit message grep), (c) dispatch a fresh reviewer with strict isolation (no plan/brainstorm/commit-messages), (d) produce a 300-600 word 4-dimension report with open questions section.

## Setup

Bash creating fixture at `/tmp/unleash-test-reporting/`. Project has a fictional logger with a bug; user did brainstorm/debate/plan/implement workflow producing B-layer artifacts only (no `.unleash/` runtime); a few commits between spec and HEAD include the pathspec-vs-grep edge case.

```bash
set -e
rm -rf /tmp/unleash-test-reporting
mkdir -p /tmp/unleash-test-reporting/{src,tests,docs/unleash/{brainstorm,specs,plans}}
cd /tmp/unleash-test-reporting
git init -q
git config user.email "test@test.local"
git config user.name "test"

# Original buggy code
cat > README.md << 'EOF'
# Logger
A small structured-logging utility. log_event() drops the message.
EOF
cat > pyproject.toml << 'EOF'
[project]
name = "logger"
version = "0.1.0"
requires-python = ">=3.11"
EOF
mkdir -p src tests
touch src/__init__.py tests/__init__.py
cat > src/logger.py << 'EOF'
import sys

def log_event(event_type: str, message: str) -> None:
    # BUG: writes only event_type, drops message
    sys.stderr.write(f"[{event_type}]\n")
EOF
git add -A && git commit -qm "initial buggy logger"
INITIAL_SHA=$(git rev-parse HEAD)

# Brainstorm + spec + plan (Unleash B-layer dialogue, all committed in docs/unleash/)
cat > docs/unleash/brainstorm/2026-04-25-logger-fix.md << 'EOF'
# Brainstorm: Logger Fix
## Project Context (Phase A Summary)
src/logger.py has log_event() but message is dropped on write.
## Harness Intent
Fix log_event to actually emit the message.
## Case-Type Hypothesis
Coding (single fix, no runtime harness needed).
## 5-Element Sketch
- Constraint: src/logger.py + tests/
- Feedback: pytest manual ack
- State: docs/unleash/
- Reversibility: git revert
- Autonomy: N/A
EOF
git add -A && git commit -qm "brainstorm: logger fix"

cat > docs/unleash/specs/2026-04-25-logger-fix-spec.md << 'EOF'
# Harness Spec: Logger Fix
## Case Type
coding (B-layer only — no runtime harness)
## 5-Element Analysis
- Constraint Boundary: src/logger.py + tests/test_logger.py
- Quantifiable Feedback: pytest passes; testing_mode: A (TDD)
- State Persistence: docs/unleash/ for spec/plan/report
- Reversibility: git revert is sufficient
- Autonomy: N/A — single fix, human in loop
## Phase Machine
1. Test (write tests/test_logger.py with failing case for log_event)
2. Impl (fix src/logger.py — log_event must emit both event_type AND message)
3. Verify (manual: pytest passes)
## Out of Scope
- pyproject.toml, README, anything outside src/ + tests/
EOF
git add -A && git commit -qm "spec: logger fix scope and 5-element analysis"
SPEC_SHA=$(git rev-parse HEAD)

cat > docs/unleash/plans/2026-04-25-logger-fix-plan.md << 'EOF'
# Plan: Logger Fix
## Group A: Phase Machine
T1: tests/test_logger.py — failing test for log_event message emission
T2: src/logger.py — fix log_event to include message in stderr write
EOF
git add -A && git commit -qm "plan: logger fix tasks"

# Implementation commits (mix of code and B-layer)
# Commit X: failing test
cat > tests/test_logger.py << 'EOF'
import sys
from src.logger import log_event

def test_log_event_includes_message(capsys):
    log_event("info", "hello world")
    captured = capsys.readouterr()
    assert "hello world" in captured.err
    assert "[info]" in captured.err
EOF
git add -A && git commit -qm "test: add failing test for log_event message emission"

# Commit Y: implementation fix — INTENTIONAL TEST for pathspec-vs-grep:
# This commit message MENTIONS "docs/unleash/specs" but only touches src/!
cat > src/logger.py << 'EOF'
import sys

def log_event(event_type: str, message: str) -> None:
    sys.stderr.write(f"[{event_type}] {message}\n")
EOF
git add src/logger.py && git commit -qm "feat: fix log_event per docs/unleash/specs/2026-04-25-logger-fix-spec.md (Section: Phase Machine T2)"

# Commit Z: a small manual edit to spec.md (post-implementation thought)
cat >> docs/unleash/specs/2026-04-25-logger-fix-spec.md << 'EOF'

## Manual verification (post-implementation note)
pytest passes locally on Python 3.11.5
EOF
git add docs/unleash/specs/2026-04-25-logger-fix-spec.md && git commit -qm "spec: add post-impl verification note"

echo "Fixture ready at /tmp/unleash-test-reporting/"
echo "Spec SHA: $SPEC_SHA"
echo ""
echo "Critical edge cases in this fixture:"
echo "  - Commit Y mentions 'docs/unleash/specs/...' in its MESSAGE but only touches src/logger.py"
echo "    → pathspec correctly INCLUDES this in the diff (filter is by file path, not message)"
echo "  - Commit Z touches docs/unleash/specs/... in its FILES"
echo "    → pathspec correctly EXCLUDES this from the diff"
```

## Baseline behavior (WITHOUT the skill)

A user without reporting has no end-of-life record for B-layer-only workflows. Without a skill enforcing "fresh reviewer with strict isolation", any ad-hoc summary they write is biased by their own implementation reasoning.

## Expected behavior (WITH the skill)

Reporting:
1. Reads spec.md, identifies its first commit SHA
2. Computes filtered aggregate diff using `git diff <spec-sha>..HEAD -- ':!docs/unleash/'` — pathspec only
3. Prints transparent filter report listing included files (e.g., `src/logger.py`, `tests/test_logger.py`) and excluded files (e.g., `docs/unleash/specs/2026-04-25-logger-fix-spec.md` from Commit Z)
4. **Critically: src/logger.py from Commit Y IS included** even though the commit message mentions "docs/unleash/specs" — pathspec filters by file path, not by message text
5. Dispatches fresh reviewer with ONLY: spec.md verbatim + aggregate diff + user's "pytest passing" notes
6. Saves report at `docs/unleash/reports/2026-04-25-logger-fix-report.md` covering 4 dimensions

## User prompt

> "Done with the logger fix. Run reporting. Verification: pytest passing on 3.11.5."

## Judge rubric

5 binary PASS/FAIL checks:

1. report.md exists at `docs/unleash/reports/2026-04-25-logger-fix-report.md` and is git-committed? PASS required
2. report.md addresses all 4 dimensions (faithfulness, quality, observability, lessons-learned) AND has an Open Questions section? PASS required
3. The transparent filter report (controller's output) lists `src/logger.py` and `tests/test_logger.py` as included AND lists docs/unleash/* files as excluded — specifically: even Commit Y (whose message mentions "docs/unleash/specs/...") contributed src/logger.py to the included list? PASS required (this is the pathspec-vs-grep test)
4. The reviewer's dispatch prompt did NOT contain plan.md content, brainstorm.md content, or any commit messages? PASS required (the cold-review isolation guarantee)
5. The user's verification notes ("pytest passing on 3.11.5") appear in the report header AND/OR are referenced in the reviewer's faithfulness paragraph? PASS required

## Ambiguity resolution

3 rules:

- **Pathspec test (Check 3):** verify by checking the controller's filter report output, not by checking which commits are in the diff. The diff for Commit Y is included (src/logger.py changes); the diff for Commit Z is excluded (only docs/unleash/* changes). If filter report wrongly shows Commit Y as excluded because of its message, FAIL.
- **Cold-review isolation (Check 4):** examine the actual subagent dispatch prompt. If even a "summary of plan" or any commit message strings appear in the prompt body, FAIL. The reviewer should see only spec verbatim + diff verbatim + user verification one-liner.
- **Manifest-conflict path:** if running this scenario but `.unleash/manifest.json` had been added to the fixture, reporting must STOP in Phase A with the redirect-to-archiving message. (Not part of this scenario's main rubric, but a sister test path.)

## How to run

```
## Test environment
- Working directory: /tmp/unleash-test-reporting/
- Subagent loads ONLY unleash-reporting skill from /Users/HaokunGuo/.claude/skills/unleash-reporting/SKILL.md
- Tools: Read + Write + Bash + Git + Agent (reporting dispatches a fresh reviewer)
- Multi-level dispatch (controller → reviewer subagent), but reviewer is a single-level skill so the chain is shallow

## Steps (Plan A — live test)
1. Run Setup
2. Dispatch fresh subagent with working dir = fixture, user prompt verbatim
3. Subagent runs Phase A-D; produces report.md; commits
4. Capture: report.md content + filter report output + reviewer's dispatch prompt
5. Apply 5 rubric checks
```
