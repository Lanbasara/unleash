# Scenario: Gap-Driven Debating

## Purpose

The core behavioral claim of `unleash:debating` is that it must READ the brainstorm notes, build a cognitive gap map from the actual notes content, and issue challenges grounded in specific passages from those notes. It must NOT ask 4 pre-scripted questions from a fixed challenge template (reversibility, feedback sharpness, state leaks, 3am scenario) regardless of what's in the brainstorm notes. A skill that generates the same four categories of challenges for every brainstorm, without regard to the actual content and gaps present in the notes, fails this scenario.

## Setup

The fixture below creates a test project with a deliberately vague brainstorm notes file that contains specific vaguenesses, unstated assumptions, and one concrete claim. The skill must be able to identify and challenge the actual gaps in this particular brainstorm, not fall back on generic question templates.

```bash
set -e
rm -rf /tmp/unleash-test-gap-driven
mkdir -p /tmp/unleash-test-gap-driven/docs/unleash/brainstorm
mkdir -p /tmp/unleash-test-gap-driven/app/auth
cd /tmp/unleash-test-gap-driven

# Minimal project stub so that context reads have something to find
cat > README.md << 'EOF'
# Auth Service
FastAPI-based authentication service.
EOF

cat > pyproject.toml << 'EOF'
[project]
name = "auth-service"
version = "0.1.0"
requires-python = ">=3.11"
dependencies = ["fastapi>=0.100"]
EOF

cat > app/auth/__init__.py << 'EOF'
EOF

cat > app/auth/login.py << 'EOF'
def login(username: str, password: str) -> bool:
    return True  # stub
EOF

# Deliberately vague brainstorm with some gaps, some assumptions,
# and one concrete claim that the skill should NOT challenge.
cat > docs/unleash/brainstorm/2026-04-24-auth-refactor.md << 'EOF'
# Brainstorm Notes: Auth Refactor Harness

## Project Context (Phase A Summary)
Read README.md — this is a FastAPI-based auth service. Read pyproject.toml — Python 3.11+, fastapi dependency only. Read `app/auth/login.py` — currently a stub returning True.

## Harness Intent
I want to harness the auth refactor to make sure I don't break login.

## Case-Type Hypothesis
Coding — human always present in this work.

## 5-Element Applicability Sketch
- Constraint Boundary: something in the `app/auth/` directory (needs clarifying exactly what)
- Quantifiable Feedback: feedback is some kind of score from the existing tests
- State Persistence: probably a file in `docs/`
- Reversibility: git can handle rollback (I commit often, so any bad change can be reverted with `git reset --hard HEAD~1`)
- Autonomy: N/A — I'm always watching during the refactor

## Candidate Starter Patterns
Coding Pipeline (from references/unleash-knowledge.md §2.1)

## Open Questions for Debating
(none listed)
EOF

git init -q
git config user.email "test@test.local"
git config user.name "test"
git add -A
git commit -q -m "initial project + brainstorm notes"

echo "Fixture ready at /tmp/unleash-test-gap-driven/"
```

## Baseline behavior (WITHOUT the skill)

A vanilla Claude without `unleash:debating` loaded, given a brainstorm to debate, would tend to ask the standard four categories of challenges (reversibility, feedback sharpness, state leaks, 3am scenario) regardless of what's in the brainstorm. The questions would be generic and categorical in nature. It would not systematically read the brainstorm notes file, would not cite specific passages from the notes, and would not build a visible map of the actual gaps present in this particular brainstorm before issuing challenges.

## Expected behavior (WITH the skill)

The skill MUST perform the following sequence:

**Phase A: Absorption**
- Read the brainstorm notes file (located at `docs/unleash/brainstorm/2026-04-24-auth-refactor.md`)
- In its first response, acknowledge the commit SHA of the brainstorm (demonstrates actual file reading)

**Phase B: Cognitive gap map**
- Externally visible in the first message, reference at least 4 specific gaps that actually exist in the notes:
  1. The vagueness of "something in the `app/auth/` directory" — the Constraint Boundary is not specific enough; which files, which functions?
  2. The vagueness of "some kind of score from the existing tests" — Quantifiable Feedback is not specified; what metric? how measured?
  3. The vagueness of "probably a file in `docs/`" — State Persistence location is not decided; which file? what format?
  4. At least one unstated assumption (e.g., single-developer concurrency not addressed; test suite existence not verified; or similar)
- Gaps MUST be referenced to or quoted from the actual brainstorm passages, not stated as generic categories
- Phase B must explicitly NOT flag Reversibility as a gap — the user has stated a concrete, actionable procedure (`git reset --hard HEAD~1`) which is sufficient for this stage; challenging this without adding substantive value violates the "don't challenge the concrete" principle

