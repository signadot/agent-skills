# Spec Authoring

Compose the spec directly as YAML and submit it with `plan create`. Always check
the live schema for exact field shapes before writing final YAML.

## Step Shape

Each step references its action by ID:

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

The server hydrates the action's body, declared params, outputs,
`extraInputsSchemaPolicy`, and image from the registered action. Do not embed
those fields under `action`.

## Values, Refs, And Extra Inputs

There are three ways to put a value into a step:

| Mechanism | Use for |
|---|---|
| `args.values` | Literal constants such as strings, numbers, booleans, and fixed JSON |
| `args.refs` | Path references into `params.X` or `steps.X.outputs.Y` |
| `extraInputs` | Additional named inputs beyond the action's declared params, wired through `args.refs` or `args.values` |

An arg name appears in `values` or `refs`, never both. Every key under
`args.values` or `args.refs` must match either a declared action param or a
step-level `extraInputs` entry.

## Reference Expressions

Allowed forms:

```text
params.<name>
steps.<id>.outputs.<name>
steps.<id>.outputs.<name>.field
steps.<id>.outputs.<name>[0]
```

Refs are path expressions, not general expressions. Do not use operators,
function calls, conditionals, string concatenation, or templating in refs. To
compose or transform a value, choose a composing action from the catalog and use
the syntax documented in that action body.

Drill-in requires a schema on the source. `params.X.field` works only when
`X` declares a schema. `steps.X.outputs.Y.field` works only when output `Y`
declares a schema. The runtime value must be JSON and no larger than 1 MB;
non-JSON outputs can only be referenced as whole values.

## Schema And File Paths

Schema controls how values enter and leave an action's working directory:

| Direction | With schema | Without schema |
|---|---|---|
| Input | `./context/<name>.json`, raw JSON bytes preserved | `./context/<name>`, raw text |
| Output | `./outputs/<name>.json` | `./outputs/<name>` |

JSON strings passed to a schemaless input arrive unquoted. Objects and arrays
passed to a schemaless input become opaque text to the consumer. When extending
an action through `extraOutputs`, choose the output file path based on whether
the extra output declares a schema. When in doubt, declare a schema. A symptom
of getting this wrong is an opaque expression-language error like *"type string
has no field X"* in a downstream step that tries to drill into the value.

## Conditions

Step `condition` expressions are expr-lang boolean expressions evaluated
against the step's resolved args, not against `params` or `steps` directly.
Whatever the condition reads must already appear in `args.refs` or
`args.values` on the same step.

## Extra Inputs And Outputs

Use `extraInputs` or `extraOutputs` only when the action body supports that
pattern for the invocation:

- `extraInputs` declare additional named inputs the action body reads from
  `./context/`. The action's `extraInputsSchemaPolicy` controls whether schemas
  are required, optional, or forbidden.
- `extraOutputs` declare additional named output files the action script writes
  to `./outputs/`. Names must not shadow declared outputs.

## Secrets

Never put secret values in `args.values`; they land in the compiled plan body.
Declare a plan param and pass the secret at execution time:

```bash
signadot plan run <plan-id> --param-secret token=<secret-name> -o json
```

Do not print secret values in chat or logs. Redact them as `<redacted>` in
summaries.

## Direct Specs Vs Compile Prompts

`spec.prompt` is for compile-flow plans. It shows up populated on plans authored
via `plan compile`, where it is the natural-language source. When authoring a
spec directly, leave `spec.prompt` absent; the create path does not read it.

## Common Validator Failures

| Failure | Fix |
|---|---|
| Same arg in `values` and `refs` | Pick exactly one source |
| Arg name not declared | Use an action param name or add a matching `extraInputs` entry |
| Ref source not in scope | Check step ID, output name, and `extraOutputs` declarations |
| Drill into schemaless source | Add schema, choose another output, or extract through an action |
| Condition reads `params.X` or `steps.X` directly | Wire the value into step args first |
| Disabled action ID | Pick an enabled action or ask an admin to enable the gated one |
