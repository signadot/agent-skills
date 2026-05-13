---
name: signadot-plan
description: >
  Use this skill to author and iterate on Signadot plan specs: discover
  schema/actions, compose params and steps, create/run plans, inspect outputs
  and logs, and tag validated plans. It is not for conceptual explanations or
  running existing tagged plans to validate code changes.
---

# Signadot: Authoring and Running Plans

> **Not for explaining plans conceptually.** If the user asks "what are
> plans," "how do plans work," or wants a tutorial or overview, do not use this
> skill. Point them at Signadot documentation instead. This skill is for
> producing, executing, or iterating on a concrete plan.

A Signadot Plan is an immutable, compiled DAG of action invocations. Each step
invokes one action from the org's catalog and wires inputs from plan params,
literal values, or upstream step outputs. Schema, action availability, and
action contracts are discoverable at runtime; fetch them before authoring.

## Reference Map

Load these one-hop references only when the workflow reaches that topic:

- [references/schema-and-actions.md](references/schema-and-actions.md):
  discovering the plan schema, action catalog, action IDs, disabled actions,
  and action-body contracts.
- [references/spec-authoring.md](references/spec-authoring.md): composing YAML
  specs, refs vs values, drill-in rules, conditions, `extraInputs`,
  `extraOutputs`, secrets, and common validator failures.
- [references/routing-and-cluster.md](references/routing-and-cluster.md):
  `routingContext`, routing-key injection, custom routing headers, query-param
  fallback, and `spec.cluster`.
- [references/running-and-debugging.md](references/running-and-debugging.md):
  create/run commands, execution JSON, logs, output artifacts, exit codes, and
  distinguishing runner failures from script failures.
- [references/tagging.md](references/tagging.md): when to tag, retagging
  safety, and `selectionHint`.
- [references/worked-examples.md](references/worked-examples.md): small plan
  snippets for baseline traffic, sandbox-routed traffic, conditional steps, and
  outputs.

## Core Workflow

1. **Clarify the goal and side effects.** Identify what the plan should prove
   or automate, what target it will run against, and whether creating,
   running, or tagging is expected. Ask only when the target, cluster/routing
   context, or side-effect risk is ambiguous.
2. **Discover the schema and catalog.** Fetch `signadot plan schema` and scan
   enabled actions before drafting. Read
   [schema-and-actions.md](references/schema-and-actions.md).
3. **Choose actions by contract, not by name alone.** For every selected
   action, fetch the action body and ID. The step spec uses
   `action.actionID`, not the action name.
4. **Resolve routing and cluster shape.** If the plan targets a sandbox, route
   group, routing key, or `.svc` URL that should hit isolated code, read
   [routing-and-cluster.md](references/routing-and-cluster.md) before drafting.
5. **Draft the YAML spec.** Compose `params`, `steps`, `output`, and optional
   `cluster`/`runner` directly. Under each step's `action`, include only
   `actionID`; the server snapshots the rest of the action contract at create
   time. Read [spec-authoring.md](references/spec-authoring.md).
6. **Self-check before create.** Verify refs use path expressions only, every
   arg is declared by the action or as an `extraInput`, drill-in sources have a
   schema, conditions read resolved args, secrets are not in literals, and every
   traffic-issuing step has the right routing context.
7. **Create, then inspect validation errors precisely.** Use
   `signadot plan create -f <spec.yaml> -o json`. The server validates at
   create time and fails on the first issue; fix the exact issue rather than
   rewriting broadly.
8. **Run and iterate when needed.** Run by plan ID or tag with `-o json`, fetch
   failed step logs or output artifacts explicitly, then re-run with corrected
   params or a fresh plan spec. Read
   [running-and-debugging.md](references/running-and-debugging.md).
9. **Tag only when the plan is reusable.** Default to leaving one-off plans
   untagged. If a tag is needed, inspect existing tag state before applying and
   add a useful `selectionHint` when creating the plan. Read
   [tagging.md](references/tagging.md).
10. **Close with the durable identifiers and evidence.** Report what was
    created or run, the target, params used, outputs inspected, and any
    remaining operator action.

## Tool Integrations And CLI Use

If an integrated Signadot tool (MCP server, plugin, IDE extension, or similar)
exposes control-plane reads — clusters, sandboxes, route groups, workloads,
endpoints — prefer its output over recalled values. Otherwise use the CLI for
the same reads.

Use the Signadot CLI for plan-specific operations unless an integration clearly
covers the same command:

