---
name: using-unleash
description: Use when the user mentions Unleash, harness design, or starts multi-step coding work that may benefit from intent → spec → plan → implement → review discipline — establishes the chain rules (sequential ordering, scope boundary at committed code, fresh-context reviews, archiving-vs-reporting routing) before any other unleash:* skill is invoked.
---

# Using Unleash

> Set the chain rules once, before any Unleash skill runs.

<SUBAGENT-STOP>
If you were dispatched as a subagent to execute a specific Unleash task — an implementer dispatched by `unleash:implementing`, a fresh reviewer dispatched by `unleash:archiving` or `unleash:reporting`, or any other narrowly-scoped subagent — skip this skill. The dispatcher already curated your context; the chain-level rules below would either be redundant or actively harmful inside a focused subagent.
</SUBAGENT-STOP>

<EXTREMELY-IMPORTANT>
Once an Unleash skill applies:

1. **The chain is sequential.** brainstorming → debating → planning → implementing → {validating → walking-through → archiving} OR reporting. Do not jump to a later skill if the artifact it consumes (brainstorm.md, spec.md, plan.md, `.unleash/manifest.json`) has not been produced and committed. The artifact, not chat narration, is the contract between skills.

2. **The chain stops at committed code.** Deployment, CI/CD pipelines, pushing to remote, release tagging, going-live operations, and production smoke tests are out of scope for every Unleash skill. If the user asks for these, complete the in-scope chain and stop — do not extend.

3. **No skill auto-advances to the next.** Each Unleash skill ends with the artifact committed and a handoff to the user. The user invokes the next skill when ready. This holds even when the next step seems obvious; auto-advance erodes the user-review checkpoint that catches mistakes cheaply.

4. **The two end-of-life skills are mutually exclusive.**
   - `unleash:archiving` — used when `.unleash/manifest.json` exists (a runtime harness was installed)
   - `unleash:reporting` — used when no manifest exists (B-layer-only, single coding task)
   - Each STOPs and redirects to the other if the wrong fit is detected. Do not invoke both.

5. **Reviews use fresh-context subagents.** `unleash:validating`, `unleash:archiving`, and `unleash:reporting` dispatch reviewers via the Agent tool with strict context isolation. The reviewer sees only the inputs the dispatching skill explicitly hands it. This isolation is the chain's auditability guarantee.
</EXTREMELY-IMPORTANT>

## Instruction Priority

Unleash chain rules govern AI behavior; user instructions always come first.

1. **User's explicit instructions** (CLAUDE.md, AGENTS.md, direct requests) — highest
2. **Unleash chain rules** (this skill, individual `unleash:*` skills) — override default Claude Code behavior where they conflict
3. **Default Claude Code behavior** — lowest

If the user says "skip the spec, just implement the change" and the chain says "always produce a spec," follow the user. State the deviation briefly so it is not silently absorbed; do not insist on the chain after the user has opted out.

## When Unleash applies

Unleash is the right tool when the work has **all three** of:

- **Design surface** — the change benefits from up-front structure (a spec, a plan), not just a single mechanical edit
- **Multiple steps** — the work breaks into more than one commit or one subagent dispatch
- **Audit or re-use value** — someone (the user, a reviewer, a future maintainer) will want to know what was decided and why

It is **not** the right tool when:

- The user is asking a question, not making a change
- The change is a single mechanical edit (rename, formatting, dependency bump, typo fix)
- The user explicitly opts out ("don't run the chain, just do it")
- The request is purely about deployment, CI/CD, or production operations — these are out of scope for Unleash regardless of structure or complexity

When ambiguous, ask once: *"This looks Unleash-shaped — want me to run it through the chain (brainstorming → debating → planning → ...) or handle it directly?"* Honor the answer.

## Workflow shape

Unleash supports two end-to-end shapes. The shape is **not declared up front by this skill** — it emerges from `unleash:debating` (which captures intent) and `unleash:implementing` (which either does or does not write a manifest):

