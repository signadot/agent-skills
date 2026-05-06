---
name: signadot-plan
description: >
  Use this skill to author a Signadot plan spec by hand, submit it via
  `signadot plan create`, run the just-authored plan by ID to verify the
  per-step output matches what you intended, and iterate by re-authoring
  as the result reveals what to fix. The skill covers the full author
  loop end-to-end — discovery (schema, action catalog), composition
  (params, steps, refs, routingContext, output wiring), running and
  inspecting your plan via `signadot plan run` and `signadot plan x
  logs` / `get-output`, and deciding when to tag. It is not for
  explaining plans conceptually or covering surfaces outside spec
  authoring and execution. It does *not* cover running existing tagged
  plans against a sandbox to validate code changes — see the
  `signadot-validate` skill. Concrete authoring tasks it fits: codifying
  a regression you just fixed as a CI gate, building a smoke-check
  flow, or composing a structured assertion (HTTP capture + drill-in +
  boolean check) as a one-off. It points you at the live schema and
  action catalog (discoverability over hardcoding), tells you the
  decision rules the schema can't carry (refs, `routingContext`,
  cluster affinity), and defers per-action rules to the action's body.
---

# Signadot: Authoring and Running Plans

> **Not for explaining plans conceptually.** If the user is asking
> "what are plans," "how do plans work," or wants a tutorial / overview,
> this skill isn't the right fit — point them at the Signadot
> documentation instead. This skill is sized for an agent that needs to
> produce or execute a plan as part of completing a task.

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

Before drafting, inspect the shape of the fields you're about to write
rather than guessing from prose. Common targets:

```bash
# params, output, and the per-step shape — the three you'll author
# directly:
signadot plan schema | jq '.properties.params, .properties.output, .properties.steps.items'

# routingContext and cluster — nullable but structurally tricky:
signadot plan schema | jq '.properties.steps.items.properties.routingContext, .properties.cluster'
```

### 2. Action catalog (org-scoped, dynamic)

Scan the org's actions by name + description; pick from those with
`enabled: true`:

```bash
signadot plan action list -o json | jq '.[] | {name, description: .status.description, enabled: .status.enabled}'
```

Entries with `enabled: false` are gated for this org — `plan create`
will reject any spec that references them. Use them as the answer to
"is this capability available *at all*, even if not right now?" — they
tell you which gated action to name when escalating to the admin.

Once you've picked one, fetch its full body to learn the per-action
rules (declared inputs/outputs, schema policy, anti-patterns):

```bash
signadot plan action get <name> -o json | jq -r .spec.body
```

The body is the action author's contract with you — read it before
wiring the action into a step. Each step's `action.actionID` in the
spec uses the action's `id`, **not** its name; grab the ID from
`signadot plan action get <name> -o json | jq -r .id` (or from the
catalog entry directly).

If the user asks for a capability that no enabled action provides, **say
so explicitly** and offer two options: pick the closest enabled
alternative, or — if a gated entry from the catalog actually fits —
name it explicitly and ask the org admin to enable it.

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
- **Schema controls how a value enters and leaves an action's working
  directory.** *On the input side* — a param or extra_input *with* a
  schema lands as `./context/<name>.json` (raw JSON bytes preserved);
  *without* a schema it lands as `./context/<name>` (raw text — JSON
  string values get unquoted, but objects/arrays become opaque strings
  the consumer sees as text). *On the output side* — symmetric: an
  action script writes schema'd outputs to `./outputs/<name>.json` and
  schemaless ones to `./outputs/<name>`. This matters when extending an
  action via `extraOutputs` — pick the file path the script writes to
  based on whether the extra_output declared a schema. The same rule
  governs drill-in refs: a drill source must declare a schema because
  the runtime needs to walk a parsed value, not a string. When in
  doubt, declare a schema — symptoms of getting this wrong include
  opaque expression-language errors like *"type string has no field X"*
  downstream.

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
signadot plan create -f /tmp/plan.yaml -o json
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

Conversely, **omit `routingContext` entirely when the plan exercises
baseline cluster traffic with no sandbox or route group involved.** The
decision is symmetric: set it when you target an isolated routing
context; leave it unset when you don't.

### Cluster affinity

`spec.cluster` is independent of `routingContext` — cluster decides
*where the runner runs*, `routingContext` decides *how a step directs
traffic*. When the plan is sandbox- or route-group-scoped you typically
set both, often referencing the same param (e.g.
`cluster.fromSandbox: sandbox` plus `routingContext.ref.sandboxRef:
params.sandbox` on every traffic-issuing step). They answer different
questions; setting one does not satisfy the other.

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
- **Arg name not declared on the action.** Every key under `args.refs`
  or `args.values` must match either a declared param of the action or
  an `extraInputs` entry on the step. Wiring a ref to an undeclared
  name is a common first-draft mistake when composing values through
  `eval` or similar — declare the missing name in `extraInputs` first,
  then reference it.
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
  `signadot plan action list -o json | jq '.[] | select(.status.enabled == true) | .name'`.

## Running and iterating

After `plan create` returns a plan ID, run it and read the result as a
single JSON document:

```bash
signadot plan run <plan-id> --param sandbox=my-sb --param expected_status=200 -o json
# or, if a tag points at the plan:
signadot plan run --tag <tag-name> --param ... -o json
```

