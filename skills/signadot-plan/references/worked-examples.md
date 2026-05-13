# Worked Examples

These examples are intentionally small. Treat them as patterns, not complete
copy/paste specs: fetch the live schema and action body first, then adjust field
names, param declarations, action IDs, and output names to match your org.

## Baseline HTTP Smoke Step

Use this when the plan intentionally tests baseline cluster traffic and does not
target a sandbox or route group.

```yaml
steps:
- id: smoke
  action:
    actionID: <http-request-action-id>
  args:
    values:
      method: GET
      url: http://checkout.default.svc:8080/health
```

No `routingContext` is set because the request is expected to hit baseline.

## Sandbox-Routed HTTP Smoke Step

Use this when a plan param supplies the sandbox name and the request should hit
sandboxed code.

```yaml
cluster:
  fromSandbox: sandbox
steps:
- id: smoke
  routingContext:
    ref:
      sandboxRef: params.sandbox
  action:
    actionID: <http-request-action-id>
  args:
    values:
      method: GET
      url: http://checkout.default.svc:8080/health
```

This sets the routing env vars for the step. The action or step code must still
inject the routing key on outbound requests using the headers or query param
accepted by the target cluster.

## Conditional Diagnostic Step

Conditions read resolved args. Wire any param or step output into the same step
before referencing it from `condition`.

```yaml
steps:
- id: diagnose_bad_status
  action:
    actionID: <diagnostic-action-id>
  args:
    refs:
      actual_status: steps.smoke.outputs.capture.response.statusCode
      expected_status: params.expected_status
  condition: actual_status != expected_status
```

The `capture` output must declare a schema, because the ref drills into
`response.statusCode`.

## Plan Output From A Step Output

Expose only the outputs callers need. Use the schema's exact `output` shape.

```yaml
output:
  refs:
    status: steps.smoke.outputs.capture.response.statusCode
    response_body: steps.smoke.outputs.capture.response.body
```

If the output path drills into a step output, that step output must be schema'd.
