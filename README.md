# Unleash

> **Design the harness once, let the AI run.**

*From harness to unleash — constraint as the path to freedom.*

[![Version](https://img.shields.io/badge/version-0.5.0-blue)](https://github.com/Lanbasara/unleash)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Claude Code](https://img.shields.io/badge/for-Claude%20Code-orange)](https://claude.ai/code)

Unleash is a **Claude Code plugin** that turns chaotic AI coding sessions into structured, auditable, and repeatable engineering workflows.

Instead of hoping the AI "does the right thing," you **design the harness first** — a system of constraints, feedback loops, and checkpoints — then let the AI run inside it.

---

## The Problem

You have probably felt this:

- You ask Claude to refactor one module. It also rewrites your CI config, bumps dependencies, and suggests pushing to production.
- Halfway through a 20-turn conversation, the AI forgets what you agreed on in turn 3.
- The AI writes code, then "reviews" its own code, and surprise — it looks fine to itself.
- You come back a week later and have no idea *why* a change was made or what the original intent was.

Unleash fixes this by treating AI coding as **an engineering process**, not a chat.

---

## How It Works

Unleash does not give you a rigid playbook. It gives you a **design philosophy** and a set of composable skills that enforce it.

The philosophy is simple:

> **Think first. Debate the design. Record the contract. Implement inside constraints. Verify independently.**

Every Unleash skill follows this rhythm. Whether you are building a runtime harness for a database migration, designing guardrails for a feature sprint, or auditing an existing flow, the same five movements apply:

1. **Think** — Explore the problem space silently before proposing solutions. (`brainstorming`)
2. **Debate** — Challenge assumptions, expose gaps, and lock a written contract. (`debating`)
3. **Record** — Commit the contract to an artifact that outlives the chat session. (`planning`, `.unleash/manifest.json`)
4. **Implement** — Run the AI inside the harness, not in open-ended conversation. (`implementing`)
5. **Check** — Verify with fresh context, independent reviewers, and intentional boundary tests. (`validating`, `walking-through`, `archiving` / `reporting`)

Different problems compose these skills into different chains. A feature refactor might go *brainstorm → debate → plan → implement → validate → report*. A long-running harness might add *walking-through* and *archiving*. The entry skill (`using-unleash`) reads the situation and routes you to the right starting point — it does not force a single path.

**The invariant rules are what matter:**
- Artifacts are the contract. Chat narration is not.
- Fresh-context reviews. The checker never sees the builder's reasoning.
- Scope stops at committed code. No "helpful" detours into CI/CD or deployment.
- No auto-advance. You review each artifact before the next step proceeds.

Unleash is not a script. It is a **harness design practice** implemented as skills.

---

## Installation

### One-line install (recommended)

Inside Claude Code:

```
/plugin marketplace add https://github.com/Lanbasara/unleash-marketplace
/plugin install unleash@lanbasara
```

Restart Claude Code, then verify:

```
What skills in the unleash: namespace are available?
```

### Manual install (skills only)

```bash
git clone https://github.com/Lanbasara/unleash.git
cd unleash
for d in skills/*/; do
  ln -s "$(pwd)/$d" ~/.claude/skills/unleash-$(basename "$d")
done
```

---

## The 9 Skills

| Skill | What you type | What it does |
|-------|---------------|--------------|
| **using-unleash** | `/unleash:using-unleash` | Entry gate. Decides if Unleash applies, picks the right starting point, and installs chain discipline. |
| **brainstorming** | `/unleash:brainstorming` | Reads your codebase silently first, then asks targeted questions. Produces `brainstorm.md`. |
| **debating** | `/unleash:debating` | Challenges gaps in your brainstorm. Produces a committed `spec.md` with testing mode, phase machine, and guardian design. |
| **planning** | `/unleash:planning` | Turns the spec into an executable plan with task groups and artifact dependency map. Produces `plan.md`. |
| **implementing** | `/unleash:implementing` | Dispatches one fresh subagent per plan task. Produces code, commits, and `.unleash/manifest.json`. |
| **validating** | `/unleash:validating` | Runs 6 harness-specific invariant checks + 2 generic checks. Reports findings only — does not modify code. |
| **walking-through** | `/unleash:walking-through` | Chaperones the first real run. Intentionally violates allowlist to verify the guardian catches it. |
| **archiving** | `/unleash:archiving` | End-of-life for runtime harnesses. Bundles all artifacts + dispatches an independent reviewer. |
| **reporting** | `/unleash:reporting` | End-of-life for single coding tasks (no runtime harness). Produces a cold-review audit of the diff against spec. |

*Archiving and reporting are mutually exclusive — Unleash picks the right one based on whether `.unleash/manifest.json` exists.*

---

## Philosophy: Harness → Unleash

A **harness** is a set of constraints: where the AI can write, what success looks like, how to roll back, who reviews the work.

An **unleashed** agent is one that runs fast and autonomously *because* the harness is trustworthy.

Unleash is the workflow that gets you from vague intent to a concrete harness. The plugin does not run the harness for you — it gives you the discipline to design it right.

> "The goal is not to control the AI. The goal is to make the AI's freedom safe enough that you can stop watching every keystroke."

---

## When to Use Unleash

**Use it when the work has all three:**
- Design surface (benefits from up-front structure, not a single mechanical edit)
- Multiple steps (more than one commit or one subagent dispatch)
- Audit or re-use value (someone will want to know what was decided and why)

**Don't use it when:**
- It's a single mechanical edit (rename, typo fix, dependency bump)
- The user explicitly opts out
- The request is purely deployment, CI/CD, or production operations

---

## Documentation

- **[INTRODUCTION.md](INTRODUCTION.md)** — Complete design rationale, 5-Element Framework, and anti-patterns
- **[INTRODUCTION.zh.md](INTRODUCTION.zh.md)** — 中文完整文档
- **[references/unleash-knowledge.md](references/unleash-knowledge.md)** — Phase primitives, guardian patterns, common pitfalls
- **[CHANGELOG.md](CHANGELOG.md)** — Version history and design decisions

---

## License

MIT — see [LICENSE](LICENSE) for details.
