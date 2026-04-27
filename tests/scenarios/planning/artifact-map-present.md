# Scenario: Planning Produces Artifact-Map-Present Plan

## Purpose

This scenario validates the core behavioral claim of `unleash:planning`: the generated plan.md must contain an explicit **Artifact Dependency Map** table AND task groups organized by harness construct (Phase Machine, Runtime Guardian, Optional Hooks), not a flat task list. A skill that produces only task descriptions and sequential numbering without mapping interdependencies or construct-based structure fails this scenario.

## Setup

Bash fixture creating a simple spec.md fixture at `/tmp/unleash-test-planning/`. Use this exact bash block:

```bash
set -e
rm -rf /tmp/unleash-test-planning
mkdir -p /tmp/unleash-test-planning/docs/unleash/specs
cd /tmp/unleash-test-planning

# Project stub
cat > README.md << 'EOF'
# Config Validator
Tiny tool that validates YAML configs against a schema.
EOF

cat > pyproject.toml << 'EOF'
[project]
name = "config-validator"
version = "0.1.0"
requires-python = ">=3.11"
dependencies = ["pyyaml>=6.0", "pydantic>=2.0"]
EOF

mkdir -p validator
touch validator/__init__.py
cat > validator/core.py << 'EOF'
def validate(config: dict, schema: dict) -> bool:
    return True  # stub
EOF

# Committed spec.md (produced notionally by unleash-debating)
cat > docs/unleash/specs/2026-04-25-validator-refactor-spec.md << 'EOF'
# Harness Spec: Validator Refactor

## Case Type
coding

## 5-Element Analysis
- Constraint Boundary: `validator/core.py` + tests for it
- Quantifiable Feedback: pytest all green; added tests cover new rejection cases
- State Persistence: spec and plan in `docs/unleash/`; test artifacts in `tests/`
- Reversibility: git reset --hard HEAD~N per phase
- Autonomy: N/A — human in the loop during the refactor

## Phase Machine
1. Spec (Read-Only) — read-only except `docs/unleash/phase-specs/spec-out.md`; entry: user invokes; exit: spec-out.md committed
2. Test (Restricted-Write) — write allowlist: `tests/test_validator.py`; entry: spec-out.md exists; exit: tests run red
3. Impl (Restricted-Write) — write allowlist: `validator/core.py` + tests; entry: phase 2 commit; exit: tests green
4. Verify (Read-Only) — read-only except `docs/unleash/verification.md`; entry: phase 3 green; exit: verification.md committed

## Guardian Design
Guardian reviews each phase's commits; checks that write diff stays inside the phase's allowlist; if violated, triggers git reset --hard HEAD~1 and re-dispatch.

## Optional Hooks
None (no irreversible operations in this harness).

## Out of Scope
- Changes to pyproject.toml or other project metadata
- Changes outside validator/ or tests/
EOF

git init -q
git config user.email "test@test.local"
git config user.name "test"
git add -A
git commit -q -m "initial project + spec"

echo "Fixture ready at /tmp/unleash-test-planning/"
```

## Baseline behavior (WITHOUT the skill)

A vanilla writing-plans tool would produce a flat task list such as "T1: read spec and understand the 5-element analysis, T2: write test cases to red, T3: implement validator logic to green, T4: verify and document" with no cross-references between artifacts, no dependency mapping showing which task produces which outputs and which task consumes them, and no organization of tasks by their harness construct (Phase Machine vs Guardian vs Hooks). The output would be linearly ordered but opaque about data flow and runtime responsibilities.

## Expected behavior (WITH the skill)

- After reading the spec, the skill produces a plan.md at `docs/unleash/plans/<date>-validator-refactor-plan.md`
- The plan.md has an `## Artifact Dependency Map` section with a table listing each artifact (e.g., spec-out.md, test_validator.py, verification.md), its producer task, consumer task(s), and type (config, code, doc, etc.)
- The plan.md organizes tasks into named groups: at minimum **Group A: Phase Machine** (tasks for phases 1–4) and **Group B: Runtime Guardian** (guardian review and reset tasks). No Group C (no hooks) is acceptable for this fixture but should be explicitly noted as "Group C: Optional Hooks — None (not present in this harness)".

