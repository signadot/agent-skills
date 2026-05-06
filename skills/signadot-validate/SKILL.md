---
name: signadot-validate
description: >
  Use this skill when code changes need to be exercised against real microservice
  dependencies running in a Kubernetes cluster — databases, queues, upstream and
  downstream services — without pushing images for every iteration. The skill does
  not prescribe a workflow; it documents the concrete signals Signadot gives you
  (cluster reachability, streamed service logs, sandbox status and endpoints,
  routing-key isolation) and the command that produces each one, so you can pull
  exactly the feedback you need while iterating.
---

# Signadot: Signals for Microservice Validation

You already know how to iterate: implement, test, read the failure, fix, retest.
What this skill gives you is a map of the feedback Signadot can surface while you
do that against a real cluster — so you can choose the cheapest signal for the
question you're asking instead of defaulting to image builds or `kubectl`.

## Signadot MCP Server

A Signadot MCP server may be available directly in this Claude Code session.
**When it is, use it autonomously** — don't ask the user to run CLI commands for
anything the MCP server can do. Discover tools, call them, read the results, and
act on them without pausing for confirmation. The only exceptions are operations
that touch the user's local network stack (see below).

### How to discover available tools

Use `ToolSearch` to find relevant tools before acting. Search by intent, not by
assumed tool name — the MCP tool list can change between sessions:

- `ToolSearch("signadot cluster")` — tools for listing or inspecting clusters
- `ToolSearch("signadot sandbox")` — tools for creating, reading, or updating sandboxes
- `ToolSearch("signadot routegroup")` — tools for managing routegroups
- `ToolSearch("signadot workload endpoint")` — tools for resolving workloads and endpoints
- `ToolSearch("signadot auth")` — tools for checking authentication

Always load a tool's schema via `ToolSearch` before calling it — calling a tool
without a loaded schema will fail with `InputValidationError`.

### When to act autonomously vs delegate to the user

- **Act autonomously via MCP** for anything on the control plane: list clusters,
  inspect or create or update sandboxes and routegroups, resolve workloads and
  endpoints. Do not ask — just do it and report what you found or changed.
- **Delegate to the user** only for commands that touch the local network stack:
  `signadot local connect/disconnect` require sudo on the user's machine. Print
  the command with a leading `!` and wait for confirmation before proceeding.
- **Run directly** (no delegation needed) for `signadot local proxy` and
  `signadot local status` — these are local processes with no sudo requirement.

## What Signadot exposes as signal

| Signal | Where it comes from | Useful for |
|---|---|---|
| **Local process receives real cluster traffic** | **Local-mapped sandbox** (service runs locally, routing key directs traffic to it) | **Default first choice — validate changes against real deps with no image build** |
| Cluster DNS/IP resolvable from your machine | `signadot local connect` | Reaching cluster services by their in-cluster name from a local process or curl |
| Your modified service's stdout/stderr streaming live | Local sandbox | Watching a request land in your code, seeing panics/logs immediately, attaching a debugger |
| Cluster service endpoints mapped to `localhost:<port>` | `signadot local proxy --map http://svc:port@localhost:port` | Hitting an in-cluster service with curl without changing client code |
| Readiness, forks, and routing state of an in-cluster fork | MCP or `signadot sandbox get <name>` | Knowing whether your sandbox is actually up and routing before you test |
| Preview endpoints that deterministically hit your fork | MCP or `signadot sandbox get <name>` (endpoints block) | Driving your forked service with curl from anywhere, no routing header needed |
| Routing-key isolation (header → fork, no header → baseline) | Any sandbox | Proving the change is scoped to your sandbox and not affecting shared traffic |

Reach for an image build only when the service genuinely can't run locally.
Otherwise the local-mapped sandbox is faster and higher-signal.

## Sandbox creation workflow

### Step 0 — agree on what "validated" means

**Before writing any code**, confirm with the user **what kind of validation
will run against it**. The implementation shape often depends on the validation
type — integration tests need a clean seam at the service boundary, Playwright
needs a driveable UI path to the feature, load tools need a stable high-traffic
endpoint. Deciding after the code is written forces rework when the code turns
out to be hard to drive from the chosen tool.

The answer also drives how the sandbox is shaped (which ports are mapped,
whether a browser or a test binary drives it) and how the routing key must be
injected.

**If the user did not specify the validation type, ask.** Offer the supported
options explicitly:

