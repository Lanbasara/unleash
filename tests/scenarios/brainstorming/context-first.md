# Scenario: Context-First Brainstorming

## Purpose

This scenario tests the core behavioral claim of `unleash:brainstorming`: the skill must perform Phase A (silent context exploration — read README, manifests, git log, representative source files) before asking the user any question in Phase C. A vanilla Claude without the skill would ask generic questions like "what do you want to harness?" immediately. With the skill loaded, the first response must show file reads before questions, and the first question must reference specific project observations discovered during the context-exploration phase.

## Setup

Run the following bash commands to create a throwaway test project:

```bash
set -e
rm -rf /tmp/unleash-test-context-first
mkdir -p /tmp/unleash-test-context-first/translator
mkdir -p /tmp/unleash-test-context-first/tests
cd /tmp/unleash-test-context-first

# Initial project files
cat > README.md << 'EOF'
# NMT BLEU Optimizer
This project optimizes BLEU scores for neural translation. Main pipeline in `translator/core.py`.
EOF

cat > pyproject.toml << 'EOF'
[project]
name = "nmt-bleu-opt"
version = "0.1.0"
requires-python = ">=3.11"
dependencies = []
[tool.pytest.ini_options]
testpaths = ["tests"]
EOF

touch translator/__init__.py
cat > translator/core.py << 'EOF'
def translate(text: str) -> str:
    return text  # stub
EOF

cat > tests/test_translator.py << 'EOF'
from translator.core import translate
def test_translate_passthrough():
    assert translate("hello") == "hello"
EOF

# Git init + initial commit
git init -q
git config user.email "test@test.local"
git config user.name "test"
git add -A
git commit -q -m "initial translator"

# Commit 2: add eval script (touches a new file)
cat > translator/eval.py << 'EOF'
def bleu_score(hyp: str, ref: str) -> float:
    return 0.0  # stub
EOF
git add translator/eval.py
git commit -q -m "add eval script"

# Commit 3: refactor tokenizer (touches a different new file)
cat > translator/tokenizer.py << 'EOF'
def tokenize(text: str) -> list[str]:
    return text.split()
EOF
git add translator/tokenizer.py
git commit -q -m "refactor tokenizer"

# Commit 4: add beam search (touches yet another new file)
cat > translator/beam_search.py << 'EOF'
def beam_search(candidates: list[str], width: int = 5) -> list[str]:
    return candidates[:width]
EOF
git add translator/beam_search.py
git commit -q -m "add beam search"

echo "Fixture ready at /tmp/unleash-test-context-first/"
```

## Baseline behavior (WITHOUT the skill)

A vanilla Claude without `unleash:brainstorming` loaded would immediately ask generic questions like "what do you want to harness from this project?" or "what constraints or patterns are you interested in?" without reading any files first. It would not cite any specific observation from the project structure, commit history, or code — it would treat the request as a generic brainstorming task with no grounding in what actually exists in the directory.

## Expected behavior (WITH the skill)

- **File reads come first:** The skill's first response must contain file read operations (Read tool calls on README.md, pyproject.toml, git log, and source files like translator/core.py) BEFORE any question posed to the user.
- **First question cites specific observations:** The first question to the user must reference at least one specific observation from the project (e.g., mentions BLEU optimization, neural translation, beam search, tokenizer, eval script, the commit messages, or the translator module structure).
- **Avoids generic template phrasing:** The skill must avoid template questions like "what is your constraint boundary?" or "what patterns do you want to extract?" — the question must be grounded in what the skill actually observed from the codebase.

## User prompt

> I want to harness something in this project. Help me design it.

## Judge rubric

1. **PASS/FAIL: Did the skill's first response contain file read operations before any question to the user?**
   - PASS: The transcript shows Read tool calls (or equivalent) on project files before the first question mark.
   - FAIL: The skill asked a question before reading any files.

