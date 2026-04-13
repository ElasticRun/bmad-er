# Graphify — Codebase Knowledge Graph

Build and query a knowledge graph from code, docs, and design artifacts. Use when the user says "build the graph", "graphify", "update the knowledge graph", or at sprint start to give all BMAD workflows structural codebase awareness.

## What This Does

[Graphify](https://github.com/safishamsi/graphify) reads your codebase and produces:

- `graphify-out/GRAPH_REPORT.md` — god nodes, communities, surprising connections
- `graphify-out/graph.json` — queryable graph (nodes, edges, relationships)
- `graphify-out/graph.html` — interactive visual explorer

BMAD workflows (`dev-story`, `quick-dev`, `code-review`, `create-story`, `create-architecture`) automatically read the graph report when it exists. No extra steps during development.

## Prerequisites

```bash
pip install graphifyy
```

## Usage

### Build the graph (sprint start or after major changes)

Run in the project root:

```
/graphify .
```

This builds the full graph. Uses AST parsing for code (no LLM), LLM for docs/images. Cached — re-runs only process changed files.

### Install always-on rule (one time per project)

For Cursor:
```bash
graphify cursor install
```

For Claude Code, create `CLAUDE.md` with:
```markdown
Before answering architecture or codebase questions, read graphify-out/GRAPH_REPORT.md for god nodes and community structure.
```

### When to rebuild

| Trigger | Action |
|---|---|
| Sprint start | Full rebuild: `/graphify .` |
| Added new docs, specs, or design artifacts | Full rebuild: `/graphify .` |
| Day-to-day development | No rebuild needed. Workflows read the existing graph. |
| Major refactor (new modules, renamed files) | Full rebuild: `/graphify .` |

### Query the graph

```bash
# Find what depends on a module
graphify query "what depends on the auth module?"

# Trace path between two components
graphify path "UserService" "PaymentGateway"

# Explain a node's role
graphify explain "WarehouseController"
```

## How BMAD Workflows Use It

| Workflow | What it reads | Why |
|---|---|---|
| `dev-story` | GRAPH_REPORT.md + graph.json | Navigate to relevant files, trace callers/callees before modifying functions |
| `quick-dev` | GRAPH_REPORT.md + graph.json | Find relevant modules during investigation, avoid grepping blind |
| `code-review` | GRAPH_REPORT.md | Understand blast radius — which modules depend on changed files |
| `create-story` | GRAPH_REPORT.md + graph.json | Write accurate Dev Notes with real file paths and dependencies |
| `create-architecture` | GRAPH_REPORT.md | Ground truth of existing codebase structure for brownfield projects |

If `graphify-out/` doesn't exist, all workflows skip the graph step gracefully. Nothing breaks.
