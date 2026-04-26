---
marp: true
theme: default
paginate: true
title: Why BMAD (and why this version)
---

# Why BMAD

A framework for AI-assisted development.
And why we run our customised version of it.

---

## The thing most devs miss: context is finite

When you "chat with the model," you're filling a fixed buffer.

That buffer holds:

- The system prompt and tool definitions
- Whatever skills/rules the IDE auto-loaded
- Memory and project files pulled in
- Every message and tool result so far
- Your actual task

Every token spent on noise is a token NOT spent on your problem.

Most devs never look at this. The model just "feels slower" or "starts hallucinating" and they blame the model.

---

## How to actually see your context

**Claude Code (verified)**

| Command | What it shows |
|---|---|
| `/context` | Visual grid of context usage by category (system prompt, tools, memory, skills, messages, free space) |
| `/usage` (aliases: `/cost`, `/stats`) | Session token spend, plan limits, activity |
| `/compact [focus]` | Summarises conversation to free context, optional focus instructions |
| `/clear` | Nukes the conversation and starts fresh |

Run `/context` mid-session. You will be surprised what's in there.

---

## How to see context: Cursor

Cursor has no direct `/context` command. Token info is surfaced indirectly:

- **Chat header chips** — files, folders, symbols you've attached
- **Three-dot menu** under any AI response → hover for context size
- **Dashboard → Usage** for aggregate token/cost tracking
- **Cursor Settings → Indexing** for codebase index status and re-index trigger

Add context explicitly with `@`-mentions:

`@filename` · `@folder/` · `@symbol` · `@Docs` · `@Past Chats`

Note: Cursor 2.0 removed `@Web`, `@Git`, `@codebase`, `@Definitions` etc. The agent now self-retrieves via "Dynamic Context Discovery" instead of front-loading.

---

## "But the model has 1M context"

True. And concise context still produces better results. Three reasons:

1. **Attention degrades with length.** Models attend best to the start and end of context. Stuff in the middle gets dropped (the "lost in the middle" effect). A 50k-token spec hides the bit that matters at token 28,000.

2. **Cost scales linearly with input.** 1M tokens at Opus rates is real money per call. A focused 30k context costs ~3% of that and runs faster.

3. **Cache hits prefer stable, focused context.** Anthropic's prompt cache rewards stable prefixes. Bloated, churning context keeps missing cache and pays the full input rate every time.

Big context window = safety net, not a feature you should burn through.

---

## BMAD's job: curate context per task

A framework's main job is loading the right context for the right step. Rough token estimates against the ad-hoc baseline:

**`create-story`**
- BMAD: PRD slice + epic + prior stories + targeted arch sections → **~6k tok**
- Naive: full PRD + full arch dump + vague description → ~25k tok
- Saved: **~19k tok (~75%)**

**`dev-story`**
- BMAD: story spec (Dev Notes + ACs + File List) + `project-context.md` + targeted code reads → **~12k tok**
- Naive: vague task + bulk file dumps + grep loops → ~40k tok
- Saved: **~28k tok (~70%)**

**`code-review`**
- BMAD: diff + spec section + graph `{blast_radius}` (importers, callers) → **~8k tok**
- Naive: diff + full spec + grep loops to find callers → ~25k tok
- Saved: **~17k tok (~70%)**

**`auto-sprint`**
- BMAD: 3 fresh subagents, each ~30k focused; zero cross-phase pollution
- Naive: one accumulating session (impl reasoning + test output + fix loops + review all in one context) → 120k+ by review time
- Saved: **~50–90k tok per story**

*Estimates from observed sessions; exact savings scale with PRD size and codebase.*

---

## Without a framework vs with BMAD

Without:

- Engineer dumps half a spec into chat. Model guesses the rest, invents file paths, breaks 3 callers it never saw.
- "Review" is whoever wrote the prompt squinting at the diff.
- Same task, different person, different week → completely different output.

With BMAD:

- Story spec is the contract. Dev Notes pre-curate the right context.
- Cross-model review is the second opinion.
- Repeatable. Auditable. Composes into auto-sprint.

You stop relying on whoever happens to be at the keyboard.

---

## Why repeatability beats speed

A flaky 10-minute task is worse than a reliable 30-minute one.

