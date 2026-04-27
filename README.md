# Unleash

> Design the harness once, let the AI run.

## What it is

Unleash is a Claude Code skill suite that helps developers design bespoke harnesses for their AI coding workflows. A harness is a system of constraints, feedback loops, state management, reversibility guarantees, and autonomy controls that makes AI agent behavior predictable and reliable. Rather than running harnesses itself, Unleash equips you with a dialogue-driven workflow to build the right harness for your specific project. The plugin takes you from a vague intent ("I want to harness my database migration flow") through structured exploration and debate to a detailed, committed specification that you can then implement and deploy.

## Status

Version 0.4.0 adds a `using-unleash` entry-point skill — the meta gate that establishes chain discipline (sequential ordering, scope boundary at committed code, fresh-context reviews, archiving-vs-reporting routing) before any other `unleash:*` skill is invoked. The 7-skill workflow chain (intake + build + lifecycle) plus `unleash:reporting` (B-layer-only end-of-life parallel to archiving) shipped in 0.3.x. Together they form a 9-skill suite: 1 entry skill + 8 workflow skills.

## Installation (local development)

To use Unleash locally during development:

1. Clone or symlink the plugin directory into your Claude Code plugins cache:
   ```bash
   ln -s /path/to/unleash ~/.claude/plugins/cache/local/unleash/0.1.0
   ```
   Alternatively, register the unleash directory as a local marketplace source in your settings.

2. Add the plugin to your `~/.claude/settings.json`:
   ```json
   {
     "enabledPlugins": {
       "unleash@local": true
     }
   }
   ```

3. Restart Claude Code to load the plugin and register its skills.

4. Verify installation by asking Claude to list available skills:
   ```
   What skills in the unleash: namespace are available?
   ```

## Skills in 0.4.0

| Skill | Purpose | Contract |
|-------|---------|----------|
| `unleash:using-unleash` | Meta entry-point: gates "should Unleash apply?", routes to the right entry skill based on existing artifacts, and installs cross-skill discipline (sequential ordering, scope boundary, archiving-vs-reporting mutual exclusion) | Consumes user intent + project state; invokes the correct downstream `unleash:*` skill or exits |
| `unleash:brainstorming` | Context-first intake dialogue that explores your project silently before asking targeted questions | Consumes user intent and project tree; produces `brainstorm.md` |
| `unleash:debating` | Gap-driven challenge dialogue that converges brainstorm notes into a formal, committed spec | Consumes `brainstorm.md`; produces `spec.md` |
| `unleash:planning` | Internalizes writing-plans discipline with harness-specific task grouping and Artifact Dependency Map | Consumes `spec.md`; produces `plan.md` |
| `unleash:implementing` | Dispatches fresh subagents per plan task with full task text pasted; appends to manifest as commits land; does not review | Consumes `plan.md`; produces harness code + commits + `.unleash/manifest.json` |
| `unleash:validating` | Harness-aware audit (6 invariant checks + 2 generic) against the spec; re-runnable; reports findings only | Consumes manifest + harness; produces validation report |
| `unleash:walking-through` | Chaperones first real run; drives a phase transition; intentionally violates allowlist to verify guardian fires | Consumes validated harness; produces walkthrough record |
| `unleash:archiving` | C-layer end-of-life: bundles lifecycle artifacts + dispatches fresh independent reviewer (used when a runtime harness was built and `.unleash/manifest.json` exists) | Consumes "archive this" signal + manifest; produces archive bundle + review |
| `unleash:reporting` | B-layer end-of-life: writes a brief independent-reviewer cold report (used when Unleash drove a single coding task without a runtime harness — no manifest exists) | Consumes "report this" signal + spec.md + filtered git diff; produces report.md |

### End-of-life: archiving vs reporting (parallel-2-of-1)

Pick one based on harness shape:

- **`unleash:archiving`** — for harnesses where you installed runtime artifacts (phase configs, guardian prompts in `.unleash/`). The skill bundles the full lifecycle + runs a deeper review covering guardian/hook dimensions.
- **`unleash:reporting`** — for single coding tasks where Unleash's value was the dialogue discipline (brainstorm → debate → plan → implement → done) but no runtime machinery got installed. The skill produces a 2-minute cold-review audit of the diff against the spec.

The skills enforce mutual exclusion: each STOPs and redirects to the other if it detects the wrong harness shape (e.g., reporting STOPs if a manifest exists).

## The full chain (complete)

The complete Unleash toolkit spans seven skills:

1. `unleash:brainstorming` ✅ 0.1.0
2. `unleash:debating` ✅ 0.1.0
3. `unleash:planning` ✅ 0.2.0
4. `unleash:implementing` ✅ 0.2.0 (manifest support added in 0.3.0)
5. `unleash:validating` ✅ 0.3.0
6. `unleash:walking-through` ✅ 0.3.0
7. `unleash:archiving` ✅ 0.3.0

Plus `scripts/unleash-uninstall.sh` (manifest-driven mechanical uninstall) and the `.unleash/` runtime directory convention documented in `references/unleash-knowledge.md` §8.

The full design specification for the complete toolkit is documented at `docs/superpowers/specs/2026-04-24-unleash-toolkit-design.md` in the present-tools repository.

## License

Licensed under the MIT License. See [LICENSE](LICENSE) for details.
