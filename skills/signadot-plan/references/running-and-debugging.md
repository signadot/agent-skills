# Running And Debugging

Create a plan from YAML, then run it by ID or tag. Plan specs are immutable; to
change behavior, author a new spec and create a new plan.

## Create

```bash
signadot plan create -f /tmp/plan.yaml -o json
```

Validation runs at create time and fails on the first issue. Read the exact
error and adjust the spec narrowly. Do not assume array order, action names, or
field shapes when a schema/action lookup can answer.

## Run

```bash
signadot plan run <plan-id> --param sandbox=my-sb --param expected_status=200 -o json
signadot plan run --tag <tag-name> --param k=v -o json
```

Use `--param-secret <name>=<secret-name>` for secret values:

```bash
signadot plan run <plan-id> --param-secret token=my-secret -o json
```

With `-o json`, the CLI blocks until execution completes and emits one JSON
document containing the authored spec, execution status, per-step phases and
errors, plan-level outputs, and identifying metadata. Logs and output values may
be inlined when small, but do not rely on that. Probe the actual JSON shape
with `jq` instead of hardcoding paths.

Exit codes:

| Code | Meaning |
|---|---|
| `0` | Completed |
| `1` | Failed |
| `2` | Cancelled |

## Logs And Outputs

Fetch logs and artifacts by execution ID:

```bash
signadot plan x logs <exec-id> <step-id>
signadot plan x get-output <exec-id> <name>
signadot plan x get-output <exec-id> <step>/<name>
signadot plan x get-output <exec-id> --all --dir ./outputs/
```

Plan-level outputs use the bare `<name>` form. Step-level outputs require
`<step>/<name>`. The CLI can return a generic "output not found" 404 when a
step output is queried as a plan-level output; retry with the step-qualified
form.

If a step failed, read its error from the run JSON, then fetch full step logs.
If the execution needs different params, run the same plan again. If the spec
needs a structural change, create a fresh plan.

Plan executions are at-least-once. Action code should be idempotent.

## Runner Failures Vs Script Failures

If a step fails before script logic runs, the plan may be correct and the
failure may be runtime-layer:

- image pull errors
- runc/container errors
- namespace permission denials
- missing runner-side dependencies

Surface those to the org admin or substitute an action whose runtime is
satisfied in this runner.

If the error points at a script exit code, stderr line, missing context file, or
bad output file, treat it as a script/action invocation failure. Read the action
body, step error, logs, and output artifacts, then iterate normally.

## Step Environment

The runner sets these env vars on every step:

- `SIGNADOT_PLAN_EXECUTION_ID`
- `SIGNADOT_PLAN_STEP_ID`
- `SIGNADOT_PLAN_WORKDIR`, containing `context/` and `outputs/`
- `SIGNADOT_PLAN_BINDIR`, per-execution `bin/` prepended to `PATH`
- `SIGNADOT_CACHE_DIR`, read-only PRG image cache for image-backed actions
- `HOME` and `TMPDIR`, per-step writable

With `routingContext`, the runner also sets a subset of:

- `SIGNADOT_ROUTING_KEY`
- `SIGNADOT_SANDBOX_NAME`
- `SIGNADOT_ROUTEGROUP_NAME`
