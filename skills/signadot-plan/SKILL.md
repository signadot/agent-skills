---
name: signadot-plan
description: >
  Use this skill when the user wants to author, run, or modify a Signadot plan
  — a compiled DAG of action invocations that runs against a cluster (smoke
  tests, request flows, scripted validations, browser automation, image-based
  jobs). The skill points you at the live schema and action catalog so you
  don't hardcode either, and tells you the decision rules the schema can't
  carry — reference-expression grammar, when `routingContext` is required,
  cluster affinity choices. Action-specific rules live on each action's
  body; this skill tells you to read it.
---

# Signadot: Authoring and Running Plans

A *Signadot Plan* is an immutable, compiled DAG of action invocations. Each
step invokes one *action* (a small reusable unit — list the catalog to see
what's available in your org) and wires its inputs from plan params or
upstream step outputs. Once compiled, a plan can be executed many times
with different parameter values.

You don't need to memorize the plan schema or the available actions —
**both are discoverable at runtime** and you should fetch them before
authoring anything.

## Discovery: schema and action catalog first

Before drafting any plan, pull the two things that change per environment.

### 1. Plan schema (org-agnostic, static)

```bash
signadot plan schema
```

Returns the JSON Schema for `PlanSpec` with field-level descriptions. Treat
this as the source of truth for field names, types, what's required, and
what each field means. Re-fetch if anything in this skill conflicts with
what the schema says — the schema wins.

### 2. Action catalog (org-scoped, dynamic)

```bash
signadot plan action list -o yaml
```

Returns the actions visible to the current org. Each entry carries the
action's `id` (use as `action.actionID` in the spec — never the name),
its `spec.body` (full markdown), and parsed metadata under `status`
(description, declared inputs/outputs, schema policy, etc.) — read the
YAML, the field names are self-explaining.

Two fields the skill itself depends on:

- **`status.enabled`** — whether the action is usable in this org *right
  now*. Disabled actions appear in the catalog but `plan create` will
  reject any spec that references them. Filter on this when picking.
- **`spec.body`** — the action's full markdown body. **Read this when you
  pick an action.** It contains the action-specific rules: what each
  input/output means, when to use the action and when not to, how the
  script reads its inputs, anti-patterns to avoid. Usage rules that
  apply to one action only live here, not in this skill.

If the user asks for a capability that no enabled action provides, **say
so explicitly** and offer two options: pick the closest alternative, or
ask the org admin to enable a gated one.

## Mental model

- **Plans are immutable.** Once created, a plan's spec is frozen. The
  server snapshots each step's action contract at create time, so
  updating an action later does not affect plans that already reference
  it. To pick up action updates, author a fresh spec and create a new
  plan.
- **Steps form a DAG.** Step ordering in the array is *not* execution
  order — execution order is derived from the dependency graph implied by
  `args.refs`. A step that references `steps.foo.outputs.bar` runs after
  `foo` completes.
- **Three places to put a value into a step:** `args.values` (literal
  constants — strings, numbers, booleans, fixed JSON), `args.refs` (path
  reference into `params.X` or `steps.X.outputs.Y`), or `extraInputs`
  (a declared additional input the step takes beyond the action's params,
  wired via `args.refs`). A given arg name appears in `values` *or*
  `refs`, never both.
- **Plan params are external; step outputs are internal.** `params.X`
  comes from the caller at execution time. `steps.X.outputs.Y` comes from
  an upstream step. The plan's own outputs (`spec.output`) wire one or
  the other to the plan's external interface.
- **Schema controls how a value reaches an action's working directory.**
  A param or extra_input *with* a schema lands as
  `./context/<name>.json` (raw JSON bytes preserved). *Without* a schema
  it lands as `./context/<name>` (raw text — JSON string values get
  unquoted, but objects/arrays become opaque strings the consumer sees
  as text). The same rule governs drill-in refs on the output side: a
  drill source must declare a schema because the runtime needs to walk
  a parsed value, not a string. When in doubt, declare a schema —
  symptoms of getting this wrong include opaque expression-language
  errors like *"type string has no field X"* downstream.

## Authoring the plan spec

You compose the spec directly — `params`, `steps`, `output`, optional
`cluster` and `runner` — and submit it. Each step references its action
by ID:

```yaml
steps:
- id: send_request
  action:
    actionID: <id from catalog>
  args:
    values:
      url: http://api.example.svc:8080/health
      method: GET
```

The server hydrates the action's `body`, declared `params`, `outputs`,
`extraInputsSchemaPolicy`, and `image` from the registered action at
create time. **Do not embed those fields yourself** — `actionID` is all
a step needs under `action`.

Submit with:

```bash
signadot plan create -f /tmp/plan.yaml -o yaml
```

Validation runs at create time and fails on the first issue. Read the
schema (Discovery, above) for the full field set; the rules below cover
the parts the schema can't fully express.

## Decision rules

### Reference expressions

- **Forms**: `params.<name>`, `steps.<id>.outputs.<name>`, with optional
  drill-in by appending `.field` or `[index]`
  (`steps.send.outputs.capture.response.statusCode`).
- **Refs are path expressions, not general expressions.** No operators,
  function calls, conditionals, or string concatenation. To compose a
  value, use a composing action from the catalog (whichever action
  accepts an expression and emits its result) — its body documents
  when and how to use it.
- **Drill-in requires a schema on the source.** `params.X.field` works
  only if `X` declared a `schema`. `steps.X.outputs.Y.field` works only
  if the action's `\output{Y, schema=...}` declared one. Drill into a
  schemaless source is rejected at compile time.
- **Drill source must be JSON at runtime, ≤1 MB.** Non-JSON outputs
  (binary, plain text) can only be referenced as whole values.

### Action-specific rules: read the action body

Most "when do I use action X / when do I not" rules live on the action
itself (`spec.body`), not in this skill. When you pick an action, **read
its body before wiring it into a step.** It documents the inputs and
outputs, the schema policy, what the script reads from `./context/`,
which environment variables it expects, and the anti-patterns that
come up specifically for that action. Re-read after each action update —
the body is the action author's contract with you.

Cross-action rules (when one action's existence affects how you compose
another) are spelled out on whichever action's body the agent is most
likely to be reading at the moment of the mistake — so if the action
catalog says "don't insert X before this," trust it.

### Routing context: literal vs ref, and when it's required

If the plan acts against a sandbox or route group, **set
`routingContext` on every step that needs the routing key** (request
steps, shell scripts that need `$SIGNADOT_ROUTING_KEY` or
`$SIGNADOT_SANDBOX_NAME`):

- `routingContext.literal` — for hardcoded sandbox/routeGroup/routingKey
- `routingContext.ref.sandboxRef` / `routeGroupRef` / `routingKeyRef` —
  when the value comes from a plan param (e.g.
  `sandboxRef: params.sandbox`)
- `routingContext.ref.anyRef` — polymorphic, plan param holds a
  `RoutingTarget` whose variant is decided at execution time

Forgetting `routingContext` on a request step that hits a sandboxed
service is a silent footgun: the request goes to the cluster baseline,
the sandbox sees no traffic, and the test passes against the wrong code.

### Cluster affinity

`spec.cluster` declares how the plan resolves its target cluster. At most
one field set:

| Field | Use when |
|---|---|
| `fromCluster: <param>` | Plan takes a cluster name directly as a param |
| `fromSandbox: <param>` | Plan takes a sandbox name; cluster is the sandbox's cluster |
| `fromRouteGroup: <param>` | Plan takes a route group name; cluster resolves from the RG (only if RG is bound to one cluster) |
| `fromAnyTarget: <param>` | Plan takes a `RoutingTarget`; the variant decides at execution time |
| `pattern: "<glob>"` | The plan should run on whichever connected cluster matches (e.g. `prod-*`) |

If the plan has no cluster relationship, omit `cluster` — the execution
caller must then specify a cluster explicitly. When you author a
cluster-agnostic plan, surface this to the user up front so they know
they'll need to pass `--cluster <name>` at run time, and offer
`signadot cluster list` if they're not sure which cluster their target
services live on.

### `extraInputs` and `extraOutputs`

Step-level fields that extend an action's declared interface for one
invocation. Use them when the plan needs to wire an additional named
input or output that the action itself didn't declare:

- **`extraInputs`**: any value the action's body needs to read at run
  time that isn't already in the action's declared `params`. The schema
  policy (`extraInputsSchemaPolicy` on the action) controls whether you
  must declare a schema or can omit it.
- **`extraOutputs`**: additional named output files the action's script
  writes to `./outputs/<name>`. Names must not shadow the action's
  declared outputs.

The action's body documents which `extraInputs` / `extraOutputs` make
sense for that action. Read it.

## Common pitfalls

- **Refs and values for the same arg name.** Pick one. If both appear,
  validation rejects the step.
- **Ref source not in scope.** A ref to `steps.foo.outputs.bar` requires
  step `foo` to declare an output `bar` (or for the step to declare
  `bar` as an `extraOutput`). The validator catches this; phrase your
  refs against the actual catalog, not a guess.
- **Drill into a schemaless source.** If you need
  `steps.X.outputs.Y.field`, the action's `\output{Y}` must declare a
  schema. Pick a different action, declare an `extraOutput` with a
  schema, or refactor to consume the whole output and extract the field
  in a composing action.
- **A `condition` referencing something not in `args`.** Conditions
  are [expr-lang](https://github.com/expr-lang/expr) boolean expressions
  evaluated against the step's *resolved args*, not against `params` or
  `steps` directly. Whatever the condition reads must already be in
  `refs` or `values` on the same step.
- **Forgetting `routingContext`.** If the plan operates against a
  sandbox/route group, every step that issues outbound traffic to it
  needs `routingContext` set. See the routing section above.
- **Disabled action referenced in the spec.** `plan create` rejects any
  step whose action is currently disabled in this org. Filter to
  `status.enabled == true` when picking IDs:
  `signadot plan action list -o yaml | yq '.[] | select(.status.enabled == true) | .name'`.

## Running and iterating

After `plan create` returns a plan ID, run it with `signadot plan run`:

```bash
signadot plan run <plan-id> --param sandbox=my-sb --param expected_status=200
# or, if a tag points at the plan:
signadot plan run --tag <tag-name> --param ...
```

Useful flags:

- `--attach` streams structured events (logs, outputs, result) to stdout
  while the execution runs.
- `--param-secret <name>=<secret-name>` for secret values you don't want
  in the command line.

Exit codes: `0` completed, `1` failed, `2` cancelled.

To inspect a finished execution:

```bash
signadot plan x logs <exec-id>                     # aggregated stdout
signadot plan x logs <exec-id> <step-id>           # one step
signadot plan x get-output <exec-id> <name>        # plan-level output
signadot plan x get-output <exec-id> --all --dir ./outputs/
```

If a step failed, read its `error` and `stderr` first — the runner
captures both. If the execution needs a re-run with different params,
just run again — plan executions are at-least-once, action code should
be written idempotently.

### Should I tag this plan?

**Default: no.** The agent's first instinct is to name everything it
creates. Plans don't need names — they need IDs. Names are for things
humans will reference later.

- **Tag** when the plan is reusable: multiple consumers (CI, other
  automation, repeated human invocations) will refer to it by a stable
  name. Re-pointing the tag at a fresh plan is how you ship updates
  without touching consumers.
- **Don't tag** one-off plans, exploratory compositions, or in-progress
  iterations. The plan ID returned by `plan create` is sufficient, and
  stale tags clutter the org's namespace.
- **When re-tagging,** run `signadot plan tag get <name>` first to see
  what you're about to overwrite. `plan tag put` silently re-points;
  if the existing target looks production-ish, confirm with the user
  before clobbering.

## Operational notes

- **Plans are immutable.** Updating a referenced action does *not* affect
  existing plans — the action contract is snapshotted at create time.
  Author a fresh spec and `plan create` again to pick up new revisions.
- **Tags vs IDs.** A plan tag is a thin pointer (`name → planID`).
  `signadot plan tag put <name> --plan <id>` creates or re-points one;
  consumers that hardcode the tag name then pick up new versions
  transparently. *When* to use one: see the "Should I tag this plan?"
  subsection above.
- **Step env vars** the runner sets on every step:
  - `SIGNADOT_PLAN_EXECUTION_ID`, `SIGNADOT_PLAN_STEP_ID`
  - `SIGNADOT_PLAN_WORKDIR` (contains `context/` and `outputs/`)
  - `SIGNADOT_PLAN_BINDIR` (per-execution `bin/`, prepended to PATH)
  - `SIGNADOT_CACHE_DIR` (PRG image cache, used by `actionbox run-image`)
  - `HOME`, `TMPDIR` (per-step writable)
  - With `routingContext`: `SIGNADOT_ROUTING_KEY`,
    `SIGNADOT_SANDBOX_NAME`, `SIGNADOT_ROUTEGROUP_NAME` (subset, depending
    on what the resolved target carries)
- **Don't include secrets in `args.values` literals.** They land in the
  compiled plan body. For caller-provided secrets, declare a plan param
  and use `--param-secret name=secret-ref` at execution time so the
  value resolves through the secrets store.

## Quick reference

| Want to… | How |
|---|---|
| List available actions | `signadot plan action list -o yaml` |
| Filter to enabled actions | `signadot plan action list -o yaml \| yq '.[] \| select(.status.enabled == true) \| .name'` |
| Read one action's body | `signadot plan action get <name> -o yaml` |
| Fetch the plan schema | `signadot plan schema` |
| Create a plan from a spec | `signadot plan create -f plan.yaml -o yaml` |
| Run a plan | `signadot plan run <plan-id> --param k=v` |
| Run via tag | `signadot plan run --tag <name> --param k=v` |
| Stream events as it runs | add `--attach` to `plan run` |
| Read a step's logs | `signadot plan x logs <exec-id> <step-id>` |
| Read a plan output | `signadot plan x get-output <exec-id> <name>` |
| Tag a plan | `signadot plan tag put <name> --plan <plan-id>` |
| Get plan details | `signadot plan get <plan-id>` |