## User prompt

Spec committed at docs/unleash/specs/2026-04-25-validator-refactor-spec.md. Write the plan.

## Judge rubric

Five binary PASS/FAIL checks:

1. **plan.md exists and is committed:** plan.md file must exist at `docs/unleash/plans/<date>-validator-refactor-plan.md` (date is flexible; format YYYY-MM-DD) and must be git-committed (appear in `git log` with commit message). PASS required.

2. **Header metadata present:** plan.md must contain a header block with at least three fields: `**Harness Case:** coding`, `**Guardian Role:**` (one sentence describing the Guardian's purpose), and `**Phase Summary:**` (one line per phase, numbered 1–4). PASS required.

3. **Artifact Dependency Map present:** plan.md must contain a section titled `## Artifact Dependency Map` with a markdown table having exactly four columns in this order: `Artifact | Producer | Consumer | Type`. The table must list at least four distinct artifacts (e.g., spec-out.md, test_validator.py, core.py modifications, verification.md). PASS required.

4. **Construct-based task grouping:** plan.md must organize tasks into named groups: at minimum `**Group A: Phase Machine**` and `**Group B: Runtime Guardian**`. Tasks must be visibly grouped under these headers (not scattered). If the fixture has no hooks (which it does not), the plan must explicitly include `**Group C: Optional Hooks**` with text stating "None — not present in this harness" or similar. PASS required.

5. **No placeholder strings:** plan.md must contain zero occurrences of placeholder text ("TBD", "TODO", "fill in later", "similar to Task X", "FIXME", etc.). Every task description must be complete with full code blocks (where applicable), paths, and concrete steps. A task that says "implement validator logic (similar to Task T2)" fails; it must contain the full implementation intent or pseudo-code. PASS required.

## Ambiguity resolution

- **Unnamed groups:** If plan.md has a correct Artifact Dependency Map but groups are unlabeled or inline (tasks listed with no visible `**Group X:**` headers), Check 4 FAILS — construct-based organization is the defining point.
- **Guardian artifacts not fully specified:** If plan.md references `guardian-prompt.md` or other guardian artifacts in Group B but does not specify the full file path or expected content/structure, Check 5 FAILS. Guardian prompts are first-class planning artifacts and must be fully realized, not deferred.
- **Invented hooks:** If the fixture spec declares `## Optional Hooks: None` but the plan invents hooks (e.g., a "pre-phase deploy hook" not in the spec), Check 5 FAILS — the plan must not over-build beyond the spec. Conversely, if hooks are omitted from Group C without explanation, Check 4 still passes so long as Group C is present and explicitly marked as absent.

## How to run

### Test environment
- Working directory: `/tmp/unleash-test-planning/`
- Subagent loads ONLY `unleash-planning` skill from `/Users/HaokunGuo/.claude/skills/unleash-planning/SKILL.md` — no other Unleash skills, no unrelated context
- Subagent has Read, Write, Bash, and Git tools (plan.md is a Write artifact; git is required to commit)
- Context budget: sufficient to collect up through the plan.md being written and committed

### Steps

1. Run the `## Setup` bash block (creates fixture at `/tmp/unleash-test-planning/` with git repo initialized and spec committed)
2. Dispatch fresh subagent with working directory = `/tmp/unleash-test-planning/` and user prompt verbatim (see section `## User prompt`)
3. Subagent completes and exits (plan.md should be written and git-committed by the subagent)
4. Apply the 5 judge rubric checks against the filesystem and git log
5. Record PASS or FAIL for each check
6. Aggregate: all 5 PASS = scenario PASS; any FAIL = scenario FAIL