- Reliable workflows compose. Flaky ones don't.
- Reliable workflows fail loudly. Flaky ones fail silently in prod.
- Reliable workflows let you delegate, automate, scale.

BMAD trades some upfront ceremony for downstream predictability. The trade pays back from story 3 onward.

---

## Solo vs team: where BMAD pays off most

**Solo dev**: you hold context in your head; ad-hoc prompting works. Style drift only hurts future-you. A flaky workflow costs one person.

**Team on a large product**: every benefit above multiplies, every cost compounds.

| Pain at scale | What BMAD fixes |
|---|---|
| Onboarding takes weeks | New dev runs `auto-sprint` on a `ready-for-dev` story without tribal knowledge |
| Style drift across 10+ devs | `project-context.md` + Dev Notes pin patterns; `code-review` flags violations |
| "Ask Priya before touching auth" | `graphify query` makes the whole codebase queryable by anyone |
| Slack-driven status tracking | `sprint-status.yaml` is the single source of truth |
| Code archaeology after 6 months | `AI-Phase`, `AI-Tool`, `Story-Ref` git trailers tied to sprint history |
| Cross-team coupling surprises | `graphify path` between modules shows real call chains across boundaries |
| Token cost at headcount | Caveman cuts × 30 devs × every workflow = real money |

The bigger the team and codebase, the more BMAD's overhead pays for itself.

---

## Our version: three force multipliers on top of stock BMAD

1. **Graphify** — the codebase becomes queryable
2. **Auto-sprint** — multiple models, fresh contexts, cross-verification
3. **Caveman** — token economics tuned across the whole skill catalogue

Stock BMAD has none of these. They compound.

---

## Multiplier 1: Graphify

`uvx graphify update .` builds an AST-based graph of the repo.

- Files, functions, classes as nodes
- Calls, imports, inheritance as edges
- Communities and god-nodes ranked

Then any skill can ask:

```bash
graphify query "what depends on the auth module?"
graphify explain "registerUser"
graphify path "AuthGuard" "request"
```

No more grep loops. No more "I forgot module X imports this." The model gets real dependency facts before touching code, all without re-reading the codebase into context.

This is curated context, on demand.

---

## Multiplier 2: Auto-sprint with cross-model verification

One sprint command. Three models. Each phase in a fresh subagent.

| Phase | Model | Why |
|---|---|---|
| Implement | Sonnet | Fast, capable, cheap per token |
| Test | Haiku | Mechanical (tsc + vitest), cheapest |
| Review | Opus | Deep reasoning, fresh eyes |

The "different model on review" is the load-bearing part. The implementer cannot rubber-stamp itself.

Each subagent starts with a clean context. No leftover impl reasoning leaking into the review.

---

## TDD is enforced, not optional

`dev-story` step 5 runs an explicit red-green-refactor cycle:

1. **RED** — write failing tests first for the task
2. **GREEN** — implement minimal code, confirm tests pass
3. **REFACTOR** — improve structure, keep tests green

DoD checklist requires unit + integration + E2E tests. Auto-sprint's Haiku phase gates the commit on green tests. No green = no commit.

Why this matters for AI-assisted dev:

- **Tests prove it works.** AI hallucinates features that look right. Tests don't lie.
- **Regression safety net.** AI edits drift unpredictably across sessions. Tests catch the drift.
- **Tests become the spec.** Cross-model review checks them against the ACs.
- **No "I'll fix the test later" loophole.** A different model runs the tests. The implementer cannot wave them through.

Without tests, auto-sprint is autocomplete. With tests, it's autonomous shipping.

---

## Real example from this week

Story 7-2 (idempotent migrations runner):

- **Sonnet impl**: 6 files changed, 25/25 tests pass, typecheck clean.
- **Haiku verify**: full suite green.
- **Opus review**: caught one AC deviation. Spec required `Migration <id> failed: <msg>`. Impl wrote `Migration failed: <msg>` without the id.

Same model writing and reviewing would have shipped that bug. Cross-model caught it pre-commit.

Story 7-3 (registration + Argon2id): same flow, 10 files, 47/47 tests, no blockers.

This is repeatable, not anecdotal.

---