| Shape | Characteristic | End-of-life skill |
|---|---|---|
| **Runtime harness** | Installs runtime artifacts: phase configs in `.unleash/phases/`, guardian prompts in `.unleash/guardians/`, hooks. Produces `.unleash/manifest.json` during implementing. | `unleash:archiving` |
| **Single coding task** | Dialogue discipline only (brainstorm → spec → plan → implement → done). No runtime artifacts; no manifest. | `unleash:reporting` |

What this skill enforces is: **don't pick the wrong end-of-life skill**. Check for `.unleash/manifest.json` before invoking either one. Each end-of-life skill self-checks and redirects, but the pre-flight check is cheap.

## The chain

```
brainstorming → debating → planning → implementing → {
    runtime harness  →  validating → walking-through → archiving
    single task      →  reporting
}
```

| Skill | Consumes | Produces |
|---|---|---|
| `unleash:brainstorming` | user intent + project tree | `docs/unleash/brainstorm/<date>-<slug>.md` |
| `unleash:debating` | brainstorm.md | `docs/unleash/specs/<date>-<slug>.md` (with `testing_mode` field) |
| `unleash:planning` | spec.md | `docs/unleash/plans/<date>-<slug>.md` |
| `unleash:implementing` | plan.md | code + commits + (if runtime harness) `.unleash/manifest.json` |
| `unleash:validating` | manifest + harness | validation report |
| `unleash:walking-through` | validated harness | walkthrough record |
| `unleash:archiving` | manifest + lifecycle artifacts | archive bundle + fresh-reviewer audit |
| `unleash:reporting` | spec.md + filtered git diff | report.md + fresh-reviewer audit |

A user starting fresh begins at `unleash:brainstorming`. A user resuming partway through begins at the skill whose input artifact already exists and is committed.

## Anti-patterns: rationalizations to recognize

These thoughts feel reasonable in the moment and degrade the chain when acted on. Recognize them as rationalizations and reject them.

> **Thought:** "The user already described the task in chat — I can skip brainstorming and go straight to debating."
> **Rebuttal:** Chat narration is not a brainstorm artifact. `unleash:debating` consumes a written, committed brainstorm.md whose Phase A summary is auditable. Skipping brainstorming means debating starts without that grounding, the spec it produces is built on user narration rather than observed project context, and the plan that follows will encode assumptions the project's real state contradicts. The artifact, not the conversation, is the contract.

> **Thought:** "The plan is committed and the user obviously wants me to start implementing — auto-invoke `unleash:implementing` now."
> **Rebuttal:** Auto-advance erodes the user-review checkpoint that each skill's Termination HARD-GATE exists to preserve. The user inspects each artifact before letting the next stage consume it; that inspection is the only place certain mistakes (mis-grouped tasks, wrong testing_mode, scope creep into deployment) can be caught cheaply. Auto-advance moves the catch-point to after a subagent has already spent tokens — the expensive place.

> **Thought:** "The user said implementation is done; I'll wrap it up by archiving even though no manifest exists."
> **Rebuttal:** `unleash:archiving` consumes `.unleash/manifest.json`. Without it, archiving has nothing to bundle and the skill will STOP at its precondition check. The correct end-of-life skill for B-layer-only work (no runtime harness installed) is `unleash:reporting`, which consumes spec.md + filtered git diff instead. The two skills produce different artifacts for different shapes of work — picking the wrong one is not a near-miss, it is the wrong skill.

> **Thought:** "After implementation lands, I'll also help the user push to remote / set up CI / tag the release."
> **Rebuttal:** Unleash stops at committed code (enforced since v0.2.1). Deployment, CI/CD, push, release tagging, and going-live operations are explicitly out of scope. Extending past the boundary is not "being helpful" — it is taking action in a domain where the user's organizational context (release process, approvals, secrets, environments) is invisible from chat. Complete the in-scope chain. Tell the user the in-scope work is done and stop.

> **Thought:** "I remember what `unleash:validating` does — I can produce a validation report inline without invoking the skill."
> **Rebuttal:** Skills evolve. `unleash:validating` v0.3.0 runs 6 invariant checks plus 2 generic checks against a manifest, with a specific output format and re-runnability guarantee. Memory of "what validating does" cannot replace its current behavior, and inline reproduction skips the fresh-context isolation that makes the skill's output auditable. Invoke the skill; do not paraphrase it.