- **Integration tests** — a language-native test suite (e.g. `go test`,
  `pytest`, `npm test`) that hits the service over HTTP/gRPC from inside the
  devbox or from the user's machine.
- **End-to-end tests** — a pre-existing e2e framework run in the repo or CI
  (Cypress, Playwright `npx playwright test`, k6, Smart Tests, etc.).
- **Playwright automation** — ad-hoc browser automation via the Playwright MCP
  tools in this session (click buttons, fill forms, assert UI state).
- **Signadot plan** — a typed DAG of action invocations (typed HTTP
  captures via `request-http`, browser drives via `playwright`, load
  tests via `k6`, boolean assertions via `check`, expression composition
  via `eval`, and others — the catalog grows).
  Plans turn validation into structured, replayable artifacts: each step
  has explicit pass/fail, outputs are typed and inspectable per-step,
  refs let later steps drill into earlier outputs, and routing is a
  first-class concern of the platform — actions integrate with
  `routingContext` directly, so the routing key reaches every outbound
  call without any header-injection plumbing on top.

  Pick this when:
  - The team already has a tagged plan that asserts the validation flow
    you need.
  - You're about to author a check you'd want to *keep* — codifying a
    regression you just fixed, capturing an SLO gate, building a smoke
    test. Tag the new plan and it becomes a CI gate by name.
  - The validation maps onto a curated action from the catalog (`k6`,
    `playwright`, etc.).

  See **"Signadot plan"** under **"Validation types"** below for the
  picker, run command, and result-reading flow. To author a *new* plan
  instead of running an existing tagged one, hand off to the
  `signadot-plan` skill.

Ask a single question, accept one answer, and move on. If the user names a
different tool (Locust, Postman collection, Cypress script, etc.), treat it as
a fourth option and apply the same principle: figure out where the HTTP/gRPC
client lives and how to set the `baggage: sd-routing-key=<key>` header on every
outbound request.

The full setup for each option is documented in **"Validation types"** below —
read that section after the sandbox is up and the routing key is known, and
follow the subsection that matches the chosen validation type.

### Step 1 — resolve cluster and workload

Use MCP tools. Always check `requiresConfirmation` on every response:
- If true on clusters: show list, ask user to pick one.
- If true on workloads: show candidates, ask user to confirm. Never auto-select.
- If true on devboxes: show list, ask user to confirm.

```
ToolSearch("signadot cluster")  → list_clusters
ToolSearch("signadot workload") → resolve_workload  (single-term query only)
ToolSearch("signadot workload") → resolve_workload_port
ToolSearch("signadot sandbox")  → list_devboxes
```

### Step 2 — check if the Claude Code environment is the devbox

`list_devboxes` often returns a devbox whose `metadata.name` matches the current
hostname. **If you are running inside a Claude Code sandbox** (check `hostname`),
look for a matching devbox — if found, you can run the service right here without
needing `signadot local connect` or any user interaction for the tunnel.

```bash
hostname   # compare against devbox metadata.name in list_devboxes output
```

If the current environment is the devbox, use its `id` as `connection.devboxId`
and run the service locally in this session.

### Step 3 — check for existing sandbox definitions

Before creating a sandbox from scratch, check whether the repo already ships
sandbox definitions. Look in `.signadot/` (the standard location):

```bash
ls .signadot/          # top-level: cluster config, CI/PR templates
ls .signadot/dev/      # per-service local dev sandboxes, if present
```

If a matching definition exists, use it (substituting `@{devbox-id}` with the
devbox ID from `list_devboxes`) rather than building the spec from scratch. This
keeps sandbox names and port mappings consistent with what the team expects.

### Step 4 — create the sandbox via MCP

Call `get_workflow_docs` with `topic: "creating_sandbox"` for the full protocol,
then call `create_sandbox` directly. Key points:

- `connection.devboxId` is required whenever `local` workloads are present.
- The `from` workload must come from `resolve_workload` output — never guess names.
- The `port` in mappings must come from `resolve_workload_port` — never guess.
  This is the **workload's container port**, not the Kubernetes Service port.
  Getting this wrong fails silently: the sandbox still reports `ready: true` with
  `connected: true` tunnels, `/etc/hosts` contains no virtual endpoint for that
  mapping, and every baggage-keyed request lands on the baseline pod instead of
  the local process. If routing appears broken despite a ready sandbox, check
  `/etc/hosts` for a `<sandbox-name>-<mapping-name>-*.<namespace>.svc` entry —
  if it is missing, the mapping port is wrong.

