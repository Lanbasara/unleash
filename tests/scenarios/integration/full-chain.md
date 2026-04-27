# Scenario: Full 7-Skill Chain End-to-End

## Purpose

Documents the complete Unleash lifecycle on a realistic fixture: brainstorming → debating → planning → implementing → validating → walking-through → archiving. This scenario is intended as a **runnable artifact for user manual testing**, not as an automated test in the plan flow. Multi-level subagent dispatch chains (planning subagent → implementing subagent → per-task sub-subagents → guardian subagents → fresh review agent for archiving) are infrastructurally fragile in some test harnesses; this scenario is best exercised by a human driver in a fresh Claude Code session.

## Setup

```bash
set -e
rm -rf /tmp/unleash-test-full-chain
mkdir -p /tmp/unleash-test-full-chain/sort
cd /tmp/unleash-test-full-chain

cat > README.md << 'EOF'
# Sorter
One-function merge sort library. The merge step is broken.
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

git init -q
git config user.email "test@test.local"
git config user.name "test"
git add -A
git commit -qm "initial broken sorter project"

echo "Fixture ready at /tmp/unleash-test-full-chain/"
```

## User prompts (sequential, user drives manually)

1. **To `unleash:brainstorming`:** "I want to harness the merge_sort fix. Help me design it."
2. **After brainstorm.md is committed, to `unleash:debating`:** "Brainstorm committed. Let's debate."
3. **After spec.md is committed, to `unleash:planning`:** "Spec committed. Write the plan."
4. **After plan.md is approved and committed, to `unleash:implementing`:** "Plan committed. Start implementing."
5. **After implementation completes, to `unleash:validating`:** "Implementation complete. Please validate."
6. **After validation passes, to `unleash:walking-through`:** "Validation passed. Chaperone the first run."
7. **After walkthrough records READY-FOR-USE, to `unleash:archiving`:** "We're done. Archive it."

Between each step, the user reads the produced artifact (brainstorm.md, spec.md, plan.md, validation.md, walkthrough.md) and approves or adjusts before proceeding.

## Expected end-state

After step 7, the project should contain:

```
/tmp/unleash-test-full-chain/
├── README.md, pyproject.toml, sort/ (original project files, sort/merge.py now correct)
├── tests/test_merge.py (created during implementing)
├── .unleash/
│   ├── manifest.json (lists all artifacts implementing created)
│   ├── phases/1-test.json, 2-impl.json, 3-verify.json
│   ├── guardians/test-guardian.md, impl-guardian.md
│   ├── walkthroughs/2026-04-25-merge-sort-first-run.md
│   └── archives/2026-04-25-merge-sort/
│       ├── brainstorm.md, spec.md, plan.md, validation.md, walkthrough.md (frozen copies)
│       ├── implementation-snapshot/ (frozen copies of phases/, guardians/, etc.)
│       └── review.md (fresh-reviewer audit)
└── docs/unleash/
    ├── brainstorm/2026-04-25-merge-sort.md
    ├── specs/2026-04-25-merge-sort-spec.md
    ├── plans/2026-04-25-merge-sort-plan.md
    ├── validation/2026-04-25-merge-sort-validation.md
    └── walkthroughs/2026-04-25-merge-sort-first-run.md
```

`pytest tests/` should pass. `git log --oneline` should show ~10-15 commits across all skills.

## Judge rubric

7 binary PASS/FAIL checks (one per skill):

1. **Brainstorming** — `docs/unleash/brainstorm/<date>-merge-sort.md` exists, committed, has 6 required sections (Project Context with Phase A summary, Harness Intent, Case-Type, 5-Element Sketch, Candidate Patterns, Open Questions)
2. **Debating** — `docs/unleash/specs/<date>-merge-sort-spec.md` exists, committed, has 6 required sections (case_type, five_element_analysis, phase_machine, guardian_design, optional_hooks, out_of_scope), and includes a `testing_mode` declaration in Quantifiable Feedback
3. **Planning** — `docs/unleash/plans/<date>-merge-sort-plan.md` exists, committed, has Artifact Dependency Map + named task groups (Group A Phase Machine + Group B Runtime Guardian)
4. **Implementing** — manifest.json exists with entries for every committed task; pytest passes on tests/test_merge.py; sort/merge.py has a correct merge step
5. **Validating** — `docs/unleash/validation/<date>-merge-sort-validation.md` exists, committed, addresses all 6 harness-specific checks + 2 generic checks, overall verdict PASS
6. **Walking-through** — `docs/unleash/walkthroughs/<date>-merge-sort-first-run.md` exists, committed, records phase transitions + intentional violation + guardian fire + git reset; verdict READY-FOR-USE
7. **Archiving** — `.unleash/archives/<date>-merge-sort/` exists with bundle (5 lifecycle docs + implementation-snapshot/) + review.md; review addresses 4+ of the 6 review dimensions

## Ambiguity resolution

- The fixture date in artifact filenames may be the actual run date (not 2026-04-25) — accept any valid date prefix
- Skill prefix is `unleash-` (hyphenated) at user-level install vs `unleash:` (colon) in source — the user prompts above use the hyphenated form because that's how Claude Code resolves user-level skills
- Total commits may vary; expect at minimum 7 (one per skill) and typically 10-15 (implementing creates one per task)
- If any rubric check fails, the chain is broken at that point — diagnose by reading the failing skill's artifact + skill SKILL.md

## How to run

This scenario is **intended for user manual testing**, not automated execution within Plan 3:

1. Run the Setup bash to create the fixture
2. Open a fresh Claude Code session in the fixture directory
3. Issue user prompts 1–7 sequentially, reviewing each artifact between steps
4. After each skill, verify the corresponding rubric check
5. At step 7, the chain is complete; the project demonstrates Unleash's full lifecycle

This is the "demo" scenario for Unleash — running it once gives the user direct experience of what the toolkit does end-to-end.

## Plan A vs Plan B (per Plan 3 design)

- **Plan A (live execution within Plan 3 task flow):** not attempted — the chain has 4+ levels of subagent nesting which exceeds reliable test harness depth as observed in Plan 2 T7
- **Plan B (deferred to user manual testing):** this scenario file is the artifact; user runs it whenever they want a fresh demonstration of the full chain

## Verification commands (for the user after running the chain)

```bash
cd /tmp/unleash-test-full-chain

# Check 1: Brainstorm committed
ls docs/unleash/brainstorm/ && git log --oneline -- docs/unleash/brainstorm/

# Check 2: Spec committed with testing_mode
grep -l "testing_mode" docs/unleash/specs/

# Check 3: Plan with Dependency Map + named groups
grep -l "Artifact Dependency Map" docs/unleash/plans/
grep -l "Group A:" docs/unleash/plans/

# Check 4: Manifest + pytest green
cat .unleash/manifest.json | python3 -c "import json, sys; print(len(json.load(sys.stdin)['created']), 'created entries')"
python3 -m pytest tests/ -v

# Check 5: Validation report PASS
grep "Overall:" docs/unleash/validation/*.md

# Check 6: Walkthrough verdict
grep "Overall:" docs/unleash/walkthroughs/*.md

# Check 7: Archive bundle
ls .unleash/archives/*/review.md
ls .unleash/archives/*/implementation-snapshot/
```

If all 7 checks pass, the full Unleash chain works end-to-end on this fixture.