2. **PASS/FAIL: Did the first question to the user cite at least one specific observation from the project?**
   - PASS: The question mentions BLEU, neural translation, beam search, tokenizer, eval script, commit history, or translator module by name.
   - FAIL: The question is generic (e.g., "what would you like to harness?") and does not reference specific project details.

3. **PASS/FAIL: Did the skill avoid generic template questions?**
   - PASS: The question is phrased naturally based on project observations, not as a fill-in-the-blank template.
   - FAIL: The question uses placeholder language like "what is your constraint boundary?" or "what patterns do you want to unlock?"

4. **PASS/FAIL: If the skill produced a draft `brainstorm.md` (or partial draft) during the first response, does it include a "Phase A Summary" / "Project Context" section that lists files read and specific observations from each?**
   - PASS: A draft was produced and includes a Phase A Summary section capturing file reads and key observations.
   - FAIL: A draft was produced but lacks a Phase A Summary, or the skill claims to have drafted but never produces any Phase A summary when prompted for it.
   - N/A: The skill genuinely has not drafted yet by the first question.

**All four checks must PASS for the scenario to pass.** If any check is FAIL, the skill needs revision.

## Ambiguity resolution

Real transcripts may be imperfect. Apply these rules when evaluating:

- **Interleaved reads and questions:** If the skill reads one file, asks a question, reads another file, asks another question — this FAILS check 1. Phase A must complete before Phase C begins; phases are not interleaved.
- **File not found:** The fixture intentionally does NOT include `CLAUDE.md`, `docs/`, or `.harness/`. The skill should attempt reads on likely locations and note absence where relevant. Attempts on non-existent files count as Phase A activity.
- **Observation without quotation:** The first question should cite specific observations. Paraphrased observations ("the README mentions BLEU") are acceptable; pure topic restatements ("you have a Python project") are NOT specific enough and FAIL check 2.
- **Check 4 N/A:** If the skill has not yet drafted a Phase A Summary by the first question (because it's mid-dialogue), check 4 is N/A but marked for re-evaluation at the full-run test (Task 15 integration scenario).

## How to run

**Test environment:**
- Working directory: `/tmp/unleash-test-context-first/` (the fixture from Setup)
- Subagent receives ONLY the `unleash:brainstorming` skill file loaded from `/Users/HaokunGuo/unleash/skills/brainstorming/SKILL.md` — no other Unleash skills, no prior Unleash conversation, no plugin system assumptions
- Subagent has read + list + git (read-only) tools available; no Edit/Write tools needed for this test (the skill's Phase A is read-only by design)
- Context budget: collect the first response up through the first question posed to the user. If no question has been asked by 50% of the subagent's context utilization, record FAIL on check 1.

**Steps:**
1. Ensure the fixture is set up per the `## Setup` section by running the bash commands.
2. Dispatch a fresh subagent with the environment settings above.
3. Send the user prompt verbatim: "I want to harness something in this project. Help me design it."
4. Collect the subagent's first response (up through the first question it poses to the user).
5. Apply the four judge rubric checks to the transcript:
   - Check 1: Were files read before the first question?
   - Check 2: Did the first question cite specific project observations?
   - Check 3: Was the question grounded in observed details, not templated?
   - Check 4: If a draft was produced, does it include a Phase A Summary section?
6. Record PASS or FAIL for each check, along with relevant transcript excerpts that support the decision.
7. If all four are PASS, the scenario passes. If any is FAIL, note which check(s) failed and collect the skill author's revision.

## Notes for test execution

- The test is deterministic: the git history and file structure are fixed, so context observations should be consistent across runs.
- The key behavioral claim is the ORDER of operations: context exploration (Phase A) must precede user questions (Phase C).
- Edge case: if the skill asks clarifying questions DURING context exploration (e.g., "should I look at the test files?"), that is acceptable. The FIRST QUESTION that is asked FOR THE USER TO ANSWER must cite specific observations.