### Step 5 — wait for ready

After creating, poll `get_sandbox` until `status.ready = true` AND the tunnel
shows `connected: true`. A sandbox that is ready but whose tunnel is not connected
will not route traffic to your local process.

### Step 6 — pull env and config

**First, check the repo README and CLAUDE.md** for documented run commands. Teams
often document the exact env vars and their format (e.g. `MYSQL_ADDR`, `REDIS_ADDR`,
`KAFKA_BROKER_ADDR`). These are ground truth for what the service expects.

Then attempt the automated pull:

```bash
eval $(signadot sandbox get-env <sandbox-name>)
signadot sandbox get-files <sandbox-name>
```

`get-env` requires `~/.kube/config` to be present. **If it fails or is unavailable,
reconstruct env vars via MCP** — do not skip them:

#### MCP-based env reconstruction

**1. Fetch the workload spec via MCP:**

```
ToolSearch("signadot workload") → get_workload_object
```

Call `get_workload_object` with the workload name and namespace. The response
contains the full container spec including `env` and `envFrom` entries.

**2. Classify each env entry and resolve its value:**

| Entry type | How to resolve |
|---|---|
| `value: "literal"` | Use the literal value directly |
| `valueFrom.configMapKeyRef` | Call `get_workload_object` with `kind: ConfigMap`, same namespace, the named key |
| `valueFrom.secretKeyRef` | Call `get_workload_object` with `kind: Secret`, same namespace — values are base64; decode with `echo <val> \| base64 -d` |
| `envFrom.configMapRef` | Call `get_workload_object` with `kind: ConfigMap` — all keys become env vars |
| `envFrom.secretRef` | Call `get_workload_object` with `kind: Secret` — all keys become env vars |

**3. Resolve in-cluster hostnames** from `/etc/hosts` (the devbox injects entries
in the `242.242.x.x` range as `<svc>.<namespace>` and `<svc>.<namespace>.svc`).
Use these addresses for any `*_ADDR`, `*_HOST`, or `*_URL` vars that reference
cluster services.

**4. Export each var explicitly** before starting the service:

```bash
export VAR1=value1
export VAR2=value2
# ...
<start command — see Step 7>
```

Missing env vars (DB addresses, credentials, feature flags) cause silent failures
that look like code bugs — always resolve them fully before concluding the service
is broken.

**Don't rely on documentation alone for service-to-service addresses.** A service
may call other in-cluster services whose addresses have defaults that only work
inside the cluster (e.g. `other-svc:8081`). Before starting, grep the source for
all address config lookups (e.g. `GetXxxAddr`, `*_ADDR`) and set each one to the
full `.svc` address resolvable from `/etc/hosts`. A missing address will produce
a 500 error on the first real request, not at startup — so starting successfully
is not enough to confirm env vars are correct.

### Step 7 — find and run the service

Before running, locate the correct entrypoint and start command. Read the repo:
- `Makefile`, `package.json` scripts, `Dockerfile`, `README`, `CLAUDE.md` — these
  reveal how the service is normally started
- Never guess the start command — always derive it from the repo

For services with a frontend or compiled UI, check for a `scripts/` directory or
dedicated Makefile target before reaching for `npm run build` / `yarn build`.
Build scripts often do post-processing (asset path rewriting, file copying) that
the bare package manager command skips. Running the wrong build command produces
a binary that silently serves 404s for its own assets with no obvious error at
startup.

**Kill any existing process on the same port** before starting a new instance —
port conflicts produce an immediate fatal error that looks like a code bug:

```bash
fuser -k <port>/tcp 2>/dev/null || true
```

Compile/build before backgrounding so errors surface immediately rather than
silently dying in the background.

**Backgrounding in a devbox:** plain `&` can receive SIGHUP and silently die
(exit code 144). Use `setsid` with a wrapper script:

```bash
cat > /tmp/start_svc.sh << 'EOF'
#!/bin/bash
export VAR=value
exec ./my-service --flag
EOF
chmod +x /tmp/start_svc.sh
setsid /tmp/start_svc.sh >> /tmp/svc.log 2>&1 &
```

