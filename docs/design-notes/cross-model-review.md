# Design Note: Cross-Model Review

**Status:** Open question, not yet acted on.
**Raised:** 2026-04-25 by user's assistant during a v0.3.2 review discussion.

## The concern

Unleash's review skills (`unleash:validating`, `unleash:archiving`'s reviewer, `unleash:reporting`'s reviewer) all run with **fresh context** — but if the same LLM (Claude) drives both the implementer AND the reviewer, model-level biases survive context isolation. Self-preference bias in LLM-as-judge is a documented phenomenon: same-model judges have detectable preference for same-model outputs.

## What fresh context handles vs doesn't

| Bias category | Fresh context eliminates? |
|---|---|
| Implementer's stated reasoning | ✅ |
| Commit message framing | ✅ |
| Same-conversation sycophancy | ✅ |
| Context accumulation drift | ✅ |
| Training-data overlap blindspots | ❌ |
| RLHF preference convergence | ❌ |
| Style-affinity self-preference | ❌ |
| Systematic failure-mode blind spots | ❌ |
| AI-tell detection | ❌ |

## Severity by Unleash skill

| Skill | Reviewer task type | Cross-model bias risk |
|---|---|---|
| `unleash:validating` | Structural invariant checks (allowlist closure, dependency closure, etc.) | **Low** — formal binary checks; little judgment surface |
| `unleash:archiving`'s reviewer | 6-dimension narrative judgment (faithfulness, quality, guardian robustness, etc.) | **High** — pure judgment territory |
| `unleash:reporting`'s reviewer | 4-dimension narrative judgment (faithfulness, quality, observability, lessons) | **High** — same |

## Implementation options

### Layer 1: Status quo (Claude subagent + fresh context)
- ✓ Eliminates context bias
- ✗ Doesn't eliminate model bias
- Loop preserved

### Layer 2: Bash → external CLI (single-turn)
- ✓ Eliminates both context and model bias
- ✗ Loses agent loop (no Read tool, no iterative exploration)
- Acceptable for `unleash:reporting` (single-turn-feasible: spec + diff + notes all fit in prompt)
- Marginal for `unleash:archiving` if implementation snapshot is small
- **Not viable** for `unleash:validating` (needs multi-file dynamic exploration)

### Layer 3: Anthropic-API-compatible router + per-subagent model parameter
- ✓ Eliminates context AND model bias
- ✓ Preserves agent loop (router-routed model still has tool use)
- Requires: a router (LiteLLM, OpenRouter, internal AI gateway) implementing Anthropic Messages API, with `model` parameter dispatching to different backends
- Setup cost: medium (deploy/configure router); per-skill cost: zero (skills already accept `model` parameter)
- This is the cleanest path for archiving + validating

### Layer 4: Per-session backend swap via `ANTHROPIC_BASE_URL`
- Set env var before launching Claude Code → entire session uses different backend
- Coarsest grain (whole session, not per-subagent)
- Useful for "I'm specifically running an audit session, want it driven by GPT/Gemini/DeepSeek"

## Open question: does Claude Code's Agent tool inherit `ANTHROPIC_BASE_URL`?

Strong suspicion yes (subagents share the parent's API client), but unverified. Needs experiment:
1. Export `ANTHROPIC_BASE_URL` to an Anthropic-compatible endpoint
2. Launch Claude Code, dispatch a subagent
3. Confirm subagent's response came from the alternative backend

Anthropic-API-compatible providers known to exist:
- DeepSeek (anthropic-compat endpoint)
- Z.ai / GLM
- LiteLLM (open-source, self-hostable)
- OpenRouter (SaaS)
- Various corporate AI gateways

## Proposed empirical test (before any implementation)

Before committing to architectural changes, run a real comparison:

1. Take a previously-tested Unleash fixture (e.g., the v0.3.1 logger fix or v0.3.0 validating fixture)
2. Run the reviewer task with two backends:
   - Claude (current behavior)
   - GPT-4 / Gemini / DeepSeek (whichever is most accessible)
3. Compare the two reviews:
   - Does the cross-model review catch issues Claude missed?
   - Are the differences substantive or stylistic?
   - Is one obviously better at this task?

If cross-model review catches at least one true-positive issue Claude missed in 3+ test cases, the bias is real and worth investing engineering into. If reviews are similar, the current design is sufficient.

## Recommendation when revisited

If empirical test shows real value:
1. **Lowest cost**: Add `unleash:reporting` env-var-based reviewer override (Layer 2) — simplest patch, single skill, opt-in
2. **Medium**: Add Layer 3 (router) for `unleash:archiving` — keeps agent loop
3. **Skip `unleash:validating` cross-model** — bias risk is low; effort high

If empirical test shows no significant difference:
- Document the test result here for future reference
- Don't implement; current design is sufficient

## Related considerations

- **Subagent ≠ single-turn LLM call.** A bash-curl reviewer downgrades from agent loop (multi-turn, tool use) to single-turn. For tasks where all inputs fit in one prompt (like reporting's reviewer), this is acceptable. For validating, it's not.
- **Cross-model adds operational cost**: API keys for multiple providers, billing across providers, potentially network paths through proxies.
- **The `model` parameter on Claude Code's Agent tool already exists**; switching backends per-subagent only requires an Anthropic-compat router behind `ANTHROPIC_BASE_URL`. No skill-file changes needed if router is in place.

