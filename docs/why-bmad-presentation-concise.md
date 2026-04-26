---
marp: true
theme: default
paginate: true
title: Why BMAD (concise)
---

# Why BMAD

A framework for AI-assisted development.
**First-time-right code, not "let me try that again".**

Our customised version, and why every team should be on it.

---

## Chatting vs using

Two ways to put AI into your dev loop.

**Chatting.** Type a prompt, eyeball the answer, ship. The work lives in your terminal scrollback. Nobody else can pick it up. Same task next week, different person, different output. The model is a smart Slack contact you bug for help.

**Using.** Work flows through a defined surface: a story spec, a skill, a validation loop, a cross-model review. Output is reviewable, shareable, reproducible. The model is a peer engineer operating under rules of engagement.

Most "AI is overhyped" complaints are complaints about chatting.

A framework is what turns the model into a tool you can build a team around.

---

## Three reasons it pays off

**Quality.** First-time-right code. Curated context per step beats dumped context every time. No invented paths. No missed ACs. Cross-model review catches the bug pre-commit, not in QA.

**Team working.** Artifacts replace folklore. Story specs, `project-context.md`, `sprint-status.yaml`, shared skills. The next person picks up where you left off. Output reads the same regardless of who prompted it. Onboarding stops being "ask Priya about auth."

**Cost.** Drops out as a side effect. ~70% token cut per workflow. Better cache hits. Fewer retries. Real money at headcount.

Quality and team are why we adopt. Cost is the kicker, not the reason.

---

## The two levers: Reduce and Delegate

Chatting vs using is the *what*. **R&D is the *how*.**

Every framework move comes down to one of two things.

**Reduce.** Less noise hits the model. Curate context per task. Cut what doesn't earn its place. Story specs, sharded PRDs, graph queries, trimmed skill prompts. All R.

**Delegate.** Work doesn't all have to land in one context window. Push it to a fresh subagent. A different model. A parallel session. Cross-model review is delegation. Sub-agents are delegation. Auto-sprint is both stacked.

That's the whole game. Reduce. Delegate. R&D.

When something feels off in your AI workflow, ask "is this an R problem or a D problem?" The answer is almost always one of them.

---

## What "going off-framework" actually feels like

Engineer dumps half a spec into chat. Then:

- Model invents a file path that doesn't exist
- Reads the right file, misses three callers, breaks them
- Skips an AC because it was at line 380 of the spec
- Tests pass, prod migration fails because of an edge case nobody framed
- Same task next sprint, different person → completely different output

The model isn't broken. **The context is.**

Most devs never look at what's loaded. They blame the model when "it starts hallucinating".

(Run `/context` in Claude Code once. You'll be surprised what's already crowding the buffer before you even type.)

---

## "But the model has 1M context"

True. Concise context still produces **better answers**. Three reasons:

1. **Attention degrades with length.** Models attend best to the start and end. Stuff in the middle gets dropped. A 50k-token spec hides the AC that matters at token 28,000. The model doesn't see it. You ship the bug.

2. **Hallucinations scale with noise.** Every irrelevant file, every stale chat turn, every unused tool definition is a distractor. More noise in = more chances for the model to anchor on the wrong thing.

3. **Yes, it's also cheaper and faster.** That's the bonus. Not the point.

Big context window is a safety net. Quality still comes from choosing what to load.

---

## A framework's job: load the right context, get it right the first time

Same task, two paths:

| Step | Naive (raw chat) | BMAD |
|---|---|---|
| `create-story` | full PRD + arch dump + vague desc | PRD slice + epic + targeted arch |
| `dev-story` | bulk file dumps + grep loops | story spec + project-context + targeted reads |
| `code-review` | diff + full spec + grep loops | diff + spec section + graph blast-radius |
| `auto-sprint` | one bloated accumulating session | 3 fresh subagents, zero cross-phase pollution |

**What the dev sees:** fewer hallucinated paths. Fewer missed ACs. Output that reads the same regardless of who prompted it.