If `setsid` immediately after a `pkill` doesn't actually start the new
process (you see no log file, no PID), the parent context is fragile —
fall back to `nohup bash /tmp/start_svc.sh > /tmp/svc.log 2>&1 &` in a
fresh Bash invocation. After any restart, **verify the new PID is alive
and the port is listening** before assuming the service is up; previously
killed processes can linger as zombies (`<defunct>`) and confuse
`pgrep` output.

After starting, verify the process is alive and the port is listening. Also curl
the primary data-fetching endpoint (not just `/healthz`) before opening the
browser — a 500 there will manifest as a blank or stuck "Loading" state in
Playwright, and diagnosing it via curl is far faster than via browser tooling.

## Validation: hitting the service

### The cardinal rule: never test against `localhost:<port>` directly

**Do not use localhost URLs for validation — not even via `signadot local
proxy`.** Hitting `localhost:<port>` (whether the service port directly or a
proxy port) bypasses the cluster routing path. Downstream calls from your local
service go to the cluster **without** the routing key, so sandboxed consumers
never fire and you are only proving your code runs in isolation.

**Always send traffic to the cluster's in-cluster `.svc` URL with the routing
key header.** The devbox `/etc/hosts` has `<svc>.<namespace>.svc` entries in
the `242.242.x.x` range — use these directly:

```bash
# curl: pass routing key via baggage header on the cluster .svc URL
curl -s http://<svc>.<namespace>.svc:<port>/path \
  -H "baggage: sd-routing-key=<routing-key>"

# gRPC
grpcurl -plaintext \
  -H "baggage: sd-routing-key=<routing-key>" \
  -d '{"field":"value"}' \
  <svc>.<namespace>.svc:<port> package.Service/Method
```

The routing key comes from the sandbox's `routingKey` field in the MCP
`create_sandbox` / `get_sandbox` response.

**Use the Service port, not the container port.** Kubernetes Services commonly
expose a different port (e.g. `:80`) than the container's `EXPOSE` (e.g. `:8080`).
Hitting the wrong one returns an Envoy 503 "upstream connect error" that looks
like the pod is unhealthy when in fact the URL is wrong. Resolve the port with
`resolve_workload_port` or `resolve_endpoints` — do not read it off the
Dockerfile or a Deployment container spec. A blanket symptom: curl works from
inside the pod but fails from the devbox with 503 — port, not code.

### Validation types

The validation type you agreed on in **Step 0** determines *how* the routing
key must be plumbed through. The cardinal rule (cluster `.svc` URL + routing
key header) still applies to every option — these subsections just show where
the header is set for each.

#### Integration tests

A language-native test binary (Go, Python, Node, etc.) hitting the service as
a library consumer would.