`-o json` blocks until the execution completes and emits one JSON
object containing the plan's spec (as authored), its status (overall
phase, per-step phases and errors, plan-level outputs), and the
execution's identifying metadata. Logs and output values may be
inlined when small but are not guaranteed to be — for anything beyond
phase / error / "did this step pass" inspection, fetch them
explicitly with the standalone subcommands below. Probe the actual
document shape (with `jq` filters as needed) rather than hardcoding
field paths.

Useful flag: `--param-secret <name>=<secret-name>` for secret values
you don't want in the command line.

Exit codes: `0` completed, `1` failed, `2` cancelled.

To pull logs or outputs reliably (regardless of inline truncation),
or to fetch raw artifact bytes, use the standalone commands keyed by
exec ID:

```bash
signadot plan x logs <exec-id> <step-id>           # one step's logs
signadot plan x get-output <exec-id> <name>        # plan-level output
signadot plan x get-output <exec-id> --all --dir ./outputs/
```

If a step failed, read its error from the run JSON, then `plan x
logs <exec-id> <step-id>` to read its full output. If the execution
needs a re-run with different params, just run again — plan
executions are at-least-once, action code should be written
idempotently.

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
  what you're about to overwrite. `plan tag apply` silently re-points;
  if the existing target looks production-ish, confirm with the user
  before clobbering.
- **If you're authoring a plan that's likely to be tagged, set
  `spec.selectionHint` when you create the plan.** A one-line
  description of *what* the plan does and *when* it's useful — e.g.
  *"Verifies the checkout flow returns 200 on a valid cart; pick
  when you've changed checkout-svc or payment-svc."* The hint
  surfaces on tag-list responses, so an agent scanning the catalog
  of tagged plans can pick by purpose without reading every plan
  body. The hint is part of the plan's spec, not the tag — it has
  to be set when the plan is authored. Tags whose plan has no hint
  force consumers to inspect the plan body or ask the user to
  figure out the tag's purpose.

## Operational notes

- **Plans are immutable.** Updating a referenced action does *not* affect
  existing plans — the action contract is snapshotted at create time.
  Author a fresh spec and `plan create` again to pick up new revisions.
- **Tags vs IDs.** A plan tag is a thin pointer (`name → planID`).
  `signadot plan tag apply <name> --plan <id>` creates or re-points one;
  consumers that hardcode the tag name then pick up new versions
  transparently. *When* to use one: see the "Should I tag this plan?"
  subsection above.
- **Step env vars** the runner sets on every step:
  - `SIGNADOT_PLAN_EXECUTION_ID`, `SIGNADOT_PLAN_STEP_ID`
  - `SIGNADOT_PLAN_WORKDIR` (contains `context/` and `outputs/`)
  - `SIGNADOT_PLAN_BINDIR` (per-execution `bin/`, prepended to PATH)
  - `SIGNADOT_CACHE_DIR` (read-only PRG image cache available to image-backed actions)
  - `HOME`, `TMPDIR` (per-step writable)
  - With `routingContext`: `SIGNADOT_ROUTING_KEY`,
    `SIGNADOT_SANDBOX_NAME`, `SIGNADOT_ROUTEGROUP_NAME` (subset, depending
    on what the resolved target carries)
- **Don't include secrets in `args.values` literals.** They land in the
  compiled plan body. For caller-provided secrets, declare a plan param
  and use `--param-secret name=secret-ref` at execution time so the
  value resolves through the secrets store.
- **`spec.prompt` is for compile-flow plans only.** The field shows up
  populated on plans authored via `plan compile` (where it's the
  natural-language source). When authoring a spec directly, leave it
  absent — the create path doesn't read it.
- **Runner-level failures vs script failures.** If a step fails before
  any script logic runs (image pull errors, runc errors, namespace
  permission denials, missing runner-side dependencies), the plan
  itself is correct — the failure is at the runtime layer, not in
  what you authored. Don't re-author the plan; surface the issue to
  the org admin or substitute an action whose runtime is satisfied in
  this runner. If the error message points at a script error code,
  stderr line, or output the script wrote, that's the script-failure
  case — read the step's `error` and `stderr` and iterate normally.

## Quick reference

Reads use `-o json` (already pretty-printed; pipe through `jq` only
when filtering); writes (`plan create`) use a YAML file.

| Want to… | How |
|---|---|
| Scan actions (name + description + enabled) | `signadot plan action list -o json \| jq '.[] \| {name, description: .status.description, enabled: .status.enabled}'` |
| Read one action's body | `signadot plan action get <name> -o json \| jq -r .spec.body` |
| Get an action's ID for `actionID` | `signadot plan action get <name> -o json \| jq -r .id` |
| Fetch the plan schema | `signadot plan schema` |
| Create a plan from a spec | `signadot plan create -f plan.yaml -o json` |
| Run a plan and read the result | `signadot plan run <plan-id> --param k=v -o json` |
| Run via tag and read the result | `signadot plan run --tag <name> --param k=v -o json` |
| Re-inspect a finished step's logs | `signadot plan x logs <exec-id> <step-id>` |
| Fetch a plan-level output (or its artifact bytes) | `signadot plan x get-output <exec-id> <name>` |
| Tag a plan | `signadot plan tag apply <name> --plan <plan-id>` |
| Get plan details | `signadot plan get <plan-id> -o json` |