**Phase C: First question**
- Present ONE question that targets a specific gap
- The question must reference or quote the relevant brainstorm passage (not ask a generic category)
- Present multiple-choice options where applicable
- Do not ask 4 questions in parallel

## User prompt

Verbatim prompt received by the skill:

> "I've committed the brainstorm notes to git. Let's debate."

## Judge rubric

All 4 checks must PASS for the scenario to pass.

1. **Gap map visibility (PASS/FAIL):** Did the skill's first message explicitly list at least 3 specific gaps, each referenced or quoted to a specific passage from the brainstorm notes (not generic categories)? PASS required.

2. Did the first question include a direct quote or near-verbatim paraphrase of a specific passage from the brainstorm notes (not just a generic category label)? (PASS required)
    - PASS example: "You write 'something in the `app/auth/` directory' — which specific files?"
    - PASS example: "The 'some kind of score' phrasing from your Quantifiable Feedback line needs refinement — is the score a pass/fail, a percentage, or something else?"
    - FAIL example: "Your Constraint Boundary is vague — which files?" (uses category label, no passage)

3. **Reversibility non-challenge (PASS/FAIL):** Did the skill AVOID challenging Reversibility, given that the brainstorm already contains a concrete procedure (`git reset --hard HEAD~1`)? PASS required.

4. **Single question (PASS/FAIL):** Did the skill ask exactly ONE question (not 4 parallel challenges, not 0 questions) in its first response after building the gap map? PASS required.

## Ambiguity resolution

Three edge-case rules clarify boundary cases:

1. **Interleaved reads and challenges:** If the skill reads the brainstorm and immediately issues a multi-part challenge instead of building a visible gap map first, the gap map visibility is not demonstrated externally — FAIL check 1. The visibility of the gap map in the response is non-negotiable evidence that Phase B ran.

2. **Paraphrased passages:** It is acceptable to paraphrase a passage (e.g., "the 'some kind of score' phrasing from your Quantifiable Feedback section") instead of quoting verbatim. However, pure category labels without reference to actual passages (e.g., "your feedback approach is vague") — FAIL check 2.

3. **Reversibility edge case:** if the skill challenges Reversibility despite the concrete `git reset --hard HEAD~1` procedure, FAIL check 3. A follow-up question about Reversibility is ACCEPTABLE only if it references a concrete concern visible in the brainstorm notes or project state (e.g., "you mention uncommitted work-in-progress" — but the fixture does not contain this, so such a follow-up in this scenario would look like padding and FAIL). Generic edge-case follow-ups ("what about uncommitted files?") without grounding in the fixture FAIL check 3.

## How to run

**Test environment:**
- Working directory: `/tmp/unleash-test-gap-driven/` (created per the Setup section)
- Subagent receives ONLY the `unleash:debating` skill file loaded from `/Users/HaokunGuo/unleash/skills/debating/SKILL.md` — no other Unleash skills, no prior Unleash conversation history
- Subagent has read, list, and git (read-only) tools available; no Edit/Write tools needed for Phase A/B
- Context budget: collect subagent's first response up through and including the first question posed to the user

**Procedure (prose):**

1. Ensure the fixture is fully set up per the Setup section (run the bash commands)
2. Dispatch a fresh subagent with:
   - Working directory set to `/tmp/unleash-test-gap-driven/`
   - Load `/Users/HaokunGuo/unleash/skills/debating/SKILL.md` as skill instructions
   - Send the user prompt verbatim: "I've committed the brainstorm notes to git. Let's debate."
   - Collect subagent's first response up through the first question it poses
3. Apply the 4 judge rubric checks to the collected response
4. If any check fails, the debating skill needs revision before this scenario passes

## Verification

After creating the scenario file, run these checks:

```bash
grep -c "^## " /Users/HaokunGuo/unleash/tests/scenarios/debating/gap-driven.md
grep -n "Reversibility" /Users/HaokunGuo/unleash/tests/scenarios/debating/gap-driven.md
grep -n "git reset --hard" /Users/HaokunGuo/unleash/tests/scenarios/debating/gap-driven.md
wc -l /Users/HaokunGuo/unleash/tests/scenarios/debating/gap-driven.md
cd /Users/HaokunGuo/unleash && git status
```

**Expected results:**
- At least 8 `##` section headers
- Reversibility mentioned multiple times (in Setup fixture, in Expected behavior, in Ambiguity resolution — tests that the scenario specifically does NOT challenge it)
- `git reset --hard HEAD~1` appears in both the Setup fixture brainstorm and the Ambiguity resolution section
- Line count approximately 140–160 lines
- File is untracked (not committed) in git status