(Token count drops ~70% as a side effect. Cost is the smallest reason this works.)

---

## Without a framework, vs with BMAD

**Without:**

- Engineer dumps half a spec into chat. Model guesses the rest, invents file paths, breaks 3 callers it never saw.
- "Review" is whoever wrote the prompt squinting at the diff.
- Same task, different person, different week → completely different output.

**With BMAD:**

- Story spec is the contract. Dev Notes pre-curate the right context.
- Cross-model review is a real second opinion.
- Repeatable. Auditable. Composable into auto-sprint.

You stop relying on whoever happens to be at the keyboard.

---

## Our BMAD = stock + three force multipliers

Stock BMAD is good scaffolding. We added:

1. **Graphify** — codebase becomes queryable
2. **Auto-sprint** — fresh contexts per phase, different model on review
3. **Caveman** — token discipline across 25+ skills

None of these exist in stock BMAD. They compound.

Next three slides: one each.

---

## Multiplier 1: Graphify

`uvx graphify update .` builds an AST graph of the repo: files, functions, classes as nodes; calls, imports, inheritance as edges.

Then any skill can ask:

```bash
graphify query "what depends on the auth module?"
graphify explain "registerUser"
graphify path "AuthGuard" "request"
```

No more grep loops. No more "I forgot module X imports this."

The model gets real dependency facts before touching code, without re-reading the codebase into context. Curated context, on demand.

**Lever:** R. Substitutes compact graph facts for raw codebase reads and grep loops.
**Pillars hit:** Quality (no invented paths) + Team (queryable codebase replaces tribal knowledge).

---

## Multiplier 2: Auto-sprint with cross-model review

One sprint command. Three models. Each phase in a fresh subagent.

| Phase | Model | Why |
|---|---|---|
| Implement | Sonnet | Fast, capable, cheap per token |
| Test | Haiku | Mechanical (tsc + vitest), cheapest |
| Review | Opus | Deep reasoning, fresh eyes |

The "different model on review" is the load-bearing part. The implementer cannot rubber-stamp itself.

Each subagent starts with a clean context. No leftover impl reasoning leaking into review. No "I'll fix the test later" loophole because a different model runs the tests.

**Lever:** D, twice. Process delegation (fresh subagent per phase) and model delegation (different model on review). The two stacked is what catches bugs same-model self-review never would.
**Pillars hit:** Quality (cross-model catches bugs pre-commit) + Team (any dev gets the same review floor; no senior reviewer bottleneck).

---

## Multiplier 3: Caveman — less ceremony, sharper output

We audited 25+ skills and stripped out:

- Duplicate `<critical>` directive blocks (instructions stated twice in the same file)
- Decorative completion banners with "Next steps" sub-lists
- Identical 30-line workflow boilerplate copy-pasted across five skills

Less noise in the model's input means more attention on your actual problem. Skill instructions read cleaner. Outputs follow them more reliably.