- **Where to run them**: inside the devbox if the cluster DNS is only reachable
  from there; otherwise the user's machine works too (with `signadot local
  connect` active).
- **Target URL**: cluster `.svc` address — same as curl. Never `localhost:<port>`.
- **Routing key**: inject the `baggage: sd-routing-key=<key>` header on every
  request the test makes. Two common shapes:
  - **The test constructs requests itself** — add the header when building the
    request:
    ```go
    req.Header.Set("baggage", "sd-routing-key="+os.Getenv("SIGNADOT_ROUTING_KEY"))
    ```
  - **The test uses a client library you don't want to touch** — wrap its
    transport once and let every request inherit the header (Go example below;
    other languages have equivalent interceptors):
    ```go
    type baggageRT struct{ base http.RoundTripper; key string }
    func (r *baggageRT) RoundTrip(req *http.Request) (*http.Response, error) {
        req.Header.Set("baggage", "sd-routing-key="+r.key)
        return r.base.RoundTrip(req)
    }
    ```
- **Driving the suite**: export the routing key and target address as env vars,
  then run the suite's normal command:
  ```bash
  export SIGNADOT_ROUTING_KEY=<key>
  export TEST_TARGET_ADDR=<svc>.<ns>.svc:<port>
  go test ./...        # or: pytest, npm test, etc.
  ```
- **If a test skips on a missing env var** (common pattern: `if os.Getenv("X")
  == ""  { t.Skip() }`), set it before `go test` or the test silently passes
  without running.

#### End-to-end tests

A pre-existing e2e framework invoked through the repo's own command (Cypress,
Playwright CLI, k6, Signadot Smart Tests, etc.). The goal is to run the
framework *as the team already runs it*, with the routing key injected at the
one layer that reaches the cluster.

- **First, find how the team runs it.** Check `package.json` scripts, a
  `Makefile` target, `cypress.config.*`, `playwright.config.*`, `.github/workflows/`,
  or the README. Use that exact command — don't invent one.
- **Point the base URL at the cluster `.svc`** via whatever env var the config
  already reads (`CYPRESS_BASE_URL`, `PLAYWRIGHT_BASE_URL`, `BASE_URL`, etc.).
  Grep the config file to confirm the variable name.
- **Attach the routing key once, at the HTTP layer**, so every request carries
  it without modifying individual tests:
  - **Cypress**: `Cypress.on('before:request', ...)` or a support-file
    `beforeEach` that calls `cy.intercept('**', ...)` to inject the header.
  - **Playwright (`npx playwright test`)**: `extraHTTPHeaders` in
    `playwright.config.ts`, or a `page.route('**/*', ...)` hook in a fixture.
  - **k6 / load tools**: add the header to the default `params.headers` in the
    setup block.
  - **Signadot Smart Tests**: `signadot st run --sandbox=<name>` — the CLI
    already attaches the routing key for that sandbox; no manual header needed.
- **Run the suite's existing command** with those env vars set. If the suite
  writes its own report (JUnit XML, Allure, console summary), read that — don't
  re-invent result parsing.
- **If the suite is usually run in CI against a dedicated env**, mirror CI's
  env vars locally; missing ones cause tests to skip or auth to fail.

#### Playwright automation (MCP tools, this session)

Ad-hoc browser automation driven from this Claude Code session via the
Playwright MCP tools — useful for "click the button, look at the page" checks
without authoring a test file.

- **Always inject the routing key via `page.route()` before navigating**, and
  always call `page.unrouteAll()` first — routes from previous
  `browser_run_code` calls persist:
  ```js
  async (page) => {
    await page.unrouteAll();
    await page.route('**/*', async route => {
      await route.continue({
        headers: { ...route.request().headers(), 'baggage': 'sd-routing-key=<key>' }
      });
    });
    await page.goto('http://<frontend-svc>.<namespace>.svc:<port>/');
    await page.waitForLoadState('networkidle');
  }
  ```
- **Navigate to the cluster `.svc` URL**, never to `localhost:<port>`. Same
  cardinal rule as every other validation type.
- **Drive the golden path**: `browser_snapshot` to inspect state,
  `browser_click` / `browser_select_option` / `browser_type` to interact, then
  `browser_snapshot` or `page.evaluate(() => document.body.innerText)` to
  assert the result rendered.
- **Check for runtime errors after each interaction**, not just after load —
  see "Browser / UI validation" below for the blanked-page pattern and the
  exact signals to check.
- **This mode is for exploratory / one-shot validation.** If the checks need to
  be repeatable or run in CI, escalate to "End-to-end tests" and author a real
  test file instead.

#### Signadot plan

A pre-existing tagged plan that asserts the validation flow you need.
The plan is a typed DAG of action invocations (HTTP captures, browser
drives, expression checks, etc.) authored to verify a specific behavior
— pick one whose `selectionHint` matches what you're validating, run it
against your sandbox, read the per-step result.

- **Pick a candidate plan.** Scan the tag catalog by selection hint:
  ```bash
  signadot plan tag list -o json | jq '.[] | {name, selectionHint: .plan.spec.selectionHint}'
  ```
  Each `selectionHint` describes what the plan does and when it's
  useful. Tags whose plan has no hint show `null` — usable but less
  self-evident; ask the user or read the plan body
  (`signadot plan get <plan-id> -o json`) to figure out its
  purpose.

- **Run against your sandbox.** Plans typically take a `sandbox` (or
  `routegroup`) param wired into each step's `routingContext`. Inspect
  the plan's params if you're not sure what it accepts:
  ```bash
  signadot plan tag get <tag> -o json | jq '.plan.spec.params'
  ```
  Then run and read the result as a single JSON document:
  ```bash
  signadot plan run --tag <tag> --param sandbox=<my-sb> -o json
  ```
  The command blocks until completion and emits one JSON object
  containing the plan's spec, its status (overall phase, per-step
  phases and errors, plan-level outputs), and identifying metadata.
  For anything beyond phase/error inspection use the standalone
  `plan x` subcommands below to fetch logs and outputs reliably.
  Exit codes: `0` completed, `1` failed, `2` cancelled. For sensitive
  params, use `--param-secret <name>=<secret-name>` so the value
  resolves through the secrets store.

- **Routing key plumbing is handled by the plan**, not by you. Plan
  steps that carry `routingContext` plumb the routing key into every
  outbound call automatically. There's no `baggage` header to inject
  at the test-framework layer — that's the distinguishing trait of
  the Signadot-plan validation type vs Integration / E2E / Playwright,
  where the routing key has to be wired manually.

- **Read the per-step result.** The run JSON tells you which step
  failed and its error message. To read full logs or fetch output
  values, use the standalone commands keyed by exec ID:
  ```bash
  signadot plan x logs <exec-id> <step-id>        # one step
  signadot plan x get-output <exec-id> <name>     # plan-level output
  ```
  If the plan is correct and the failure is in your code, fix and
  re-run with the same `--tag`. If the plan itself looks wrong (rare
  for tagged plans the team relies on), surface to the plan author
  rather than working around it.

- **No matching plan?** If no tagged plan fits and authoring one would
  be a worthwhile investment (regression coverage, smoke check, SLO
  gate), see the iteration-loop "Before declaring done, consider
  codifying" beat below — and hand off to the `signadot-plan` skill
  for the authoring runbook.

### Routing key propagation through synchronous HTTP/gRPC

For synchronous calls, baggage propagation is **only automatic when the caller
uses an instrumented HTTP/gRPC client** (e.g. `otelhttp`-wrapped transport,
gRPC interceptor, Istio/Envoy sidecar with tracing enabled). A raw
`http.DefaultClient.Do`, Node `fetch`, `requests.get`, etc. will **drop the
routing key** and the upstream call hits the cluster baseline.

This matters most in **new proxy, gateway, or forwarder handlers** where you
are writing the outbound call by hand. If the handler is new code, assume
baggage is not forwarded until proven otherwise. Either:

- Copy the `baggage` header from the incoming request onto the outbound one
  explicitly, or
- Use the service's existing instrumented HTTP client if one exists.

**Diagnostic signal:** the proxy path returns a 404 or stale data that looks
exactly like the cluster baseline response, while a direct call to the local
upstream works. That's baggage propagation failing — the proxy is reaching the
baseline upstream (which lacks the new endpoint / field).

**Anti-pattern — do not do this:** "fix" the proxy by pointing its upstream env
var at `localhost:<port>`. That bypasses the cluster, masks the routing bug,
and the service silently won't work for any consumer that isn't on the same
dev box. Always fix propagation at the hop that drops it.

### Routing key propagation through async protocols

The routing key only reaches downstream services if every intermediate hop
forwards it. **For async protocols (Kafka, SQS, RabbitMQ, etc.) it is never
automatic** — the producer must explicitly copy the baggage into message
headers/metadata, and the consumer must read it back into the request context.

Before testing, read the producer code and confirm the routing key is written
into the message headers/metadata. If it is not, messages dispatched without
the key will be consumed by the baseline cluster service — the sandboxed
consumer will never fire — and tests will appear to work but actually validate
the wrong code path.

Signs that the key is missing from async messages:
- The sandboxed downstream service log shows no activity after a request
- The response looks correct but comes too fast (baseline handled it)
- A feature you know you changed behaves as the old baseline

### Browser / UI validation

Always validate using the browser golden path — don't stop at API checks. The
browser exercises the full stack end-to-end and will surface breakage (blank
fields, wrong values, JS errors) that a curl check misses.

**A passing curl check is not a stopping point.** Do not report success or pause
after confirming a JSON field or API response looks correct via curl. Proceed
directly to the browser golden path — that is the first real signal of whether
the change works end-to-end.

**Use the Playwright MCP tools** (search: `ToolSearch("playwright")`) if they are
available in the session — do not try to run `npx playwright test` or install
browsers. The MCP tools provide `browser_navigate`, `browser_run_code`,
`browser_snapshot`, `browser_click`, `browser_select_option`, etc.

**Inject the routing key on all requests** using `browser_run_code` with
Playwright's `page.route()` API before navigating. Always call `page.unrouteAll()`
first — routes from previous `browser_run_code` calls persist across invocations:

```js
async (page) => {
  await page.unrouteAll();
  await page.route('**/*', async route => {
    await route.continue({
      headers: { ...route.request().headers(), 'baggage': 'sd-routing-key=<key>' }
    });
  });
  await page.goto('http://<frontend-svc>.<namespace>.svc:<port>/');
  await page.waitForLoadState('networkidle');
  // interact, assert, return results
}
```

**Exercise the golden path.** Fill in forms, click buttons, trigger the changed
behavior, verify the result renders correctly. Use `browser_snapshot` to inspect
the accessibility tree and confirm fields are populated.

**Check the page didn't blank after an interaction, not just after load.** An
unhandled runtime error in a React/SPA component (e.g. `TypeError: Cannot read
properties of undefined`) empties the root div — `browser_snapshot` returns an
empty YAML and `document.body.innerText` is empty or tiny. This commonly happens
when a wire-type change (number→string) slips past a `find(x => x.id === id)`
comparison and downstream code dereferences `undefined`. Signal to check:
`browser_console_messages({level:"error"})` after the interaction, plus
`page.content().length` — a healthy SPA page is thousands of bytes.

**Rebuild and restart both sides after a code edit.** If you changed a shared
type touching multiple services (backend + frontend), rebuild each binary/bundle
and restart *every* local process. Restarting only the service whose code you
viewed last is a common source of stale behavior that looks like the fix didn't
work.

## Iteration loop

**Sandbox only what you changed. Run the validation type you agreed on in Step 0.
Let failures tell you what else to fix.**

1. Create a sandbox with only the service(s) you changed running locally —
   but **follow the seam, not just the file**. When a user-visible value is
   computed in more than one place (e.g. a preview rendered by service A and a
   committed value produced by service B), sandbox every service whose code
   path contributes to what the user sees. Sandboxing only one side is a common
   way to ship a silent UI/backend mismatch that passes API-level tests but
   looks wrong in the browser.
2. Run the validation type the user chose in Step 0 — integration tests, e2e
   tests, or Playwright automation. Use the setup from "Validation types".
3. If a check fails:
   - Read the failure: wrong field, blank UI element, JS error, bad API response.
   - Determine the cause: service code bug, wrong env var, a downstream consumer
     that also needs updating, routing key not propagating.
   - Fix it — update the code, add the broken consumer to the sandbox if needed,
     restart the affected service(s).
   - Re-run — **keep the same sandbox** so the routing key stays stable.
4. Only declare done when the full golden path passes.

### A failed validation is not a stopping point — it's the next iteration

When validation fails, **do not stop and write up "validation failed" as if
the task is done**. The whole point of iterating against the cluster is to
turn each failure into a concrete next fix. The default behavior is:

1. Read the failure precisely (status code, error message, stack trace, missing
   UI element). Don't paraphrase — quote it.
2. Identify the smallest cause that explains it. Be honest about whether the
   bug is in code you just changed, in a baseline consumer that wasn't
   rebuilt, in the sandbox shape, or in env/routing setup.
3. Apply the fix and re-run the same validation against the same sandbox.
   Same routing key, same target URL, same browser session if applicable.
4. Repeat until the golden path passes. Only then stop and report.

**Stop and ask the user only when the fix requires a judgment call** they
haven't made — e.g. the requested change is intentionally breaking and they
need to decide between fixing forward (extending the sandbox + rebuilding
consumers), making the change backward-compatible, or accepting the break.
Don't ask for permission to do mechanical fixes (typos, missing env vars,
restarting a process). Just do them.

**Do not declare success after a partial fix.** If you fixed the obvious
break but haven't re-run the full golden path end-to-end, you don't yet know
whether your fix introduced a new failure downstream. Re-run before reporting.

**Before declaring done, consider codifying what you just verified.** When
the bug you just fixed wouldn't have been caught by the existing test
suite, that's a candidate for a Signadot plan: author one now that
asserts the fixed behavior, tag it (with a `selectionHint` describing
what it verifies and when it should fire), and the next regression in the same shape gets
caught by CI before anyone has to iterate on it again. The sandbox is
still up — running the new plan once against it confirms it catches
the bug (or passes for the fixed code), and tagging it makes it the
team's by name. Hand off to the `signadot-plan` skill for the
authoring details.

## Operational notes

- **Sudo-gated commands must be delegated to the user.** `signadot local
  connect` and `signadot local disconnect` modify the local network stack and
  fall in this bucket. Print the command with a leading `!` and wait.
- **A sandbox only needs to contain the services you changed.** Everything else
  is shared from the baseline cluster. If you changed multiple services, put
  them in the same sandbox so they share one routing key.
- **Update, don't recreate.** Re-run sandbox apply or use MCP update with the
  same name. Deleting and recreating churns the routing key and any tests pinned
  to it.
- **When a test fails, check sandbox state first.** Use MCP `get_sandbox` or
  `signadot sandbox get` to verify `ready: true` and tunnel `connected: true`
  before concluding the code is wrong.
- **Never add `defaultRouteGroup.endpoints` to a sandbox without the user explicitly asking.** It creates a publicly accessible preview URL (`*.preview.signadot.com`) — treat it the same as any other externally visible action that requires confirmation.
- **Leave the sandbox up when you finish. Do not auto-delete.** The user may want
  to inspect it, re-test, or keep iterating. At the end of the run, report the
  sandbox name and routing key and surface the delete command as an *option*, not
  an action you take:

  ```
  Sandbox `<name>` (routing key `<key>`) is still up on cluster `<cluster>`.
  Delete when you're done with:
      signadot sandbox delete <name>
  ```

  Only delete if the user explicitly asks. If the user ran
  `signadot local connect` earlier, also mention:
  `! signadot local disconnect` (they run it — requires sudo).
- **Stop local processes you started.** The sandbox stays up, but services you
  launched on the devbox are yours to clean up (`fuser -k <port>/tcp` or kill by
  PID) so ports are free for the next iteration.
- **Go gRPC clients can hang ~30s per channel on SRV DNS.** The default Go gRPC
  resolver does an `_grpclb._tcp.<target>` SRV lookup and waits the full DNS
  timeout (~30s) on clusters that don't publish those records. A service that
  dials N downstream gRPC endpoints at request time can spend N × 30s on a
  single request — looks like a deadlock. Two mitigations: (1) prefix gRPC
  targets with `passthrough:///` (e.g. `passthrough:///cartservice.ns.svc:7070`)
  to skip DNS resolution entirely; (2) dial once at startup and reuse the
  connection. `passthrough:///` only helps on fresh dials, so it does nothing
  for connections already opened at boot.