> **Thought:** "This is a small bug fix — running the whole chain is overkill."
> **Rebuttal:** Possibly correct. The decision is the user's, not the skill's. If the change is a genuinely mechanical edit, Unleash should not be used at all — say so and handle it directly. If the change has design surface (root cause is contested, the right approach is unclear, or the fix could regress related code), the chain is appropriate and "overkill" is the rationalization. The honest test: would you write a one-paragraph spec before changing the code? If yes, the chain applies.

> **Thought:** "The user's request is borderline — I'll start invoking unleash:brainstorming and see if it sticks."
> **Rebuttal:** Invoking brainstorming commits the user to a chain whose minimum cost is the dialogue itself plus the artifact review. Borderline cases deserve the one-question check ("Want me to run this through the chain or handle it directly?") before commitment, not implicit conscription into a workflow they did not ask for.

## Cross-skill discipline (the universal rules)

Every Unleash skill enforces these. Treat them as invariants of the chain, not as advice:

- **Each skill stops with the artifact committed and a handoff to the user.** No auto-advance.
- **Reviews use fresh-context subagents.** Reviewers see only what their dispatching skill explicitly hands them — never the conversation history, never the implementer's reasoning, never (in reporting's case) commit messages. Preserving this isolation is non-negotiable.
- **Scope ends at committed code.** Repeated from EXTREMELY-IMPORTANT because it is the most-violated rule: deployment, CI/CD, push, release operations are out of scope. Each skill's Termination section enforces this with a HARD-GATE.
- **`testing_mode` is a spec field, not a default.** `unleash:debating` v0.2.1 captures the user's chosen testing approach (A: TDD / B: manual checklist / C: skip / D: other). `unleash:planning` v0.3.2 honors it by branching the Test phase shape. Do not silently coerce a B-mode (manual checklist) project into pytest TDD.
- **Mutual exclusion of archiving and reporting.** Detected by manifest presence. Do not invoke both.

## Long-duration dialogue guard

When any Unleash skill has exchanged more than 8 messages with the user (counting from the skill's first user-facing message):

**Before responding to the user's latest message, the skill MUST:**
1. Re-read `docs/unleash/specs/<latest-spec>.md` from disk (if a spec exists)
2. Re-read `docs/unleash/plans/<latest-plan>.md` from disk (if a plan exists)
3. Output an **Anchor Summary** of no more than 5 bullet points:
   - What the harness was originally designed to do (from spec)
   - What decisions are committed and cannot change without user approval (from spec)
   - What the current turn is actually about
   - Whether the current turn threatens any committed decision
   - Recommended stance: proceed / pause-for-confirmation / reject-as-out-of-scope

This Anchor Summary is not shown to the user unless the stance is pause-for-confirmation or reject. It is an internal reset mechanism.

## Decision flow

```
User starts a task
      │
      ▼
Has design surface AND multiple steps AND audit value?
      ├── No  →  Handle directly. Unleash does not apply.
      └── Yes
            │
            ▼
      Out-of-scope (deployment, CI/CD, push, release ops)?
      ├── Yes →  Decline the out-of-scope portion;
      │          offer to handle in-scope work via the chain.
      └── No
            │
            ▼
      What artifact already exists for this task?
      ├── nothing                       →  unleash:brainstorming
      ├── brainstorm.md committed       →  unleash:debating
      ├── spec.md committed             →  unleash:planning
      ├── plan.md committed             →  unleash:implementing
      ├── code committed + manifest     →  unleash:validating
      │     (then walking-through, then archiving)
      └── code committed + no manifest  →  unleash:reporting
```

## Checklist

This skill sets up discipline; it does not run phases. Complete in order:

1. Determine whether Unleash applies (gating section). If no, exit and handle the task directly.
2. Determine which artifact already exists; pick the entry skill from the decision flow.
3. State briefly which Unleash skill you are about to invoke and why ("Brainstorm-shaped, no prior artifact — invoking unleash:brainstorming"). One sentence.
4. Invoke that skill via the Skill tool.
5. Do not invoke a second Unleash skill in the same turn unless the user explicitly asks. Each skill's Termination handoff is the user's checkpoint.