```bash
signadot plan schema
signadot plan action list -o json
signadot plan action get <name> -o json
signadot plan create -f <spec.yaml> -o json
signadot plan run <plan-id> --param k=v -o json
signadot plan x logs <exec-id> <step-id>
signadot plan x get-output <exec-id> <name>
signadot plan get <plan-id> -o json
signadot plan tag get <name> -o json
signadot plan tag apply <name> --plan <plan-id>
```

## Side-Effect Policy

| Action | Default behavior |
|---|---|
| Read schema, actions, clusters, tags, plans, executions, logs, and outputs | Do autonomously |
| Create an untagged plan for the requested task | Do autonomously when the spec and target are clear |
| Run a newly created plan against a dev/test sandbox or explicit non-production target | Do autonomously when params and cluster/routing target are clear |
| Run any plan against production, shared customer-facing targets, or ambiguous targets | Ask first |
| Apply a new tag requested by the user | Do after confirming it does not already point somewhere important |
| Re-point an existing tag | Inspect with `plan tag get`; ask before overwriting unless the user explicitly requested that exact retag |
| Include secret values in a spec or chat summary | Never; use plan params and `--param-secret` |

## Essential Rules

- **Schema wins.** If this skill conflicts with `signadot plan schema`, follow
  the schema.
- **Actions are org-scoped.** Filter to `status.enabled == true`; disabled
  actions cannot be referenced by a created plan.
- **Plans are immutable.** Updating an action later does not affect existing
  plans. Author a fresh spec and create a new plan to pick up action updates.
- **Step order is dependency-driven.** Array order is not execution order; refs
  imply the DAG.
- **Refs are paths, not expressions.** Use `params.<name>` or
  `steps.<id>.outputs.<name>` with optional drill-in; use a composing action
  for operators, conditionals, string concatenation, or transformations.
- **Drill-in requires schema.** The source param/output must declare a schema
  and the runtime value must be JSON.
- **Routing has two halves.** `routingContext` sets env vars such as
  `SIGNADOT_ROUTING_KEY`; outbound requests still need the routing key injected
  in accepted headers or query params.
- **`spec.cluster` is not `routingContext`.** Cluster decides where the runner
  runs; routing context decides how a step directs traffic.
- **Tagging is optional.** Tags are stable pointers for reusable plans, not a
  default naming mechanism for every draft.
- **Executions are at-least-once.** A step can run more than once across
  retries or re-runs. Action code should be idempotent; do not author plans
  that assume exactly-once execution.

## Quick Reference

Reads use `-o json`; the CLI already pretty-prints JSON, so pipe through `jq`
only when filtering. Writes (`plan create`) use a YAML file.

| Want to... | How |
|---|---|
| Scan actions | `signadot plan action list -o json \| jq '.[] \| {name, description: .status.description, enabled: .status.enabled}'` |
| Read one action body | `signadot plan action get <name> -o json \| jq -r .spec.body` |
| Get action ID | `signadot plan action get <name> -o json \| jq -r .id` |
| Fetch plan schema | `signadot plan schema` |
| Inspect key schema fields | `signadot plan schema \| jq '.properties.params, .properties.output, .properties.steps.items'` |
| Create a plan | `signadot plan create -f plan.yaml -o json` |
| Run by ID | `signadot plan run <plan-id> --param k=v -o json` |
| Run by tag | `signadot plan run --tag <name> --param k=v -o json` |
| Fetch step logs | `signadot plan x logs <exec-id> <step-id>` |
| Fetch plan output | `signadot plan x get-output <exec-id> <name>` |
| Fetch step output | `signadot plan x get-output <exec-id> <step>/<name>` |
| Bulk-fetch all outputs | `signadot plan x get-output <exec-id> --all --dir ./outputs/` |
| Get plan details | `signadot plan get <plan-id> -o json` |
| Inspect a tag | `signadot plan tag get <name> -o json` |
| Tag a plan | `signadot plan tag apply <name> --plan <plan-id>` |

## Final Report

Include the parts that exist for the task:

- Plan ID, execution ID, and tag name if one was created or updated.
- Cluster, sandbox, route group, routing key, or explicit note that the run was
  baseline/cluster-agnostic.
- Params used, with secret values redacted and secret refs named only when safe.
- Action names and IDs selected, especially if a close alternative was used.
- Outputs inspected and the final pass/fail signal.
- Failed step errors, log locations, or artifact commands when unresolved.
- Side effects left behind: untagged plans, retagged names, generated YAML files,
  or any operator follow-up.