## Quick reference

| Want to… | How |
|---|---|
| List registered clusters | MCP (search: "signadot cluster") |
| List / inspect sandboxes | MCP (search: "signadot sandbox") |
| Create a sandbox | MCP (search: "signadot sandbox") — call `get_workflow_docs` first |
| Update a sandbox | MCP (search: "signadot sandbox") — call `get_workflow_docs` first |
| Resolve workloads | MCP (search: "signadot workload") — single-term query |
| Resolve endpoints | MCP (search: "signadot workload endpoint") |
| Check if this env is a devbox | `hostname` then compare against `list_devboxes` output |
| Make the cluster reachable locally | `! sudo signadot local connect --cluster <cluster>` (**user runs**) |
| Check the tunnel is up | `signadot local status` |
| Pull env vars for local service | `eval $(signadot sandbox get-env <name>)` — requires kubeconfig; fallback: MCP `get_workload_object` on workload + Secrets/ConfigMaps, then resolve hostnames from `/etc/hosts` (devbox `242.242.x.x` range) |
| Pull config files for local service | `signadot sandbox get-files <name>` |
| Send request with routing key (curl) | `curl -H "baggage: sd-routing-key=<key>" http://<svc>.<ns>.svc:<port>/path` |
| Send request with routing key (grpc) | `grpcurl -H "baggage: sd-routing-key=<key>" -plaintext <svc>.<ns>.svc:<port> Svc/Method` |
| Test browser UI with routing key | Playwright `page.setExtraHTTPHeaders({'baggage':'sd-routing-key=<key>'})` then navigate to cluster `.svc` URL |
| Pick a tagged plan | `signadot plan tag list -o json \| jq '.[] \| {name, selectionHint: .plan.spec.selectionHint}'` |
| Inspect a tagged plan's params | `signadot plan tag get <tag> -o json \| jq '.plan.spec.params'` |
| Run a tagged plan and read the result | `signadot plan run --tag <name> --param sandbox=<my-sb> -o json` |
| Read a plan step's logs | `signadot plan x logs <exec-id> <step-id>` |
| Read a plan-level output | `signadot plan x get-output <exec-id> <name>` |
| Background a service safely | `setsid /tmp/start.sh >> /tmp/svc.log 2>&1 &` (plain `&` can SIGHUP) |
| Tear down a sandbox | `signadot sandbox delete <sandbox-name>` — **surface to the user, do not run unless asked** (leave it up by default) |
| Disconnect | `! signadot local disconnect` (**user runs**) |
