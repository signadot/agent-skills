# Validation Types Reference

## Contents

- Shared routing setup
- Integration tests
- Existing e2e suites
- Ad-hoc Playwright automation
- Existing tagged Signadot plans
- Browser golden path checks

## Shared Routing Setup

Use the cluster service URL and Service port:

```bash
http://<svc>.<namespace>.svc:<service-port>/<path>
```

Inject routing headers on every outbound request:

```text
baggage: sd-routing-key=<routing-key>
tracestate: sd-routing-key=<routing-key>
```

If the cluster declares `clusterConfig.routing.customHeaders`, inject every
listed custom header with the routing key value. The cluster may match any one
of them, but application instrumentation can propagate only some headers, so
including all configured names is safest.

Use query-param routing only when the surface cannot set headers. If
`queryParamRouting.enabled: true`, use the cluster's configured parameter name.

## Integration Tests

Run the language-native test suite as the repo expects (`go test`, `pytest`,
`npm test`, etc.).

- Run inside a devbox when cluster DNS is available only there.
- Set the target URL to the cluster `.svc` URL, never `localhost`.
- Inject routing headers in the test client or a shared transport/interceptor.
- Export the routing key and target URL as env vars if the tests are already
  parameterized that way.
- Watch for skipped tests that silently pass when env vars are missing.

Example Go transport:

```go
type routingRT struct {
    base http.RoundTripper
    key  string
}

func (r *routingRT) RoundTrip(req *http.Request) (*http.Response, error) {
    req.Header.Set("baggage", "sd-routing-key="+r.key)
    req.Header.Set("tracestate", "sd-routing-key="+r.key)
    return r.base.RoundTrip(req)
}
```

## Existing E2E Suites

Use the suite exactly as the team runs it. Check `package.json`, Makefiles,
test configs such as `cypress.config.*` and `playwright.config.*`, CI workflows
such as `.github/workflows/`, and READMEs. Do not invent a new command when a
repo command exists.

- Point the base URL at the cluster `.svc` URL using the env/config field the
  suite already reads, such as `CYPRESS_BASE_URL`, `PLAYWRIGHT_BASE_URL`, or
  `BASE_URL`.
- Attach routing headers once at the framework HTTP layer:
  - Cypress: support-file hook such as `Cypress.on('before:request', ...)`, or
    `cy.intercept('**', ...)`.
  - Playwright test runner: `extraHTTPHeaders` or a fixture route hook.
  - k6/load tools: default `params.headers`.
  - Signadot Smart Tests: `signadot st run --sandbox=<name>`; the CLI attaches
    routing.
- Read the suite's native report or console summary, such as JUnit XML or
  Allure output.
- Mirror CI env vars when the suite normally runs in CI.

## Ad-Hoc Playwright Automation

Use available Playwright-compatible tooling for one-shot browser validation.
Before navigation, clear previous routes when state persists, then inject the
routing key on every request:

```js
async (page) => {
  await page.unrouteAll();
  await page.route('**/*', async route => {
    await route.continue({
      headers: {
        ...route.request().headers(),
        'baggage': 'sd-routing-key=<key>',
        'tracestate': 'sd-routing-key=<key>'
      }
    });
  });
  await page.goto('http://<frontend-svc>.<namespace>.svc:<service-port>/');
  await page.waitForLoadState('networkidle');
}
```

If the cluster has custom routing headers, include them in the same route hook.

Then drive the golden path: click, type, select, submit, and inspect rendered
state. Check console errors after interactions, not only after page load.

Use this mode for exploratory checks. If the check must run repeatedly or in CI,
add or update a real e2e test or Signadot plan.

## Existing Tagged Signadot Plans

Use an existing tagged plan when its `selectionHint` matches the behavior being
validated. Plans are typed DAGs of action invocations; common actions include
`request-http`, `playwright`, `k6`, `check`, and `eval`. Plan steps have typed,
inspectable outputs, refs can drill into prior step outputs, and pass/fail is
explicit per step. For plans with `routingContext`, the runner provides routing
context directly to each step, so the plan action usually owns header injection
rather than the test framework.

```bash
signadot plan tag list -o json | jq '.[] | {name, selectionHint: .plan.spec.selectionHint}'
signadot plan run --tag <tag> --param sandbox=<sandbox-name> -o json
```

The run command blocks until completion. Exit codes are commonly `0` completed,
`1` failed, and `2` cancelled.

Read failed steps from the run JSON, then fetch logs or outputs:

```bash
signadot plan x logs <exec-id> <step-id>
signadot plan x get-output <exec-id> <name>
signadot plan x get-output <exec-id> <step>/<name>
```

Use the `signadot-plan` skill for inspecting plan params in detail, handling
`--param-secret`, authoring new plans, or tagging a newly created reusable plan.

## Browser Golden Path Checks

For UI changes, do not stop at a passing API curl. The browser path catches
blank fields, stale frontend bundles, wrong formatting, JavaScript exceptions,
and backend/frontend type drift.

Check:

- initial page rendered
- changed data appears in the UI
- relevant interaction succeeds
- body text or accessibility tree remains populated after interaction
- browser console has no relevant errors
- page content length remains substantial for SPAs
- local service logs show the request hit sandboxed code