(Workflow runs also come out ~700-1,100 tokens lighter. We'll take it.)

**Lever:** R. Strips ceremony from skill instructions so signal earns the tokens it costs.
**Pillars hit:** Cost (the obvious one) + Quality (less noise in attention, sharper output). Cost is the side effect, attention is the win.

---

## Real evidence: Story 7-2 (this week)

Idempotent migrations runner.

- **Sonnet impl:** 6 files changed, 25/25 tests pass, typecheck clean.
- **Haiku verify:** full suite green.
- **Opus review:** caught one AC deviation. Spec required `Migration <id> failed: <msg>`. Impl wrote `Migration failed: <msg>` without the id.

Same model writing and reviewing would have shipped that bug. Cross-model caught it pre-commit.

Story 7-3 (registration + Argon2id) the next day: same flow, 10 files, 47/47 tests, no blockers.

This is repeatable, not anecdotal.

---

## The whole loop, on one slide

Once per project:

```bash
graphify update .             # build the graph
sprint-planning               # generate sprint-status.yaml
```

Per story:

```bash
create-story <epic>-<n>       # spec the next story
auto-sprint                   # impl + test + review + commit
```

Auto-sprint runs unattended for `ready-for-dev` stories. When in doubt about what's loaded: `/context` in Claude Code.

---

## Your first week on BMAD

**Day 1.** Install. Run `graphify update .` on your service. Run `/context` in your next chat session. Notice what's loaded.

**Day 2.** Pick one ready story from the backlog. Run `create-story` on it. Read the generated spec. This is what curated context looks like.

**Day 3.** Run `auto-sprint` on that story. Watch the three phases. Read the Opus review output before committing.

**Day 5.** Compare against your last ad-hoc PR: how many bugs did Opus review catch pre-commit? How many "the model invented this file" moments did you have? How does the diff feel?

If after one week you don't see the delta, come find me. I'll buy you coffee and we'll dig into your workflow.

---

## Questions I expect you to ask

**"My codebase is too dynamic for graphify."**
Graphify catches what AST can see (calls, imports, inheritance). Even partial coverage beats grep loops. Run it, see what it gets right.

**"This adds ceremony I don't need for small changes."**
That's what `quick-dev` is for. Story loop is for non-trivial work. Use the right tool.

**"What if the spec is wrong mid-sprint?"**
`correct-course` exists for exactly this. Mid-sprint scope changes get re-baked into the spec, not patched in chat.

**"I prompt better than the framework."**
Maybe. But your colleague three desks over doesn't, and your output is no longer reproducible. The framework's job is the floor, not the ceiling.

**"I trust Opus to review its own work."**
Story 7-2 says you shouldn't. Same-model self-review has a known confirmation bias. Cross-model is the load-bearing part.

---

## TL;DR

Two ways to put AI in your dev loop. **Chatting** works for one person on one task. **Using** a framework works for a team shipping a product.

**Two levers underneath: Reduce and Delegate.** R&D. Cut noise into the context, push work across agents and models. That's the whole game.

**Three outcomes:**

- **Quality.** First-time-right code. No invented paths. No missed ACs. Bugs caught pre-commit by a different model.
- **Team working.** Reproducible regardless of who's at the keyboard. Artifacts replace tribal knowledge. Onboarding compresses from weeks to days.
- **Cost.** ~70% token cut per workflow as a side effect.

**Our BMAD adds:**
- Code awareness (graphify) → R, kills invented file paths
- Cross-model verification (auto-sprint) → D, bugs caught pre-commit
- Less ceremony (caveman) → R, model focuses on your problem

Quality and team are the reasons. Cost is the kicker.

**Chatting vs using. Reduce and delegate. Adopt it, don't argue with it.**

We ship faster, and we ship right.

---

## Appendix: full command palette

| Phase | Command | What it does |
|---|---|---|
| **Plan** | `create-prd` | Guided PRD workflow |
|  | `create-architecture` | Tech stack and component design |
|  | `create-epics-and-stories` | Break PRD into epics + stories |
|  | `sprint-planning` | Generate `sprint-status.yaml` |
| **Per story** | `create-story <id>` | Spec next story (Dev Notes + ACs) |
|  | `dev-story` | Implement (red-green-refactor) |
|  | `code-review` | Adversarial parallel-layer review |
|  | `auto-sprint` | Autonomous impl + test + review + commit |
|  | `quick-dev` | Ad-hoc dev outside the story loop |
| **Track** | `sprint-status` | Where are we, what's stale |
|  | `correct-course` | Handle mid-sprint scope changes |
|  | `retrospective` | Post-epic review |
| **Codebase** | `graphify update .` | Build/refresh `graph.json` |
|  | `graphify query "<q>"` | Natural-language graph question |
|  | `graphify explain "<sym>"` | Callers and callees of a symbol |
|  | `graphify path "<A>" "<B>"` | Shortest dependency chain |

Reference, not a tour. The 90% workflow is the previous slides.