## Multiplier 3: Caveman — token economics

We just audited 25+ skills and removed:

- Duplicate `<critical>` directive blocks (stated twice in the same file)
- Emoji-sectioned DoD checklists where plain bullets work
- Decorative completion banners with "Next steps" sub-lists
- Identical 30-line `## WORKFLOW ARCHITECTURE` block copy-pasted across 5 skills

Result: ~700 to 1100 tokens cut per typical workflow run.

50 stories per quarter × 1000 tokens = 50k tokens of pure ceremony saved, before counting Opus review calls.

Multiplied by every team member, every project. Compounds quietly.

---

## What we actually see

Cross-model review catches:

- AC deviations the impl missed (real example: 7-2 stderr format)
- Edge cases buried in spec text
- Pattern violations against existing code

Graphify queries catch:

- Hidden importers before you change a function
- Cross-module coupling worth a path query

Auto-sprint enforces:

- Tests written and green before commit
- One commit per story, conventional message
- Sprint status updated automatically

Consistency without anyone enforcing it manually.

---

## Key BMAD commands at a glance

| Phase | Command | What it does |
|---|---|---|
| **Plan** | `create-prd` | Guided workflow producing the product PRD |
|  | `create-architecture` | Tech stack and component design decisions |
|  | `create-epics-and-stories` | Break PRD into epics + stories backlog |
|  | `sprint-planning` | Generate `sprint-status.yaml` from epics |
| **Per story** | `create-story <id>` | Spec the next story with Dev Notes + ACs |
|  | `dev-story` | Implement one story (red-green-refactor) |
|  | `code-review` | Adversarial review with parallel layers |
|  | `auto-sprint` | Autonomous impl + test + review + commit |
|  | `quick-dev` | Ad-hoc dev for tasks outside the story loop |
| **Track** | `sprint-status` | Where are we, what's next, what's stale |
|  | `correct-course` | Handle mid-sprint scope changes |
|  | `retrospective` | Post-epic review |
| **Codebase** | `graphify update .` | Build or refresh `graph.json` |
|  | `graphify query "<q>"` | Ask the graph a natural-language question |
|  | `graphify explain "<sym>"` | Callers and callees of a symbol |
|  | `graphify path "<A>" "<B>"` | Shortest dependency chain between two symbols |

The 90% workflow is just the next slide. This is the full palette when you need it.

---

## Operating model: how to plug in

Once per project:

```bash
graphify update .             # build the graph
sprint-planning               # generate sprint-status.yaml
```

Per story:

```bash
create-story <epic>-<n>       # spec the next story
auto-sprint                   # impl + test + review + commit
code-review                   # optional human-in-the-loop
```

That's the whole loop. Auto-sprint runs unattended for ready-for-dev stories.

When in doubt about what's loaded: `/context` (Claude Code) or check the chip bar (Cursor).

---

## Why this version vs vanilla BMAD

Stock BMAD is good scaffolding. We extended it with:

- Graphify hooks in `dev-story`, `code-review`, `auto-sprint`, `quick-dev`
- Auto-sprint with cross-model orchestration (not in stock BMAD)
- Caveman cuts across 25+ skills
- Tighter dev-story DoD checklist
- Single source of truth in `bmad-er/` synced to `claude/`, `cursor/`, `.claude/`

The investment compounds. Every cycle gets faster, every review catches more, every token spent goes further.

---

## Asks from the team

1. **Watch your context.** Run `/context` once a session. Get a feel for what's loaded.
2. **Use the workflows as written.** Don't bypass them with raw prompts.
3. **Keep `graph.json` fresh.** `graphify update .` at sprint start.
4. **Run `code-review` with a different model** than `dev-story` used.
5. **When a skill feels heavy**, file it as a caveman cut, not a workaround.

Predictable beats clever. Compounding beats heroic.

---

## TL;DR

Context is finite even at 1M. Concise wins.

Framework's job: load the right context for the right step.

Our version of BMAD adds:

- **Code awareness** via graphify
- **Cross-model verification** via auto-sprint
- **Token discipline** via caveman

Real bugs caught pre-commit. Real time saved per story. Real cost saved per sprint.

Adopt it, don't argue with it, and we ship faster than the team next door.
